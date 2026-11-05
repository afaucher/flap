extends TestCase
## Race mode (RaceCourse, RaceRun, RaceRecord): a gate counts only through its window the way it faces; the gates go
## in order; the clock starts off the perch and stops at the finish; a miss is counted and the gate stays next; best
## times are kept only when better. The generated course keeps its rules on two seeds, every bird can fly it
## (LinePilot, in the simulation), and in the built wood (its collision) each window's way in and out is open; birds
## flown through a gate in the simulation count it, and birds flown beside it or through it backwards don't.

const SHARDS := 5
const DT := 1.0 / 60.0


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(0):
		_gate_crossing()
		_run_rules()
		_record()
		_rules_by_hand()
		_course_rules(11)
	if in_shard(1):
		await _course_in_the_wood(7)
	if in_shard(2):
		await _ai_takes_the_first_gate(7)
	if in_shard(3):
		await _flyable(11)
	if in_shard(4):
		await _flyable(7)
	finish()


static func _gate(kind: String, centre: Vector3, n: Vector3) -> RaceCourse.Gate:
	var g := RaceCourse.Gate.new()
	g.kind = kind
	g.centre = centre
	g.normal = n
	if kind == "post":
		g.face(n, 0.0)
	return g


## Through the window the way it faces counts; backwards, beside it (left and right), over and under it don't; a
## hoop's round window leaves its square's corners out.
func _gate_crossing() -> void:
	var g := _gate("post", Vector3(0, 5, 0), Vector3.FORWARD)   # (faces -z)
	near(g.crossing(Vector3(0, 5, 1), Vector3(0, 5, -1)), 0.5, 1e-6, "straight through the middle")
	near(g.crossing(Vector3(0.5, 5, 0.25), Vector3(0.5, 5, -0.75)), 0.25, 1e-6, "where in the tick it crosses")
	eq(g.crossing(Vector3(0, 5, -1), Vector3(0, 5, 1)), -1.0, "backwards doesn't count")
	for side: float in [-1.0, 1.0]:
		eq(g.crossing(Vector3(1.6 * side, 5, 1), Vector3(1.6 * side, 5, -1)), -1.0, "beside it (%+.0f) doesn't count" % side)
		check(g.missed(Vector3(1.6 * side, 5, 1), Vector3(1.6 * side, 5, -1)), "beside it (%+.0f) is a miss" % side)
		check(g.crossing(Vector3(1.4 * side, 5, 1), Vector3(1.4 * side, 5, -1)) >= 0.0, "just inside its edge (%+.0f) counts" % side)
		eq(g.crossing(Vector3(0, 5 + 1.6 * side, 1), Vector3(0, 5 + 1.6 * side, -1)), -1.0, "over / under it (%+.0f) doesn't count" % side)
	check(not g.missed(Vector3(0, 5, -1), Vector3(0, 5, 1)), "backwards isn't a miss either")
	check(not g.missed(Vector3(30, 5, 1), Vector3(30, 5, -1)), "far beside it isn't a miss")
	var h := _gate("hoop", Vector3(0, 5, 0), Vector3.RIGHT)   # (faces +x)
	check(h.crossing(Vector3(-1, 5, 0), Vector3(1, 5, 0)) >= 0.0, "through the hoop")
	eq(h.crossing(Vector3(-1, 6.2, 1.2), Vector3(1, 6.2, 1.2)), -1.0, "a hoop's corner isn't in it")
	check(_gate("post", Vector3(0, 5, 0), Vector3.RIGHT).crossing(Vector3(-1, 6.2, 1.2), Vector3(1, 6.2, 1.2)) >= 0.0, "a post gate's corner is")


## The clock, the order, the splits, misses and the finish.
func _run_rules() -> void:
	var gs: Array[RaceCourse.Gate] = [_gate("post", Vector3(0, 5, -10), Vector3.FORWARD), _gate("post", Vector3(0, 5, -20), Vector3.FORWARD),
		_gate("hoop", Vector3(0, 5, -30), Vector3.FORWARD)]
	var c := RaceCourse.from_gates(null, Perch.new(), gs)
	var r := RaceRun.new(c)
	var at := Vector3(0, 5, 0)
	for i in 30:
		r.step(at, at, DT, true)
	eq(r.phase, RaceRun.Phase.READY, "on the perch: not started")
	eq(r.clock, 0.0, "the clock waits on the perch")
	r.step(at, at + Vector3(0, 0, -0.2), DT, false)
	eq(r.event, "start", "off the perch: started")
	near(r.clock, DT, 1e-6, "the clock runs from the tick it leaves")
	# Round gate 0 (beside it) and through gate 1 first: neither counts.
	r.step(Vector3(4, 5, -9.5), Vector3(4, 5, -10.5), DT, false)
	eq(r.next, 0, "beside the first gate: not taken")
	eq(r.misses, 1, "beside the first gate: a miss")
	r.step(Vector3(0, 5, -19.5), Vector3(0, 5, -20.5), DT, false)
	eq(r.next, 0, "the second gate first doesn't count")
	eq(r.splits.size(), 0, "no split for it")
	# Back, and through gate 0: its split is the moment it crossed, within the tick.
	var t0 := r.clock
	r.step(Vector3(0, 5, -9.75), Vector3(0, 5, -10.75), DT, false)
	eq(r.next, 1, "through the first gate")
	near(r.splits[0], t0 + DT * 0.25, 1e-6, "its split, within the tick")
	r.step(Vector3(0, 5, -19.9), Vector3(0, 5, -20.1), DT, false)
	eq(r.next, 2, "then the second")
	check(r.splits[1] > r.splits[0], "splits in order")
	check(not r.finished(), "not finished with a gate to go")
	var t1 := r.clock
	r.step(Vector3(0, 5, -29.5), Vector3(0, 5, -30.5), DT, false)
	check(r.finished(), "through the last gate: finished")
	near(r.time, t1 + DT * 0.5, 1e-6, "the finish time, within the tick")
	for i in 60:
		r.step(at, at + Vector3(0, 0, -1), DT, false)
	near(r.clock, r.time, 1e-6, "the clock stops at the finish")


