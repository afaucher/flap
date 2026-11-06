extends TestCase
## The AI's tree avoidance (docs/design/flight_model.md, section 6), one situation at a time in small hand-built
## arenas, each checked both ways (left and right, blocked and open):
##   - a bird in a steep turn that curves into a trunk sees it in time and flies round it;
##   - an escape that climbs reaches the pitch, not just the heading;
##   - coming in to land, the perch's own trunk still counts (no flying through it to the far side's branch), but
##     a proper approach to the branch is not blocked by the branch itself;
##   - just after take-off, the tree it left still counts (its other limbs), but not the branch it sat on;
##   - routes leave and reach a perch's tree past its trunk and limbs, not through them;
##   - hemmed in on every side, it keeps to the planned route; with no goal it still turns away from a trunk;
##   - a perch it can't make the approach to is given up after ATTEMPT_TIME and left alone for a while.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	for side in [1.0, -1.0]:
		await _turn_into_trunk("hawk", side)
		await _turn_into_trunk("crow", side)
		# Low down, where guidance banks less: a trunk just outside the turn half a second ahead (it must not roll
		# out into it: rolling takes time), and one on the turn it really flies (wider than at full bank).
		await _low_turn_at_trunk("hawk", side, 0.5, 0.6)
		await _low_turn_at_trunk("crow", side, 0.5, 0.6)
		await _low_turn_at_trunk("falcon", side, 0.7, 0.0)
		await _low_turn_at_trunk("crow", side, 0.7, 0.0)
	await _escape_climbs()
	await _final_not_through_own_trunk()
	await _takeoff_own_tree()
	_routes_round_own_trees()
	_routes_out_of_tight_spots()
	await _hemmed_in_keeps_route()
	await _no_goal_still_avoids()
	await _gives_up_unreachable_perch()
	await _sets_aside_perch_without_route()
	finish()


# --- Building blocks ------------------------------------------------------------------------------

static func _tree(a: ArenaLayout, x: float, z: float, h: float, r: float) -> ArenaLayout.TreeData:
	var t := ArenaLayout.TreeData.new()
	t.id = a.trees.size()
	t.base = Vector2(x, z)
	t.height = h
	t.radius = r
	a.trees.append(t)
	ArenaLayout._add_to_hash(a._tree_hash, t.base, t.id)
	return t


## A straight limb from the trunk's axis at height y, `length` m along `dir` (tip `rise` m higher), with a perch
## along its top facing across it (to the limb's right, looking out along it).
static func _limb(a: ArenaLayout, t: ArenaLayout.TreeData, y: float, dir: Vector3, length: float, rise := 0.0, perch := true) -> Perch:
	var b := ArenaLayout.BranchData.new()
	b.tree_id = t.id
	b.root = Vector3(t.base.x, y, t.base.y)
	b.tip = b.root + Vector3(dir.x, 0.0, dir.z).normalized() * length + Vector3.UP * rise
	b.radius = 0.06
	t.branches.append(b)
	a.max_tree_reach = maxf(a.max_tree_reach, length - 4.0)
	if not perch:
		return null
	var up := Vector3.UP * b.radius
	var t0 := (t.radius + ArenaLayout.GRIP_TRUNK_GAP) / length
	var p := Perch.branch(a.perches.size(), b.root.lerp(b.tip, t0) + up, b.root.lerp(b.tip, 1.0 - ArenaLayout.GRIP_TIP_GAP / length) + up, dir.rotated(Vector3.UP, PI * 0.5), t.id, b.radius)
	b.perch_id = p.id
	a._add_perch(p)
	return p


## A limb of `t` (no perch) across the middle of each swoop in to `goal` (FlightPlanner.ways_in): no way in is left.
static func _block_ways_in(a: ArenaLayout, t: ArenaLayout.TreeData, goal: Perch, p: BirdProfile) -> void:
	for d in FlightPlanner.ways_in(goal, goal.position + goal.facing):
		var mid := FlightPlanner.approach_point(goal, p, d).lerp(goal.approach_anchor(), 0.5)
		_limb(a, t, mid.y, Vector3(mid.x - t.base.x, 0.0, mid.z - t.base.y), Vector2(mid.x - t.base.x, mid.z - t.base.y).length() + 1.0, 0.0, false)


