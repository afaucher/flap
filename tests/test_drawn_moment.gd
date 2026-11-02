extends TestCase
## What's placed by hand each frame is placed for the moment the frame draws the birds (Bird.drawn_lag: physics
## interpolation draws each body between its last two ticks): a round in flight is drawn between its last two positions,
## not at the latest (a tick ahead of the birds); its smoke runs to where the round is drawn and holds nothing laid
## after that moment; a wing trail ends at the wingtip where it is drawn, not where the last tick left it.


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var trails := WingTrails.new()
	add_child(trails)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
	b.fly_from(Vector3(0, 30, 0), Vector3.FORWARD, 12.0)
	trails.track(b)
	var p := Projectile.launch(Projectile.Kind.ROCKET, Vector3(8, 30, 0), Vector3.ZERO, Vector3(0, 0, -1), null)
	world.spawn(p)
	await frames(8)
	await get_tree().process_frame   # (as a frame draws: in the physics step the engine reports the tick's transforms)
	var lag := Bird.drawn_lag()
	var f := 1.0 - lag * Engine.physics_ticks_per_second
	print("drawn lag %.4f s (fraction %.3f)" % [lag, f])
	# (pin the moment: the frame's fraction as the tests run is whatever --fixed-fps leaves; place things for a known one)
	world._process(0.0)
	var drawn: Vector3 = world._bodies[0].global_position
	var want := p.last_pos.lerp(p.pos, f)
	var step := p.last_pos.distance_to(p.pos)
	check(step > 0.2, "the round moves a tick's worth between ticks (%.3f m)" % step)
	check(drawn.distance_to(want) < 1e-4, "the round is drawn between its last two ticks, as the birds are (off by %.4f m)" % drawn.distance_to(want))
	check(not world._bodies[0].is_physics_interpolated(), "and placed for that moment, not interpolated again")
	var heads := {p.id: want}
	var pts := CombatWorld.smoke_points(world._smoke[0], world._clock - lag, heads)
	check((pts[-1][0] as Vector3).distance_to(want) < 1e-4, "its smoke runs to where it is drawn")
	var late := 0
	for q in pts:
		if float(q[1]) > world._clock - lag + 1e-6:
			late += 1
	check(late == 0, "and holds nothing laid after the drawn moment (%d points)" % late)
	# The wing trail ends at the drawn wingtip: the tick's tip carried with the bird to where it is drawn.
	var tp := trails.drawn_points(b, trails._clock - lag)
	var tick_tips := WingTrails.tips(b)
	var drawn_xf := b.get_global_transform_interpolated()
	for side in 2:
		var tip_drawn: Vector3 = drawn_xf * (b.global_transform.affine_inverse() * (tick_tips[side] as Vector3))
		check((tp[-1][side + 1] as Vector3).distance_to(tip_drawn) < 1e-4, "side %d: the trail ends at the drawn wingtip (off by %.4f m)" % [side, (tp[-1][side + 1] as Vector3).distance_to(tip_drawn)])
	if lag > 1e-4:
		check(drawn.distance_to(p.pos) > step * 0.05, "(drawn behind the latest tick: %.3f m)" % drawn.distance_to(p.pos))
		check((tp[-1][1] as Vector3).distance_to(tick_tips[0]) > 0.05, "(the drawn wingtip behind the tick's: %.3f m)" % (tp[-1][1] as Vector3).distance_to(tick_tips[0]))
	# A trail laid at 0, 25 and 50 ms, drawn as of 40 ms with its round at X: the first two points, then X.
	var x := Vector3(1, 2, 3)
	var trail := {"id": 7, "pts": [[Vector3.ZERO, 0.0], [Vector3(0, 0, 1), 0.025], [Vector3(0, 0, 2), 0.05]]}
	var sp := CombatWorld.smoke_points(trail, 0.04, {7: x})
	check(sp.size() == 3 and (sp[1][0] as Vector3) == Vector3(0, 0, 1) and (sp[2][0] as Vector3) == x and is_equal_approx(float(sp[2][1]), 0.04), "smoke as of the drawn moment: what was laid by then, on to the drawn round (%s)" % str(sp))
	var closed := CombatWorld.smoke_points(trail, 0.06, {})
	check(closed.size() == 3, "a burst round's smoke: every point laid by then, nothing added (%d points)" % closed.size())
	finish()
