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
##   4. AVOIDANCE: the next second or so of flight is predicted the way the bird will fly it (roll rate, turn
##      rate, the bank allowed at that height, the height a bank sheds) and checked against the geometry; if
##      the route's path is blocked, it flies the clear escape (a heading, level, climbing or sinking) that
##      ends nearest the way it wants to go. The trees it is leaving and landing on count too, passed closer.
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
## What the last avoidance check saw, for a view to draw (RouteView; nothing in the flying reads them): the path
## predicted toward the aim, how many seconds of it are clear (`predict_horizon`: all of it), and, while `avoiding`,
## the escape it chose instead (empty when it kept to the route).
var predicted := PackedVector3Array()
var predicted_clear := 0.0
var predict_horizon := 0.0
var escape := PackedVector3Array()
var min_perch_height := 0.0

var _min_dist := INF
var _progress_clock := 0.0
var _last_tree := -1
var _left_perch := -1           ## the perch it last took off from, and where (its tree is passed closer near there)
var _takeoff_pos := Vector3.INF
var _attempt_start := 0.0
var _given_up := {}             ## perch id -> clock until which it isn't picked again (an approach that failed)
const ATTEMPT_TIME := 25.0      ## s to reach a perch before giving it up for GIVE_UP_TIME
const GIVE_UP_TIME := 60.0
var _stick := Vector2.ZERO
var _settling := false          ## steer() let the bird settle onto the ground (spent, low and slow)
var _around_until := -INF       ## clock until which it flies a go-around (_go_around; -INF: not going round)
var _around_dir := Vector3.ZERO
var go_arounds := 0
var lined_up := false           ## the route's last legs are a line-up (_line_up), or one was tried for this route
var _aim_ahead := AIM_AHEAD     ## m along the route it aims ahead (further on a line-up's turn: the bank it needs; to
                                ## the approach point and on, AIM_AHEAD)
var _spiralling := false        ## circling down to lose height before the approach (_spiral)
var _spiral_side := 1.0
var _v_cap := INF               ## this tick's speed for the lift's bank cap (_bank_room; INF: none)


func _init(l: ArenaLayout, s := 1) -> void:
	rng.seed = s
	planner = FlightPlanner.new(l)


## Fit the plan to the bird's turning circle at cruise (v* at 85% of its bank limit): wide turners (hawk
## ~7 m, falcon ~5 m) can't thread the understory's ~5.5 m gaps, so they plan with more clearance and only
## pick perches above the understory.
func _fit(bird: Bird) -> void:
	var p := bird.profile
	turn_radius = cruise_turn_radius(p)
	planner.clearance = plan_clearance(p)
	min_perch_height = 2.0 + p.v_stall * 0.35
	if turn_radius > 4.5:
		min_perch_height = maxf(min_perch_height, ArenaLayout.TIERS[0].h.y + 1.0)


## m, the turning circle at cruise (v* at 85% of the bank limit).
static func cruise_turn_radius(p: BirdProfile) -> float:
	return p.v_best * p.v_best / (BirdProfile.G * tan(deg_to_rad(p.max_bank_deg * 0.85)))


## m, how far its planned routes keep from the wood.
static func plan_clearance(p: BirdProfile) -> float:
	return 0.9 + 0.15 * cruise_turn_radius(p)


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
		bird.candidate_lock = null
		_around_until = -INF
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
	_left_perch = bird.perch.id
	_takeoff_pos = bird.global_position
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
	_attempt_start = clock
	_replan(bird)
	return true


func _best_perch(bird: Bird, climb_budget: float, floor_y: float) -> Perch:
	var pos := bird.global_position
	var p := bird.profile
	var best: Perch = null
	var best_score := -INF
	for cand in bird.layout.perches:
		if cand.tree_id == _last_tree or clock < float(_given_up.get(cand.id, -1.0)):
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
		if cand.fallback:
			score -= 1000.0   # (an edge post: only when nothing else is in reach)
		if score > best_score:
			best_score = score
			best = cand
	return best


## Fly to `perch` and land on it (a combat bird going to rest or to rearm at its base): it becomes the target,
## planned from here; sample() then flies there, lands and rests as for any perch.
func go_to_perch(bird: Bird, perch: Perch) -> void:
	target = perch
	_attempt_start = clock
	_around_until = -INF
	if bird.state == Bird.State.FLYING:
		mode = Mode.CRUISE
	_replan(bird)