func _bird(id: String, layout: ArenaLayout, pilot: AIPilot, arena: ArenaBuilder = null) -> Bird:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, pilot)
	b.arena = arena
	b.rig.visible = false
	pilot._fit(b)
	return b


## Put the pilot on its way to `target` along `route` (from where the bird is now), as if it had planned it.
static func _going(pilot: AIPilot, target: Perch, route: Array) -> void:
	pilot.target = target
	pilot.route.assign(route)
	pilot.wp = 1
	pilot.mode = AIPilot.Mode.CRUISE
	pilot._attempt_start = pilot.clock
	pilot._progress_clock = pilot.clock
	pilot._min_dist = INF
	pilot.lined_up = true   # (the route as given: no line-up for the final in its place)


func _free_all(nodes: Array) -> void:
	for n in nodes:
		n.queue_free()
	await frames(2)


# --- Situations -----------------------------------------------------------------------------------

## In a steady steep turn (banked as far as guidance allows) toward a waypoint further round, with a trunk on the
## turning circle a second ahead: the prediction rolls and turns the way the bird does, so it sees the trunk in time
## and flies round it -- no bump, turning either way. (A straight whisker, or one that assumed it could roll out at
## once, saw it too late or chose escapes it couldn't fly.)
func _turn_into_trunk(id: String, side: float) -> void:
	var layout := ArenaLayout.new()
	var p := BirdProfile.by_id(id)
	var y := 12.0
	var v := p.v_best
	var bank := AIPilot._bank_room(p, y)
	var r := v * v / (BirdProfile.G * tan(bank))
	var ang := v * 1.0 / r                                  # (a second round the circle)
	var centre := Vector3(side * r, y, 0.0)                 # (heading -z, turning toward +x when side is +1)
	var on_circle := func(a: float) -> Vector3: return centre + Vector3(-side * r * cos(a), 0.0, -r * sin(a))
	var trunk_at: Vector3 = on_circle.call(ang)
	_tree(layout, trunk_at.x, trunk_at.z, 30.0, 0.3)
	var far := _tree(layout, side * 40.0, 30.0, 20.0, 0.3)
	var goal := _limb(layout, far, 10.0, Vector3(-side, 0.0, 0.0), 3.0)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird(id, layout, pilot, arena)
	b.fly_from(Vector3(0.0, y, 0.0), Vector3.FORWARD, v)
	b.model.bank = side * bank
	pilot._stick = Vector2(side * bank / deg_to_rad(p.max_bank_deg), 0.0)
	_going(pilot, goal, [b.global_position, on_circle.call(ang * 2.2), goal.approach_anchor()])
	var closest := INF
	for f in 150:
		await get_tree().physics_frame
		closest = minf(closest, Vector2(b.global_position.x - trunk_at.x, b.global_position.z - trunk_at.z).length() - 0.3)
	print("%s turning %s into a trunk: %d bumps, came within %.2f m" % [id, "right" if side > 0 else "left", b.bonks, closest])
	check(b.bonks == 0, "%s turning %s: flies round the trunk on its turning circle (%d bumps)" % [id, "right" if side > 0 else "left", b.bonks])
	await _free_all([b, arena])


## The same low down (4.5 m: the bank guidance allows shrinks toward the ground), with the trunk where the bird
## would be after `lead` s of its turn without it (flown first, trunk-free), moved `out` m to the outside of the turn.
func _low_turn_at_trunk(id: String, side: float, lead: float, out: float) -> void:
	var at: Vector3 = await _low_turn(id, side, lead, out, Vector3.INF)
	var n: int = await _low_turn(id, side, lead, out, at)
	var turn := "right" if side > 0 else "left"
	print("%s low, turning %s, trunk %.1f s ahead %.1f m outside: %d bumps" % [id, turn, lead, out, n])
	check(n == 0, "%s low down turning %s: misses a trunk %.1f s ahead, %.1f m outside its turn (%d bumps)" % [id, turn, lead, out, n])


