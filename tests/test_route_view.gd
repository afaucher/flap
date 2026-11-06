extends TestCase
## The bird lab's route view (RouteView) draws what the AI plans, read back from its meshes:
##  - flying the lab's rail scenarios (a falcon, then a crow, sent to land on the race's start rail in the pine wood),
##    sampled through the flight: the drawn route is AIPilot.route point for point (each version of it as it
##    replans; one replan is made part way if it makes none), the waypoint dots the same points, the line to the current waypoint from the bird to route[wp], the
##    target's grip line its perch's a -> b and its approach ring round the route's last point but one (the approach
##    point), the predicted path AIPilot.predicted from beside the bird;
##  - the lattice: every node drawn is a planner node within the radius, the usable ones those FlightPlanner.node_usable
##    passes and the rejected ones those it fails, and together all the nodes in the radius;
##  - a bird flying at a trunk: the avoidance's predicted path is drawn green up to where it meets the wood and red from
##    there, the star on that point; with the trunk out of the way, no star and all green;
##  - the view changes no flight: the same scenario flown with the view drawn every tick and without leaves the bird in
##    the same place;
##  - the lab scene: picking a route scenario builds the pine wood, the route view shows the AI's route; P hides it; a
##    landing scenario goes back to the one-tree arena with the view hidden.

const SHARDS := 2


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(0):
		await _flown()
	if in_shard(1):
		await _lab()
	finish()


func _flown() -> void:
	var layout := Pinewood.generate(LabScenarios.FOREST_SEED)
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	await frames(2)
	for id in ["falcon", "crow"]:
		await _follow(layout, arena, id, LabScenarios.by_id("rail_front" if id == "falcon" else "rail_behind"))
	await _blocked(layout, arena)
	await _unchanged(layout, arena)
	arena.queue_free()


## Fly a route scenario with the view drawn every tick, checking what's drawn against the pilot every 10 ticks.
func _follow(layout: ArenaLayout, arena: ArenaBuilder, id: String, s: Dictionary) -> void:
	var b := _bird(layout, arena, id)
	var pilot := LabScenarios.start(s, b, layout)
	var ai := pilot.ai
	var view := RouteView.new()
	add_child(view)
	view.pilot = ai
	view.bird = b
	view.rejected = true
	var routes := {}
	var bad := {"route": 0, "dots": 0, "current": 0, "target": 0, "approach": 0, "predicted": 0, "lattice": 0}
	var samples := 0
	var landed := false
	for i in 1500:
		await frames(1)
		if i == 120 and routes.size() < 2 and ai.target != null and b.state == Bird.State.FLYING:
			ai._replan(b)   # (a plan made afresh part way, if it hasn't made one of its own: the view must follow it)
		view.refresh()
		if b.state != Bird.State.FLYING:
			landed = b.state == Bird.State.PERCHED
			if landed:
				break
			continue
		if i % 10 != 0 or ai.route.size() < 2:
			continue
		samples += 1
		routes[str(ai.route)] = true
		var r := PackedVector3Array(ai.route)
		bad.route += int(not _same(view.drawn("route"), r))
		bad.dots += int(not _same(view.drawn("waypoints"), r))
		var wp := clampi(ai.wp, 1, r.size() - 1)
		bad.current += int(not _same(view.drawn("current"), PackedVector3Array([b.global_position, r[wp]])))
		if ai.target != null:
			var t := view.drawn("target")
			bad.target += int(t.size() < 2 or t[0].distance_to(ai.target.a) > 1e-4 or t[1].distance_to(ai.target.b) > 1e-4)
			var ring := Vector3.INF
			if t.size() >= 34:
				ring = Vector3.ZERO
				for k in range(2, 34):   # (the approach ring: 16 line pairs after the grip line)
					ring += t[k] / 32.0
			bad.approach += int(ring.distance_to(r[r.size() - 2]) > 1e-3)
		var p := view.drawn("predicted")
		var p_bad := not _same(p, ai.predicted) or p[0].distance_to(b.global_position) > b.model.speed / 60.0 * 1.5 + 0.05
		if ai.predicted.size() < 2:   # (cut short at once by the catch: nothing to draw)
			p_bad = not p.is_empty()
		if p_bad:
			print("%s at %d: predicted drawn %d points from %s, the pilot's %d, the bird at %s (%.1f m/s, mode %d)" % [id, i, p.size(), str(p[0]) if not p.is_empty() else "-", ai.predicted.size(), str(b.global_position), b.model.speed, ai.mode])
		bad.predicted += int(p_bad)
		if samples % 10 == 1:
			bad.lattice += int(not _lattice_ok(view, b.global_position))
	var what := "%s, %s" % [id, s.id]
	print("%s: %d samples, %d routes drawn, %s; %s" % [what, samples, routes.size(), "landed on " + ("the rail" if b.perch == pilot.goal else "perch %d" % b.perch.id) if landed else "not landed", str(bad)])
	check(samples >= 20, "%s: the route was drawn through the flight (%d samples)" % [what, samples])
	check(routes.size() >= 2, "%s: it replanned or moved on along the way and the view followed (%d routes)" % [what, routes.size()])
	for k in bad:
		eq(bad[k], 0, "%s: the drawn %s matches the pilot every time" % [what, k])
	view.queue_free()
	b.queue_free()
	await frames(1)


