extends TestCase
## Moving air (AirField, FlightModel.wind): a bird glides through the air as it would in still air -- the same
## airspeed and the same glide through it -- and the air carries it: rising air lifts it by just the air's speed,
## sinking air drops it (both ways). A thermal's air rises most in its core, less to its edge, sinks a little in a
## ring round it, nothing far off, nothing near the floor or over its top, and pulses; ridge lift rises in front of a
## face and over its edge, not behind the edge nor past its ends. The pine wood has its thermals over the clearing
## and the glade. A crow circling in a thermal climbs where, in still air, it sinks. The HUD says LIFT in rising air,
## SINK in sinking air, nothing in still air or perched. The game draws the thermals (AirFx: fluff rising in each).


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	_glide_in_moving_air()
	_thermal_profile()
	_ridge_profile()
	_pinewood_thermals()
	_hud()
	_drawn()
	await _circling_climbs()
	finish()


## Hands-off glides of 10 s in still air, rising air (+1.5 m/s) and sinking air (-1.5): through the air all the same;
## over the ground the moving air adds its own speed times the time.
func _glide_in_moving_air() -> void:
	var p := BirdProfile.by_id("crow")
	var runs := {}
	for w in [0.0, 1.5, -1.5]:
		var m := FlightModel.new(p)
		m.launch(Vector3(0, 50, 0), Vector3(0, -0.1, -1), p.v_best)
		m.wind = Vector3(0, w, 0)
		m.velocity += m.wind   # (gliding steadily in the air mass already)
		var inp := FlightInput.new()
		for i in 600:
			m.step(1.0 / 60.0, inp)
		runs[w] = [m.position.y, m.speed]
	var still: float = runs[0.0][0]
	near(float(runs[1.5][0]) - still, 15.0, 0.75, "rising air at 1.5 m/s lifts the glide 15 m in 10 s (%.2f)" % (float(runs[1.5][0]) - still))
	near(float(runs[-1.5][0]) - still, -15.0, 0.75, "sinking air drops it as much (%.2f)" % (float(runs[-1.5][0]) - still))
	near(float(runs[1.5][1]), float(runs[0.0][1]), 0.05, "and the airspeed is the still air's (%.2f v %.2f m/s)" % [runs[1.5][1], runs[0.0][1]])


func _thermal_profile() -> void:
	var air := AirField.new()
	air.add_thermal(Vector2(10, -5), 12.0, 2.5, 50.0)
	var at := func(dx: float, h: float, t := 0.0) -> float:
		return air.at(Vector3(10 + dx, ArenaLayout.GROUND_Y + h, -5), t).y
	var core: float = at.call(0.0, 25.0)
	check(core > 2.5 * (1.0 - AirField.THERMAL_PULSE) - 0.05, "a thermal's core rises (%.2f m/s)" % core)
	check(at.call(6.0, 25.0) > 0.3 and at.call(6.0, 25.0) < core, "less half way out (%.2f)" % at.call(6.0, 25.0))
	check(at.call(-6.0, 25.0) > 0.3 and absf(at.call(-6.0, 25.0) - at.call(6.0, 25.0)) < 1e-4, "the same either side")
	check(at.call(16.0, 25.0) < 0.0, "a ring round it sinks (%.2f)" % at.call(16.0, 25.0))
	eq(at.call(40.0, 25.0), 0.0, "far off, nothing")
	check(absf(at.call(0.0, 0.5)) < 0.2 * core, "near the floor, little (%.2f)" % at.call(0.0, 0.5))
	eq(at.call(0.0, 52.0), 0.0, "over its top, nothing")
	var lo := INF
	var hi := -INF
	for k in 36:
		var v: float = at.call(0.0, 25.0, k * 1.0)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(hi - lo > 0.6, "it pulses as bubbles lift off (%.2f .. %.2f)" % [lo, hi])
	AirField.enabled = false
	eq(at.call(0.0, 25.0), 0.0, "--calm: no thermal")
	AirField.enabled = true


## A cliff 20 m high, its top edge from (-30, 20, 0) to (30, 20, 0), facing +z.
func _ridge_profile() -> void:
	var air := AirField.new()
	air.add_ridge(Vector3(-30, 20, 0), Vector3(30, 20, 0), Vector3(0, 0, 1), 20.0, 3.0)
	var front: float = air.at(Vector3(0, 25, 6)).y
	check(front > 2.0, "ridge lift in front of the face, over its edge (%.2f)" % front)
	check(air.at(Vector3(0, 14, 4)).y > 0.5, "rising up the face's upper part (%.2f)" % air.at(Vector3(0, 14, 4)).y)
	eq(air.at(Vector3(0, 25, -10)).y, 0.0, "nothing behind the edge (the lee)")
	eq(air.at(Vector3(50, 25, 6)).y, 0.0, "nothing past the face's ends")
	check(air.at(Vector3(0, 70, 6)).y < 0.05, "it fades out high over the top (%.2f)" % air.at(Vector3(0, 70, 6)).y)
	check(air.at(Vector3(0, 25, 60)).y < 0.05, "and far out from the face (%.2f)" % air.at(Vector3(0, 25, 60)).y)


