extends TestCase
## The wingbeat is drawn for the moment the frame draws (Bird.drawn_lag, FlightModel.phase_at), not stepped with the
## ticks: a sparrow's 0.1 s beat is 6 ticks, so at 80 fps a quarter of the frames held the last tick's pose and a slow
## frame jumped several. Flapping held, posed at four moments a tick through a beat: the wingtip is somewhere new at
## every one; the beat's phase moves evenly with the clock; held beats run into each other, so the drawn wing keeps up
## with its beat (eased into each beat as a new one, a sparrow's never did: at the top of the beat its hand was still
## folded 20 deg from the upstroke and its wing 9 deg short of the top); a moment a whole tick back is drawn as the
## last tick was (not a tick ahead); and a frame (Bird._process) draws the wing for its own drawn moment.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var layout := ArenaLayout.lab()
	var input := ScriptedInput.new()
	input.hold = true
	var b := Bird.new()
	add_child(b)
	var p := BirdProfile.sparrow()
	b.setup(p, layout, input)
	b.fly_from(Vector3(0, 60, 0), Vector3(0, 0, -1), p.v_best)
	var dt := 1.0 / Engine.physics_ticks_per_second
	await frames(30)
	# From the first tick of a beat to its last.
	var guard := 0
	while not (b.model.flap_cooldown > p.flap_period - 1.5 * dt) and guard < 60:
		await get_tree().physics_frame
		guard += 1
	check(guard < 60, "the sparrow is flapping")
	var count := b.model.flap_count
	var tips := []     # the left wingtip, rig space, at each moment
	var phases := []
	var beats := []    # (shoulder, hand: deg) as drawn at each moment
	var last_tick := Vector2.INF   # the beat as drawn at the last tick's moment (lag 0): the shoulder, the hand
	var back_off := 0.0
	while b.model.flap_count == count:
		for f in [1.0, 0.75, 0.5, 0.25, 0.0]:
			var lag: float = f * dt
			b._animate_rig(0.0, lag)
			var tip := _tip(b)
			# (the beat itself: the rest of the wing eases toward each tick's flight between these, as frames draw it)
			var beat := Vector2(b.rig.flap, deg_to_rad(b.rig.hand_lift))
			if f == 1.0:
				if last_tick != Vector2.INF:
					back_off = maxf(back_off, rad_to_deg(beat.distance_to(last_tick)))
				continue
			tips.append(tip)
			phases.append(b.model.phase_at(lag))
			beats.append(Vector2(rad_to_deg(beat.x), b.rig.hand_lift))
			if f == 0.0:
				last_tick = beat
		await get_tree().physics_frame
	check(tips.size() >= 20, "a beat posed at four moments a tick (%d)" % tips.size())
	var held := 0
	var least := INF
	for i in range(1, tips.size()):
		var d: float = (tips[i] as Vector3).distance_to(tips[i - 1])
		least = minf(least, d)
		if d < 1e-4:
			held += 1
	check(held == 0, "the wingtip is somewhere new at every moment, between ticks too (%d held; the least move %.4f m)" % [held, least])
	var step := 0.25 * dt / b.model.beat_cycle()
	var uneven := 0.0
	for i in range(1, phases.size()):
		uneven = maxf(uneven, absf(float(phases[i]) - float(phases[i - 1]) - step))
	check(uneven < 1e-4, "the beat moves evenly with the clock (%.4f of a beat a quarter tick, off by at most %.5f)" % [step, uneven])
	check(float(phases[0]) < step * 1.01 and float(phases[-1]) > 1.0 - 4.0 * step - 1e-4, "through the whole beat (%.3f .. %.3f)" % [phases[0], phases[-1]])
	var top := -INF
	for v: Vector2 in beats:
		top = maxf(top, v.x)
	var turn: Vector2 = beats[-1]   # (the beat's last moment: its top, where the next begins)
	check(absf(float(phases[-1]) - 1.0) < 1e-4 and turn.x > top - 0.5, "the wing is at the top of its beat where the next begins (%.1f deg, the beat's highest %.1f)" % [turn.x, top])
	check(absf(turn.y) < 2.0, "with its hand spread again from the upstroke (folded %.1f deg)" % turn.y)
	check(back_off < 1e-3, "a moment a tick back is drawn as the last tick was, not a tick ahead (off by %.5f deg)" % back_off)
	# A frame draws the wing for its own moment: Bird._process poses it for drawn_lag() before the latest tick.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lag_now := Bird.drawn_lag()
	b._posed_t = b._sim_t - 1.0
	b._process(0.0)
	var framed := _tip(b)
	b._animate_rig(0.0, lag_now)
	var direct := _tip(b)
	b._animate_rig(0.0, 0.0)
	var latest := _tip(b)
	check(framed.distance_to(direct) < 1e-5, "a frame draws the wing as of its drawn moment (%.4f s back; off by %.6f m)" % [lag_now, framed.distance_to(direct)])
	if lag_now > 1e-3 and b.model.flap_cooldown > 0.0:
		check(framed.distance_to(latest) > 1e-4, "(not as of the latest tick: %.4f m apart)" % framed.distance_to(latest))
	b.queue_free()
	finish()


## The left wingtip as posed, in the rig's own frame.
func _tip(b: Bird) -> Vector3:
	var t := WingTrails.tips(b)
	return b.rig.global_transform.affine_inverse() * (t[0] as Vector3)