## A level turn at 4.5 m, banked as far as guidance allows there, toward a point further round. With `trunk` INF
## there's no trunk, and it returns where the bird is after `lead` s, moved `out` m to the outside of the turn;
## otherwise the trunk stands there, and it returns the bumps.
func _low_turn(id: String, side: float, lead: float, out: float, trunk: Vector3):
	var layout := ArenaLayout.new()
	var p := BirdProfile.by_id(id)
	var y := 4.5
	var v := p.v_best
	var bank := AIPilot._bank_room(p, y)
	var r := v * v / (BirdProfile.G * tan(bank))
	if trunk != Vector3.INF:
		_tree(layout, trunk.x, trunk.z, 30.0, 0.3)
	var far := _tree(layout, side * 40.0, 30.0, 20.0, 0.3)
	var goal := _limb(layout, far, 10.0, Vector3(-side, 0.0, 0.0), 3.0)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(1)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird(id, layout, pilot, arena)
	b.fly_from(Vector3(0.0, y, 0.0), Vector3.FORWARD, v)
	b.model.bank = side * bank
	pilot._stick = Vector2(side * bank / deg_to_rad(p.max_bank_deg), 0.0)
	var a := v * 2.0 / r   # (two seconds round its circle)
	_going(pilot, goal, [b.global_position, Vector3(side * r * (1.0 - cos(a)), y, -r * sin(a)), goal.approach_anchor()])
	var result = null
	for f in 150:
		await get_tree().physics_frame
		if trunk == Vector3.INF and f == int(lead * 60.0):
			var fd := b.model.flight_dir()
			result = b.global_position - Vector3(-fd.z, 0.0, fd.x).normalized() * side * out
			break
	if trunk != Vector3.INF:
		result = b.bonks
	await _free_all([b, arena])
	return result


## Level at 5 m toward a long low fence (trunks 1.2 m apart, tops at 5 m) too close to turn back from: the escape
## is a climb, and the pilot pulls up for it (the escape sets the path angle, not just the heading).
func _escape_climbs() -> void:
	var layout := ArenaLayout.new()
	for i in 61:
		_tree(layout, -36.0 + i * 1.2, -6.0, 5.0, 0.1)
	var far := _tree(layout, 0.0, -60.0, 20.0, 0.3)
	var goal := _limb(layout, far, 5.0, Vector3(1.0, 0.0, 0.0), 3.0)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("hawk", layout, pilot)
	b.fly_from(Vector3(0.0, 5.0, 0.0), Vector3.FORWARD, b.profile.v_best)
	_going(pilot, goal, [b.global_position, Vector3(0.0, 5.0, -40.0), goal.approach_anchor()])
	var inp: FlightInput
	for i in 12:
		inp = pilot.sample(b, 1.0 / 60.0)
	print("toward a low fence: avoiding %.2f, stick (%.2f, %.2f)" % [pilot.avoiding, inp.stick.x, inp.stick.y])
	check(pilot.avoiding > 0.0, "a low fence ahead: avoiding")
	check(inp.stick.y > 0.3, "the escape over a low fence climbs: pulls up (stick %.2f)" % inp.stick.y)
	# Both ways: with the fence well below, it just flies on, level.
	b.fly_from(Vector3(0.0, 9.0, 0.0), Vector3.FORWARD, b.profile.v_best)
	_going(pilot, goal, [b.global_position, Vector3(0.0, 9.0, -40.0), goal.approach_anchor()])
	pilot.avoiding = 0.0
	pilot.sample(b, 1.0 / 60.0)
	check(pilot.avoiding == 0.0, "the fence well below: not avoiding")
	await _free_all([b])


