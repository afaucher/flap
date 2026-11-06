extends TestCase
## Diagnostic (windowed: .\probe.ps1 probe_glance_close [--out <png>] [--bird crow] [--deg 15] [--right]): a bird glides
## hands off past the lab tree's trunk and glances off it (LabScenarios' glance); the frames round the touch, up close
## from outside the trunk -- the foot thrown onto the bark, the claws raking it, the push off -- tiled 3 x 2.

const AGES := [-0.03, 0.02, 0.05, 0.09, 0.14, 0.24]   ## s after the touch


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	if out == "":
		out = OS.get_user_data_dir() + "/probe_glance_close.png"
	var id := Boot.arg_value(args, "--bird") if Boot.arg_value(args, "--bird") != "" else "crow"
	var deg := float(Boot.arg_value(args, "--deg")) if Boot.arg_value(args, "--deg") != "" else 15.0
	var side := 1.0 if args.has("--right") else -1.0
	Game.add_environment(self)
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, null)
	b.arena = arena
	var s := {"kind": "hit", "deg": deg, "side": side, "speed": 1.0}
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 35.0
	get_window().size = Vector2i(960, 720)
	await frames(5)
	# A first run finds where and when it touches; a second, slowed, frames it there.
	LabScenarios.start(s, b, layout)
	var t0 := b._sim_t
	var t := 0.0
	var touch_t := -1.0
	var at := Vector3.ZERO
	while t < 2.0 and touch_t < 0.0:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if t > 0.4 and touch_t < 0.0 and OS.get_environment("GLANCE_DEBUG") != "":
			print("  t %.3f bank %.0f deg, fold %.2f, stick %s, bracing %s, braces %d, pos %s v %s" % [t, rad_to_deg(b.model.bank), b.model.fold, b.last_input.stick, not b.brace.is_empty(), b.braces, b.global_position, b.model.velocity])
		if b.glances > 0 or b.bonks > 0:
			touch_t = b._sim_t - t0
			print("  touch: bank %.0f deg, fold %.2f, braces %d, into %.2f" % [rad_to_deg(b.model.bank), b.model.fold, b.braces, -b.model.velocity.dot(b.glance.n) if b.glances > 0 else -1.0])
			at = b.glance.at if b.glances > 0 else b.global_position
	print("probe_glance_close: %s at %.0f deg: glances %d bonks %d, touched at %.2f s at %s" % [id, deg, b.glances, b.bonks, touch_t, at])
	var tree: ArenaLayout.TreeData = layout.trees[0]
	var axis := Vector3(tree.base.x, at.y, tree.base.y)
	var outward := (at - axis).normalized()
	b.glances = 0
	b.bonks = 0
	LabScenarios.start(s, b, layout)
	b.reset_physics_interpolation()
	t0 = b._sim_t
	Engine.time_scale = 0.1
	var shots := []
	var want := 0
	var sim := 0.0
	while want < AGES.size() and sim < 2.5:
		await RenderingServer.frame_post_draw
		sim = b._sim_t - Bird.drawn_lag() - t0
		var age := sim - touch_t
		# (following the near foot as drawn: from ahead, a little out from the trunk and below)
		var ni := 0 if side < 0.0 else 1
		var foot: Vector3 = b.rig.global_transform * (b.rig.leg_joints[ni][3] as Vector3) if not (b.rig.leg_joints[ni] as Array).is_empty() else b.global_position
		var ahead := Vector3(0, 0, 1)
		cam.look_at_from_position(foot + ahead * 0.5 + outward * 0.28 + Vector3.DOWN * 0.12, foot + outward * 0.03)
		if age >= float(AGES[want]):
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			shots.append(img)
			print("  frame at %+.3f s: rake %s, glance %s" % [age, b.rig.rake_w, b.telemetry().glance.get("age", -1.0)])
			want += 1
	Engine.time_scale = 1.0
	var w := 960
	var h := 720
	var sheet := Image.create(w * 3, h * 2, false, Image.FORMAT_RGB8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png(out)
	print("probe_glance_close: ", out)
	finish()
