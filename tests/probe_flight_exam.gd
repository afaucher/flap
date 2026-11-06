extends TestCase
## Diagnostic: the flight exam's landings (FlightExam, docs/design/flight_exam.md). Every perch of one tree grown alone
## (or its outpost's rail), each species sent to land on each from several bearings round it; prints every attempt
## and a table of landed / tried per species.
##   .\probe.ps1 -Headless probe_flight_exam [--tree pine|veteran|pole|oak] [--rail] [--birds crow,...]
##        [--bearings 0,90,180,270] [--ups 3] [--out 30] [--seconds 40] [--seed 1] [--perches 3,5] [--fails]
##   ... probe_flight_exam --gates [--courses straight,uturn,...] [--skills recruit,pilot,ace]: the gate courses

func _init() -> void:
	timeout_sec = 1800.0


func _list(args: PackedStringArray, key: String, def: String) -> PackedStringArray:
	var v := Boot.arg_value(args, key)
	return (v if v != "" else def).split(",")


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--gates"):
		await _gates(args)
		finish()
		return
	var form := Boot.arg_value(args, "--tree") if Boot.arg_value(args, "--tree") != "" else "pine"
	var s := int(Boot.arg_value(args, "--seed")) if Boot.arg_value(args, "--seed") != "" else 1
	var seconds := float(Boot.arg_value(args, "--seconds")) if Boot.arg_value(args, "--seconds") != "" else 40.0
	var out := float(Boot.arg_value(args, "--out")) if Boot.arg_value(args, "--out") != "" else 30.0
	var birds := _list(args, "--birds", ",".join(BirdProfile.IDS))
	var bearings := _list(args, "--bearings", "0,90,180,270")
	var ups := _list(args, "--ups", "3")
	var a := FlightExam.place()
	var t := FlightExam.add_tree(a, form, Vector2.ZERO, s)
	var targets: Array[Perch] = []
	if args.has("--rail"):
		var r := FlightExam.add_outpost(a, t, s)
		if r != null:
			targets.append(r)
	else:
		targets = FlightExam.perches_of(a, t.id)
	var only := Boot.arg_value(args, "--perches")
	if only != "":
		var keep: Array[Perch] = []
		for q in targets:
			if only.split(",").has(str(q.id)):
				keep.append(q)
		targets = keep
	print("EXAM %s (seed %d): %d perches" % [form, s, targets.size()])
	for q in targets:
		print("EXAM  perch %2d %s at %s, %.1f m long, slope %+.2f, facing %s" % [q.id, "top " if q.kind == Perch.Kind.TREETOP else "limb", str(q.position.snapped(Vector3.ONE * 0.1)),
			q.a.distance_to(q.b), (q.b.y - q.a.y) / maxf(Vector2(q.b.x - q.a.x, q.b.z - q.a.z).length(), 0.01), str(q.facing.snapped(Vector3.ONE * 0.01))])
	var ex := FlightExam.new(self, a)
	await frames(2)
	var k := 0
	for id in birds:
		for q in targets:
			for be in bearings:
				for u in ups:
					k += 1
					ex.add_landing(id, q, float(be), float(u), out, 100 + k)
	var tr := Boot.arg_value(args, "--trace")
	if tr != "":
		ex.trace = ex.attempts[int(tr)]
		print("TRACE " + ex.trace.describe())
		var r := ex.trace.pilot.route
		for i in r.size():
			print("TRACE  route %d %s" % [i, str(r[i].snapped(Vector3.ONE * 0.1))])
	var t0 := Time.get_ticks_msec()
	await ex.fly(seconds)
	var fails := args.has("--fails")
	for at in ex.attempts:
		if not fails or not at.ok():
			print("EXAM   " + at.describe())
	print("EXAM %s: %d attempts in %.0f s" % [form, ex.attempts.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	for id in birds:
		var r := FlightExam.rate(ex.attempts, id)
		var times := []
		for at in ex.attempts:
			if at.id == id and at.ok():
				times.append(at.landed)
		times.sort()
		print("EXAM %-8s landed %3d / %3d   median %.1f s" % [id, r.x, r.y, times[times.size() / 2] if not times.is_empty() else INF])
	var by_perch := ""
	for q in targets:
		var n := 0
		var ok := 0
		for at in ex.attempts:
			if at.perch == q:
				n += 1
				ok += 1 if at.ok() else 0
		by_perch += " %d:%d/%d" % [q.id, ok, n]
	print("EXAM by perch:" + by_perch)
	ex.clear()
	finish()


func _gates(args: PackedStringArray) -> void:
	var seconds := float(Boot.arg_value(args, "--seconds")) if Boot.arg_value(args, "--seconds") != "" else 40.0
	var birds := _list(args, "--birds", ",".join(BirdProfile.IDS))
	var names := _list(args, "--courses", ",".join(FlightExam.COURSES.keys()))
	var skills := _list(args, "--skills", "pilot")
	var a := FlightExam.place()
	var ex := FlightExam.new(self, a)
	var courses := {}
	var k := 0
	for nm in names:
		# (each course on its own patch of ground, 200 m apart: their posts don't meet)
		var off := Vector3(200.0 * k, 0.0, 0.0)
		k += 1
		var gs := FlightExam.gates_of(nm)
		for g in gs:
			g.centre += off
			g.face(g.normal, ArenaLayout.GROUND_Y)
		courses[nm] = ex.add_course(gs, FlightExam.GATE_START + off, Vector3(0, 0, 1))
	a.half_extent = 200.0 * k + 100.0
	a.boundary = a.half_extent
	ex.build()
	await frames(2)
	k = 0
	for id in birds:
		for sk in skills:
			for nm in names:
				k += 1
				ex.add_race(id, courses[nm], "%s %s" % [nm, sk.substr(0, 3)], sk, 200 + k)
	await ex.fly(seconds)
	for at in ex.attempts:
		print("GATES  " + at.describe())
	for id in birds:
		var r := FlightExam.rate(ex.attempts, id)
		print("GATES %-8s through %3d / %3d" % [id, r.x, r.y])
	ex.clear()
