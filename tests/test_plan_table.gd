extends TestCase
## FlightPlanner.prepare's lattice table (the game works it out on the loading screen): it answers every edge and node
## as the checks it stands for do, at every clearance a planner uses, so routes come out the same with it and without
## it; and a bird's route request ends after REQUEST_EXPANSIONS search steps, route or not.


func setup() -> void:
	var a := FlightExam.place()
	var t := FlightExam.add_tree(a, "pine")
	FlightExam.add_outpost(a, t)
	FlightExam.add_tree(a, "oak", Vector2(14.0, 6.0), 3)
	a.half_extent = 40.0
	a.boundary = 40.0
	FlightPlanner.prepare(a)
	var table: Dictionary = a.get_meta(FlightPlanner.EDGE_TABLE)
	var cs := FlightPlanner.species_clearances()
	check(cs.size() >= 2 and cs.has(FlightPlanner.DEFAULT_CLEARANCE), "the table covers each species' clearance and the default (%s)" % str(cs))
	# Every node and a spread of edges: the table's answer against the check's, at each clearance.
	var fp := FlightPlanner.new(a)
	var nodes := 0
	var node_wrong := 0
	for k: Vector3i in table.n:
		nodes += 1
		for c in cs:
			fp.clearance = c
			if (float(table.n[k]) >= c) != fp.node_usable(k):
				node_wrong += 1
	var edges := 0
	var edge_wrong := 0
	var clear_some := 0
	var blocked_some := 0
	var i := 0
	for k: Vector3i in table.e:
		for k2: Vector3i in table.e[k]:
			i += 1
			if i % 7 != 0:
				continue
			edges += 1
			var w := float(table.e[k][k2])
			clear_some += 1 if w >= cs[-1] else 0
			blocked_some += 1 if w < cs[0] else 0
			for c in cs:
				if (w >= c) != a.segment_clear(FlightPlanner.node_pos(k), FlightPlanner.node_pos(k2), c):
					edge_wrong += 1
	print("table: %d nodes, %d edges sampled (%d clear at the narrowest, %d blocked at the widest); wrong %d, %d" % [nodes, edges, clear_some, blocked_some, node_wrong, edge_wrong])
	check(nodes > 1000 and edges > 1000, "the table covers the lattice (%d nodes, %d edges sampled)" % [nodes, edges])
	check(clear_some > 0 and blocked_some > 0, "with edges both clear and blocked to tell apart")
	eq(node_wrong, 0, "every node answers as node_usable does, at every clearance")
	eq(edge_wrong, 0, "every edge answers as segment_clear does, at every clearance")
	# The same routes with the table as without it: every perch of the pine, from round the oak.
	var b := FlightExam.place()
	var tb := FlightExam.add_tree(b, "pine")
	FlightExam.add_outpost(b, tb)
	FlightExam.add_tree(b, "oak", Vector2(14.0, 6.0), 3)
	b.half_extent = 40.0
	b.boundary = 40.0
	var same := 0
	var routes := 0
	var searched := 0
	for q in FlightExam.perches_of(a, t.id):
		for id in ["crow", "falcon"]:
			var p := BirdProfile.by_id(id)
			var with := FlightPlanner.new(a, AIPilot.plan_clearance(p))
			var without := FlightPlanner.new(b, AIPilot.plan_clearance(p))
			var from := Vector3(22.0, 9.0, 14.0)
			var r1 := with.plan_to_perch(from, q, p)
			var r2 := without.plan_to_perch(from, b.perches[q.id], p)
			routes += 1
			same += 1 if r1 == r2 else 0
			searched += 1 if r1.size() > 3 else 0
	print("routes: %d of %d the same with the table as without (%d went round something)" % [same, routes, searched])
	eq(same, routes, "every route the same with the table as without")
	check(searched > 0, "some of them searched the lattice (went round the wood)")
	# A request ends when its steps run out, route or not: a search that needs more steps than it has left finds none.
	var q0: Perch = null
	var need := 0
	for q in FlightExam.perches_of(a, t.id):
		var pl := FlightPlanner.new(a, 1.4)
		pl._steps_left = 100000
		var r := pl.plan(Vector3(22.0, 9.0, 14.0), q.approach_anchor(), -1, t.id, -1, q.id)
		if r.size() > 2 and 100000 - pl._steps_left > need:
			need = 100000 - pl._steps_left
			q0 = q
	check(q0 != null and need > 4, "a route that takes searching (%d steps)" % need)
	if q0 != null:
		var pl := FlightPlanner.new(a, 1.4)
		pl._steps_left = need - 1
		var r := pl.plan(Vector3(22.0, 9.0, 14.0), q0.approach_anchor(), -1, t.id, -1, q0.id)
		print("a search of %d steps given %d: %d points, %d steps left" % [need, need - 1, r.size(), pl._steps_left])
		check(r.is_empty() and pl._steps_left == 0, "given a step fewer than it needs, the search ends without a route")
	check(FlightPlanner.REQUEST_EXPANSIONS < FlightPlanner.MAX_EXPANSIONS, "a bird's request has fewer steps than a course's planning")
	finish()