## Every lattice node drawn is a planner node within the radius, usable as the planner judges it (or rejected,
## drawn apart), and together they're all the nodes in the radius.
func _lattice_ok(view: RouteView, c: Vector3) -> bool:
	var planner := view.pilot.planner
	var want_ok := 0
	var want_no := 0
	var n := ceili(view.lattice_radius / FlightPlanner.LATTICE) + 1
	for ly in FlightPlanner.LEVELS.size():
		for dx in range(-n, n + 1):
			for dz in range(-n, n + 1):
				var k := Vector3i(roundi(c.x / FlightPlanner.LATTICE) + dx, ly, roundi(c.z / FlightPlanner.LATTICE) + dz)
				if FlightPlanner.node_pos(k).distance_to(c) <= view.lattice_radius:
					if planner.node_usable(k):
						want_ok += 1
					else:
						want_no += 1
	var ok := true
	for set_ in [["lattice", true], ["rejected", false]]:
		for v in view.drawn(set_[0]):
			var k := Vector3i(roundi(v.x / FlightPlanner.LATTICE), FlightPlanner.LEVELS.find(v.y), roundi(v.z / FlightPlanner.LATTICE))
			ok = ok and k.y >= 0 and FlightPlanner.node_pos(k).distance_to(v) < 1e-4 and v.distance_to(c) <= view.lattice_radius + 1e-4 and planner.node_usable(k) == set_[1]
	var counts := Vector2i(view.drawn("lattice").size(), view.drawn("rejected").size())
	if counts != Vector2i(want_ok, want_no) or not ok:
		print("lattice round %s: drawn %s, want %s, nodes right %s" % [str(c), str(counts), str(Vector2i(want_ok, want_no)), ok])
		return false
	return want_ok > 0


## A bird flying at a trunk: the predicted path is drawn red from where it meets the wood, the star there; with the
## aim off to the side in open air, all green and no star.
func _blocked(layout: ArenaLayout, arena: ArenaBuilder) -> void:
	var tree: ArenaLayout.TreeData = null
	for t in layout.trees:   # (a mature trunk with open air round it to come at it through)
		if t.height > 20.0 and t.base.length() < 50.0 and layout.clear_by(Vector3(t.base.x, 6.0, t.base.y) + Vector3(0, 0, -9.0), 2.5) and layout.segment_clear(Vector3(t.base.x, 6.0, t.base.y - 12.0), Vector3(t.base.x, 6.0, t.base.y - t.radius - 2.0), 0.8):
			tree = t
			break
	if not check(tree != null, "a trunk with open air before it"):
		return
	var b := _bird(layout, arena, "crow")
	var ai := AIPilot.new(layout, 3)
	b.controller = ai
	ai._fit(b)
	var axis := Vector3(tree.base.x, 6.0, tree.base.y)
	b.fly_from(axis + Vector3(0, 0, -9.0), Vector3(0, 0, 1), b.profile.v_best)
	ai.steer(b, axis + Vector3(0, 0, 20.0), 1.0 / 60.0)
	var view := RouteView.new()
	add_child(view)
	view.pilot = ai
	view.bird = b
	view.refresh()
	var at: Variant = view.blocked_point()
	var star := view.drawn("blocked")
	print("at the trunk %d: clear %.2f of %.2f s, blocked at %s, star %s" % [tree.id, ai.predicted_clear, ai.predict_horizon, str(at), str(star)])
	check(at != null and ai.predicted_clear < ai.predict_horizon, "flying at the trunk, the predicted path meets it")
	var ahead := view.drawn("predicted")
	var straight := ahead.size() >= 2 and ahead[-1].z > ahead[0].z + 1.0
	for v in ahead:
		straight = straight and absf(v.x - axis.x) < 0.3
	check(straight, "the path drawn is the one toward its aim, straight on at the trunk (not an escape it tried)")
	if at != null:
		var mid := Vector3.ZERO
		for v in star:
			mid += v / star.size()
		check(star.size() == 6 and mid.distance_to(at) < 1e-4, "the star is drawn where the path meets the wood")
		check(Vector2(at.x - axis.x, at.z - axis.z).length() < tree.reach() + AIPilot.WHISKER_CLEARANCE + 1.0, "... which is by the trunk (%.2f m from its axis)" % Vector2(at.x - axis.x, at.z - axis.z).length())
		var cols: PackedColorArray = (view.surfaces["predicted"][0] as ImmediateMesh).surface_get_arrays(view.surfaces["predicted"][1])[Mesh.ARRAY_COLOR]
		var cut := roundi(ai.predicted_clear / AIPilot.PREDICT_STEP)
		check(_col(cols[0], RouteView.COL_CLEAR) and _col(cols[cols.size() - 1], RouteView.COL_BLOCKED) and _col(cols[maxi(cut - 1, 0)], RouteView.COL_CLEAR) and _col(cols[cut], RouteView.COL_BLOCKED), "green up to it, red from it")
	# Across the clearing in the middle of the wood, in the open: clear all the way.
	var from := Vector3.INF
	for x in range(-48, 49, 6):   # (somewhere 30 m of open air run straight ahead)
		for z in range(-48, 49, 6):
			var spot := Vector3(x, 10.0, z)
			if from == Vector3.INF and layout.segment_clear(spot, spot + Vector3(0, 0, 30.0), 3.0):
				from = spot
	var open := from != Vector3.INF
	if open:
		b.fly_from(from, Vector3(0, 0, 1), b.profile.v_best)
		ai.steer(b, from + Vector3(0, 0, 40.0), 1.0 / 60.0)
		view.refresh()
	if open and ai.predicted_clear >= ai.predict_horizon:
		check(view.blocked_point() == null and view.drawn("blocked").is_empty(), "a clear prediction draws no star")
		var cols: PackedColorArray = (view.surfaces["predicted"][0] as ImmediateMesh).surface_get_arrays(view.surfaces["predicted"][1])[Mesh.ARRAY_COLOR]
		check(Array(cols).all(func(c): return _col(c, RouteView.COL_CLEAR)), "and is all green")
	else:
		check(false, "the way across the clearing is open (%s), its prediction clear (%.2f of %.2f s)" % [open, ai.predicted_clear, ai.predict_horizon])
	view.queue_free()
	b.queue_free()
	await frames(1)


