extends TestCase
## Race mode (RaceCourse, RaceRun, RaceRecord): a gate counts only through its window the way it faces; the gates go
## in order; the clock starts off the start rail and stops when the bird lands back on it with every gate taken (not
## before, not on another perch); a miss is counted and the gate stays next; best times are kept only when better, and
## landing on the rail with gates to go resets the run; the average of the last three finishes counts the slower ones too. The AI field (pilots and aces) takes every gate
## without bonking and lands home on the rail. The way home is planned: straight from the last gate to a run-in in
## front of the rail (hand-built: a tree on the line, a last gate facing away, home from behind all break it). The generated course keeps its rules on two seeds, every bird can fly it
## (LinePilot, in the simulation), and in the built wood (its collision) each window's way in and out is open; birds
## flown through a gate in the simulation count it, and birds flown beside it or through it backwards don't.

const SHARDS := 11
const DT := 1.0 / 60.0
const ARENA := 7   ## every course here is on the game's arena (Menu.ARENA_SEED); the course seeds are the menu's


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(0):
		_gate_crossing()
		_run_rules()
		_record()
		_rules_by_hand()
		_home_by_hand()
		_dubins()
		_course_rules(28)
	if in_shard(1):
		await _course_in_the_wood(23)
	if in_shard(2):
		await _ai_takes_the_first_gate(16)
	if in_shard(3):
		await _flyable(23)
	if in_shard(4):
		await _flyable(17)
	if in_shard(5):
		await _field_finishes(16)
	if in_shard(6):
		await _goes_round(16)
		await _takes_off_again(16)
		await _lands_from_run_in(16)
	for k in RaceCourse.STYLES.size():   # (shards 7-10: the menu's course of each style)
		if in_shard(7 + k):
			_style_course(RaceCourse.STYLES[k])
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


