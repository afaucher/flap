extends TestCase
## Holding full pull stalls the wing (speed bleeds, path drops, drag soars); releasing recovers onto the
## glide slope without input tricks.

const DT := 1.0 / 60.0


func setup() -> void:
	for p in BirdProfile.all():
		var m := FlightModel.new(p)
		m.launch(Vector3(0, 300, 0), Vector3.FORWARD, p.v_best)
		var pull := FlightInput.new(Vector2(0, 1.0))
		var was_stalled := false
		var max_cd := 0.0
		for i in 60 * 4:
			m.step(DT, pull)
			was_stalled = was_stalled or m.stalled
			max_cd = maxf(max_cd, m.cd)
		check(was_stalled, p.id + " full pull stalls")
		check(max_cd > 0.3, "%s stall drag (cd %.2f)" % [p.id, max_cd])
		check(m.speed < p.v_best, p.id + " stall bleeds speed")
		# Let go: back to flying within a few seconds, on the glide slope after a while.
		var recovered_at := -1.0
		for i in 60 * 12:
			m.step(DT, FlightInput.new())
			if recovered_at < 0.0 and not m.stalled:
				recovered_at = i * DT
		check(recovered_at >= 0.0 and recovered_at < 3.0, "%s recovers (%.2f s)" % [p.id, recovered_at])
		near(rad_to_deg(m.path_angle), -rad_to_deg(p.glide_angle), 0.5, p.id + " recovery ends on the glide slope")
	finish()