## The same scenario flown by two birds side by side in the same ticks (birds don't collide with each other), one with
## the view drawn every tick and one without: they fly the same.
func _unchanged(layout: ArenaLayout, arena: ArenaBuilder) -> void:
	var birds := []
	var pilots := []
	for k in 2:
		var b := _bird(layout, arena, "falcon")
		pilots.append(LabScenarios.start(LabScenarios.by_id("rail_front"), b, layout))
		birds.append(b)
	var view := RouteView.new()
	add_child(view)
	view.pilot = pilots[0].ai
	view.bird = birds[0]
	view.rejected = true
	var apart := 0.0
	for i in 600:
		await frames(1)
		view.refresh()
		apart = maxf(apart, birds[0].global_position.distance_to(birds[1].global_position))
	var a: AIPilot = pilots[0].ai
	var c: AIPilot = pilots[1].ai
	print("flown with the view and without: at most %.6f m apart over 10 s; replans %d / %d, routes %d / %d points" % [apart, a.replans, c.replans, a.route.size(), c.route.size()])
	check(apart < 1e-5 and a.replans == c.replans and _same(PackedVector3Array(a.route), PackedVector3Array(c.route)), "drawing the view changes no flight")
	view.queue_free()
	for b in birds:
		b.queue_free()
	await frames(1)


func _lab() -> void:
	var lab: Node = load("res://scenes/bird_lab.tscn").instantiate()
	add_child(lab)
	await frames(5)
	lab.speed = 1.0
	lab.bird_id = "falcon"
	lab._pick_scenario(LabScenarios.LIST.find(LabScenarios.by_id("rail_front")))
	await frames(60)
	var ai: AIPilot = lab.pilot.ai
	check(lab.layout.outposts.size() > 0 and lab.arena.is_inside_tree(), "the route scenario flies in the pine wood (outposts %d)" % lab.layout.outposts.size())
	check(lab.route_view.visible and ai != null and ai.target == LabScenarios.rail(lab.layout), "the route view shows, the AI is going to the rail")
	await get_tree().process_frame
	check(_same(lab.route_view.drawn("route"), PackedVector3Array(ai.route)), "the lab draws the AI's route (%d points)" % ai.route.size())
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	lab._unhandled_input(key)
	await get_tree().process_frame
	check(not lab.route_view.visible, "P hides the route view")
	lab._unhandled_input(key)
	lab._pick_scenario(LabScenarios.LIST.find(LabScenarios.by_id("land_level")))
	await frames(5)
	check(lab.layout.outposts.is_empty() and lab.layout.trees.size() == 1 and lab.arena.is_inside_tree(), "a landing goes back to the one-tree arena")
	check(not lab.route_view.visible, "with no AI flying, no route view")
	lab.queue_free()
	Engine.time_scale = 1.0
	await frames(2)


func _bird(layout: ArenaLayout, arena: ArenaBuilder, id: String) -> Bird:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, null)
	b.arena = arena
	b.rig.visible = false
	return b


## A drawn vertex colour is `want` (stored 8 bits a channel).
static func _col(c: Color, want: Color) -> bool:
	return absf(c.r - want.r) < 0.01 and absf(c.g - want.g) < 0.01 and absf(c.b - want.b) < 0.01 and absf(c.a - want.a) < 0.01


static func _same(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].distance_to(b[i]) > 1e-4:
			return false
	return true
