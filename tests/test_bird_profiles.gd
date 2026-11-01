extends TestCase
## Every preset derives a consistent polar: L/D max is the designed glide ratio, best glide sits clear of
## the stall, and the species differ the way the research says they should.


func setup() -> void:
	var by := {}
	for p in BirdProfile.all():
		by[p.id] = p
		print(p.summary())
		var m := FlightModel.new(p)
		# The polar's L/D at CL* is the designed glide ratio.
		var ld := p.cl_best / m.drag_coefficient(p.cl_best, p.alpha_best, 0.0)
		near(ld, p.glide_ratio, 0.01, p.id + " L/D max")
		# And it is the best: a bit either side is worse.
		for c in [p.cl_best * 0.8, p.cl_best * 1.2]:
			check(c / m.drag_coefficient(c, 0.0, 0.0) < ld, p.id + " CL* is the max")
		check(p.v_best > p.v_stall * 1.1, "%s best glide %.1f clears stall %.1f" % [p.id, p.v_best, p.v_stall])
		check(p.alpha_best < p.alpha_stall * 0.85, p.id + " best-glide alpha below stall")
		check(rad_to_deg(p.glide_angle) < 12.0, p.id + " glide is shallow")
		check(p.grab_speed_max > p.v_stall and p.grab_speed_max < p.v_best * 1.2, p.id + " catch speed between stall and cruise-ish")
		near(m.alpha_for_stick(0.0), p.alpha_best, 1e-6, p.id + " neutral stick is best glide")
		check(m.alpha_for_stick(1.0) > p.alpha_stall, p.id + " full pull can stall (the flare)")
		check(m.alpha_for_stick(-1.0) < 0.0, p.id + " full push unloads the wing")
		# Tucking cuts parasitic drag at low CL (the stoop).
		check(m.drag_coefficient(0.05, 0.0, 1.0) * (1.0 - p.fold_area_cut) < m.drag_coefficient(0.05, 0.0, 0.0), p.id + " tuck cuts drag area")
	check(by.hawk.glide_ratio > by.crow.glide_ratio and by.crow.glide_ratio > by.sparrow.glide_ratio, "hawk > crow > sparrow glide")
	check(by.owl.v_stall < by.crow.v_stall and by.owl.v_stall < by.falcon.v_stall, "owl stalls slowest")
	check(by.falcon.wing_loading() > by.crow.wing_loading() and by.falcon.wing_loading() > by.owl.wing_loading(), "falcon most wing-loaded of the three")
	finish()
