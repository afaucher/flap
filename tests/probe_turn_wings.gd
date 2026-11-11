extends TestCase
## Diagnostic (windowed: .\probe.ps1 probe_turn_wings [--bird crow] [--out <png>] [--flat]): the bird flies a fixed set of
## moves through its own flight model -- level glide, rolling into a right turn, the turn held, rolling out, rolling into a
## left turn, a flapping roll back to the right (filmed early in a downstroke) -- and each is filmed from behind (the chase camera's side, the horizon level), from behind
## rolled with the bird (its wings level in the frame: twist and droop show) and from over its back (the bird's own frame:
## span and sweep show), tiled moments across and views down. `--flat`: the wings and tail as they were before they took the
## roll's shape (BirdRig.roll_shape off), for an A/B on one build.

const VIEWS := ["behind", "behind, rolled", "on its back"]
const CELL := Vector2i(480, 360)


func _init() -> void:
	timeout_sec = 240.0


## The moves, as [time, stick x, flap held] from the start, and the moments filmed, [time, label]; T is the bird's
## time to roll from level to its full bank.
static func script_for(p: BirdProfile) -> Dictionary:
	var T := p.max_bank_deg / p.roll_rate_deg
	var a := 0.5                 # level glide, then the stick right
	var b := a + T + 0.7         # the stick back to centre
	var c := b + T + 0.5         # the stick left
	var d := c + T + 0.4         # flapping, rolling from the left turn to the right
	return {
		"moves": [[0.0, 0.0, false], [a, 1.0, false], [b, 0.0, false], [c, -1.0, false], [d - 0.3, -1.0, true], [d, 1.0, true]],
		"shots": [[0.4, "level"], [a + 0.5 * T, "rolling in (right)"], [a + T + 0.5, "turn held"],
			[b + 0.5 * T, "rolling out"], [c + 0.5 * T, "rolling in (left)"], [d + 0.6 * T, "flapping roll (right)", true]],
		"end": d + 2.0 * T,
	}


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var id := Boot.arg_value(args, "--bird") if Boot.arg_value(args, "--bird") != "" else "crow"
	var out := Boot.arg_value(args, "--out")
	if out == "":
		out = OS.get_user_data_dir() + "/probe_turn_wings_%s.png" % id
	BirdRig.roll_shape = not args.has("--flat")
	Game.add_environment(self)
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	var ctrl := ScriptedInput.new()
	var b := Bird.new()
	add_child(b)
	var p := BirdProfile.by_id(id)
	b.setup(p, layout, ctrl)
	b.arena = arena
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.fov = 30.0
	get_window().size = CELL
	await frames(5)
	var sc := script_for(p)
	b.fly_from(Vector3(-40.0, 40.0, 0.0), Vector3.RIGHT, p.v_best)
	var t0 := b._sim_t
	Engine.time_scale = 0.05
	var shots := {}   # view -> [Image]
	for v in VIEWS:
		shots[v] = []
	var moves: Array = sc.moves
	var mi := 0
	var want := 0
	var view_i := 0
	var span := p.span
	var pending := false   # (a camera placed for a shot: the next drawn frame is it)
	while want < sc.shots.size():
		await RenderingServer.frame_post_draw
		if pending:
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			shots[VIEWS[view_i]].append(img)
			pending = false
			view_i += 1
			if view_i == VIEWS.size():
				view_i = 0
				want += 1
				if want >= sc.shots.size():
					break
		var sim := b._sim_t - t0
		while mi < moves.size() and sim >= float(moves[mi][0]):
			ctrl.stick = Vector2(float(moves[mi][1]), 0.0)
			ctrl.hold = bool(moves[mi][2])
			ctrl.flap = bool(moves[mi][2])
			mi += 1
		if mi > 0 and not bool(moves[mi - 1][2]):
			ctrl.flap = false
		var drawn := sim - Bird.drawn_lag()
		if drawn < float(sc.shots[want][0]):
			continue
		# (the flapping roll: filmed early in a downstroke, where the wings differ most)
		if (sc.shots[want] as Array).size() > 2 and view_i == 0 and not (b.rig.roll_phase > 0.06 and b.rig.roll_phase < 0.2 and absf(b.rig._roll_rate) > 0.5):
			continue
		# The bird as drawn this frame (physics interpolation draws it behind the latest tick).
		var xf: Transform3D = b.rig.get_global_transform_interpolated()
		var at := xf.origin
		var v3: Vector3 = b.model.velocity
		var fwd := Vector3(v3.x, 0.0, v3.z).normalized()
		var dist := span * 2.4
		var bx := xf.basis.orthonormalized()
		match VIEWS[view_i]:
			"behind": cam.look_at_from_position(at - fwd * dist + Vector3.UP * dist * 0.2, at)
			"behind, rolled": cam.look_at_from_position(at + bx.z * dist + bx.y * dist * 0.2, at, bx.y)
			"on its back": cam.look_at_from_position(at + bx.y * dist, at, -bx.z)
		pending = true
		if view_i == 0:
			var r := b.rig
			print("  %-20s t %.2f bank %+5.1f deg  alpha %4.1f deg  load %.2f  speed %.1f | roll %+.2f  twist L %+.1f R %+.1f deg  fold L %.2f R %.2f  tail %+.1f deg" % [
				sc.shots[want][1], drawn, rad_to_deg(b.model.bank), rad_to_deg(b.model.alpha), b.model.load_factor, b.model.speed,
				r.roll_cmd, rad_to_deg(r.wing_twist(0)), rad_to_deg(r.wing_twist(1)), r.wing_fold(0), r.wing_fold(1), rad_to_deg(r.tail_twist)])
	Engine.time_scale = 1.0
	var n: int = sc.shots.size()
	var sheet := Image.create(CELL.x * n, CELL.y * VIEWS.size(), false, Image.FORMAT_RGB8)
	for r in VIEWS.size():
		var row: Array = shots[VIEWS[r]]
		for k in row.size():
			var img: Image = row[k]
			if img.get_size() != CELL:
				img.resize(CELL.x, CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(k * CELL.x, r * CELL.y))
	sheet.save_png(out)
	print("probe_turn_wings: ", out)
	finish()
