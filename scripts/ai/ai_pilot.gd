class_name AIPilot
extends RefCounted
## An AI bird's controller (docs/design/flight_model.md, "AI pilot"). It produces the same FlightInput a
## player does -- stick and space, nothing else -- from what the bird can see: its own telemetry and the
## arena geometry. Four layers:
##   1. GOAL: pick a perch it can reach on its energy (glide budget from height + a climb budget from
##      stamina), not on the tree it just left.
##   2. ROUTE: FlightPlanner A* through free air to the perch's approach point, then the perch.
##   3. GUIDANCE: bank toward the next waypoint (bank-to-turn), pitch to hold the path angle that reaches
##      it, flap when it must climb or is slow and the energy allows, push when near the stall.
##   4. AVOIDANCE: "whiskers" sweep the next second of flight against the geometry; if blocked, it steers
##      toward the nearest clear direction (sideways first, then up) until clear, then re-plans.
## Arrival: final approach from below, pulling up to bleed speed under the catch speed, SPACE when the
## bird reports the catch is on. A missed catch goes around (re-plans the approach). Perched, it rests
## until its stamina recovers, then drops off and picks the next perch.

enum Mode { PERCHED, CRUISE, FINAL, GROUNDED }

var rng := RandomNumberGenerator.new()
var planner: FlightPlanner
var target: Perch = null
var route: Array[Vector3] = []
var wp := 0
var mode := Mode.PERCHED
var rest_until := 0.0
var clock := 0.0
var avoiding := 0.0
var perches_reached := 0
var replans := 0
var debug_reason := ""
var turn_radius := -1.0         ## m, at cruise (set on the first tick)
var min_perch_height := 0.0

var _min_dist := INF
var _progress_clock := 0.0
var _last_tree := -1
var _stick := Vector2.ZERO


func _init(l: ArenaLayout, s := 1) -> void:
	rng.seed = s
	planner = FlightPlanner.new(l)


## Fit the plan to the bird's turning circle at cruise (v* at 85% of its bank limit): wide turners (hawk
## ~7 m, falcon ~5 m) can't thread the understory's ~5.5 m gaps, so they plan with more clearance and only
## pick perches above the understory.
func _fit(bird: Bird) -> void:
	var p := bird.profile
	turn_radius = p.v_best * p.v_best / (BirdProfile.G * tan(deg_to_rad(p.max_bank_deg * 0.85)))
	planner.clearance = 0.9 + 0.15 * turn_radius
	min_perch_height = 2.0 + p.v_stall * 0.35
	if turn_radius > 4.5:
		min_perch_height = maxf(min_perch_height, ArenaLayout.TIERS[0].h.y + 1.0)


func sample(bird: Bird, dt: float) -> FlightInput:
	if turn_radius < 0.0:
		_fit(bird)
	clock += dt
	match bird.state:
		Bird.State.PERCHED:
			return _perched(bird)
		Bird.State.GROUNDED:
			return _grounded(bird)
		Bird.State.LANDING:
			return FlightInput.new()
	return _fly(bird, dt)


func _perched(bird: Bird) -> FlightInput:
	if mode != Mode.PERCHED:
		mode = Mode.PERCHED
		perches_reached += 1
		rest_until = clock + rng.randf_range(0.6, 1.5)
		target = null
	_last_tree = bird.perch.tree_id if bird.perch != null else -1   # (also for a bird that spawned perched)
	var stamina: float = bird.model.energy.stamina
	if clock < rest_until or stamina < 0.5:
		return FlightInput.new()
	# Pick where to go before letting go, so the drop-off already heads there.
	if target == null:
		_choose_target(bird)
	if target == null or route.is_empty():   # (nothing reachable, or no route to it: wait and retry)
		target = null
		rest_until = clock + 1.0
		return FlightInput.new()
	# Turn on the perch to face the way out (the first leg of the route), then push off with a wingbeat.
	var out := (route[1] - bird.global_position) if route.size() > 1 else (target.position - bird.global_position)
	var err := _signed_heading(bird.facing, out)
	if absf(err) > deg_to_rad(20.0) and clock < rest_until + 3.0:
		return FlightInput.new(Vector2(clampf(err * 1.5, -1.0, 1.0), 0.0))
	mode = Mode.CRUISE
	return FlightInput.new(Vector2.ZERO, true, false)