## Has it given `perch` up for now (no route in, or an approach that failed)?
func gave_up_on(perch: Perch) -> bool:
	return clock < float(_given_up.get(perch.id, -1.0))


func _replan(bird: Bird) -> void:
	replans += 1
	var p0 := Perf.t()
	var fd := bird.model.flight_dir()
	planner.heading = Vector3(fd.x, 0.0, fd.z).normalized() if bird.state == Bird.State.FLYING and Vector2(fd.x, fd.z).length() > 1e-3 else Vector3.ZERO
	planner.turn_r = _held_radius(bird.profile, maxf(bird.model.speed, bird.profile.v_best), minf(bird.global_position.y, target.position.y)) * LINEUP_MARGIN
	route = planner.plan_to_perch(bird.global_position + bird.model.flight_dir() * 0.5, target, bird.profile, _last_tree, bird.perch.id if bird.perch != null else -1)
	Perf.add("ai.plan", p0)
	wp = 1
	lined_up = false
	_aim_ahead = AIM_AHEAD
	_min_dist = INF
	_progress_clock = clock
	if route.is_empty():
		debug_reason = "no route"
		_given_up[target.id] = clock + GIVE_UP_TIME   # (no way in: don't pick it again straight away)
		target = null


## Missed the catch: go around -- out and up, away from the perch's tree (not on over the deck or into its limbs), for
## about a turning circle and a half, then plan the approach afresh from there.
func _go_around(bird: Bird) -> void:
	var pos := bird.global_position
	var fd := bird.model.flight_dir()
	var h := Vector3(fd.x, 0.0, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 1e-3 else bird.facing
	var t: ArenaLayout.TreeData = bird.layout.trees[target.tree_id] if target.tree_id >= 0 and target.tree_id < bird.layout.trees.size() else null
	var away := Vector3(pos.x - t.base.x, 0.0, pos.z - t.base.y) if t != null else Vector3.ZERO
	_around_dir = (h + away.normalized()).normalized() if away.length() > 0.1 and (h + away.normalized()).length() > 0.1 else h
	var v := maxf(bird.model.speed, 1.0)
	_around_until = clock + clampf(1.5 * _held_radius(bird.profile, v, pos.y) / v, AROUND_TIME.x, AROUND_TIME.y)
	go_arounds += 1
	bird.candidate_lock = null


## Line up for the final: a turn-straight-turn path (Dubins) on the turning circle it holds at its speed (with a
## margin), from where it is and the way it's flying to the approach point, arriving heading in along the way in. The
## planned route doesn't know which way the bird is flying: a wide turner reaching its last points still turning
## overshoots the line onto the perch and misses to the side. Taken in place of the route's last legs if every chord
## is clear of the wood (lineup_clearance) and it isn't long (a turning circle round and LINEUP_PAD m); true if it was.
func _line_up(bird: Bird) -> bool:
	lined_up = true
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	var way := planner.way if planner.way != Vector3.ZERO else target.facing
	var app := FlightPlanner.approach_point(target, p, way)
	app.y = maxf(app.y, planner.clearance + 0.5)
	var r := _held_radius(p, maxf(m.speed, p.v_best), minf(pos.y, app.y)) * LINEUP_MARGIN
	var fd := m.flight_dir()
	var d0 := Vector2(fd.x, fd.z)
	if d0.length() < 1e-3:
		return false
	if FlightPlanner.on_line(target, p, way, pos, Vector3(fd.x, 0.0, fd.z).normalized()):
		# (In on the line already: on to the approach point if it's still ahead, then in.)
		var along := (app - pos).dot(-Vector3(way.x, 0.0, way.z).normalized())
		var straight: Array[Vector3] = [pos]
		if along > AIM_AHEAD:
			straight.append(app)
		straight.append(target.approach_anchor())
		route = straight
		wp = 1
		return true
	var p0 := Perf.t()
	for flat: PackedVector2Array in Dubins.all(Vector2(pos.x, pos.z), d0.normalized(), Vector2(app.x, app.z), Vector2(-way.x, -way.z).normalized(), r):
		var n := flat.size()
		if n < 2 or n > TAU * r + LINEUP_PAD:
			continue
		var pts: Array[Vector3] = []
		for q in n:
			pts.append(Vector3(flat[q].x, lerpf(pos.y, app.y, smoothstep(0.0, 1.0, float(q) / (n - 1))), flat[q].y))
		var clear := true
		for q in range(0, n - 1, 2):
			if not bird.layout.segment_clear(pts[q], pts[mini(q + 2, n - 1)], lineup_clearance(p)):
				clear = false
				break
		if clear:
			pts[0] = pos
			pts.append(target.approach_anchor())
			route = pts
			wp = 1
			_aim_ahead = maxf(AIM_AHEAD, r * 0.8)   # (the bank the turn needs, by the guidance's own law)
			Perf.add("ai.plan", p0)
			return true
	Perf.add("ai.plan", p0)
	return false


## Energy for the final: the height over the approach point and the speed over cruise (as height), less what a glide
## that brakes a little loses on the way there (DESCENT_GRADE per metre). Far over (SPIRAL_START m), it circles down
## where it is -- a turn its lift holds, gliding steeply, no wingbeats -- until it's nearly back on (SPIRAL_STOP), then
## plans the rest from there: diving the height away would arrive too fast to catch, and a bird can't brake while
## it's still coming down. The FlightInput of a tick spent circling, or null.
func _spiral(bird: Bird, dt: float) -> FlightInput:
	if route.size() < 3 or wp >= route.size() - 1:
		_spiralling = false
		return null
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	var app := route[route.size() - 2]
	var excess := (pos.y - app.y) + (m.speed * m.speed - p.v_best * p.v_best) / (2.0 * BirdProfile.G) 			- Vector2(app.x - pos.x, app.z - pos.z).length() * DESCENT_GRADE / p.glide_ratio
	if excess > SPIRAL_START or (_spiralling and excess > SPIRAL_STOP):
		if not _spiralling:
			_spiralling = true
			_spiral_side = -1.0 if _signed_heading(m.flight_dir(), app - pos) < 0.0 else 1.0   # (turning toward where it's going)
		var r := _held_radius(p, maxf(m.speed, p.v_best), pos.y)
		var fd := m.flight_dir()
		var ahead := Vector3(fd.x, 0.0, fd.z).normalized().rotated(Vector3.UP, -_spiral_side * 0.9)
		var inp := steer(bird, pos + ahead * r, dt, {"gamma": -SPIRAL_GAMMA, "flap": "none", "lift_cap": true, "cruise": p.v_best})
		_progress_clock = clock   # (circling down is progress)
		return inp if _settling else FlightInput.new(inp.stick, false, inp.flap_held)
	if _spiralling:
		_spiralling = false
		_replan(bird)
		if route.is_empty():   # (no way on from here: glide on, and choose again)
			return _hold_glide(bird, dt)
	return null


## m a line-up's path keeps from the wood: half a wingspan and a margin, at least the avoidance's own (a line-up is
## flown with the avoidance on; the planner's wider berth is for routes it hasn't turned onto yet).
static func lineup_clearance(p: BirdProfile) -> float:
	return maxf(WHISKER_CLEARANCE + 0.2, p.span * 0.5 + 0.35)


## m, its turning circle at speed v and height y: the bank it holds there (held_bank) within what guidance allows at
## that height (_bank_room: its usual 85% of the limit, less near the ground).
static func _held_radius(p: BirdProfile, v: float, y := INF) -> float:
	return v * v / (BirdProfile.G * tan(_bank_room(p, y, 0.85, v)))


func _fly(bird: Bird, dt: float) -> FlightInput:
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	if mode == Mode.PERCHED or mode == Mode.GROUNDED:
		mode = Mode.CRUISE
	if target == null:
		if not _choose_target(bird):
			return _hold_glide(bird, dt)
	if route.is_empty():
		return _hold_glide(bird, dt)

	var dist_perch := target.distance_to(pos)   # (to the nearest grip point on the branch)
	# Progress / stuck watchdog: re-plan if no closer for 8 s, pick a new perch after 3 failed tries or when it
	# hasn't got there in ATTEMPT_TIME (circling a perch it can't make the approach to, coming close each time),
	# and leave that one alone for a while.
	if clock - _attempt_start > ATTEMPT_TIME:
		return _give_up(bird, dt)
	if _around_until > -INF:
		if clock < _around_until:   # (going around: out and climbing, then a fresh approach)
			var ga := steer(bird, pos + _around_dir * 20.0 + Vector3.UP * 4.0, dt, {"cruise": p.v_best, "lift_cap": true})
			return ga if _settling else FlightInput.new(ga.stick, false, ga.flap_held)
		_around_until = -INF
		_replan(bird)
		if route.is_empty():
			return _hold_glide(bird, dt)
	if dist_perch < _min_dist - 0.5:
		_min_dist = dist_perch
		_progress_clock = clock
	elif clock - _progress_clock > 8.0:
		if replans > 3:
			return _give_up(bird, dt)
		_replan(bird)
		if route.is_empty():
			return _hold_glide(bird, dt)

	# Too much energy for the way left (high above the approach, or fast): circle down here first, then plan on.
	var spiral := _spiral(bird, dt)
	if spiral != null:
		return spiral

	# Near enough the approach point, line up for it (once a route).
	if not lined_up and route.size() >= 3 and wp < route.size() - 1:
		var app := route[route.size() - 2]
		if Vector2(app.x - pos.x, app.z - pos.z).length() < LINEUP_RUNS * _held_radius(p, maxf(m.speed, p.v_best), minf(pos.y, app.y)) + LINEUP_REACH:
			_line_up(bird)

	# Advance along the route.
	while wp < route.size() - 1:
		var to_wp := route[wp] - pos
		var seg := route[wp] - route[wp - 1]
		if to_wp.length() < (_aim_ahead if wp < route.size() - 2 else AIM_AHEAD) or (seg.length() > 0.1 and to_wp.dot(seg) < 0.0):
			wp += 1
		else:
			break
	var final := wp >= route.size() - 1
	mode = Mode.FINAL if final else Mode.CRUISE
	var aim := route[wp]
	if final and dist_perch < 6.0:
		# The outer branch, aimed a little high: the feet reach forward and down from the flight line, so the
		# path should meet the branch from level or above (the swoop up from the approach point does that).
		aim = target.approach_anchor() + Vector3.UP * AIM_HIGH

	var opts := {"route": true, "cruise": p.v_best, "lift_cap": true}
	if wp >= route.size() - 2:
		opts.cruise = p.v_best / CRUISE_OVER   # (on the approach: no wingbeats above its cruise -- no speed it must lose to catch)
		opts.slow_to = p.v_best                # (and come down to it by the approach point: the final bleeds the rest)
	if final and target.position.y < 5.0:
		opts.floor = 0.8   # (landing low)
	if final and dist_perch < maxf(10.0, m.speed * 1.5):
		opts.bleed_to = FlightPlanner.catch_speed(p)
		opts.flap_below = target.position.y - 0.3
	if final and dist_perch < 4.0:
		opts.recover = false
	var inp := steer(bird, aim, dt, opts)
	if _settling:
		return inp

	# --- SPACE: catch when the bird says it's on; otherwise a flap ---------------------------------
	# Its target held as the catch candidate on the final (as the novice landing assist holds the player's: another
	# limb the path passes near doesn't take the highlight), and catch held through the last metres once it's the
	# perch the bird would catch.
	bird.candidate_lock = target if final and dist_perch < LOCK_RANGE else null
	var catch_hold := final and dist_perch < 8.0 and bird.candidate == target
	# Missed it (flew past), or circling it with the perch out of the forward cone: go around (_go_around: out and up,
	# then a fresh approach).
	var to_perch := (target.position - pos).normalized()
	var off_cone := final and dist_perch < 12.0 and dist_perch > 2.0 and m.flight_dir().dot(to_perch) < 0.3 and clock - _progress_clock > 1.5
	if (final and dist_perch > 4.0 and _min_dist < 2.5 and dist_perch > _min_dist + 2.0) or off_cone:
		_go_around(bird)
	return FlightInput.new(inp.stick, false, inp.flap_held, false, catch_hold)


## Fly toward `aim`: the guidance law, the avoidance, the ground guard and low-speed recovery, with no route,
## perch or catch of its own (the combat pilot flies with this; `_fly` adds its route and landing). `opts`:
##   bank_frac   share of the bank limit to use (0.85; a fight wants up to 0.95)
##   gamma       path angle to hold instead of the one that reaches `aim` (a zoom, a stoop)
##   flap        "auto" (when climbing or slow), "sprint" (every wingbeat, weak ones too), "none", "hold" (below
##               `speed`); the ground guard and recovery flap regardless
##   speed       the airspeed "hold" keeps
##   floor       the ground guard's height (4 m)
##   bleed_to    landing: pull to bleed speed toward this, flapping only when below `flap_below`
##   recover     low-speed recovery (true)
##   route       predict along this pilot's route from `wp` (its perch flight) rather than straight at `aim`
##   cruise      a perch flight's cruise speed: no wingbeats above CRUISE_OVER of it (the ground guard and recovery
##               still beat)
##   slow_to     pull gently (SLOW_GAIN) to come down to this speed (the leg into the approach point)
##   lift_cap    bank no more than the lift holds at this speed (held_bank; a perch flight's turns: a sustained
##               over-banked turn sinks into a stall spiral); off by default (a race's escape, a combat break pull
##               harder for their moment; the combat brain caps its own turns)
## `avoiding` > 0 afterwards when it flew an escape rather than toward `aim`.
func steer(bird: Bird, aim: Vector3, dt: float, opts := {}) -> FlightInput:
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	_settling = false
	var frac: float = opts.get("bank_frac", 0.85)
	_v_cap = m.speed if opts.get("lift_cap", false) else INF
	var bank_room := _bank_room(p, pos.y, frac, _v_cap)
	var horiz := Vector2(aim.x - pos.x, aim.z - pos.z).length()
	var gamma_cmd: float = opts.get("gamma", clampf(atan2(aim.y - pos.y, maxf(horiz, 1.0)), deg_to_rad(-35.0), deg_to_rad(25.0)))
	var p0 := Perf.t()
	var steer_to := _avoid(bird, aim, gamma_cmd, dt, frac, opts.get("route", false))
	Perf.add("ai.avoid", p0)

	# --- Lateral: bank toward the desired heading -------------------------------------------------
	var fd := m.flight_dir()
	var max_bank := deg_to_rad(p.max_bank_deg)
	var bank_cmd := clampf(_signed_heading(fd, steer_to[0]) * TURN_GAIN, -bank_room, bank_room)
	var sx := bank_cmd / max_bank

	# --- Longitudinal: path angle toward the aim point (or the escape's), speed protection ----------
	gamma_cmd = steer_to[1]
	var sy := clampf((gamma_cmd - m.path_angle) * 3.0, -0.8, 0.75)
	var flap_policy: String = opts.get("flap", "auto")
	var want_flap := gamma_cmd > -p.glide_angle + deg_to_rad(1.5) or m.speed < p.v_best * 0.9
	match flap_policy:
		"sprint": want_flap = true
		"none": want_flap = false
		"hold": want_flap = m.speed < float(opts.get("speed", p.v_best))
	if opts.has("cruise") and m.speed > float(opts.cruise) * CRUISE_OVER:
		want_flap = false   # (fast enough: a wingbeat now only adds speed it must lose to land)
	if opts.has("slow_to") and m.speed > float(opts.slow_to) and not opts.has("bleed_to"):
		sy = clampf(sy + (m.speed - float(opts.slow_to)) * SLOW_GAIN, -0.8, 0.75)   # (a gentle pull: it rides a little high)
	if opts.has("bleed_to"):
		# Bleed speed for the catch (earlier the faster we come in): pull harder the faster we are; no
		# flapping unless sinking below it.
		var catch_v: float = opts.bleed_to
		sy = clampf(sy + (m.speed - catch_v) * 0.12, -0.6, 0.9)
		want_flap = pos.y < float(opts.get("flap_below", -INF)) and m.speed < catch_v
	# Ground guard: below 4 m (and not landing low), climb away and flap -- unless spent, in which case
	# settle onto the ground, rest, and take off again.
	var floor_y: float = opts.get("floor", 4.0)
	var spent: bool = m.energy.burst < 1.0 and m.energy.stamina < 0.25
	if pos.y < 1.5 and m.speed < p.v_stall * 1.1 and spent:
		_settling = true
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
	if m.speed < p.v_stall * 1.15 and opts.get("recover", true):
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
	# Flap only on a full-strength wingbeat (a weak one costs double stamina) unless recovering low down, or
	# sprinting.
	var energy_ok: bool = m.energy.burst >= 1.0 or recovering or flap_policy == "sprint"
	_stick = _stick.lerp(Vector2(sx, sy), 1.0 - exp(-10.0 * dt))
	return FlightInput.new(_stick, false, want_flap and energy_ok)


func _give_up(bird: Bird, dt: float) -> FlightInput:
	replans = 0
	_around_until = -INF
	_given_up[target.id] = clock + GIVE_UP_TIME
	target = null
	return _hold_glide(bird, dt)


## Glide on (no goal): best glide, flap to keep off the ground, turning only to miss the trees.
func _hold_glide(bird: Bird, dt: float) -> FlightInput:
	var m := bird.model
	var p := bird.profile
	var low := bird.global_position.y < 6.0
	_v_cap = m.speed
	var room := _bank_room(p, bird.global_position.y, 0.85, _v_cap)
	var steer := _avoid(bird, Vector3.INF, m.path_angle, dt)
	var sx := clampf(_signed_heading(m.flight_dir(), steer[0]) * TURN_GAIN, -room, room) / deg_to_rad(p.max_bank_deg)
	var sy := clampf((steer[1] - m.path_angle) * 3.0, -0.3, 0.6) if avoiding > 0.0 else (-0.1 if low else 0.0)
	return FlightInput.new(Vector2(sx, sy), false, low or avoiding > 0.0)


## Avoidance. The next stretch of flight is predicted the way the bird will really fly it (`_predict`): rolling
## at its roll rate, turning at g tan(bank)/v, its path angle easing to the one asked for -- so a bird already
## in a steep turn, or one that needs a second to roll the other way, sees the trunk its turn curves into in
## time. If following the route (toward `aim`; Vector3.INF: straight on) stays clear, it does that. Otherwise
## it tries a fan of headings, level, climbing, then sinking, and flies the clear one that ends nearest the
## way it wants to go (if none is clear, the one that stays clear longest). Returns [direction to steer to
## (horizontal), path angle].
func _avoid(bird: Bird, aim: Vector3, gamma: float, dt: float, frac := 0.85, follow_route := true) -> Array:
	var pos := bird.global_position
	var m := bird.model
	var v := maxf(m.speed, 2.0)
	var fd := m.flight_dir()
	var ahead := Vector3(fd.x, 0.0, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 1e-3 else bird.facing
	var radius := v * v / (BirdProfile.G * tan(maxf(_bank_room(bird.profile, pos.y, frac, _v_cap), deg_to_rad(10.0))))
	var horizon := clampf(maxf(v * 1.1, radius * 1.3), 4.0, 30.0) / v + 0.25
	var near := []
	for t in bird.layout.trees_near_segment(pos, pos, v * horizon):
		if Vector2(t.base.x - pos.x, t.base.y - pos.z).length() < v * horizon + t.reach() + 1.0:
			near.append(t)
	var want := (aim - pos) if aim != Vector3.INF else ahead
	var first: Array = _predict(bird, near, aim, true, gamma, horizon, frac, follow_route) if aim != Vector3.INF else _predict(bird, near, ahead, false, gamma, horizon, frac)
	predicted = first[2]
	predicted_clear = first[0]
	predict_horizon = horizon
	escape = PackedVector3Array()
	if first[0] >= horizon:
		avoiding = maxf(0.0, avoiding - dt)
		return [want, gamma]
	avoiding = 0.5
	var want_h := Vector3(want.x, 0.0, want.z).normalized()
	var best: Array = [ahead, deg_to_rad(25.0)]
	var best_score := -INF
	var best_pts := PackedVector3Array()
	for climb in [gamma, deg_to_rad(18.0), deg_to_rad(-12.0), deg_to_rad(30.0)]:
		for yaw_deg in [0.0, 25.0, -25.0, 50.0, -50.0, 80.0, -80.0, 115.0, -115.0, 150.0, -150.0]:
			var d := ahead.rotated(Vector3.UP, deg_to_rad(yaw_deg))
			# (Once one is clear, a heading that couldn't beat it even clear isn't checked against the wood.)
			var r := _predict(bird, near, d, false, climb, horizon, frac, true, want_h, best_score if best_score >= horizon else INF)
			if r[0] < 0.0:
				continue
			var end_dir: Vector3 = r[1]
			var score: float = r[0] + (2.0 + end_dir.dot(want_h) if r[0] >= horizon else 0.0)
			if score > best_score:
				best_score = score
				best = [d, climb]
				best_pts = r[2]
		if best_score >= horizon:
			break   # (something clear without climbing more)
	if best_score <= 0.0:
		return [want, gamma]   # (hemmed in on every side right now: keep to the route, which was planned clear)
	escape = best_pts
	return best


const DESCENT_GRADE := 2.0    ## a braking glide on the way to the approach loses this many glide ratios' worth of height
const SPIRAL_START := 3.0     ## m of energy over the approach's at which it circles down first ...
const SPIRAL_STOP := 0.5      ## ... and stops circling
const SPIRAL_GAMMA := deg_to_rad(16.0)   ## the path angle it circles down at
const AIM_AHEAD := 3.0        ## m: a waypoint this close is passed on to the next (the guidance aims past it)
const LINEUP_MARGIN := 1.15   ## a line-up's turns this much wider than the circle the bird holds
const LINEUP_RUNS := 3.0      ## turning circles (and LINEUP_REACH m) from the approach point it lines up within
const LINEUP_REACH := 25.0
const LINEUP_PAD := 40.0      ## m more than a turning circle round a line-up may be
const AROUND_TIME := Vector2(0.6, 2.5)   ## s a go-around flies out for, at least and at most
const SLOW_GAIN := 0.08      ## stick pulled per m/s over a leg's slow_to
const CRUISE_OVER := 1.1     ## share of its cruise speed above which a perch flight doesn't beat its wings
const LOCK_RANGE := 12.0   ## m from its target on the final within which it's held as the catch candidate
const AIM_HIGH := 0.45      ## m the last metres aim above the branch (the feet reach forward and down from the path)
const TURN_GAIN := 2.2       ## bank (rad) per radian of heading error
const PREDICT_STEP := 0.1    ## s, the chord of a predicted path
const PREDICT_LAG := 0.1     ## s before the stick (smoothed) starts the roll
const WHISKER_CLEARANCE := 0.6   ## m kept from the wood
const OWN_TREE_CLEARANCE := 0.3   ## m from the perch's own tree in the last metres (it has to get close to land)
const DEPARTURE_RANGE := 12.0     ## m from the take-off within which the tree it left is passed closer
const PATH_RATE_DEG := 30.0  ## deg/s the path angle follows its command at, predicted
const BANK_SINK := 0.12      ## rad of path angle lost per unit of extra load factor a bank needs (1/cos - 1)


## The bank guidance allows at height y: a steep bank sheds vertical lift, so near the ground it banks gently; and at
## speed `v` no more than the lift holds (held_bank; INF: no cap).
static func _bank_room(p: BirdProfile, y: float, frac := 0.85, v := INF) -> float:
	var room := deg_to_rad(lerpf(25.0, p.max_bank_deg * frac, clampf((y - 1.5) / 6.0, 0.0, 1.0)))
	return minf(room, held_bank(p, v)) if v < INF else room


## The steepest bank a bird can hold at speed `v` without sinking into a stall spiral: the lift's load factor
## (v / v_stall)^2 with a 15% margin (as CombatStyle.lift_bank); 15 deg at least, its bank limit at most.
static func held_bank(p: BirdProfile, v: float) -> float:
	var n := 0.85 * pow(maxf(v, 0.1) / p.v_stall, 2.0)
	return clampf(acos(clampf(1.0 / maxf(n, 1.0), 0.0, 1.0)), deg_to_rad(15.0), deg_to_rad(p.max_bank_deg))


## Fly `horizon` seconds ahead in prediction: steer by the guidance law toward `toward` (a point, following
## the route's later waypoints the way `_fly` advances them, or a fixed heading), the bank slewing at the roll
## rate up to the room it has at that height, the path angle easing toward `gamma` less what the bank sheds.
## Returns [seconds clear (`horizon` if all of it), final heading, the predicted points]. Coming in to land, the perch's own tree counts
## too, closer (OWN_TREE_CLEARANCE) and without the perch's branch, and the path ends where it passes closest to
## the perch if that's in the feet's reach (the catch). Just after take-off, so does the tree it left (past the
## first PUSH_OFF metres, which it passes through as it lets go). With `to_beat` (the fan's best score so far, a clear
## one): [-1, final heading] if the path couldn't score more even clear (horizon + 2 + its end heading . `want_h`),
## without checking it against the wood.
func _predict(bird: Bird, near: Array, toward: Vector3, is_point: bool, gamma: float, horizon: float, frac := 0.85, follow_route := true, want_h := Vector3.ZERO, to_beat := INF) -> Array:
	var m := bird.model
	var layout := bird.layout
	var v := maxf(m.speed, 2.0)
	var roll := deg_to_rad(bird.profile.roll_rate_deg)
	var bank := m.bank
	var g := m.path_angle
	var fd := m.flight_dir()
	var dir := Vector3(fd.x, 0.0, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 1e-3 else bird.facing
	var pos := bird.global_position
	# (Landing: the last 8 m, or the final leg -- planned clear of the wood with the perch's own tree passed closer -- from
	# wherever the look-ahead takes it.)
	var landing := target != null and (target.distance_to(pos) < 8.0 or (mode == Mode.FINAL and follow_route and is_point))
	var own := target.tree_id if landing else -1
	var left := _last_tree if _takeoff_pos.distance_to(pos) < DEPARTURE_RANGE and _last_tree != own else -1
	# Fly it first (where it goes doesn't depend on what it meets), then find the first chord that meets wood,
	# against just the trees whose reach overlaps the path.
	var pts := PackedVector3Array([pos])
	var lo := Vector2(pos.x, pos.z)
	var hi := lo
	var goal := toward
	var k := wp
	var t := 0.0
	while t < horizon - 1e-6:
		if is_point and follow_route:
			while k < route.size() - 1 and pos.distance_to(goal) < (_aim_ahead if k < route.size() - 2 else AIM_AHEAD):
				k += 1
				goal = route[k]
		var err := _signed_heading(dir, (goal - pos) if is_point else goal)
		if t >= PREDICT_LAG:
			var room := _bank_room(bird.profile, pos.y, frac, _v_cap)
			bank = move_toward(bank, clampf(err * TURN_GAIN, -room, room), roll * PREDICT_STEP)
		dir = dir.rotated(Vector3.UP, -BirdProfile.G * tan(clampf(bank, -1.4, 1.4)) / v * PREDICT_STEP)
		# (A steep bank sheds vertical lift: the bird sinks below the path angle asked for.)
		var sink := BANK_SINK * (1.0 / maxf(cos(bank), 0.3) - 1.0)
		g = move_toward(g, gamma - sink, deg_to_rad(PATH_RATE_DEG) * PREDICT_STEP)
		var nxt := pos + (dir * cos(g) + Vector3.UP * sin(g)) * v * PREDICT_STEP
		if landing and target.distance_to(nxt) > target.distance_to(pos) and Perch.in_reach(bird.profile, pos, (nxt - pos) / PREDICT_STEP, target.closest_grip(pos)):
			break   # (its closest pass, within the feet's reach: the catch)
		pts.append(nxt)
		lo = lo.min(Vector2(nxt.x, nxt.z))
		hi = hi.max(Vector2(nxt.x, nxt.z))
		pos = nxt
		t += PREDICT_STEP
	if to_beat < INF and horizon + (2.0 + dir.dot(want_h)) <= to_beat:
		return [-1.0, dir, pts]
	var close := []
	for tr in near:
		var rr: float = tr.reach() + WHISKER_CLEARANCE
		if tr.base.x > lo.x - rr and tr.base.x < hi.x + rr and tr.base.y > lo.y - rr and tr.base.y < hi.y + rr:
			close.append(tr)
	var decks := []   # (the outposts whose decks could reach the path; a chord's own check skips the rest anyway)
	for o in layout.outposts:
		var od: float = o.width + o.depth + WHISKER_CLEARANCE + 0.01
		if o.centre.x >= lo.x - od and o.centre.x <= hi.x + od and o.centre.z >= lo.y - od and o.centre.z <= hi.y + od:
			decks.append(o)
	var blocked := layout.path_blocked_at(close, pts, WHISKER_CLEARANCE, own, left, decks)
	# The trees it is leaving and landing on, closer, up to the first chord the rest of the wood blocks.
	var upto := (pts.size() - 1 if blocked < 0 else blocked) if left >= 0 or own >= 0 else 0
	for i in upto:
		var a := pts[i]
		var b := pts[i + 1]
		if left >= 0 and a.distance_to(_takeoff_pos) > FlightPlanner.PUSH_OFF and not layout.tree_clear(left, a, b, OWN_TREE_CLEARANCE, _left_perch):
			return [i * PREDICT_STEP, dir, pts]
		if own >= 0 and not layout.tree_clear(own, a, b, OWN_TREE_CLEARANCE, target.id):
			return [i * PREDICT_STEP, dir, pts]
	if blocked >= 0:
		return [blocked * PREDICT_STEP, dir, pts]
	return [horizon, dir, pts]


static func _signed_heading(from: Vector3, to: Vector3) -> float:
	var a := atan2(from.x, -from.z)
	var b := atan2(to.x, -to.z)
	return wrapf(b - a, -PI, PI)