## The clock, the order, the splits, misses and the finish: back on the start rail with every gate taken.
func _run_rules() -> void:
	var gs: Array[RaceCourse.Gate] = [_gate("post", Vector3(0, 5, -10), Vector3.FORWARD), _gate("post", Vector3(0, 5, -20), Vector3.FORWARD),
		_gate("hoop", Vector3(0, 5, -30), Vector3.FORWARD)]
	var st := Perch.new()
	var elsewhere := Perch.new()
	var c := RaceCourse.from_gates(null, st, gs)
	var r := RaceRun.new(c)
	var at := Vector3(0, 5, 0)
	for i in 30:
		r.step(at, at, DT, st)
	eq(r.phase, RaceRun.Phase.READY, "on the perch: not started")
	eq(r.event, "", "no start (or reset) while it waits there")
	eq(r.clock, 0.0, "the clock waits on the perch")
	r.step(at, at + Vector3(0, 0, -0.2), DT, null)
	eq(r.event, "start", "off the perch: started")
	near(r.clock, DT, 1e-6, "the clock runs from the tick it leaves")
	# Round gate 0 (beside it) and through gate 1 first: neither counts.
	r.step(Vector3(4, 5, -9.5), Vector3(4, 5, -10.5), DT, null)
	eq(r.next, 0, "beside the first gate: not taken")
	eq(r.misses, 1, "beside the first gate: a miss")
	r.step(Vector3(0, 5, -19.5), Vector3(0, 5, -20.5), DT, null)
	eq(r.next, 0, "the second gate first doesn't count")
	eq(r.splits.size(), 0, "no split for it")
	# Back, and through gate 0: its split is the moment it crossed, within the tick.
	var t0 := r.clock
	r.step(Vector3(0, 5, -9.75), Vector3(0, 5, -10.75), DT, null)
	eq(r.next, 1, "through the first gate")
	near(r.splits[0], t0 + DT * 0.25, 1e-6, "its split, within the tick")
	r.step(Vector3(0, 5, -19.9), Vector3(0, 5, -20.1), DT, null)
	eq(r.next, 2, "then the second")
	check(r.splits[1] > r.splits[0], "splits in order")
	var t1 := r.clock
	r.step(Vector3(0, 5, -29.5), Vector3(0, 5, -30.5), DT, null)
	eq(r.event, "gate", "through the last gate")
	near(r.splits[2], t1 + DT * 0.5, 1e-6, "its split, within the tick")
	check(not r.finished() and r.home(), "every gate taken: not finished, on the way home")
	eq(r.state().next_centre, st.position, "the HUD's mark on the rail")
	for i in 30:
		r.step(at, at, DT, null)
	r.step(at, at, DT, elsewhere)
	check(not r.finished(), "landing on another perch doesn't finish")
	r.step(at, at, DT, null)
	var t2 := r.clock
	r.step(at, at, DT, st)
	check(r.finished(), "landed on the rail: finished")
	eq(r.event, "finish", "the finish's event")
	near(r.time, t2 + DT, 1e-6, "the time: the tick it landed")
	for i in 60:
		r.step(at, at + Vector3(0, 0, -1), DT, null)
	near(r.clock, r.time, 1e-6, "the clock stops at the finish")
	r.step(at, at, DT, st)
	check(r.finished() and r.next == 3, "landing on the rail again once finished changes nothing")
	# Back on the rail with gates to go: the run starts over.
	var r2 := RaceRun.new(c)
	r2.step(at, at + Vector3(0, 0, -0.2), DT, null)
	r2.step(Vector3(4, 5, -9.5), Vector3(4, 5, -10.5), DT, null)
	r2.step(Vector3(0, 5, -9.5), Vector3(0, 5, -10.5), DT, null)
	eq(r2.next, 1, "a gate taken")
	r2.step(at, at, DT, elsewhere)
	eq(r2.phase, RaceRun.Phase.RUNNING, "another perch: still running")
	r2.step(at, at, DT, st)
	eq(r2.event, "reset", "on the rail with gates to go: reset")
	check(r2.phase == RaceRun.Phase.READY and r2.next == 0 and r2.clock == 0.0 and r2.splits.is_empty() and r2.misses == 0,
		"ready to start again: the first gate next, the clock, splits and misses cleared")
	for i in 30:
		r2.step(at, at, DT, st)
	eq(r2.clock, 0.0, "the clock waits on the rail again")
	r2.step(at, at + Vector3(0, 0, -0.2), DT, null)
	check(r2.event == "start" and is_equal_approx(r2.clock, DT), "off the rail: a new run")


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
	near(float(RaceRecord.average(k)[0]), (41.0 + 38.5 + 40.0) / 3.0, 1e-6, "the average of the last three finishes, slower ones too")
	RaceRecord.offer(k, 50.0, [])
	near(float(RaceRecord.average(k)[0]), (41.0 + 38.5 + 50.0) / 3.0, 1e-6, "the last three: the oldest dropped")
	var k2 := RaceRecord.key(1, 2, "owl", "novice")
	eq(RaceRecord.average(k2), [INF, 0], "none yet")
	RaceRecord.offer(k2, 30.0, [])
	eq(RaceRecord.average(k2), [30.0, 1], "one finish: its time, of one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceRecord.path))
	RaceRecord.path = was


## Courses placed by hand in an empty wood: a leg turning tighter than the hawk's circle breaks the rules, a gentle
## one doesn't; a post standing in a gate's way in breaks them, the same post off to the side doesn't.
func _rules_by_hand() -> void:
	var st := Perch.new()
	st.position = Vector3(0, 5, 0)
	st.facing = Vector3.FORWARD
	var flat := func(gs: Array[RaceCourse.Gate], l: ArenaLayout) -> PackedStringArray:   # (the rules of the legs; the way home apart)
		return PackedStringArray(Array(RaceCourse.from_gates(l, st, gs).problems()).filter(func(x: String): return not x.begins_with("home:")))
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


## The menu's course of `style` (Menu.COURSES): full, every rule kept, and of its style -- technical: twelve gates,
## short legs, planned for the agile birds' turns; long: seven, long legs, routed through the wood where a smooth
## curve can't fly clear; level: windows within a few metres of each other; high and low: far apart.
func _style_course(style: String) -> void:
	var s: int = Menu.COURSES[style]
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s, BirdProfile.IDS, style)
	var what := "%s (course %d)" % [style, s]
	eq(c.style, style, what + ": in its style")
	eq(c.gates.size(), c.gate_count, what + ": a full course")
	var probs := c.problems()
	check(probs.is_empty(), what + ": the rules kept: %s" % "; ".join(probs))
	var lo := INF
	var hi := -INF
	var legs := 0.0
	var routed := 0
	for k in c.gates.size():
		lo = minf(lo, c.gates[k].centre.y)
		hi = maxf(hi, c.gates[k].centre.y)
		var a: Vector3 = c.gates[k - 1].centre if k > 0 else c.start.position
		legs += Vector2(c.gates[k].centre.x - a.x, c.gates[k].centre.z - a.z).length() / c.gates.size()
		routed += int(c.is_routed(c.gates, k))
	if style.begins_with("technical"):
		eq(c.gates.size(), 12, what + ": twelve gates")
		check(legs <= 21.0, what + ": short legs (%.1f m on average)" % legs)
		check(c.envelope.turn_r < AIPilot.cruise_turn_radius(BirdProfile.by_id("hawk")) * 0.7, what + ": turns planned for the agile birds (%.1f m)" % c.envelope.turn_r)
		eq(routed, 0, what + ": no leg routed")
	else:
		eq(c.gates.size(), 7, what + ": seven gates")
		check(legs >= 30.0, what + ": long legs (%.1f m on average)" % legs)
		check(routed >= 1, what + ": legs routed through the wood (%d)" % routed)
		near(c.envelope.turn_r, AIPilot.cruise_turn_radius(BirdProfile.by_id("hawk")), 1e-4, what + ": planned for every bird")
	if style.ends_with("high-low"):
		check(hi - lo >= 8.0, what + ": windows from %.1f to %.1f m up" % [lo, hi])
	else:
		check(hi - lo <= 4.0, what + ": windows level, from %.1f to %.1f m up" % [lo, hi])