func _pinewood_thermals() -> void:
	var a := Pinewood.generate(7)
	for o in a.openings:
		if o.kind == "clearing" or o.kind == "glade":
			var w := a.air.at(Vector3(o.centre.x, 25.0, o.centre.y)).y
			check(w > 1.2, "the %s has a thermal over it (%.2f m/s at 25 m)" % [o.kind, w])
	var far := Vector2(70, 0)
	for o in a.openings:
		if (o.centre as Vector2).distance_to(far) < float(o.r) * 2.5:
			far = Vector2(0, -75)
	check(absf(a.air.at(Vector3(far.x, 25.0, far.y)).y) < 0.05, "not under the trees")


## A crow circling (stick held over) round a thermal's core for 20 s: in the thermal it gains height; in still air
## it loses it.
func _circling_climbs() -> void:
	var dh := {}
	for calm in [false, true]:
		AirField.enabled = not calm
		var layout := ArenaLayout.new()
		layout.air.add_thermal(Vector2.ZERO, 20.0, 2.6, 60.0)   # (as the pine wood's clearing)
		var world := Node3D.new()
		add_child(world)
		var b := Bird.new()
		world.add_child(b)
		var inp := ScriptedInput.new()
		inp.stick = Vector2(0.55, 0.15)   # (a circle about 8 m round)
		b.setup(BirdProfile.by_id("crow"), layout, inp)
		b.rig.visible = false
		b.fly_from(Vector3(-8, 30, 0), Vector3(0, 0, -1), b.profile.v_best)   # (banking right: round the core)
		var y0 := b.global_position.y
		for i in 20 * 60:
			await get_tree().physics_frame
		dh[calm] = b.global_position.y - y0
		world.queue_free()
		await get_tree().process_frame
	AirField.enabled = true
	print("circling 20 s: in the thermal %+.1f m, in still air %+.1f m" % [dh[false], dh[true]])
	check(dh[false] > 8.0, "a crow circling in a thermal climbs (%+.1f m in 20 s)" % dh[false])
	check(dh[true] < -5.0, "in still air the same turns lose height (%+.1f m)" % dh[true])


func _hud() -> void:
	var hud := FlightHud.new()
	for c in [[2.1, Bird.State.FLYING, "LIFT +2.1"], [-0.6, Bird.State.FLYING, "SINK -0.6"], [0.1, Bird.State.FLYING, ""], [2.1, Bird.State.PERCHED, ""]]:
		hud.t = {"air": Vector3(0, c[0], 0), "state": c[1], "velocity": Vector3(0, 0.8, -9)}
		var s := hud.lift_text()
		check(s.begins_with(c[2]) and (c[2] != "" or s == ""), "the HUD in air rising %+.1f m/s, %s: \"%s\"" % [c[0], Bird.State.keys()[c[1]], s])
	hud.free()


func _drawn() -> void:
	var air := AirField.new()
	air.add_thermal(Vector2(5, 5), 20.0, 2.6, 55.0)
	air.add_thermal(Vector2(-40, 10), 8.0, 1.0, 30.0)
	var fx := AirFx.new()
	add_child(fx)
	fx.build(air)
	var parts := fx.find_children("*", "GPUParticles3D", true, false)
	eq(parts.size(), 2, "a column of motes for each thermal")
	if parts.size() == 2:
		var big := parts[0] as GPUParticles3D
		var small := parts[1] as GPUParticles3D
		check(big.amount > small.amount, "more in the wider thermal (%d v %d)" % [big.amount, small.amount])
		var m := big.process_material as ParticleProcessMaterial
		check(m.direction.y > 0.9 and m.initial_velocity_min > 0.5, "rising")
		check(Vector2(big.global_position.x, big.global_position.z).distance_to(Vector2(5, 5)) < 0.01 and big.visibility_aabb.end.y > 50.0, "over its thermal, up to its top")
		# Points of light, not snowflakes (0.22 m soft discs read as a snowfall up close).
		var quad := big.draw_pass_1 as QuadMesh
		var mat := quad.material as ShaderMaterial if quad != null else null
		check(quad != null and quad.get_aabb().size.x < 0.06, "a mote is a speck: %s m across" % [quad.get_aabb().size.x if quad != null else -1.0])
		check(mat != null and mat.shader.code.contains("blend_add"), "a mote adds light (a glint, not a pale disc)")
		check(mat != null and not mat.shader.code.contains("unshaded") and mat.shader.code.contains("void light()"), "a mote is lit by the sun (it glints in the sunbeams, not in the shade)")
	fx.queue_free()
