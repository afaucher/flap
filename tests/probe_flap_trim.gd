extends TestCase
## Diagnostic (run by name): the flapping trim. For each bird: the climb trim FlightModel.best_climb picks (and what it
## costs to work out), then flap held at neutral stick from level best-glide flight (burst kept full), second by
## second, and released. `-- --curve` also prints the steady flapping flight steady_flapping predicts at each
## airspeed beside what the model flies holding that angle of attack (no damper).


func _stick_for(p: BirdProfile, a: float) -> float:
	if a >= p.alpha_best:
		return (a - p.alpha_best) / (p.alpha_stall * 0.98 - p.alpha_best) * FlightModel.STALL_STICK
	return -(p.alpha_best - a) / (p.alpha_best - deg_to_rad(p.alpha_push_deg)) * 0.5


func setup() -> void:
	var dt := 1.0 / 60.0
	var curve := OS.get_cmdline_user_args().has("--curve")
	for p in BirdProfile.all():
		var t0 := Time.get_ticks_usec()
		var m0 := FlightModel.new(p)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var bc := m0.best_climb()
		var vy := m0.best_climb(1.0, 1.2 * p.v_stall)
		var weak := m0.best_climb(p.weak_flap)
		var at_a := m0.steady_flapping(p.v_best)
		print("%s: v* %.2f alpha* %.2f stall %.2f m/s; climb trim alpha %.2f deg at %.2f m/s (%.2f Vs), %.2f m/s up (path %.1f deg); Vy (>= 1.2 Vs) alpha %.2f at %.2f m/s (%.2f Vs), %.2f up; weak beat's best alpha %.2f at %.2f m/s, %.2f up; at v* %.2f up; worked out in %.1f ms" % [
			p.id, p.v_best, rad_to_deg(p.alpha_best), p.v_stall, rad_to_deg(bc.x), bc.y, bc.y / p.v_stall, bc.z, rad_to_deg(asin(bc.z / bc.y)),
			rad_to_deg(vy.x), vy.y, vy.y / p.v_stall, vy.z, rad_to_deg(weak.x), weak.y, weak.z, p.v_best * sin(at_a.y), ms])
		if curve:
			var v := p.v_stall * 0.7
			while v < p.v_best * 1.6:
				var st := m0.steady_flapping(v, 1.0)
				var line := "  v %5.2f (%.2f Vs)  alpha %6.2f path %6.2f climb %5.2f" % [v, v / p.v_stall, rad_to_deg(st.x), rad_to_deg(st.y), v * sin(st.y)]
				if not is_nan(st.x):
					var m := FlightModel.new(p)
					m.pitch_damping = 0.0
					m.launch(Vector3(0, 500, 0), Vector3(0, sin(st.y), -cos(st.y)), v)
					m.alpha = st.x
					var inp := FlightInput.new(Vector2(0, _stick_for(p, st.x)), false, true)
					for i in 60 * 10:
						m.energy.burst = 1e6
						m.step(dt, inp)
					var y0 := m.position.y
					var v_sum := 0.0
					for i in 60 * 20:
						m.energy.burst = 1e6
						m.step(dt, inp)
						v_sum += m.speed
					line += "   | flown v %5.2f climb %5.2f%s" % [v_sum / 1200.0, (m.position.y - y0) / 20.0, " STALLED" if m.stalled else ""]
				print(line)
				v += 0.5
		var m := FlightModel.new(p)
		m.launch(Vector3(0, 500, 0), Vector3(0, -sin(p.glide_angle), -cos(p.glide_angle)), p.v_best)
		for i in 60 * 20:
			m.step(dt, FlightInput.new())
		var y_last := m.position.y
		var a_last := m.alpha
		for s in 20:
			var held := s < 10
			var inp := FlightInput.new(Vector2.ZERO, false, held)
			var rate := 0.0
			var v_min := INF
			for i in 60:
				m.energy.burst = 1e6
				m.step(dt, inp)
				rate = maxf(rate, absf(m.alpha - a_last) / dt)
				a_last = m.alpha
				v_min = minf(v_min, m.speed)
			print("  t %2d %s v %5.2f (min %5.2f)  path %6.2f  alpha %5.2f (trim %5.2f, max rate %5.1f deg/s)  climb %5.2f m/s%s" % [s + 1, "flap" if held else "    ", m.speed, v_min, rad_to_deg(m.path_angle), rad_to_deg(m.alpha), rad_to_deg(m.trim_alpha()), rad_to_deg(rate), m.position.y - y_last, " STALLED" if m.stalled else ""])
			y_last = m.position.y
	finish()
