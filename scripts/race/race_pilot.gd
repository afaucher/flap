class_name RacePilot
extends RefCounted
## An AI racer. It flies the course's planned line (RaceCourse.flown_line, gate to gate: the line the course was
## proven flyable along, LinePilot / probe_flyable) by an L1 pursuit of a point ahead on it, producing a FlightInput
## and nothing else -- the player's authority exactly. Its skill (CombatSkill's presets, recruit | pilot | ace) takes
## away from a perfect pilot, never adds:
##   look       s of flight ahead it steers for (further: smoother, cuts corners, strays more)  0.8 / 0.65 / 0.55
##   bank_frac  share of the bank limit it uses (CombatSkill)                                    0.7 / 0.85 / 0.95
##   delay      s its inputs lag what it sees (a share of CombatSkill.reaction)                  0.18 / 0.1 / 0.05
##   drift      m (sd) its aim wanders off the line, slowly                                      0.6 / 0.3 / 0.1
##   pace       its cruise against the bird's best glide speed (flaps below it)                  1.0 / 1.05 / 1.12
## Slow (under SLOW x its stall speed: after a bonk, say), AIPilot.steer's low-speed recovery flies until it has speed
## again. A wood guard: if the next 0.4 s straight on meets wood, AIPilot.steer (its avoidance) flies that tick. A ground
## guard pulls up under GROUND_GUARD. Lost (past the next gate's plane without going through it, or STRAY m off the
## line): it goes round, on a path planned from where it is to out in front of the gate (_plan_round, a Dubins path).
## No gate for STUCK s: it gives up (dnf). Every gate taken, it flies home and lands on the start rail as any AI bird
## goes to a perch (AIPilot.go_to_perch: a planned route, the approach and the catch); not home in HOME_STUCK s: dnf.

const SKILL := {   ## name -> [look s, delay share of reaction, drift m, pace]
	"recruit": [0.8, 0.4, 0.6, 1.0],
	"pilot": [0.65, 0.4, 0.3, 1.05],
	"ace": [0.55, 0.4, 0.1, 1.12],
}
const LOOK_MIN := 3.5       ## m
const VERT_LOOK := 0.6      ## s ahead the height it holds is taken from
const DRIFT_TAU := 1.5      ## s: how slowly the aim wanders
const STRAY := 5.0          ## m off the line: lost
const ROUND_MARGIN := 1.15   ## a go-around's circles: this much wider than the bird turns at its speed ...
const ROUND_BANK := 60.0
const ROUND_UP := 3.0       ## m over the gate (or where it is) a go-around's loop climbs to
const ROUND_BLEED := 0.25   ## stick pulled while going round above best glide speed (a tighter turn)    ## ... banked at most this (deg: a turn it can hold its height in)
const GROUND_GUARD := 1.0   ## m, and GROUND_LEAD s of its sink rate more
const GROUND_LEAD := 0.5
const WOOD_AHEAD := 0.4     ## s
const PULL_GAIN := 3.0
const LOW_LINE := 1.0       ## m under its line: it banks at most LOW_BANK deg until it's back up
const LOW_BANK := 45.0
const SLOW := 1.25          ## x stall speed: below it AIPilot.steer (its low-speed recovery) flies ...
const TAKEOFF_TIME := 2.0   ## ... except in the first s off the perch (every bird is slow leaving it)
const BANK_PULL := 0.8
const STUCK := 30.0
const HOME_STUCK := 40.0    ## s from the last gate to land on the rail
const HOME_RETRY := 2.0     ## s between asking AIPilot for the rail again (no route yet, or it landed elsewhere)
const THROUGH := 6.0        ## m past the gate a go-around's run-in runs