## A stub on the far side of its trunk: flying at it from the near side, straight at the trunk, the prediction
## counts the perch's own trunk and turns away. Both ways: coming in properly, across the branch from the side it
## faces, nothing (not the branch itself) gets in the way.
func _final_not_through_own_trunk() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, 0.0, 20.0, 0.3)
	var stub := _limb(layout, t, 8.0, Vector3(-1.0, 0.0, 0.0), 1.1)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("owl", layout, pilot)
	var aim := stub.approach_anchor() + Vector3.UP * 0.45
	b.fly_from(Vector3(4.0, 8.3, 0.05), Vector3(-1.0, 0.0, 0.0), 6.5)
	_going(pilot, stub, [b.global_position, stub.approach_anchor()])
	pilot._avoid(b, aim, 0.0, 1.0 / 60.0)
	check(pilot.avoiding > 0.0, "landing: a path through the perch's own trunk is blocked")
	var from := stub.approach_anchor() + stub.facing * 5.0 + Vector3.DOWN * 0.6
	b.fly_from(from, (aim - from).normalized(), 6.5)
	_going(pilot, stub, [b.global_position, stub.approach_anchor()])
	pilot.avoiding = 0.0
	pilot._avoid(b, aim, atan2(aim.y - from.y, 5.0), 1.0 / 60.0)
	check(pilot.avoiding == 0.0, "landing: coming in across the branch, nothing in the way (not the branch itself)")
	await _free_all([b])


## Just off a limb (the push-off done): heading for another limb of the same tree, that limb counts; heading out
## into open air, the limb it sat on and the trunk behind it don't.
func _takeoff_own_tree() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, 0.0, 15.0, 0.4)
	var sat := _limb(layout, t, 6.0, Vector3(1.0, 0.0, 0.0), 4.0)
	_limb(layout, t, 6.3, Vector3(1.0, 0.0, -1.0), 5.0, 0.0, false)   # (crosses the way out to -z, 2.2 m ahead)
	var far := _tree(layout, 2.2, -40.0, 20.0, 0.3)
	var goal := _limb(layout, far, 6.0, Vector3(1.0, 0.0, 0.0), 3.0)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("crow", layout, pilot)
	var seat := Perch.seat_at(sat.position, b.profile)
	for out in [Vector3.FORWARD, Vector3.BACK]:
		b.fly_from(seat, out, 4.0)
		pilot._last_tree = t.id
		pilot._left_perch = sat.id
		pilot._takeoff_pos = seat
		pilot.avoiding = 0.0
		_going(pilot, goal, [seat, seat + out * 30.0, goal.approach_anchor()])
		pilot._avoid(b, seat + out * 30.0, 0.0, 1.0 / 60.0)
		if out == Vector3.FORWARD:
			check(pilot.avoiding > 0.0, "just off a limb: another limb of the same tree ahead is in the way")
		else:
			check(pilot.avoiding == 0.0, "just off a limb: open air ahead (the limb it sat on doesn't count)")
	await _free_all([b])


