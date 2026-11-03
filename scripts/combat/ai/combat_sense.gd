class_name CombatSense
extends RefCounted
## What a combat AI bird can see (docs/design/combat_ai.md, 2 and 4.1): the player's information, not the
## simulation's. Each tick it builds the Picture:
##   tracks   other birds it can see -- inside its field of view (the rest a blind cone it looks into every
##            `scan_every` s), within VIEW_RANGE, line of sight clear of the trunks -- each as it was `reaction` s
##            ago, carried on to now along the velocity it had then; one it loses is remembered for MEMORY s,
##            carried on along its last velocity.
##   threats  rounds in flight it can see by their smoke (within ROUND_RANGE): time to closest approach and miss
##            distance, from straight-line motion -- or, for a seeker guided at it, a hit at its time to go.
##   locked   enemy launchers holding a lock on it above half (the HUD's lock warning).
## Line of sight uses ArenaLayout's geometry, refreshed every LOS_EVERY s per bird, never physics queries.

const VIEW_RANGE := 90.0
const ROUND_RANGE := 45.0
const MEMORY := 3.0
const LOS_EVERY := 0.15
const HISTORY := 0.6        ## s of past states kept per bird (the reaction delay reads back into it)


class Track:
	var bird: Bird
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var seen_at := -INF       ## clock when last actually seen
	var visible := false
	var enemy := true


class Picture:
	var me: Bird
	var clock := 0.0
	var tracks: Array = []    ## Track, enemies and friends it knows of (visible or remembered)
	var threats: Array = []   ## {pos, vel, tgo, miss, kind, guided}
	var locked := false       ## an enemy holds a lock on it
	var locked_from := Vector3.ZERO

	func enemies() -> Array:
		return tracks.filter(func(t): return t.enemy)

	## The track of `b`, or null.
	func track_of(b: Bird) -> Track:
		for t in tracks:
			if t.bird == b:
				return t
		return null


var me: Bird
var world: CombatWorld
var skill: CombatSkill
var clock := 0.0
var _history := {}          ## Bird -> Array of [t, pos, vel]
var _los := {}              ## Bird -> [clock checked, clear]
var _tracks := {}           ## Bird -> Track
var _next_scan := 0.0
var _scanning := 0.0


func _init(b: Bird, w: CombatWorld, s: CombatSkill) -> void:
	me = b
	world = w
	skill = s


func update(dt: float) -> Picture:
	clock += dt
	var pic := Picture.new()
	pic.me = me
	pic.clock = clock
	var my_pos := me.global_position
	var fd := me.model.flight_dir() if me.state == Bird.State.FLYING else me.facing
	# Checking six: every scan_every s, a short look into the blind cone.
	_scanning = maxf(0.0, _scanning - dt)
	if clock >= _next_scan:
		_next_scan = clock + skill.scan_every
		_scanning = 0.2
	var half := deg_to_rad(skill.view_deg * 0.5)
	for b in world.birds:
		if b == me or not is_instance_valid(b):
			continue
		var h: Array = _history.get(b, [])
		h.append([clock, b.global_position, Projectile.velocity_of(b)])
		while h.size() > 2 and float(h[0][0]) < clock - HISTORY:
			h.pop_front()
		_history[b] = h
		var past: Array = _at(h, clock - skill.reaction)
		var pos: Vector3 = past[1]
		var tr: Track = _tracks.get(b, null)
		if tr == null:
			tr = Track.new()
			tr.bird = b
			_tracks[b] = tr
		tr.enemy = not world.friends(me, b)
		var to := pos - my_pos
		var in_view := to.length() < VIEW_RANGE and (_scanning > 0.0 or fd.angle_to(to) <= half)
		var seen: bool = in_view and _clear(b, my_pos, pos) and not b.is_down()
		if seen or not tr.enemy:   # (teammates call out where they are: always known)
			# What it saw a reaction time ago, carried on to now along that velocity (a pilot leads for the delay;
			# what the bird did in that moment it can't know).
			tr.vel = past[2]
			tr.pos = pos + tr.vel * minf(skill.reaction, clock - float(past[0]))
			tr.seen_at = clock
			tr.visible = seen
		else:
			tr.visible = false
			tr.pos += tr.vel * dt   # (remembered: carried on along its last velocity)
		if clock - tr.seen_at <= MEMORY:
			pic.tracks.append(tr)
	# Rounds in flight, by their smoke.
	var my_vel := me.model.velocity
	for p in world.projectiles:
		if p.shooter == me or not p.alive:
			continue
		var rel: Vector3 = p.pos - my_pos
		if rel.length() > ROUND_RANGE:
			continue
		var rv: Vector3 = p.vel - my_vel
		var guided: bool = p.kind == Projectile.Kind.SEEKER and p.target == me
		var tgo: float
		var miss: float
		if guided:
			tgo = rel.length() / maxf(-rv.dot(rel.normalized()), 1.0)
			miss = 0.0
		else:
			tgo = clampf(-rel.dot(rv) / maxf(rv.length_squared(), 1e-4), 0.0, 5.0)
			miss = (rel + rv * tgo).length()
		if tgo <= 0.0 and not guided:
			continue   # (past it, going away)
		pic.threats.append({"pos": p.pos, "vel": p.vel, "tgo": tgo, "miss": miss, "kind": p.kind, "guided": guided})
	# Lock warnings.
	for l in world.launchers:
		if l.bird != me and is_instance_valid(l.bird) and l.lock_target == me and l.lock > 0.5 and not world.friends(me, l.bird):
			pic.locked = true
			pic.locked_from = l.bird.global_position
	return pic


## Line of sight from `from` to `b` at `to`, through the trunks and branches (cached for LOS_EVERY s).
func _clear(b: Bird, from: Vector3, to: Vector3) -> bool:
	var c: Array = _los.get(b, [-INF, false])
	if clock - float(c[0]) >= LOS_EVERY:
		c = [clock, world.layout == null or world.layout.segment_clear(from, to, 0.0, -1)]
		_los[b] = c
	return c[1]


## The state in history `h` at time t (the oldest kept if t is before it).
static func _at(h: Array, t: float) -> Array:
	for i in range(h.size() - 1, -1, -1):
		if float(h[i][0]) <= t:
			return h[i]
	return h[0]
