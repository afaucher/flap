extends TestCase
## The flapping trim (FlightModel.climb_alpha, docs/design/flight_model.md "Flapping trim"): with flap held, neutral
## stick climbs, at the fastest steady climb no slower than best-glide speed; let go and it glides again. Every bird,
## from the lightest (sparrow, 0.06 kg) to the heaviest (hawk, 1.2 kg), from a settled best glide:
##   - flap held, neutral stick: it climbs, at the climb steady_flapping predicts for the trim (within 10%), no slower
##     than best-glide speed, never stalled, never under 1.2x its stall speed;
##   - the stick still works both ways round the new neutral: a little pull flies slower, a little push faster and
##     shallower;
##   - flapping in a 45 deg bank, left and right: still on the wing (no stall, no hovering climb: the sparrow's
##     wingbeat lifts more than its weight when slow, and the trim must keep it well clear of that);
##   - the nose eases over: at the first wingbeat and on letting go, the angle of attack moves under 40 deg/s (a jerk
##     would slew it at the bird's alpha rate, 135-210 deg/s);
##   - let go: no stall, never under 1.1x stall speed, and back on its ideal glide slope at best-glide speed (as
##     test_glide_trim), the trim back at best glide;
##   - on its own burst (not topped up), flapping until it runs dry and on: it climbs a good height, never stalls,
##     and the trim slides most of the way back toward best glide as the wingbeats weaken.

const DT := 1.0 / 60.0


func _settled(p: BirdProfile) -> FlightModel:
	var m := FlightModel.new(p)
	m.launch(Vector3(0, 800, 0), Vector3(0, -sin(p.glide_angle), -cos(p.glide_angle)), p.v_best)
	for i in 60 * 20:
		m.step(DT, FlightInput.new())
	return m


## Fly `secs` with `inp`, the burst topped up unless `own_burst`; returns {climb (m/s over the last half), v (mean,
## last half), v_min, stalled, rate (max |d alpha/dt| over the first 1.5 s, deg/s)}.
func _fly(m: FlightModel, inp: FlightInput, secs: float, own_burst := false) -> Dictionary:
	var n := int(secs * 60.0)
	var y_half := 0.0
	var v_sum := 0.0
	var v_min := INF
	var stalled := false
	var rate := 0.0
	var a_last := m.alpha
	for i in n:
		if not own_burst:
			m.energy.burst = m.profile.burst_max
		m.step(DT, inp)
		if i < 90:
			rate = maxf(rate, rad_to_deg(absf(m.alpha - a_last)) / DT)
		a_last = m.alpha
		v_min = minf(v_min, m.speed)
		stalled = stalled or m.stalled
		if i == n / 2:
			y_half = m.position.y
		if i > n / 2:
			v_sum += m.speed
	return {"climb": (m.position.y - y_half) / (secs * 0.5), "v": v_sum / (n - n / 2 - 1), "v_min": v_min,
		"stalled": stalled, "rate": rate}