## Routes: leaving a tree toward a perch behind its own trunk, the first leg passes the trunk, not through it; a
## bird on a stub right against its trunk still gets a route out; a perch whose swoop in from its approach point
## another limb of the same tree crosses is come in to another way, and with limbs across every way in gets no
## route (one without them does).
func _routes_round_own_trees() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, 0.0, 15.0, 0.4)
	var sat := _limb(layout, t, 6.0, Vector3(1.0, 0.0, 0.0), 4.0)
	var stub := _limb(layout, t, 7.0, Vector3(0.0, 0.0, 1.0), 0.9)
	var far := _tree(layout, -30.0, 0.0, 20.0, 0.3)
	var goal := _limb(layout, far, 6.0, Vector3(0.0, 0.0, 1.0), 3.0)   # (faces +x: approached from this side)
	var crow := BirdProfile.crow()
	var planner := FlightPlanner.new(layout)
	var route := planner.plan_to_perch(sat.position, goal, crow, t.id, sat.id)
	check(route.size() >= 3, "a route from behind its own trunk (%d points)" % route.size())
	if route.size() >= 2:
		var d := (route[1] - route[0]).normalized()
		check(layout.tree_clear(t.id, route[0] + d * FlightPlanner.PUSH_OFF, route[1], FlightPlanner.OWN_TREE_CLEARANCE * 0.99, sat.id), "the first leg passes its own trunk, not through it")
	check(planner.plan_to_perch(stub.position, goal, crow, t.id, stub.id).size() >= 3, "a route out from a stub right against its trunk")
	check(not planner._a_through, "... past its own trunk, not through it (the push-off's first metre is let off)")
	var swoop_from := FlightPlanner.approach_point(goal, crow)
	var mid := swoop_from.lerp(goal.approach_anchor(), 0.5)
	var open_route := planner.plan_to_perch(sat.position, goal, crow, t.id, sat.id)
	check(open_route.size() >= 3, "the swoop in is open: a route")
	_limb(layout, far, mid.y, Vector3(mid.x - far.base.x, 0.0, mid.z - far.base.y), Vector2(mid.x - far.base.x, mid.z - far.base.y).length() + 1.0, 0.0, false)
	planner = FlightPlanner.new(layout)
	var other := planner.plan_to_perch(sat.position, goal, crow, t.id, sat.id)
	check(other.size() >= 3 and planner.way.dot(goal.facing) < 0.99, "another limb of its tree across the swoop in square on: it comes in another way (%d points, way %s)" % [other.size(), str(planner.way)])
	_block_ways_in(layout, far, goal, crow)
	planner = FlightPlanner.new(layout)
	check(planner.plan_to_perch(sat.position, goal, crow, t.id, sat.id).is_empty(), "limbs of its tree across every swoop in: no route")


## Routes out of tight spots: deep in its own crown (every way out passes close to another of its limbs) it leaves
## through them rather than not at all; wedged near another tree (closer than its planning berth) the first leg
## may pass closer.
func _routes_out_of_tight_spots() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, 0.0, 16.0, 0.4)
	var sat := _limb(layout, t, 8.0, Vector3(1.0, 0.0, 0.0), 3.0)
	for i in 41:   # (a cage of limbs 2-14 m up, every 0.3 m and 7.5 degrees, 6 m long)
		for k in 48:
			if absf(2.0 + i * 0.3 - 8.0) < 0.2 and k == 0:
				continue
			_limb(layout, t, 2.0 + i * 0.3, Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(7.5 * k)), 6.0, 0.0, false)
	var far := _tree(layout, 40.0, 0.0, 20.0, 0.3)
	var goal := _limb(layout, far, 9.0, Vector3(0.0, 0.0, 1.0), 3.0)
	var crow := BirdProfile.crow()
	var caged := FlightPlanner.new(layout)
	check(not caged.plan_to_perch(sat.position, goal, crow, t.id, sat.id).is_empty(), "deep in its own crown: still a route out")
	check(caged._a_through, "... through its own limbs (no way out passes them)")
	var hawk := BirdProfile.by_id("hawk")
	var l2 := ArenaLayout.new()
	var t2 := _tree(l2, 0.0, 0.0, 16.0, 0.3)
	var sat2 := _limb(l2, t2, 9.0, Vector3(1.0, 0.0, 0.0), 3.0)
	_tree(l2, sat2.position.x, 1.5, 20.0, 0.3)   # (a neighbour's trunk 1.5 m from where it sits)
	var far2 := _tree(l2, 40.0, -10.0, 20.0, 0.3)
	var goal2 := _limb(l2, far2, 9.0, Vector3(0.0, 0.0, 1.0), 3.0)
	var wide := FlightPlanner.new(l2, 1.95)   # (a hawk's berth)
	check(not wide.plan_to_perch(sat2.position, goal2, hawk, t2.id, sat2.id).is_empty(), "wedged within its berth of another trunk: still a route out")