var course: RaceCourse
var run: RaceRun
var skill: CombatSkill
var guide: AIPilot
var layout: ArenaLayout
var rng := RandomNumberGenerator.new()
var dnf := false
var go_arounds := 0
var line := PackedVector3Array()
var leg_of := PackedInt32Array()
var leg_start := PackedInt32Array()   ## each leg's first line point
var _i := 0
var _path := PackedVector3Array()    ## the line it's following: the course's, or (going round) a straight run-in to the gate
var _around := false          ## on a go-around's path
var _runin_from := 0
var _took_off := -INF           ## when it left the start perch           ## where that path's run-in to the gate starts
var _drift := Vector2.ZERO
var _queue: Array[FlightInput] = []
var _clock := 0.0
var _last_gate_t := 0.0
var _last_next := 0
var _look := 0.65
var _delay := 0.1
var _drift_sd := 0.3
var _pace := 1.05
var _aim := Vector3.ZERO     ## (this tick's: probes)
var _home_asked := -INF      ## when it last sent AIPilot to the rail


func _init(l: ArenaLayout, c: RaceCourse, r: RaceRun, s: CombatSkill = null, seed := 1) -> void:
	layout = l
	course = c
	run = r
	skill = s if s != null else CombatSkill.preset("pilot")
	guide = AIPilot.new(l, seed)
	rng.seed = seed * 31 + 7
	var k: Array = SKILL.get(skill.name, SKILL["pilot"])
	_look = k[0]
	_delay = skill.reaction * float(k[1])
	_drift_sd = k[2]
	_pace = k[3]
	for g in c.gates.size():
		leg_start.append(line.size())
		var pts := c.flown_line(c.gates, g)
		for j in pts.size() - 1:
			var n := maxi(1, ceili(pts[j].distance_to(pts[j + 1])))
			for q in n:
				line.append(pts[j].lerp(pts[j + 1], float(q) / n))
				leg_of.append(g)
	var last := c.gates[-1]
	for q in 15:
		line.append(last.centre + last.normal * q)
		leg_of.append(c.gates.size() - 1)
	_path = line


func sample(bird: Bird, dt: float) -> FlightInput:
	if guide.turn_radius < 0.0:
		guide._fit(bird)
	_clock += dt
	guide.clock = _clock   # (its take-off from the ground times its rest by this)
	if run.finished() or dnf:
		return guide._hold_glide(bird, dt) if bird.state == Bird.State.FLYING else FlightInput.new()
	if run.home():
		return _home(bird, dt)
	match bird.state:
		Bird.State.PERCHED:
			return _start(bird)
		Bird.State.GROUNDED:
			return guide._grounded(bird)
		Bird.State.LANDING:
			return FlightInput.new()
	if run.next != _last_next:   # (a gate taken: on along the line from the next leg)
		_last_next = run.next
		_last_gate_t = _clock
		_around = false
		if run.next < leg_start.size():
			_i = maxi(_i, leg_start[run.next]) if _path.size() == line.size() else leg_start[run.next]
		_path = line
	if _clock - _last_gate_t > STUCK:
		dnf = true
	var g := course.gates[run.next]
	var pos := bird.global_position
	_i = _nearest(pos, _i, 40)
	var off := pos.distance_to(_path[_i])
	var along := (pos - g.centre).dot(g.normal)
	var past := along > 0.5 and (not _around or _i >= _runin_from)   # (a go-around's loop may swing out past the plane)
	if past or (off > STRAY and (m_speed_ok(bird) or _clock - _took_off <= TAKEOFF_TIME)):
		go_arounds += 1
		_plan_round(bird, g)
	return _delayed(_follow(bird, dt))


## Every gate taken: AIPilot flies it to the start rail and lands (asked again if it has no route yet, or landed on
## another perch).
func _home(bird: Bird, dt: float) -> FlightInput:
	if run.next != _last_next:
		_last_next = run.next
		_last_gate_t = _clock
		guide._last_tree = -1   # (the rail is where it's going now, not the tree it left: no departure clearance round it)
		guide._left_perch = -1
		guide._takeoff_pos = Vector3.INF
	if _clock - _last_gate_t > HOME_STUCK:
		dnf = true
		return FlightInput.new()
	if guide.target != course.start and _clock - _home_asked > HOME_RETRY:
		_home_asked = _clock
		guide.go_to_perch(bird, course.start)
	return guide.sample(bird, dt)


