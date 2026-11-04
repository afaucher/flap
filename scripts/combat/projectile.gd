class_name Projectile
extends RefCounted
## One rocket or seeker in flight (docs/design/combat_concepts.html, "Ranged"): pure simulation, stepped by
## CombatWorld, headless-testable.
##
## ROCKET: unguided. Leaves the launcher at the carrier's velocity plus a kick, burns briefly, then coasts
## under drag and gravity; it lives about a second (~40 m), so it's a short-range weapon you aim by leading.
## SEEKER: launched at a locked target, it steers toward where the target will be (lead pursuit), turning at
## most TURN deg/s -- 1.5x a hawk's turn rate, so a sparrow can out-turn it and a hawk can't. It loses the
## target if the target leaves its GIMBAL cone, then flies on straight.
## Both arm after ARM metres (no bursting in the shooter's face) and burst within use metres of any bird but
## the shooter, measured at the closest point of each step (no tunnelling at ~45 m/s). They also burst on a
## trunk, a branch or the ground, and at the end of their life.
## Targets are anything with `global_position` (and optionally `model.velocity`): Birds, or test dummies.

enum Kind { ROCKET, SEEKER, GUN }

const SPEC := {
	Kind.ROCKET: {"launch": 28.0, "accel": 30.0, "burn": 0.35, "drag": 0.004, "life": 1.0, "turn": 0.0},
	Kind.SEEKER: {"launch": 16.0, "accel": 16.0, "burn": 1.2, "drag": 0.004, "life": 2.2, "turn": 150.0},
	Kind.GUN: {"launch": 95.0, "accel": 0.0, "burn": 0.0, "drag": 0.002, "life": 0.42, "turn": 0.0},
}
const GUN_HIT := 0.25   ## m, a bullet's reach on a target with no profile (test dummies); a bird's: hit_radius
const ARM := 3.0        ## m travelled before the fuse is live
static var fuse := 1.0  ## m, proximity fuse radius (tunable). At 1.5 m with a 2 m blast no break turn mattered;
                         ## at 1.0 / 1.3 an evading sparrow beats seekers about half the time, a crow rarely.
const GIMBAL := 60.0    ## deg, a seeker loses its target outside this cone
const G := 9.81

var kind := Kind.ROCKET
var pos := Vector3.ZERO
var last_pos := Vector3.ZERO   ## where it was a tick ago: it's drawn between the two (CombatWorld, as the birds are)
var vel := Vector3.ZERO
var age := 0.0
var travelled := 0.0
var shooter: Object = null
var target: Object = null   ## a seeker's locked target (null: flying straight)
var alive := true
var id := 0


static func launch(k: int, from: Vector3, carrier_vel: Vector3, aim: Vector3, by: Object, at: Object = null) -> Projectile:
	var p := Projectile.new()
	p.kind = k
	p.pos = from
	p.last_pos = from
	p.vel = carrier_vel + aim.normalized() * float(SPEC[k].launch)
	p.shooter = by
	p.target = at if k == Kind.SEEKER else null
	return p


## How close a bullet must pass `o` to hit it: the bird's own size (its body, or a quarter of its span, whichever is
## more: a crow about 0.27 m, a hawk 0.33, a sparrow 0.09), GUN_HIT for anything without a profile.
static func hit_radius(o: Object) -> float:
	var pr = o.get("profile")
	if pr == null:
		return GUN_HIT
	return maxf(0.6 * float(pr.body_length), 0.25 * float(pr.span))


static func velocity_of(o: Object) -> Vector3:
	var m = o.get("model")
	return m.velocity if m != null else Vector3.ZERO


## Advance by dt. Returns {} while in flight, or the event that ended it:
## {"burst": Vector3, "why": "fuse" | "hit" (a bullet on a bird) | "impact" | "expired", "near": the bird that set off
## the fuse or took the bullet, "surface": what it burst on -- "bird" (a fuse, a bullet), "trunk" (wood: a trunk, a limb,
## an outpost), "ground", "air" (it ran out)}.
func step(dt: float, layout: ArenaLayout, birds: Array) -> Dictionary:
	if not alive:
		return {}
	last_pos = pos
	var s: Dictionary = SPEC[kind]
	age += dt
	var speed := vel.length()
	var dir := vel / speed if speed > 1e-4 else Vector3.FORWARD
	if kind == Kind.SEEKER and target != null:
		if not is_instance_valid(target):
			target = null
		else:
			_guide(dt, s, speed, dir)
			dir = vel.normalized()
	if age < float(s.burn):
		vel += dir * float(s.accel) * dt
	vel -= vel * vel.length() * float(s.drag) * dt
	vel.y -= G * dt
	var prev := pos
	pos += vel * dt
	var was := travelled
	travelled += prev.distance_to(pos)
	if travelled >= ARM:
		# (only the armed part of this step counts)
		var from := prev.lerp(pos, clampf((ARM - was) / maxf(travelled - was, 1e-6), 0.0, 1.0)) if was < ARM else prev
		var gun := kind == Kind.GUN
		var best: Object = null
		var best_d := INF
		var best_q := pos
		for b in birds:
			if b == shooter or not is_instance_valid(b):
				continue
			var bp: Vector3 = b.global_position
			var q := Geometry3D.get_closest_point_to_segment(bp, from, pos)
			if not gun:
				if q.distance_to(bp) <= fuse:
					alive = false
					pos = q
					return {"burst": q, "why": "fuse", "near": b, "surface": "bird"}
				continue
			var d := from.distance_to(q)   # (a bullet takes the first bird it reaches along the step)
			if q.distance_to(bp) <= hit_radius(b) and d < best_d:
				best = b
				best_d = d
				best_q = q
		if best != null:
			alive = false
			pos = best_q
			return {"burst": best_q, "why": "hit", "near": best, "surface": "bird"}
	var floor_y := ArenaLayout.GROUND_Y + (layout.ground(pos.x, pos.z) if layout != null else 0.0)   # (the floor's mounds)
	if pos.y <= floor_y or (layout != null and not layout.segment_clear(prev, pos, 0.0)):
		alive = false
		var surface := "ground" if pos.y <= floor_y else "trunk"
		pos.y = maxf(pos.y, floor_y + 0.05)
		return {"burst": pos, "why": "impact", "surface": surface}
	if age >= float(s.life):
		alive = false
		return {"burst": pos, "why": "expired", "surface": "air"}
	return {}


## Lead pursuit: aim at where the target will be when we get there, turning at most TURN deg/s.
func _guide(dt: float, s: Dictionary, speed: float, dir: Vector3) -> void:
	var tp: Vector3 = target.global_position
	var tv := velocity_of(target)
	var to := tp - pos
	if dir.angle_to(to) > deg_to_rad(GIMBAL):
		target = null   # lost it: fly on straight
		return
	var closing := maxf(speed - tv.dot(to.normalized()), 5.0)
	var want := (tp + tv * (to.length() / closing) - pos).normalized()
	var ang := dir.angle_to(want)
	if ang < 1e-5:
		return
	var axis := dir.cross(want)
	if axis.length() < 1e-6:
		return
	vel = dir.rotated(axis.normalized(), minf(ang, deg_to_rad(float(s.turn)) * dt)) * speed
