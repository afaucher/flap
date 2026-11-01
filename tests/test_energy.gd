extends TestCase
## Flapping: a fresh bird can hold height and climb; held flapping drains the burst in seconds and
## the stamina within a couple of minutes; a tired bird can't hold height; flaps can't come faster than
## the wingbeat or push past the flap speed cap; perching restores both reserves.

const DT := 1.0 / 60.0


func setup() -> void:
	for p in BirdProfile.all():
		var m := FlightModel.new(p)
		m.launch(Vector3(0, 300, 0), Vector3.FORWARD, p.v_best)
		var hold := FlightInput.new(Vector2.ZERO, false, true)
		# A few seconds of flapping from fresh: no height lost, burst spent.
		var y0 := m.position.y
		var e0 := m.specific_energy()
		for i in 60 * 6:
			m.step(DT, hold)
		check(m.specific_energy() > e0, "%s fresh flapping adds energy (%.0f -> %.0f)" % [p.id, e0, m.specific_energy()])
		check(m.position.y > y0 - 1.0, "%s fresh flapping holds height (%.1f)" % [p.id, m.position.y - y0])
		check(m.energy.burst < p.burst_max * 0.6, "%s burst drains (%.1f of %.1f)" % [p.id, m.energy.burst, p.burst_max])
		# Wingbeat cap: never more flaps than the period allows.
		var expected_flaps := ceili(6.0 / p.flap_period) + 1
		check(m.flap_count <= expected_flaps, "%s flaps capped by the wingbeat (%d <= %d)" % [p.id, m.flap_count, expected_flaps])
		# Speed cap: flapping while pushing can't go past the flap speed cap in level-ish flight.
		check(m.speed < p.flap_speed_cap, p.id + " under the flap speed cap")
		# Keep flapping until exhausted.
		var secs := 6.0
		while m.energy.stamina > 0.01 and secs < 600.0:
			for i in 60:
				m.step(DT, hold)
			secs += 1.0
		check(secs > 20.0 and secs < 400.0, "%s stamina lasts a while, not forever (%.0f s)" % [p.id, secs])
		check(m.energy.burst_cap() < p.burst_max * 0.35, p.id + " tired bird has a small burst")
		# Tired: flapping no longer holds height.
		var tired_y := m.position.y
		var tired_e := m.specific_energy()
		for i in 60 * 5:
			m.step(DT, hold)
		check(m.specific_energy() < tired_e, "%s exhausted flapping can't hold energy (%.0f -> %.0f)" % [p.id, tired_e, m.specific_energy()])
		check(m.position.y < tired_y, p.id + " exhausted bird sinks")
		# Rest on a perch: both come back; perched recovery beats gliding recovery.
		var glide := EnergyModel.new(p)
		var perch := EnergyModel.new(p)
		glide.stamina = 0.0; glide.burst = 0.0
		perch.stamina = 0.0; perch.burst = 0.0
		for i in 60 * 10:
			glide.tick(DT, false, 1.0, false)
			perch.tick(DT, false, 0.0, true)
		check(perch.stamina > glide.stamina * 3.0, "%s perching rests faster (%.2f vs %.2f)" % [p.id, perch.stamina, glide.stamina])
		check(perch.stamina > 0.5, p.id + " ten seconds perched restores most stamina")
		check(perch.burst > glide.burst, p.id + " perched burst refills faster")
	# Hard pulls cost burst.
	var e := EnergyModel.new(BirdProfile.crow())
	var b0 := e.burst
	for i in 60:
		e.tick(DT, true, 3.5, false)
	check(e.burst < b0 - 1.0, "a 3.5 g second drains burst")
	finish()