## On the ground: rest, then take off flapping hard (held flaps carry it up and out).
func _grounded(bird: Bird) -> FlightInput:
	if mode != Mode.GROUNDED:
		mode = Mode.GROUNDED
		rest_until = clock + 1.0
	if clock < rest_until or bird.model.energy.stamina < 0.5:
		return FlightInput.new()
	return FlightInput.new(Vector2.ZERO, true, true)


## Choose a perch: within reach of a glide plus what the stamina can climb, preferring 20-60 m hops.
func _choose_target(bird: Bird) -> bool:
	var pos := bird.global_position
	var p := bird.profile
	var e: EnergyModel = bird.model.energy
	# How high it can afford to climb: energy left, scaled by how good a climber the species is (a crow's
	# sprint and wingbeat = 1; the hawk's small burst makes it ~0.5).
	var climber := minf(1.5, p.burst_max * p.flap_accel / (16.0 * 22.0))
	var climb_budget: float = -2.0 + 10.0 * e.stamina * (0.5 + 0.5 * e.burst_fraction()) * climber
	var best := _best_perch(bird, climb_budget, min_perch_height)
	if best == null:
		# Nothing comfortable in reach (e.g. a hawk down low): accept any perch, and a bigger climb.
		best = _best_perch(bird, climb_budget * 2.0 + 3.0, 2.0 + p.v_stall * 0.35)
	if best == null:
		return false
	target = best
	_replan(bird)
	return true


func _best_perch(bird: Bird, climb_budget: float, floor_y: float) -> Perch:
	var pos := bird.global_position
	var p := bird.profile
	var best: Perch = null
	var best_score := -INF
	for cand in bird.layout.perches:
		if cand.tree_id == _last_tree:
			continue
		var d := Vector2(cand.position.x - pos.x, cand.position.z - pos.z).length()
		if d < 12.0 or d > 70.0:
			continue
		if cand.position.y < floor_y:
			continue   # too low to approach at this bird's speeds and turning circle
		var reach := pos.y - d / (p.glide_ratio * 0.75) + climb_budget
		if cand.position.y > reach:
			continue
		# Prefer 25-40 m hops that go down a little (free energy) over ones that climb.
		var climb := cand.position.y - pos.y
		# ... and perches up in the trees over ones near the ground (safer, and more interesting).
		var score := -absf(d - 32.0) * 0.1 - maxf(0.0, climb) * 0.4 + minf(cand.position.y, 15.0) * 0.15 + rng.randf() * 3.0
		if score > best_score:
			best_score = score
			best = cand
	return best


func _replan(bird: Bird) -> void:
	replans += 1
	route = planner.plan_to_perch(bird.global_position + bird.model.flight_dir() * 0.5, target, bird.profile, _last_tree)
	wp = 1
	_min_dist = INF
	_progress_clock = clock
	if route.is_empty():
		debug_reason = "no route"
		target = null