## A better time replaces the best; a worse one doesn't.
func _record() -> void:
	var was := RaceRecord.path
	RaceRecord.path = "user://test_race_best_%d.cfg" % OS.get_process_id()   # (its own: tests run side by side)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceRecord.path))
	var k := RaceRecord.key(1, 2, "crow", "novice")
	check(RaceRecord.best(k).is_empty(), "no best yet")
	check(RaceRecord.offer(k, 40.0, [10.0, 20.0]), "the first time is a best")
	check(not RaceRecord.offer(k, 41.0, [11.0, 21.0]), "a slower time isn't")
	near(RaceRecord.best(k).time, 40.0, 1e-6, "the best kept")
	check(RaceRecord.offer(k, 38.5, [9.0, 19.0]), "a faster one is")
	near(RaceRecord.best(k).time, 38.5, 1e-6, "and replaces it")
	near(float(RaceRecord.best(k).splits[0]), 9.0, 1e-6, "with its splits")
	check(RaceRecord.best(RaceRecord.key(1, 2, "crow", "realistic")).is_empty(), "each way of flying has its own")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceRecord.path))
	RaceRecord.path = was


## Courses placed by hand in an empty wood: a leg turning tighter than the hawk's circle breaks the rules, a gentle
## one doesn't; a post standing in a gate's way in breaks them, the same post off to the side doesn't.
func _rules_by_hand() -> void:
	var st := Perch.new()
	st.position = Vector3(0, 5, 0)
	st.facing = Vector3.FORWARD
	var flat := func(gs: Array[RaceCourse.Gate], l: ArenaLayout) -> PackedStringArray:
		return RaceCourse.from_gates(l, st, gs).problems()
	var l := ArenaLayout.new()
	var gentle: Array[RaceCourse.Gate] = [_gate("post", Vector3(0, 5, -20), Vector3.FORWARD), _gate("post", Vector3(-12, 5, -40), Vector3(-0.5, 0, -1).normalized())]
	var probs: PackedStringArray = flat.call(gentle, l)
	check(probs.is_empty(), "a gentle course keeps the rules: %s" % "; ".join(probs))
	var tight: Array[RaceCourse.Gate] = [_gate("post", Vector3(0, 5, -20), Vector3.FORWARD), _gate("post", Vector3(-16, 5, -26), Vector3(-1, 0, -0.2).normalized())]
	probs = flat.call(tight, l)
	check(Array(probs).any(func(x: String): return x.contains("turns at")), "a turn tighter than the hawk's circle breaks them: %s" % "; ".join(probs))
	var blocked := ArenaLayout.new()
	blocked.add_post(Vector2(-8.87, -33.74), 12.0, 0.15)   # (on gate 1's way in, 7 m out in front of it)
	probs = flat.call(gentle, blocked)
	check(Array(probs).any(func(x: String): return x.contains("way in or out")), "a post in a gate's way in breaks them: %s" % "; ".join(probs))
	var aside := ArenaLayout.new()
	aside.add_post(Vector2(-25.0, -33.0), 12.0, 0.15)   # (well off to the side)
	probs = flat.call(gentle, aside)
	check(probs.is_empty(), "the same post off to the side doesn't: %s" % "; ".join(probs))


## The generated course: whole, every rule kept, varied.
func _course_rules(s: int) -> RaceCourse:
	var l := Pinewood.generate(s)
	var c := RaceCourse.generate(l, s)
	eq(c.gates.size(), RaceCourse.GATES, "seed %d: a full course" % s)
	var probs := c.problems()
	check(probs.is_empty(), "seed %d: the rules kept: %s" % [s, "; ".join(probs)])
	check(c.gates[-1].finish and not c.gates[0].finish, "seed %d: the last gate is the finish" % s)
	var lo := INF
	var hi := -INF
	var kinds := {}
	var left := 0
	var right := 0
	for lg in c.legs():
		lo = minf(lo, lg.height)
		hi = maxf(hi, lg.height)
		kinds[lg.kind] = true
		left += 1 if lg.turn > 15.0 else 0
		right += 1 if lg.turn < -15.0 else 0
		check(lg.radius >= c.envelope.turn_r - 0.01, "seed %d gate %d: its line turns no tighter than the hawk can (%.1f m)" % [s, lg.gate, lg.radius])
	check(hi - lo >= 6.0, "seed %d: windows from %.1f to %.1f m up" % [s, lo, hi])
	check(kinds.size() >= 3, "seed %d: gates of %d kinds" % [s, kinds.size()])
	check(left >= 1 and right >= 1, "seed %d: turns both ways (%d left, %d right)" % [s, left, right])
	near(c.envelope.turn_r, AIPilot.cruise_turn_radius(BirdProfile.by_id("hawk")), 1e-4, "planned for the widest turner, the hawk")
	return c


