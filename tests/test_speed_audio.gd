extends TestCase
## Speed bands and the flight audio: bands follow the cuts (stall, catch, best glide, 1.5x, 2.2x) with
## hysteresis; a flight that speeds up and slows down crosses every band and fires one whoosh per crossing,
## rising then falling; the wind gets louder with speed; a wingbeat thumps; nothing produces NaN.


func setup() -> void:
	var p := BirdProfile.crow()
	var c := SpeedBands.cuts(p.v_stall, p.grab_speed_max, p.v_best)
	eq(SpeedBands.band(p.v_stall * 0.5, c), 0, "below stall")
	eq(SpeedBands.band((p.v_stall + p.grab_speed_max) * 0.5, c), 1, "catchable")
	eq(SpeedBands.band(p.v_best * 1.2, c), 3, "cruise")
	eq(SpeedBands.band(p.v_best * 3.0, c), 5, "dive")
	# Hysteresis: sitting just past a cut doesn't flip the band; well past it does.
	eq(SpeedBands.band(p.v_best * 1.01, c, 2), 2, "just over best glide stays SLOW")
	eq(SpeedBands.band(p.v_best * 1.05, c, 2), 3, "clearly over best glide is GLIDE")
	eq(SpeedBands.band(p.v_best * 0.99, c, 3), 3, "just under stays GLIDE")
	eq(SpeedBands.band(p.v_best * 0.95, c, 3), 2, "clearly under is SLOW")
	eq(SpeedBands.band(p.v_best * 3.0, c, 0), 5, "a jump crosses several cuts at once")

	var audio := FlightAudio.new()
	add_child(audio)
	await frames(1)
	var t := _telemetry(p, 0.0, 0)
	# Ramp 0 -> 3x best glide -> 0, a frame at a time.
	var loud_slow := 0.0
	var loud_fast := 0.0
	for i in 400:
		var u := float(i) / 399.0
		var v := p.v_best * 3.0 * (1.0 - absf(2.0 * u - 1.0))
		t = _telemetry(p, v, 0)
		audio.set_state(t)
		var block := audio.render(256)
		var e := _energy(block)
		check(not is_nan(e), "no NaN")
		if v < p.v_stall and i > 5:
			loud_slow = maxf(loud_slow, e)
		if v > p.v_best * 2.5:
			loud_fast = maxf(loud_fast, e)
	print("whooshes: ", audio.events)
	eq(audio.events.size(), 10, "five cuts crossed up and five down")
	for i in 5:
		check(audio.events[i][1] > audio.events[i][0], "speeding up rises")
		check(audio.events[i + 5][1] < audio.events[i + 5][0], "slowing down falls")
	check(loud_fast > loud_slow * 4.0, "wind is louder fast than slow (%.4f vs %.4f)" % [loud_fast, loud_slow])
	# A wingbeat thumps.
	audio.set_state(_telemetry(p, p.v_best, 5))
	audio.render(2048)
	var quiet := _energy(audio.render(512))
	audio.set_state(_telemetry(p, p.v_best, 6))
	var thump := _energy(audio.render(512))
	check(thump > quiet * 1.5, "a wingbeat thumps (%.4f vs %.4f)" % [thump, quiet])
	# Not flying (perched): no band, no whoosh.
	var n := audio.events.size()
	audio.set_state({"state": Bird.State.PERCHED, "speed": 0.0, "v_best": p.v_best, "v_stall": p.v_stall,
		"grab_speed": p.grab_speed_max, "stalled": false, "flap_count": 6})
	eq(audio.band, -1, "perched has no band")
	eq(audio.events.size(), n, "perching doesn't whoosh")
	finish()


func _telemetry(p: BirdProfile, v: float, flaps: int) -> Dictionary:
	return {"state": Bird.State.FLYING, "speed": v, "v_best": p.v_best, "v_stall": p.v_stall,
		"grab_speed": p.grab_speed_max, "stalled": v < p.v_stall, "flap_count": flaps}


func _energy(block: PackedVector2Array) -> float:
	var s := 0.0
	for f in block:
		s += f.x * f.x
	return s / maxf(1.0, block.size())