func _fly(bird: Bird, dt: float) -> FlightInput:
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	if mode == Mode.PERCHED or mode == Mode.GROUNDED:
		mode = Mode.CRUISE
	if target == null:
		if not _choose_target(bird):
			return _hold_glide(bird)
	if route.is_empty():
		return _hold_glide(bird)

	var dist_perch := pos.distance_to(target.position)
	# Progress / stuck watchdog: re-plan if no closer for 8 s, pick a new perch after 3 failed tries.
	if dist_perch < _min_dist - 0.5:
		_min_dist = dist_perch
		_progress_clock = clock
	elif clock - _progress_clock > 8.0:
		if replans > 3:
			replans = 0
			target = null
			return _hold_glide(bird)
		_replan(bird)
		if route.is_empty():
			return _hold_glide(bird)

	# Advance along the route.
	while wp < route.size() - 1:
		var to_wp := route[wp] - pos
		var seg := route[wp] - route[wp - 1]
		if to_wp.length() < 3.0 or (seg.length() > 0.1 and to_wp.dot(seg) < 0.0):
			wp += 1
		else:
			break
	var final := wp >= route.size() - 1
	mode = Mode.FINAL if final else Mode.CRUISE
	var aim := route[wp]
	if final and dist_perch < 6.0:
		aim = target.position + Vector3.UP * 0.2

	var desired := (aim - pos).normalized()
	# A steep bank sheds vertical lift: near the ground, bank gently.
	var bank_room := deg_to_rad(lerpf(25.0, p.max_bank_deg * 0.85, clampf((pos.y - 1.5) / 6.0, 0.0, 1.0)))
	desired = _avoid(bird, desired, dt, bank_room)

	# --- Lateral: bank toward the desired heading -------------------------------------------------
	var fd := m.flight_dir()
	var h_err := _signed_heading(fd, desired)
	var max_bank := deg_to_rad(p.max_bank_deg)
	var bank_cmd := clampf(h_err * 2.2, -bank_room, bank_room)
	var sx := bank_cmd / max_bank

	# --- Longitudinal: path angle toward the aim point, speed protection --------------------------
	var horiz := Vector2(aim.x - pos.x, aim.z - pos.z).length()
	var gamma_cmd := clampf(atan2(aim.y - pos.y, maxf(horiz, 1.0)), deg_to_rad(-35.0), deg_to_rad(25.0))
	var sy := clampf((gamma_cmd - m.path_angle) * 3.0, -0.8, 0.75)
	var want_flap := gamma_cmd > -p.glide_angle + deg_to_rad(1.5) or m.speed < p.v_best * 0.9
	if final and dist_perch < maxf(10.0, m.speed * 1.5):
		# Bleed speed for the catch (earlier the faster we come in): pull harder the faster we are; no
		# flapping unless sinking below it.
		var catch_v := p.grab_speed_max * 0.8
		sy = clampf(sy + (m.speed - catch_v) * 0.12, -0.6, 0.9)
		want_flap = pos.y < target.position.y - 0.3 and m.speed < catch_v
	# Ground guard: below 3 m (and not landing low), climb away and flap -- unless spent, in which case
	# settle onto the ground, rest, and take off again.
	var floor_y := 4.0 if not (final and target.position.y < 5.0) else 0.8
	var spent: bool = m.energy.burst < 1.0 and m.energy.stamina < 0.25
	if pos.y < 1.5 and m.speed < p.v_stall * 1.1 and spent:
		return FlightInput.new(Vector2.ZERO, false, false)
	if pos.y < floor_y:
		want_flap = true
		if m.speed > p.v_stall * 1.25:
			var climb := deg_to_rad(12.0) * (1.0 + (floor_y - pos.y))
			sy = maxf(sy, clampf((climb - m.path_angle) * 3.0, -0.2, 0.75))
		else:
			sy = minf(sy, 0.0)   # too slow to climb away: flap level to build speed first
	# Too slow. With height to spare, push and trade it for speed. Low down, pushing flies into the ground
	# (fatal for a high-stall bird like the falcon), so instead flap hard along a nearly level path with the
	# wings almost level until the speed is back.
	var recovering := false
	if m.speed < p.v_stall * 1.15 and not (final and dist_perch < 4.0):
		want_flap = true
		if pos.y < 6.0:
			recovering = true
			sy = clampf((deg_to_rad(4.0) - m.path_angle) * 3.0, -0.3, 0.4)
			var level := deg_to_rad(15.0) / max_bank
			sx = clampf(sx, -level, level)
		else:
			sy = minf(sy, -0.25)
	if m.stalled and not recovering:
		sy = minf(sy, -0.3)
	# Flap only on a full-strength wingbeat (a weak one costs double stamina) unless recovering low down.
	var energy_ok: bool = m.energy.burst >= 1.0 or recovering
	_stick = _stick.lerp(Vector2(sx, sy), 1.0 - exp(-10.0 * dt))

	# --- SPACE: catch when the bird says it's on; otherwise a flap ---------------------------------
	# Hold catch through the final approach (only once the target is the perch the bird would catch).
	var catch_hold := final and dist_perch < 8.0 and bird.candidate == target
	# Missed it (flew past), or circling it with the perch out of the forward cone: go around (re-plan out
	# through the approach points).
	var to_perch := (target.position - pos).normalized()
	var off_cone := final and dist_perch < 12.0 and dist_perch > 2.0 and fd.dot(to_perch) < 0.3 and clock - _progress_clock > 1.5
	if (final and dist_perch > 4.0 and _min_dist < 2.5 and dist_perch > _min_dist + 2.0) or off_cone:
		_replan(bird)
	var hold := want_flap and energy_ok
	return FlightInput.new(_stick, false, hold, false, catch_hold)