## In the built wood: the posts are solid; rays through each window along its way in and out meet no collision;
## and birds flown in the simulation count a gate through its window, not beside it or backwards.
func _course_in_the_wood(s: int) -> void:
	var l := Pinewood.generate(s)
	var c := RaceCourse.generate(l, s)
	var trees0 := l.trees.size()
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var posts := c.gates.filter(func(g): return g.kind == "post").size()
	eq(l.trees.size() - trees0, posts * 2, "two posts in the wood for each post gate")
	await frames(2)
	var space := trial.get_world_3d().direct_space_state
	for k in c.gates.size():
		var g := c.gates[k]
		var q := PhysicsRayQueryParameters3D.create(g.centre - g.normal * c.envelope.entry(), g.centre + g.normal * c.envelope.exit(), ArenaBuilder.WORLD_LAYER)
		check(space.intersect_ray(q).is_empty(), "gate %d: its way in and out is open (collision)" % k)
		for p in g.rim():
			var qr := PhysicsRayQueryParameters3D.create(p - g.normal * RaceCourse.RIM_LANE, p + g.normal * RaceCourse.RIM_LANE, ArenaBuilder.WORLD_LAYER)
			check(space.intersect_ray(qr).is_empty(), "gate %d: the lanes along its window's edges are open (collision)" % k)
	# Birds put just in front of gate 0, flying its way (through it, and a window and a half to either side), and one
	# flying through it the wrong way.
	var g0 := c.gates[0]
	var cases := [[0.0, 1.0, true], [g0.half_w + 2.5, 1.0, false], [-g0.half_w - 2.5, 1.0, false], [0.0, -1.0, false]]
	var es := []
	for cs in cases:
		var e := trial.add_bird("crow", ScriptedInput.new())
		var b: Bird = e.bird
		var dir: Vector3 = g0.normal * float(cs[1])
		var at: Vector3 = g0.centre - dir * 5.0 + g0.right() * float(cs[0]) + Vector3.UP * 0.3
		b.fly_from(at, dir, b.profile.v_best)
		e.prev = at
		e.run.phase = RaceRun.Phase.RUNNING
		es.append(e)
	for f in 90:
		await trial.step()
	for i in cases.size():
		var e: Dictionary = es[i]
		var label := "through it" if cases[i][2] else ("backwards" if cases[i][1] < 0.0 else "beside it (%+.1f m)" % cases[i][0])
		eq(e.run.next, 1 if cases[i][2] else 0, "a bird flown %s: gate 0 %s" % [label, "taken" if cases[i][2] else "not taken"])
	check(es[0].run.splits.size() == 1 and es[0].run.splits[0] > 0.2 and es[0].run.splits[0] < 1.0, "its split: about 5 m at cruise (%s)" % str(es[0].run.splits))
	trial.queue_free()


## Every bird can fly the course's planned line (LinePilot: the line known exactly, the bird's own flight model): every
## leg by at least four of the five birds, and every bird at least nine of the ten legs (2026-11-05: seed 11 all of
## them; seed 7 all but the falcon's leg 1, a descent out of a 62 deg turn).
func _flyable(s: int) -> void:
	var l := Pinewood.generate(s)
	var c := RaceCourse.generate(l, s)
	var res := await LinePilot.fly_course(l, c, BirdProfile.IDS, self)
	for k in c.gates.size():
		var by := BirdProfile.IDS.filter(func(id): return res[id][k].ok)
		check(by.size() >= 4, "seed %d leg %d: flown by %s" % [s, k, by])
	for id in BirdProfile.IDS:
		var n: int = res[id].filter(func(lg): return lg.ok).size()
		check(n >= c.gates.size() - 1, "seed %d: the %s flies %d of %d legs" % [s, id, n, c.gates.size()])


## An AI racer leaves the start and flies through the first gate (the pipeline works; how well it races is
## probe_race's to measure).
func _ai_takes_the_first_gate(s: int) -> void:
	var l := Pinewood.generate(s)
	var c := RaceCourse.generate(l, s)
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var e := trial.add_ai("crow", "ace", 3)
	var inp: Variant = e.pilot.sample(e.bird, DT)
	check(inp is FlightInput, "a racer flies by a FlightInput")
	for f in 60 * 12:
		await trial.step()
		if e.run.next >= 1:
			break
	eq(e.run.phase, RaceRun.Phase.RUNNING, "it left the start")
	check(e.run.next >= 1, "it took the first gate within 12 s")
	trial.queue_free()