## The way home, by hand in an empty wood (the rail facing -z, so home comes in from -z flying +z): a last gate out
## in front, facing home, keeps the rules; the same with a tree on the line home, facing away from home, or come
## round behind the rail doesn't.
func _home_by_hand() -> void:
	var st := Perch.new()
	st.position = Vector3(0, 5, 0)
	st.facing = Vector3.FORWARD
	var problem := func(centre: Vector3, n: Vector3, l: ArenaLayout) -> String:
		var g := _gate("post", centre, n)
		var gs: Array[RaceCourse.Gate] = [g]
		return RaceCourse.from_gates(l, st, gs).home_problem(gs)
	var l := ArenaLayout.new()
	var at := Vector3(-6, 5, -38)
	var c0 := RaceCourse.from_gates(l, st, [] as Array[RaceCourse.Gate])
	var home := (c0.home_in() - at) * Vector3(1, 0, 1)
	eq(problem.call(at, home.normalized(), l), "", "a last gate out in front, facing home: the way home keeps the rules")
	var treed := ArenaLayout.new()
	var mid := at.lerp(c0.home_in(), 0.5)
	treed.add_post(Vector2(mid.x, mid.z), 12.0, 0.3)
	check((problem.call(at, home.normalized(), treed) as String).contains("wood on the line home"), "a tree on the line home breaks them")
	check((problem.call(at, -home.normalized(), l) as String).contains("out of the last gate"), "the last gate facing away from home breaks them")
	check((problem.call(Vector3(2, 5, 30), Vector3.FORWARD, l) as String).contains("onto the rail's run-in"), "home from behind the rail breaks them")


## The generated course: whole, every rule kept, varied.
func _course_rules(s: int) -> RaceCourse:
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	eq(c.gates.size(), c.gate_count, "seed %d: a full course" % s)
	var probs := c.problems()
	check(probs.is_empty(), "seed %d: the rules kept: %s" % [s, "; ".join(probs)])
	check(c.start != null and c.layout.perches.has(c.start), "seed %d: it starts (and ends) on a perch of the wood" % s)
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
	check(hi - lo >= 5.5, "seed %d: windows from %.1f to %.1f m up" % [s, lo, hi])
	check(kinds.size() >= 3, "seed %d: gates of %d kinds" % [s, kinds.size()])
	check(left >= 1 and right >= 1, "seed %d: turns both ways (%d left, %d right)" % [s, left, right])
	near(c.envelope.turn_r, AIPilot.cruise_turn_radius(BirdProfile.by_id("hawk")), 1e-4, "planned for the widest turner, the hawk")
	return c


