extends TestCase
## Diagnostic: the way home. Each bird, flown by AIPilot from just past a course's last gate (along its way through, at
## cruise), is sent to land on the start rail (go_to_perch), as a racer is once every gate is taken: does it land, how
## long it takes, how many approaches and touches of wood. With the course's posts in (`--posts`, the default) or out
## (`--no-posts`), to tell the rail's approach from the gates' wood near it.
##   .\probe.ps1 -Headless probe_race_home [--seed 7] [--course <n>] [--no-posts] [--seconds 45] [--tries 3]

func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_seed := int(Boot.arg_value(args, "--seed")) if Boot.arg_value(args, "--seed") != "" else 7
	var course_seed := int(Boot.arg_value(args, "--course")) if Boot.arg_value(args, "--course") != "" else arena_seed
	var seconds := float(Boot.arg_value(args, "--seconds")) if Boot.arg_value(args, "--seconds") != "" else 45.0
	var tries := int(Boot.arg_value(args, "--tries")) if Boot.arg_value(args, "--tries") != "" else 3
	var layout := Pinewood.generate(arena_seed)
	var course := RaceCourse.generate(layout, course_seed)
	var posts := not args.has("--no-posts")
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	if posts:
		course.apply(layout)
	arena.build(layout)
	var last := course.gates[-1]
	print("HOME seed %d: rail at %s facing %s, %.0f m from the last gate; posts %s" % [arena_seed, str(course.start.position),
		str(course.start.facing), course.start.position.distance_to(last.centre), "in" if posts else "out"])
	var entries := []
	for id in BirdProfile.IDS:
		for t in tries:
			var b := Bird.new()
			var pilot := AIPilot.new(layout, 300 + t)
			add_child(b)
			b.setup(BirdProfile.by_id(id), layout, pilot)
			b.arena = arena
			b.rig.visible = false
			b.fly_from(last.centre + last.normal * 2.0, last.normal, b.profile.v_best)
			pilot.go_to_perch(b, course.start)
			entries.append({"id": id, "bird": b, "pilot": pilot, "landed": INF, "approaches": 0, "mode": pilot.mode})
	for f in int(seconds * 60.0):
		await get_tree().physics_frame
		var all := true
		for e in entries:
			var b: Bird = e.bird
			var pl: AIPilot = e.pilot
			if e.landed == INF:
				if b.state == Bird.State.PERCHED and b.perch == course.start:
					e.landed = f / 60.0
				elif b.state == Bird.State.PERCHED:   # (landed elsewhere: sent on again, as RacePilot does)
					pl.go_to_perch(b, course.start)
				if pl.target != course.start and pl.target == null and b.state == Bird.State.FLYING and f % 120 == 0:
					pl.go_to_perch(b, course.start)
				if pl.mode != e.mode and pl.mode == AIPilot.Mode.FINAL:
					e.approaches += 1
				e.mode = pl.mode
				all = false
		if all:
			break
	var by := {}
	for e in entries:
		var b: Bird = e.bird
		print("HOME  %-8s %s  approaches %d  bonks %d  glances %d  wings %d" % [e.id, ("%5.1f s" % e.landed) if e.landed < INF else "  never", e.approaches, b.bonks, b.glances, b.wing_strikes])
		by[e.id] = by.get(e.id, 0) + int(e.landed < INF)
	for id in BirdProfile.IDS:
		print("HOME  %-8s landed %d of %d" % [id, by[id], tries])
	finish()
