extends TestCase
## Go-arounds in a place of its own: each bird put beside a post gate (left, right), at a start speed, gate height and
## heading, and how it got through: s to the gate, go-arounds, its speed and height at the gate.
##   .\probe.ps1 -Headless probe_go_round [--birds falcon,hawk] [--heights 7,12] [--speeds 1.0,1.3] [--above 0]


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var birds := (Boot.arg_value(args, "--birds") if Boot.arg_value(args, "--birds") != "" else "falcon,hawk").split(",")
	var heights := (Boot.arg_value(args, "--heights") if Boot.arg_value(args, "--heights") != "" else "7,12").split(",")
	var above := float(Boot.arg_value(args, "--above"))   # (m above the gate it starts)
	var speeds := (Boot.arg_value(args, "--speeds") if Boot.arg_value(args, "--speeds") != "" else "1.0,1.3").split(",")
	for h in heights:
		var y := float(h)
		var l := FlightExam.place()
		var gs: Array[RaceCourse.Gate] = [FlightExam.post_gate(Vector3(0, y, -30), Vector3(0, 0, 1)),
			FlightExam.post_gate(Vector3(0, y, 0), Vector3(0, 0, 1)), FlightExam.post_gate(Vector3(0, y, 30), Vector3(0, 0, 1))]
		var c := RaceCourse.from_gates(l, Perch.branch(-1, Vector3(0, y, -60), Vector3(0, y, -60), Vector3(0, 0, 1), -1, 0.05), gs)
		var trial := RaceTrial.new()
		add_child(trial)
		trial.setup(l, c)
		var g := c.gates[1]
		var es := []
		for id in birds:
			for sp in speeds:
				for side: float in [-1.0, 1.0]:
					for back: float in [3.0, -6.0]:   # (just short of the gate's line, and past it)
						var e := trial.add_ai(id, "pilot", 7)
						e.run.phase = RaceRun.Phase.RUNNING
						e.run.next = 1
						var at: Vector3 = g.centre - g.normal * back + g.right() * side * (g.half_w + 3.0) + Vector3.UP * above
						e.bird.fly_from(at, g.normal, e.bird.profile.v_best * float(sp))
						e.prev = at
						es.append({"e": e, "id": id, "sp": sp, "side": side, "back": back, "t": INF, "ga": -1, "v": 0.0, "dy": 0.0})
		for f in 60 * 40:
			await trial.step()
			for x in es:
				if x.t == INF and x.e.run.next > 1:
					x.t = (f + 1) / 60.0
					x.ga = x.e.pilot.go_arounds
					x.v = x.e.bird.model.speed
					x.dy = x.e.bird.global_position.y - y
		for x in es:
			print("ROUND gate %4.1f m  %-7s x%.1f  %-5s %+3.0f m: %s  go-arounds %d  at the gate %.1f m/s %+.1f m" % [y, x.id, float(x.sp),
				"left" if x.side < 0.0 else "right", -x.back, ("%5.1f s" % x.t) if x.t < INF else " none ", x.ga if x.ga >= 0 else x.e.pilot.go_arounds, x.v, x.dy])
		trial.queue_free()
		await frames(2)
	finish()