## Fast enough to fly a path (a slow bird recovers first, then plans).
func m_speed_ok(bird: Bird) -> bool:
	return bird.model.speed >= bird.profile.v_stall * SLOW


## On the start perch: turn to face along the first leg, then go.
func _start(bird: Bird) -> FlightInput:
	var to := line[mini(8, line.size() - 1)] - bird.global_position
	var err := AIPilot._signed_heading(bird.facing, to)
	if absf(err) > deg_to_rad(12.0):
		return FlightInput.new(Vector2(clampf(err * 1.5, -1.0, 1.0), 0.0))
	guide._last_tree = bird.perch.tree_id if bird.perch != null else -1
	guide._takeoff_pos = bird.global_position
	_last_gate_t = _clock
	_took_off = _clock
	return FlightInput.new(Vector2.ZERO, true, false)


## Along the line: the L1 pursuit of a point `look` s ahead (plus its drifting aim error), the pull a bank needs,
## flaps to hold its pace or climb; the wood and ground guards.
func _follow(bird: Bird, dt: float) -> FlightInput:
	var m := bird.model
	var p := bird.profile
	var pos := bird.global_position
	var v := maxf(m.speed, 1.0)
	var j := _i
	var walked := 0.0
	while j < _path.size() - 1 and walked < maxf(LOOK_MIN, v * _look):
		walked += _path[j].distance_to(_path[j + 1])
		j += 1
	var tangent := (_path[mini(j + 1, _path.size() - 1)] - _path[maxi(j - 1, 0)]).normalized()
	var side := tangent.cross(Vector3.UP).normalized()
	var w := 1.0 - dt / DRIFT_TAU
	var kick := _drift_sd * sqrt(2.0 * dt / DRIFT_TAU)
	_drift = _drift * w + Vector2(rng.randfn(0.0, kick), rng.randfn(0.0, kick))
	_aim = _path[j] + side * _drift.x + Vector3.UP * _drift.y * 0.6
	# Slow (a bonk, a stall): AIPilot's low-speed recovery flies it until it has speed again.
	if m.speed < p.v_stall * SLOW and _clock - _took_off > TAKEOFF_TIME:
		return guide.steer(bird, _aim, dt, {"bank_frac": skill.bank_frac, "floor": 2.0})
	# The wood guard: straight on meets wood within WOOD_AHEAD s -- the avoidance flies this tick.
	if not layout.segment_clear(pos, pos + m.velocity * WOOD_AHEAD, 0.25, guide._last_tree if _clock - _last_gate_t < 1.0 and run.next == 0 else -1):
		return guide.steer(bird, _aim, dt, {"bank_frac": skill.bank_frac, "floor": 0.8})
	var fd := m.flight_dir()
	var to := Vector3(_aim.x - pos.x, 0.0, _aim.z - pos.z)
	var eta := AIPilot._signed_heading(Vector3(fd.x, 0.0, fd.z).normalized(), to)
	var a_lat := 2.0 * v * v * sin(eta) / maxf(to.length(), 1.0)
	var max_bank := deg_to_rad(p.max_bank_deg) * skill.bank_frac
	if _around:
		max_bank = minf(max_bank, deg_to_rad(ROUND_BANK + 5.0))
	var below := _path[_i].y - pos.y
	if below > LOW_LINE:   # (sinking under the line: keep height before turn)
		max_bank = minf(max_bank, deg_to_rad(LOW_BANK))
	var bank_cmd := clampf(atan(a_lat / BirdProfile.G), -max_bank, max_bank)
	# Height by a nearer point than heading (VERT_LOOK): a fast bird tracks the line's height closely.
	var jv := _i
	walked = 0.0
	while jv < _path.size() - 1 and walked < maxf(LOOK_MIN, v * VERT_LOOK):
		walked += _path[jv].distance_to(_path[jv + 1])
		jv += 1
	var hv := Vector2(_path[jv].x - pos.x, _path[jv].z - pos.z).length()
	var gamma := atan2(_path[jv].y + _drift.y * 0.6 - pos.y, maxf(hv, 1.0))
	var sy := (gamma - m.path_angle) * PULL_GAIN + (1.0 / maxf(cos(m.bank), 0.25) - 1.0) * BANK_PULL
	var flap := m.speed < p.v_best * _pace or gamma > -p.glide_angle * 0.5 or below > 0.3
	if _around and _i < _runin_from and m.speed > p.v_best and below < 0.3:   # (going round: bleed off speed for a tighter turn)
		flap = false
		sy += ROUND_BLEED
	if pos.y - layout.ground(pos.x, pos.z) < GROUND_GUARD + maxf(-m.velocity.y, 0.0) * GROUND_LEAD and m.path_angle < 0.0:
		sy = maxf(sy, 0.4)
		flap = true
	return FlightInput.new(Vector2(bank_cmd / deg_to_rad(p.max_bank_deg), clampf(sy, -0.8, 1.0)), false, flap and (m.energy.burst >= 1.0 or m.speed < p.v_stall * 1.2))


