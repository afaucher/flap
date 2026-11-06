extends TestCase
## Diagnostic: many race courses on one arena at a glance -- for each course seed, whether it's full (every gate, the
## way home kept), its kinds of gate, the spread of window heights, turns both ways, the start rail, the way home's
## length and what test_race's _course_rules would say. For tuning RaceCourse's search and scoring.
##   .\probe.ps1 -Headless probe_courses [--seed 7] [--courses 1-12]

func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var arena := int(Boot.arg_value(args, "--seed")) if Boot.arg_value(args, "--seed") != "" else 7
	var span := (Boot.arg_value(args, "--courses") if Boot.arg_value(args, "--courses") != "" else "1-12").split("-")
	var l := Pinewood.generate(arena)
	var good := 0
	for s in range(int(span[0]), int(span[-1]) + 1):
		var c := RaceCourse.generate(l, s)
		var lo := INF
		var hi := -INF
		var kinds := {}
		var left := 0
		var right := 0
		for lg in c.legs():
			lo = minf(lo, lg.height)
			hi = maxf(hi, lg.height)
			kinds[lg.kind] = int(kinds.get(lg.kind, 0)) + 1
			left += 1 if lg.turn > 15.0 else 0
			right += 1 if lg.turn < -15.0 else 0
		var probs := c.problems()
		var ok := c.gates.size() == RaceCourse.GATES and probs.is_empty() and hi - lo >= 6.0 and kinds.size() >= 3 and left >= 1 and right >= 1
		good += int(ok)
		var home := c.gates[-1].centre.distance_to(c.start.position) if not c.gates.is_empty() else INF
		print("COURSES %2d: %2d gates %s, heights %4.1f-%4.1f, kinds %s, turns %dL %dR, start %d, home %.0f m, %.1f s%s" % [s, c.gates.size(),
			"ok" if probs.is_empty() else "(%s)" % probs[0], lo, hi, str(kinds), left, right, c.start.id, home, c.build_ms / 1000.0, "  <- passes" if ok else ""])
	print("COURSES %d of %d pass _course_rules" % [good, int(span[-1]) - int(span[0]) + 1])
	finish()
