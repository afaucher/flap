class_name CombatSense
extends RefCounted
## What a combat AI bird can see (docs/design/combat_ai.md, 2 and 4.1): the player's information, not the
## simulation's. Each tick it builds the Picture:
##   tracks   other birds it can see -- inside its field of view (the rest a blind cone it looks into every
##            `scan_every` s), within VIEW_RANGE, line of sight clear of the trunks -- each as it was `reaction` s
##            ago, carried on to now along the velocity it had then, with the turn rate it was seen turning at;
##            one it loses is remembered for MEMORY s, carried on along its last velocity.
##   threats  rounds coming at it, as the HUD warns the player (CombatWorld.warnings_for): time to closest approach
##            and miss distance from a rocket's straight line; a seeker taken as guided at it, a hit at its time to go.
##   locked   a lock on it above half (the HUD's lock warning), and where from.
## Line of sight uses ArenaLayout's geometry, refreshed every LOS_EVERY s per bird, never physics queries.

const VIEW_RANGE := 90.0
const MEMORY := 3.0
const LOS_EVERY := 0.15
const HISTORY := 0.9        ## s of past states kept per bird (the reaction delay reads back into it)
const TURN_SPAN := 0.2      ## s over which a bird's turn rate is read from its velocity
const RECKON_STEPS := 4     ## steps along its turn when carrying a seen bird on to now


class Track:
	var bird: Bird
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var turn := 0.0           ## rad/s it is turning about the vertical, as seen (+ = to its right)
	var seen_at := -INF       ## clock when last actually seen
	var visible := false
	var enemy := true
	var seekers := false      ## it carries seekers (its pods show it), not rockets


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
			for l in world.launchers:
				if l.bird == b:
					tr.seekers = int(l.capacity.get(Launcher.Weapon.SEEKERS, 0)) > 0
			_tracks[b] = tr
		tr.enemy = not world.friends(me, b)
		var to := pos - my_pos
		var in_view := to.length() < VIEW_RANGE and (_scanning > 0.0 or fd.angle_to(to) <= half)
		var seen: bool = in_view and _clear(b, my_pos, pos) and not b.is_down()
		if seen or not tr.enemy:   # (teammates call out where they are: always known)
			# What it saw a reaction time ago -- where, how fast, turning how hard -- carried on to now along that turn
			# (a pilot leads for the delay; what the bird did in that moment it can't know).
			var seen_vel: Vector3 = past[2]
			var before: Array = _at(h, float(past[0]) - TURN_SPAN)
			var span := float(past[0]) - float(before[0])
			var v0 := Vector3((before[2] as Vector3).x, 0.0, (before[2] as Vector3).z)
			var v1 := Vector3(seen_vel.x, 0.0, seen_vel.z)
			tr.turn = clampf(-v0.signed_angle_to(v1, Vector3.UP) / span, -6.0, 6.0) if span > 0.05 and v0.length() > 1.0 and v1.length() > 1.0 else 0.0
			var lag := minf(skill.reaction, clock - float(past[0]))
			tr.pos = pos
			tr.vel = seen_vel
			for k in RECKON_STEPS:
				tr.vel = tr.vel.rotated(Vector3.UP, -tr.turn * lag / RECKON_STEPS)
				tr.pos += tr.vel * lag / RECKON_STEPS
			tr.seen_at = clock
			tr.visible = seen
		else:
			tr.visible = false
			tr.pos += tr.vel * dt   # (remembered: carried on along its last velocity)
		if clock - tr.seen_at <= MEMORY:
			pic.tracks.append(tr)
	# What the HUD warns the player of (CombatWorld.warnings_for): rounds coming at it, locks on it. A seeker
	# coming is taken as guided at it; a rocket's miss is from its straight line.
	var w := world.warnings_for(me)
	var my_vel := me.model.velocity
	for r in w.rounds:
		var rel: Vector3 = (r.pos as Vector3) - my_pos
		var rv: Vector3 = (r.vel as Vector3) - my_vel
		var guided: bool = r.kind == Projectile.Kind.SEEKER
		var tgo := clampf(-rel.dot(rv) / maxf(rv.length_squared(), 1e-4), 0.0, 5.0)
		var miss := 0.0 if guided else (rel + rv * tgo).length()
		if guided:
			tgo = float(r.tgo)
		pic.threats.append({"pos": r.pos, "vel": r.vel, "tgo": tgo, "miss": miss, "kind": r.kind, "guided": guided})
	if not (w.locks as Array).is_empty():
		pic.locked = true
		pic.locked_from = w.locks[0].from
	return pic


## Line of sight from `from` to `b` at `to`, through the trunks and branches (cached for LOS_EVERY s).
func _clear(b: Bird, from: Vector3, to: Vector3) -> bool:
	var c: Array = _los.get(b, [-INF, false])
	if clock - float(c[0]) >= LOS_EVERY:
		var own := me.perch.tree_id if me.state == Bird.State.PERCHED and me.perch != null else -1   # (not through the branch it sits on)
		c = [clock, world.layout == null or world.layout.segment_clear(from, to, 0.0, own)]
		_los[b] = c
	return c[1]


## The state in history `h` at time t (the oldest kept if t is before it).
static func _at(h: Array, t: float) -> Array:
	for i in range(h.size() - 1, -1, -1):
		if float(h[i][0]) <= t:
			return h[i]
	return h[0]
