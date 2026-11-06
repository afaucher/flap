extends TestCase
## Diagnostic: can each bird fly each leg of a course? Every bird flies the course's planned line with LinePilot (the
## line known exactly, no avoidance or noise, the full bank limit), each leg from where the last left it (a failed leg
## puts the bird back at its gate), and each leg is marked per bird: ok, or how far it strayed, how low it got, how many
## times it touched wood. A leg no bird can fly is the course's to fix; one they can fly and the AI misses is the AI's.
##   .\probe.ps1 -Headless probe_flyable [--seed 7] [--course <n>] [--birds crow,...] [--plan-for <birds>]

func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_seed := int(Boot.arg_value(args, "--seed")) if Boot.arg_value(args, "--seed") != "" else 7
	var course_seed := int(Boot.arg_value(args, "--course")) if Boot.arg_value(args, "--course") != "" else arena_seed
	var birds := (Boot.arg_value(args, "--birds") if Boot.arg_value(args, "--birds") != "" else ",".join(BirdProfile.IDS)).split(",")
	var plan_for: Array = Array(Boot.arg_value(args, "--plan-for").split(",")) if Boot.arg_value(args, "--plan-for") != "" else BirdProfile.IDS
	var layout := Pinewood.generate(arena_seed)
	var course := RaceCourse.generate(layout, course_seed, plan_for, Boot.arg_value(args, "--style"))
	var res := await LinePilot.fly_course(layout, course, Array(birds), self)
	print("FLY seed %d: %d gates, planned for %s" % [arena_seed, course.gates.size(), ",".join(plan_for)])
	var head := "FLY  #  kind        height  turn  climb  radius |"
	for id in birds:
		head += " %-22s|" % id
	print(head)
	var legs := course.legs()
	var bad := 0
	for k in course.gates.size():
		var lg: Dictionary = legs[k]
		var row := "FLY %2d  %-10s %5.1f  %+4.0f  %+5.0f  %6.1f |" % [k, lg.kind, lg.height, legs[k - 1].turn if k > 0 else 0.0, lg.climb, lg.radius]
		var all_ok := true
		for id in birds:
			var r: Dictionary = res[id][k]
			all_ok = all_ok and r.ok
			row += " %-22s|" % (("ok %4.1fm/s %2.0fdeg" % [r.speed, r.bank]) if r.ok else ("NO off %.1f low %.1f t%d" % [r.off, r.low, r.touches]))
		bad += 0 if all_ok else 1
		print(row)
	print("FLY %d of %d legs flown by every bird" % [course.gates.size() - bad, course.gates.size()])
	finish()