## In the built wood: the posts are solid; rays through each window along its way in and out meet no collision;
## and birds flown in the simulation count a gate through its window, not beside it or backwards.
func _course_in_the_wood(s: int) -> void:
	var l := Pinewood.generate(ARENA)
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
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	var res := await LinePilot.fly_course(l, c, BirdProfile.IDS, self)
	for k in c.gates.size():
		var by := BirdProfile.IDS.filter(func(id): return res[id][k].ok)
		check(by.size() >= 4, "seed %d leg %d: flown by %s" % [s, k, by])
	for id in BirdProfile.IDS:
		var n: int = res[id].filter(func(lg): return lg.ok).size()
		check(n >= c.gates.size() - 1, "seed %d: the %s flies %d of %d legs" % [s, id, n, c.gates.size()])


## Every bird at pilot and ace finishes seed 7's course, without bonking; a recruit, where it finishes, is slower
## than the ace of its species (2026-11-05: pilot 18.6-24.6 s, ace 18.7-24.5, recruits 25.4-32.6 or out).
func _field_finishes(s: int) -> void:
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var i := 0
	for sk in ["recruit", "pilot", "ace"]:
		for id in BirdProfile.IDS:
			trial.add_ai(id, sk, 100 + i)
			i += 1
	await trial.run(120.0)
	var by := {}
	for r in trial.results():
		by["%s %s" % [r.skill, r.id]] = r
	var pairs := 0
	for id in BirdProfile.IDS:
		for sk in ["pilot", "ace"]:
			var r: Dictionary = by["%s %s" % [sk, id]]
			eq(r.gates, c.gate_count, "seed %d: the %s %s takes every gate" % [s, sk, id])
			check(r.time < INF, "seed %d: the %s %s lands home on the rail" % [s, sk, id])
			check(r.course_bonks == 0, "seed %d: the %s %s doesn't bonk on the course (%d)" % [s, sk, id, r.course_bonks])
		var rec: Dictionary = by["recruit %s" % id]
		var ace: Dictionary = by["ace %s" % id]
		if rec.time < INF and ace.time < INF:
			pairs += 1
			check(rec.time > ace.time, "seed %d: the recruit %s (%.1f s) is slower than the ace (%.1f s)" % [s, id, rec.time, ace.time])
	check(pairs >= 2, "seed %d: recruits finished to compare (%d)" % [s, pairs])
	trial.queue_free()


## Every gate taken, racers out on the rail's run-in -- having left from that rail, as every racer has -- fly in and
## land on it (the tree it left mustn't be given a departure's wide berth now: it carries the rail it's landing on).
func _lands_from_run_in(s: int) -> void:
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var es := []
	for k in BirdProfile.IDS.size():
		var id: String = BirdProfile.IDS[k]
		var e := trial.add_ai(id, "pilot", 11 + k)
		e.run.phase = RaceRun.Phase.RUNNING
		e.run.next = c.gates.size()
		var pl: RacePilot = e.pilot
		pl.guide._last_tree = c.start.tree_id   # (as it is after leaving the rail: RacePilot._start)
		pl.guide._takeoff_pos = c.start.position
		pl.guide._left_perch = c.start.id
		var f := RaceCourse._flat(c.start.facing)
		var at := c.home_in() + f * 4.0
		e.bird.fly_from(at, -f, e.bird.profile.v_best)
		e.prev = at
		es.append(e)
	for t in 3:
		await trial.step()
	for e in es:   # (on its way home: the rail's tree no longer the one it's leaving)
		check((e.pilot as RacePilot).guide._takeoff_pos == Vector3.INF, "seed %d: the %s heading home has no departure clearance left round the rail's tree" % [s, e.bird.profile.id])
	await trial.run(30.0)
	for e in es:
		check(e.run.finished(), "seed %d: the %s, out on the rail's run-in, lands on it" % [s, e.bird.profile.id])
	trial.queue_free()