## Inside the clearance of a trunk already (every way out blocked from the first metre): it keeps to the route
## it was given rather than whatever came first in the fan.
func _hemmed_in_keeps_route() -> void:
	var layout := ArenaLayout.new()
	_tree(layout, 0.0, 0.0, 20.0, 0.3)
	var far := _tree(layout, 40.0, 0.0, 20.0, 0.3)
	var goal := _limb(layout, far, 10.0, Vector3(0.0, 0.0, 1.0), 3.0)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("crow", layout, pilot)
	b.fly_from(Vector3(0.75, 10.0, 0.0), Vector3.FORWARD, 8.0)
	var aim := Vector3(30.0, 10.0, -5.0)
	_going(pilot, goal, [b.global_position, aim, goal.approach_anchor()])
	var steer := pilot._avoid(b, aim, 0.0, 1.0 / 60.0)
	var d: Vector3 = steer[0]
	check(pilot.avoiding > 0.0, "hemmed in: avoiding")
	check(d.normalized().dot((aim - b.global_position).normalized()) > 0.99, "hemmed in: keeps to the route (%s)" % d)
	await _free_all([b])


## No perch anywhere (nothing to plan to): gliding at a trunk just off to one side or the other, it still steers
## clear of it.
func _no_goal_still_avoids() -> void:
	for side in [1.0, -1.0]:
		var layout := ArenaLayout.new()
		_tree(layout, side * 0.5, -6.0, 30.0, 0.3)
		var pilot := AIPilot.new(layout, 3)
		var b := _bird("crow", layout, pilot)
		b.fly_from(Vector3(0.0, 10.0, 0.0), Vector3.FORWARD, 8.0)
		var inp: FlightInput
		for i in 12:
			inp = pilot.sample(b, 1.0 / 60.0)
		check(pilot.target == null, "no perch: no target")
		check(pilot.avoiding > 0.0 and absf(inp.stick.x) > 0.2, "no goal, a trunk ahead %s: steers clear (stick x %.2f)" % ["right" if side > 0 else "left", inp.stick.x])
		await _free_all([b])


## A perch it can't plan a route to (limbs of its tree across every swoop in) is set aside, not picked
## again every second.
func _sets_aside_perch_without_route() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, -30.0, 20.0, 0.3)
	var goal := _limb(layout, t, 9.0, Vector3(0.0, 0.0, 1.0), 3.0)   # (faces +x)
	var crow := BirdProfile.crow()
	_block_ways_in(layout, t, goal, crow)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("crow", layout, pilot)
	b.fly_from(Vector3(0.0, 10.0, 0.0), Vector3.FORWARD, 8.0)
	pilot.sample(b, 1.0 / 60.0)
	check(pilot.target == null, "no route in: no target")
	check(pilot._given_up.has(goal.id), "a perch with no route in is set aside")
	check(pilot._best_perch(b, 50.0, 0.0) == null, "and not picked again straight away")
	await _free_all([b])


## A perch it hasn't reached in ATTEMPT_TIME is given up and left alone (not picked again) for GIVE_UP_TIME;
## one it is still within time for is kept.
func _gives_up_unreachable_perch() -> void:
	var layout := ArenaLayout.new()
	var t := _tree(layout, 0.0, -30.0, 20.0, 0.3)
	var goal := _limb(layout, t, 9.0, Vector3(1.0, 0.0, 0.0), 3.0)
	var pilot := AIPilot.new(layout, 3)
	var b := _bird("crow", layout, pilot)
	b.fly_from(Vector3(0.0, 10.0, 0.0), Vector3.FORWARD, 8.0)
	pilot.clock = 100.0
	_going(pilot, goal, [b.global_position, goal.approach_anchor()])
	pilot._attempt_start = pilot.clock - 5.0
	pilot.sample(b, 1.0 / 60.0)
	check(pilot.target == goal, "within the attempt time: keeps its perch")
	pilot._attempt_start = pilot.clock - AIPilot.ATTEMPT_TIME - 1.0
	pilot.sample(b, 1.0 / 60.0)
	check(pilot.target != goal, "past the attempt time: gives the perch up")
	check(pilot._best_perch(b, 50.0, 0.0) != goal, "a perch given up isn't picked again straight away")
	pilot.clock += AIPilot.GIVE_UP_TIME + 1.0
	check(pilot._best_perch(b, 50.0, 0.0) == goal, "after a while it can be picked again")
	await _free_all([b])