## Round again: a planned path (a Dubins path: turn, straight, turn, on the turning circle the bird has at its speed
## and at most ROUND_BANK, ROUND_MARGIN wider) from where it is, the way it's flying, to a point out in front of the gate facing
## through it (the course's way in and a turning circle more), then the run-in along the gate's axis; it climbs
## ROUND_UP for the loop (a hard turn costs height: a falcon loses ~6 m turning back) and is down at the gate's height
## by the run-in. It follows that as it follows the course's line, and plans again if it strays.
func _plan_round(bird: Bird, g: RaceCourse.Gate) -> void:
	var m := bird.model
	var pos := bird.global_position
	var bank := minf(deg_to_rad(bird.profile.max_bank_deg) * skill.bank_frac, deg_to_rad(ROUND_BANK))
	var r := maxf(4.0, m.speed * m.speed / (BirdProfile.G * tan(bank)) * ROUND_MARGIN)
	var e := g.centre - g.normal * (course.envelope.entry() + r)
	var fd := m.flight_dir()
	var d0 := Vector2(fd.x, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 0.1 else Vector2(g.normal.x, g.normal.z)
	# The shortest of the turn-straight-turn paths that's clear of the wood (else the shortest).
	var ways := dubins_all(Vector2(pos.x, pos.z), d0, Vector2(e.x, e.z), Vector2(g.normal.x, g.normal.z).normalized(), r)
	_path = PackedVector3Array()
	for flat: PackedVector2Array in ways:
		var pts := PackedVector3Array()
		var top := maxf(pos.y, g.centre.y) + ROUND_UP   # (up for the loop: a hard turn costs height; down on the run-in)
		for q in flat.size():
			var f := float(q) / maxf(flat.size() - 1, 1.0)
			var y := lerpf(pos.y, top, smoothstep(0.0, 0.35, f)) if f < 0.6 else lerpf(top, g.centre.y, smoothstep(0.6, 1.0, f))
			pts.append(Vector3(flat[q].x, y, flat[q].y))
		if _path.is_empty():
			_path = pts
		var clear := true
		for q in range(0, pts.size() - 1, 2):
			if not layout.segment_clear(pts[q], pts[mini(q + 2, pts.size() - 1)], bird.profile.span * 0.5 + 0.2):
				clear = false
				break
		if clear:
			_path = pts
			break
	if _path.is_empty():
		_path = PackedVector3Array([pos, e])
	_runin_from = _path.size()
	var n := ceili(e.distance_to(g.centre) + THROUGH)
	for q in range(1, n + 1):
		_path.append(e.lerp(g.centre + g.normal * THROUGH, float(q) / n))
	_i = 0
	_around = true
	_queue.clear()


## The shortest turn-straight-turn path (a Dubins CSC path) from `p` heading `d0` to `q` heading `d1` on circles of
## radius `r`, as points about a metre apart (x, z). If none fits (the ends too close), a straight line.
static func dubins(p: Vector2, d0: Vector2, q: Vector2, d1: Vector2, r: float) -> PackedVector2Array:
	var all := dubins_all(p, d0, q, d1, r)
	return all[0] if not all.is_empty() else PackedVector2Array([p, q])


## Every turn-straight-turn path from `p` heading `d0` to `q` heading `d1` on circles of radius `r`, shortest first
## (dubins).
static func dubins_all(p: Vector2, d0: Vector2, q: Vector2, d1: Vector2, r: float) -> Array:
	var found := []   # [length, points]
	var best_pts := PackedVector2Array()
	for s1: float in [1.0, -1.0]:
		for s2: float in [1.0, -1.0]:
			var c1 := p - r * s1 * Vector2(d0.y, -d0.x)   # (the circle's centre: the bird on it, moving along d0 in sense s1)
			var c2 := q - r * s2 * Vector2(d1.y, -d1.x)
			var v := c2 - c1
			var dd := v.length()
			var u: Vector2
			if s1 == s2:
				if dd < 1e-3:   # (one circle: an arc from p round to q)
					var a := fposmod(s1 * ((q - c1).angle() - (p - c1).angle()), TAU)
					best_pts = PackedVector2Array()
					var na := maxi(1, ceili(r * a))
					for k in na + 1:
						best_pts.append(c1 + (p - c1).rotated(s1 * a * k / na))
					found.append([r * a, _dedup(best_pts)])
					continue
				u = v / dd
			else:
				if dd <= 2.0 * r:
					continue
				var phi := v.angle() + asin(clampf(2.0 * r * s1 / dd, -1.0, 1.0))
				u = Vector2.from_angle(phi)
			var t1 := c1 + r * s1 * Vector2(u.y, -u.x)
			var t2 := c2 + r * s2 * Vector2(u.y, -u.x)
			if s1 != s2:
				t2 = c2 - r * s1 * Vector2(u.y, -u.x)
			var a1 := fposmod(s1 * ((t1 - c1).angle() - (p - c1).angle()), TAU)
			var a2 := fposmod(s2 * ((q - c2).angle() - (t2 - c2).angle()), TAU)
			var length := r * (a1 + a2) + t1.distance_to(t2)
			if true:
				best_pts = PackedVector2Array()
				var n1 := maxi(1, ceili(r * a1))
				for k in n1:
					best_pts.append(c1 + (p - c1).rotated(s1 * a1 * k / n1))
				var nl := maxi(1, ceili(t1.distance_to(t2)))
				for k in nl:
					best_pts.append(t1.lerp(t2, float(k) / nl))
				var n2 := ceili(r * a2)
				for k in n2 + 1:
					best_pts.append(c2 + (t2 - c2).rotated(s2 * a2 * k / maxf(n2, 1.0)))
				found.append([length, _dedup(best_pts)])
	found.sort_custom(func(x, y): return x[0] < y[0])
	return found.map(func(x): return x[1])


static func _dedup(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])   # (no repeated points where one piece meets the next)
	for k in range(1, pts.size()):
		if pts[k].distance_to(out[-1]) > 0.05:
			out.append(pts[k])
	return out


## `inp`, as it was `_delay` s ago (the lag between seeing and moving).
func _delayed(inp: FlightInput) -> FlightInput:
	_queue.append(inp)
	var n := maxi(1, roundi(_delay * 60.0) + 1)
	while _queue.size() > n:
		_queue.pop_front()
	return _queue[0]


## The nearest line point to `pos` from `from`, looking `span` points on.
func _nearest(pos: Vector3, from: int, span: int) -> int:
	var best := INF
	var at := from
	for j in range(from, mini(from + span, _path.size() - 1) + 1):
		var d := pos.distance_squared_to(_path[j])
		if d < best:
			best = d
			at = j
	return at