## The go-around's path (RacePilot.dubins): a U-turn either way is half a circle; a straight run is the straight line;
## each ends where it should, heading the way it should.
func _dubins() -> void:
	for side: float in [1.0, -1.0]:
		var pts := RacePilot.dubins(Vector2.ZERO, Vector2.RIGHT, Vector2(0, 20.0 * side), Vector2.LEFT, 10.0)
		near(_length(pts), PI * 10.0, 0.5, "a U-turn (%+.0f) is half a 10 m circle" % side)
		check(pts[-1].distance_to(Vector2(0, 20.0 * side)) < 0.01, "the U-turn (%+.0f) ends there" % side)
		check((pts[-1] - pts[-2]).normalized().dot(Vector2.LEFT) > 0.99, "heading back (%+.0f)" % side)
	near(_length(RacePilot.dubins(Vector2.ZERO, Vector2.RIGHT, Vector2(40, 0), Vector2.RIGHT, 5.0)), 40.0, 0.01, "straight on: the straight line")


static func _length(pts: PackedVector2Array) -> float:
	var n := 0.0
	for i in pts.size() - 1:
		n += pts[i].distance_to(pts[i + 1])
	return n


## A racer put down on the ground mid-race takes off again and flies on.
func _takes_off_again(s: int) -> void:
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var e := trial.add_ai("crow", "pilot", 5)
	e.run.phase = RaceRun.Phase.RUNNING
	e.run.next = 2
	var g := c.gates[2]
	var at := g.centre - g.normal * 20.0
	at.y = l.ground(at.x, at.z) + 0.3
	var pilot: RacePilot = e.pilot
	e.bird.controller = ScriptedInput.new()   # (set it down first, as test_ground_takeoff does; then the racer flies)
	e.bird.fly_from(at, (g.normal + Vector3.DOWN).normalized(), 1.0)
	e.prev = at
	for f in 60:
		await trial.step()
		if e.bird.state == Bird.State.GROUNDED:
			break
	check(e.bird.state == Bird.State.GROUNDED, "set down by the ground, it stands on it")
	e.bird.controller = pilot
	var flew_again := false
	for f in 60 * 12:
		await trial.step()
		var b: Bird = e.bird
		flew_again = flew_again or (b.state == Bird.State.FLYING and b.global_position.y - l.ground(b.global_position.x, b.global_position.z) > 2.0)
	check(flew_again, "the racer takes off again (2 m up within 12 s)")
	trial.queue_free()


## Put beside a gate on a clear line (a miss, left and right), a racer goes round and comes back through it.
func _goes_round(s: int) -> void:
	var l := Pinewood.generate(ARENA)
	var c := RaceCourse.generate(l, s)
	var trial := RaceTrial.new()
	add_child(trial)
	trial.setup(l, c)
	var k := 3
	var g := c.gates[k]
	var es := []
	for id in ["crow", "hawk"]:   # (not the falcon: turning back it loses ~6 m even flapping, too much beside a 7 m gate)
		for side: float in [-1.0, 1.0]:
			var e := trial.add_ai(id, "pilot", 7)
			e.run.phase = RaceRun.Phase.RUNNING
			e.run.next = k
			var at := g.centre - g.normal * 3.0 + g.right() * side * (g.half_w + 3.0)
			for out: float in [3.0, 4.5, 6.0, 8.0]:   # (beside it, on a line clear of the wood: going round, not a bonk)
				at = g.centre - g.normal * 3.0 + g.right() * side * (g.half_w + out)
				if l.segment_clear(at, at + g.normal * 12.0, 1.0):
					break
			check(l.segment_clear(at, at + g.normal * 12.0, 1.0), "a clear line beside gate %d (%+.0f)" % [k, side])
			e.bird.fly_from(at, g.normal, e.bird.profile.v_best)
			e.prev = at
			es.append([e, id, side])
	for f in 60 * 25:
		await trial.step()
	for x in es:
		var e: Dictionary = x[0]
		check(e.run.next > k, "the %s put %s of gate %d goes round and through it (go-arounds %d)" % [x[1], "left" if x[2] < 0.0 else "right", k, e.pilot.go_arounds])
		check(e.pilot.go_arounds >= 1, "the %s put %s of gate %d went round" % [x[1], "left" if x[2] < 0.0 else "right", k])
	trial.queue_free()


## An AI racer leaves the start and flies through the first gate (the pipeline works; how well it races is
## probe_race's to measure).
func _ai_takes_the_first_gate(s: int) -> void:
	var l := Pinewood.generate(ARENA)
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