func setup() -> void:
	var flap := FlightInput.new(Vector2.ZERO, false, true)
	var glide := FlightInput.new()
	for p in BirdProfile.all():
		var tag := p.id
		var m := _settled(p)
		var bc := m.best_climb()
		check(m.climb_alpha < p.alpha_stall * 0.6, "%s: the climb trim is well short of the stall (%.1f deg, stall %.1f)" % [tag, rad_to_deg(m.climb_alpha), rad_to_deg(p.alpha_stall)])

		# Flap held, neutral stick.
		var up := _fly(m, flap, 12.0)
		print("%s: flapping at neutral %.2f m/s up at %.2f m/s (predicted %.2f at %.2f; v* %.2f, stall %.2f), min %.2f m/s, alpha %.2f deg (trim %.2f), first wingbeats' nose rate %.1f deg/s" % [
			tag, up.climb, up.v, bc.z, bc.y, p.v_best, p.v_stall, up.v_min, rad_to_deg(m.alpha), rad_to_deg(m.climb_alpha), up.rate])
		# (Within 10%: steady_flapping averages the wingbeat over the beat, and the sparrow's, 4 ticks of thrust in 7,
		# flies 3% faster than its mean and climbs 7% less; the others are within 2%.)
		check(up.climb > 0.0 and up.climb >= bc.z * 0.9, "%s: flap held at neutral climbs as fast as predicted (%.2f m/s, predicted %.2f)" % [tag, up.climb, bc.z])
		near(up.v, bc.y, bc.y * 0.05, "%s: at the trim's speed" % tag)
		check(up.v >= p.v_best * 0.98, "%s: no slower than best glide (%.2f m/s, v* %.2f)" % [tag, up.v, p.v_best])
		check(not up.stalled and up.v_min >= 1.2 * p.v_stall, "%s: on the wing throughout (min %.2f m/s, stall %.2f)%s" % [tag, up.v_min, p.v_stall, " STALLED" if up.stalled else ""])
		check(up.rate < 40.0, "%s: the nose eases into the climb (%.1f deg/s)" % [tag, up.rate])
		near(m.trim_alpha(), m.climb_alpha, deg_to_rad(0.05), "%s: neutral is the climb trim while flapping" % tag)

		# The stick round the new neutral, both ways (from the same steady climb).
		var pulled := _settled(p)
		_fly(pulled, flap, 8.0)
		var pull := _fly(pulled, FlightInput.new(Vector2(0, 0.12), false, true), 10.0)
		var pushed := _settled(p)
		_fly(pushed, flap, 8.0)
		var push := _fly(pushed, FlightInput.new(Vector2(0, -0.12), false, true), 10.0)
		print("%s: flapping, pull 0.12: %.2f m/s up at %.2f; push 0.12: %.2f up at %.2f" % [tag, pull.climb, pull.v, push.climb, push.v])
		check(pull.v < up.v - 0.3, "%s: a little pull while flapping flies slower (%.2f vs %.2f m/s)" % [tag, pull.v, up.v])
		check(push.v > up.v + 0.3 and push.climb < up.climb, "%s: a little push flies faster and climbs less (%.2f m/s, %.2f up)" % [tag, push.v, push.climb])

		# Flapping in a 45 deg bank, both ways.
		for side in [-1.0, 1.0]:
			var tm := _settled(p)
			var bank_stick: float = 45.0 / p.max_bank_deg * side
			var turn := _fly(tm, FlightInput.new(Vector2(bank_stick, 0.0), false, true), 10.0)
			var way := "left" if side < 0.0 else "right"
			print("%s: flapping in a 45 deg %s bank: %.2f m/s up at %.2f, min %.2f" % [tag, way, turn.climb, turn.v, turn.v_min])
			check(not turn.stalled and turn.v_min >= 1.1 * p.v_stall, "%s: flapping in a 45 deg %s bank stays on the wing (min %.2f m/s, stall %.2f)%s" % [tag, way, turn.v_min, p.v_stall, " STALLED" if turn.stalled else ""])

		# Let go: back to the glide.
		var down := _fly(m, glide, 25.0)
		print("%s: let go: min %.2f m/s, nose rate %.1f deg/s; then path %.2f deg (ideal %.2f) at %.2f m/s" % [tag, down.v_min, down.rate, rad_to_deg(m.path_angle), -rad_to_deg(p.glide_angle), m.speed])
		check(not down.stalled and down.v_min >= 1.1 * p.v_stall, "%s: letting go doesn't stall it (min %.2f m/s, stall %.2f)%s" % [tag, down.v_min, p.v_stall, " STALLED" if down.stalled else ""])
		check(down.rate < 40.0, "%s: the nose eases back to the glide (%.1f deg/s)" % [tag, down.rate])
		near(rad_to_deg(m.path_angle), -rad_to_deg(p.glide_angle), 0.2, "%s: back on the ideal glide slope" % tag)
		near(m.speed, p.v_best, p.v_best * 0.08, "%s: at best-glide speed" % tag)
		near(m.trim_alpha(), p.alpha_best, deg_to_rad(0.01), "%s: neutral is best glide again" % tag)

		# On its own burst, until it runs dry and on.
		var own := _settled(p)
		var y0 := own.position.y
		var tired := _fly(own, flap, 15.0, true)
		var gained := own.position.y - y0
		var weak := own.flap_strength
		print("%s: on its own burst for 15 s: %.1f m up, min %.2f m/s, last wingbeat %.2f strong, trim %.2f of the way" % [tag, gained, tired.v_min, weak, own.flap_trim])
		check(gained > 10.0, "%s: flapping on its own burst climbs a good height (%.1f m in 15 s)" % [tag, gained])
		check(not tired.stalled, "%s: and never stalls" % tag)
		check(weak < 0.5 and own.flap_trim < 0.5, "%s: once the wingbeats weaken the trim slides back toward best glide (%.2f)" % [tag, own.flap_trim])
	finish()
