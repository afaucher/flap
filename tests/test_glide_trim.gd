extends TestCase
## Neutral stick, no flapping: every bird settles onto its ideal glide slope at its best-glide speed,
## from too slow or too fast, without a long phugoid bob.


func setup() -> void:
	var dt := 1.0 / 60.0
	var neutral := FlightInput.new()
	for p in BirdProfile.all():
		for start in [p.v_best * 0.8, p.v_best * 1.6]:
			var m := FlightModel.new(p)
			m.launch(Vector3(0, 500, 0), Vector3.FORWARD, start)
			for i in 60 * 25:
				m.step(dt, neutral)
			var tag := "%s from %.1f m/s" % [p.id, start]
			print("%s -> %.2f m/s, path %.2f deg (ideal %.2f), alpha %.2f deg, fold %.2f" % [tag, m.speed, rad_to_deg(m.path_angle), -rad_to_deg(p.glide_angle), rad_to_deg(m.alpha), m.fold])
			near(rad_to_deg(m.path_angle), -rad_to_deg(p.glide_angle), 0.2, tag + " path angle")
			near(m.speed, p.v_best, p.v_best * 0.08, tag + " speed")
			check(not m.stalled, tag + " not stalled")
			# Settled: one more second barely changes anything.
			var a0 := m.path_angle
			for i in 60:
				m.step(dt, neutral)
			check(absf(m.path_angle - a0) < deg_to_rad(0.3), tag + " steady")
	finish()