## Glide straight ahead (no goal): wings level, best glide, flap to keep off the ground.
func _hold_glide(bird: Bird) -> FlightInput:
	var low := bird.global_position.y < 6.0
	return FlightInput.new(Vector2(0.0, -0.1 if low else 0.0), false, low)


## Whiskers: sweep ahead; if blocked, return the nearest clear direction. They reach a second of flight or
## 1.3 turn radii at the bank it will use, whichever is longer: a wide-turning bird (hawk, falcon) has to
## start turning away much earlier than a crow.
func _avoid(bird: Bird, desired: Vector3, dt: float, bank_room: float) -> Vector3:
	var pos := bird.global_position
	var m := bird.model
	var radius := m.speed * m.speed / (BirdProfile.G * tan(maxf(bank_room, deg_to_rad(10.0))))
	var look := clampf(maxf(m.speed * 1.1, radius * 1.3), 4.0, 30.0)
	var c := 0.6
	var tree := bird.perch.tree_id if bird.perch != null else -1
	var ahead := m.flight_dir()
	var final_tree := target.tree_id if target != null and pos.distance_to(target.position) < 8.0 else -1
	if _arc_clear(bird, look, c, final_tree) and bird.layout.segment_clear(pos, pos + ahead * look, c, final_tree) and pos.y + ahead.y * look > 1.5:
		avoiding = maxf(0.0, avoiding - dt)
		return desired
	avoiding = 0.5
	# Try directions fanning out from the desired one: sideways, then with a climb.
	var best := desired
	var best_dot := -INF
	for pitch in [0.0, 0.25, -0.15, 0.5]:
		for yaw_deg in [20.0, -20.0, 40.0, -40.0, 65.0, -65.0, 90.0, -90.0]:
			var d := ahead.rotated(Vector3.UP, deg_to_rad(yaw_deg))
			d = (d + Vector3.UP * pitch).normalized()
			if not bird.layout.segment_clear(pos, pos + d * look, c, final_tree):
				continue
			var score := d.dot(desired)
			if score > best_dot:
				best_dot = score
				best = d
		if best_dot > -INF:
			break
	if best_dot == -INF:
		best = (ahead + Vector3.UP).normalized()   # boxed in: climb
	return best


## The path the bird is actually on: an arc at its current bank (turn rate g tan(bank) / v), swept in
## quarter-second chords for `look` metres. A straight whisker misses the trunk a steady turn curves into.
func _arc_clear(bird: Bird, look: float, c: float, ignore_tree: int) -> bool:
	var m := bird.model
	var v := maxf(m.speed, 1.0)
	var omega := BirdProfile.G * tan(clampf(m.bank, -1.4, 1.4)) / v
	var dir := m.flight_dir()
	var p0 := bird.global_position
	var t := 0.0
	var step := 0.25
	while t * v < look:
		dir = dir.rotated(Vector3.UP, -omega * step)
		var p1 := p0 + dir * v * step
		if not bird.layout.segment_clear(p0, p1, c, ignore_tree):
			return false
		p0 = p1
		t += step
	return true


static func _signed_heading(from: Vector3, to: Vector3) -> float:
	var a := atan2(from.x, -from.z)
	var b := atan2(to.x, -to.z)
	return wrapf(b - a, -PI, PI)
