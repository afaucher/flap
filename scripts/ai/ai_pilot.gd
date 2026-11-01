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

var _min_dist := INF
var _progress_clock := 0.0
var _last_tree := -1
var _stick := Vector2.ZERO


func _init(l: ArenaLayout, s := 1) -> void:
	rng.seed = s
	planner = FlightPlanner.new(l)


func sample(bird: Bird, dt: float) -> FlightInput:
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
		_last_tree = bird.perch.tree_id if bird.perch != null else -1
		rest_until = clock + rng.randf_range(0.6, 1.5)
		target = null
	var stamina: float = bird.model.energy.stamina
	if clock < rest_until or stamina < 0.5:
		return FlightInput.new()
	# Pick where to go before letting go, so the drop-off already heads there.
	if target == null and not _choose_target(bird):
		rest_until = clock + 1.0
		return FlightInput.new()
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
	var climb_budget: float = -2.0 + 10.0 * e.stamina * (0.5 + 0.5 * e.burst_fraction())
	var best: Perch = null
	var best_score := -INF
	for cand in bird.layout.perches:
		if cand.tree_id == _last_tree:
			continue
		var d := Vector2(cand.position.x - pos.x, cand.position.z - pos.z).length()
		if d < 12.0 or d > 70.0:
			continue
		if cand.position.y < 2.0 + p.v_stall * 0.35:
			continue   # too low to approach at this bird's speeds
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
	if best == null:
		return false
	target = best
	_replan(bird)
	return true


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
	desired = _avoid(bird, desired, dt)

	# --- Lateral: bank toward the desired heading -------------------------------------------------
	var fd := m.flight_dir()
	var h_err := _signed_heading(fd, desired)
	var max_bank := deg_to_rad(p.max_bank_deg)
	# A steep bank sheds vertical lift: near the ground, bank gently.
	var bank_room := deg_to_rad(lerpf(25.0, p.max_bank_deg * 0.85, clampf((pos.y - 1.5) / 6.0, 0.0, 1.0)))
	var bank_cmd := clampf(h_err * 2.2, -bank_room, bank_room)
	var sx := bank_cmd / max_bank

	# --- Longitudinal: path angle toward the aim point, speed protection --------------------------
	var horiz := Vector2(aim.x - pos.x, aim.z - pos.z).length()
	var gamma_cmd := clampf(atan2(aim.y - pos.y, maxf(horiz, 1.0)), deg_to_rad(-35.0), deg_to_rad(25.0))
	var sy := clampf((gamma_cmd - m.path_angle) * 3.0, -0.8, 0.75)
	var want_flap := gamma_cmd > -p.glide_angle + deg_to_rad(1.5) or m.speed < p.v_best * 0.9
	if final and dist_perch < 10.0:
		# Bleed speed for the catch: pull harder the faster we are; no flapping unless sinking below it.
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
	if m.speed < p.v_stall * 1.1 and not (final and dist_perch < 4.0):
		sy = minf(sy, -0.25)
		want_flap = true
	if m.stalled:
		sy = minf(sy, -0.3)
	var energy_ok: bool = m.energy.burst >= 1.0 or m.energy.stamina > 0.3
	_stick = _stick.lerp(Vector2(sx, sy), 1.0 - exp(-10.0 * dt))

	# --- SPACE: catch when the bird says it's on; otherwise a flap ---------------------------------
	var catch_on := bird.candidate == target and bird.candidate_status == Perch.Catch.OK
	if catch_on:
		return FlightInput.new(_stick, true, false)
	# Missed it (flew past), or circling it with the perch out of the forward cone: go around (re-plan out
	# through the approach points).
	var to_perch := (target.position - pos).normalized()
	var off_cone := final and dist_perch < 12.0 and dist_perch > 2.0 and fd.dot(to_perch) < 0.3 and clock - _progress_clock > 1.5
	if (final and dist_perch > 4.0 and _min_dist < 2.5 and dist_perch > _min_dist + 2.0) or off_cone:
		_replan(bird)
	var hold := want_flap and energy_ok
	return FlightInput.new(_stick, false, hold)


## Glide straight ahead (no goal): wings level, best glide, flap to keep off the ground.
func _hold_glide(bird: Bird) -> FlightInput:
	var low := bird.global_position.y < 6.0
	return FlightInput.new(Vector2(0.0, -0.1 if low else 0.0), false, low)


## Whiskers: sweep the next second of flight; if blocked, return the nearest clear direction.
func _avoid(bird: Bird, desired: Vector3, dt: float) -> Vector3:
	var pos := bird.global_position
	var m := bird.model
	var look := clampf(m.speed * 1.1, 4.0, 18.0)
	var c := 0.6
	var tree := bird.perch.tree_id if bird.perch != null else -1
	var ahead := m.flight_dir()
	var final_tree := target.tree_id if target != null and pos.distance_to(target.position) < 8.0 else -1
	if bird.layout.segment_clear(pos, pos + ahead * look, c, final_tree) and pos.y + ahead.y * look > 1.5:
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


static func _signed_heading(from: Vector3, to: Vector3) -> float:
	var a := atan2(from.x, -from.z)
	var b := atan2(to.x, -to.z)
	return wrapf(b - a, -PI, PI)
