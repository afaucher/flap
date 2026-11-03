class_name FireControl
extends RefCounted
## "Would this round hit?" (docs/design/combat_ai.md, 4.5), answered by flying the real Projectile code forward
## against a dummy that moves as the target was seen moving -- straight, or turning at a given rate -- rather
## than by a hand-tuned cone. Pure and headless: no CombatWorld, no physics.

const STEP := 1.0 / 60.0


## A stand-in target: where it is and how it moves (Projectile reads `global_position` and `model.velocity`).
class Dummy:
	class Motion:
		var velocity := Vector3.ZERO
	var global_position := Vector3.ZERO
	var model := Motion.new()


## The closest a round of `kind` fired now would pass a target at `t_pos` moving at `t_vel`, turning at
## `t_turn` rad/s about the vertical (+ = to its right; 0 = straight on) -- from the start, or (`break_tgo` > 0) only
## once the round is that many seconds from it, as a bird breaks against a seeker it sees coming: m, or INF if it
## bursts on the wood first (`layout`; null = open air). A seeker is fired locked on the target; a rocket flies free.
static func miss(kind: int, muzzle: Vector3, carrier_vel: Vector3, aim: Vector3, t_pos: Vector3, t_vel: Vector3, t_turn := 0.0, layout: ArenaLayout = null, break_tgo := 0.0) -> float:
	return float(_fly(kind, muzzle, carrier_vel, aim, t_pos, t_vel, t_turn, layout, break_tgo).miss)


## Where to point to hit it with a rocket: the quick lead (Engagement.lead_point) corrected by where a real
## rocket passes it, a few times over. Returns the aim point (a world position to fly the gunsight onto).
static func lead(muzzle: Vector3, carrier_vel: Vector3, t_pos: Vector3, t_vel: Vector3, t_turn := 0.0, iterations := 3) -> Vector3:
	var at := Engagement.lead_point(muzzle, carrier_vel.length(), t_pos, t_vel)
	for i in iterations:
		var r := _fly(Projectile.Kind.ROCKET, muzzle, carrier_vel, at - muzzle, t_pos, t_vel, t_turn, null)
		if r.miss == INF:
			break
		at += (r.target as Vector3) - (r.round as Vector3)   # (shift the aim by how far it missed, at the moment it passed)
	return at


## Fly it: {miss (m, INF if it hit the wood first), round and target (where each was at the closest pass)}.
static func _fly(kind: int, muzzle: Vector3, carrier_vel: Vector3, aim: Vector3, t_pos: Vector3, t_vel: Vector3, t_turn: float, layout: ArenaLayout, break_tgo := 0.0) -> Dictionary:
	var d := Dummy.new()
	d.global_position = t_pos
	d.model.velocity = t_vel
	var p := Projectile.launch(kind, muzzle, carrier_vel, aim, null, d)
	var best := {"miss": INF, "round": muzzle, "target": t_pos}
	var life: float = Projectile.SPEC[kind].life
	var t := 0.0
	var no_birds: Array = []
	var turning := break_tgo <= 0.0
	while t < life:
		var from := p.pos
		var ev := p.step(STEP, layout, no_birds)
		if not turning:
			var to := d.global_position - p.pos
			turning = to.length() / maxf((p.vel - d.model.velocity).dot(to.normalized()), 1.0) <= break_tgo
		if turning:
			d.model.velocity = d.model.velocity.rotated(Vector3.UP, -t_turn * STEP)
		d.global_position += d.model.velocity * STEP
		var q := Geometry3D.get_closest_point_to_segment(d.global_position, from, p.pos)
		var dist := q.distance_to(d.global_position)
		if p.travelled >= Projectile.ARM and dist < float(best.miss):
			best = {"miss": dist, "round": q, "target": d.global_position}
		if not ev.is_empty():
			if String(ev.why) == "impact" and float(best.miss) > Projectile.fuse:
				best.miss = INF
			return best
		t += STEP
	return best


## The distance within which a round hurts (its fuse sets it off this close, its blast reaches this far).
static func reach() -> float:
	return Projectile.fuse + CombatWorld.blast
