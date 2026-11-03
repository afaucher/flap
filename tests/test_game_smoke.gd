extends TestCase
## The whole game scene runs: arena, player bird on its start perch, AI birds, camera, HUD. It loads behind a
## loading screen: up at once, its bar only ever filling, its step named, gone once the game is ready to fly. The
## mouse wheel zooms the chase camera out (down) and in (up), within its range. The player's
## bird is put on autopilot and flies for a while; every bird switch works.


func setup() -> void:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _loading_screen(game)
	await frames(5)
	await _zoom(game)
	check(game.bird != null and game.bird.state == Bird.State.PERCHED, "player starts perched")
	check(game.ai_birds.size() >= 1, "AI birds spawned")
	check(not game.hud.t.is_empty(), "HUD has telemetry")
	# The chase camera moves every rendered frame, so physics interpolation must be off for it (on, the engine
	# warns -- only in a windowed run, which these headless tests never see).
	check(not game.camera.is_physics_interpolated(), "chase camera isn't physics-interpolated")
	# The far blur: only the far wood (nothing within 40 m, nothing on the near side), gentle, and F5's toggle works.
	var ca := game.get_viewport().world_3d.camera_attributes as CameraAttributesPractical
	check(ca != null and ca.dof_blur_far_enabled and not ca.dof_blur_near_enabled, "the far wood is softened, nothing near")
	if ca != null:
		check(ca.dof_blur_far_distance >= 40.0 and ca.dof_blur_amount <= 0.05, "only past 40 m, and gently (from %.0f m, amount %.3f)" % [ca.dof_blur_far_distance, ca.dof_blur_amount])
		check(not ForestLight.toggle_far_blur(game) and not ca.dof_blur_far_enabled, "F5 turns it off")
		check(ForestLight.toggle_far_blur(game) and ca.dof_blur_far_enabled, "and on again")
	# The classic HUD: the perch ahead is marked only while catch is held (and always with --hud dev).
	eq(FlightHud.style, "classic", "the classic HUD is the default")
	var near: Perch = game.layout.perches[0]
	for held in [false, true]:
		game.bird.candidate = near
		game.bird.last_input.catch_held = held
		game._physics_process(0.0)
		eq(game.arena.highlight.visible, held, "the perch ahead is marked %s" % ("while catch is held" if held else "only while catch is held"))
	_landing_bar(game)
	FlightHud.style = "dev"
	game.bird.last_input.catch_held = false
	game._physics_process(0.0)
	check(game.arena.highlight.visible, "--hud dev marks it always")
	FlightHud.style = "classic"
	game.use_autopilot = true
	game.bird.controller = game.autopilot
	await frames(60 * 8)
	check(game.bird.state != Bird.State.PERCHED or game.autopilot.perches_reached > 0, "autopilot left the perch")
	for id in BirdProfile.IDS:
		game._spawn_player(id, game.layout.start_perch())
		await frames(10)
		eq(game.bird.profile.id, id, "switched to " + id)
		check(game.camera.bird == game.bird, "camera follows the new bird")
	finish()


## The landing bar: a short band round the branch at the landing point (not the whole branch), as long as the catch
## reach either side and cut at the branch's end, hidden by needles in front as the branch is; green when slow enough to catch, red when too fast -- and a bird is too
## fast over the catch speed, in reach or not yet, never too slow.
func _landing_bar(game: Game) -> void:
	var arena: ArenaBuilder = game.arena
	var p: Perch = null
	for q: Perch in game.layout.perches:
		if q.kind == Perch.Kind.BRANCH and q.a.distance_to(q.b) > 2.5:
			p = q
			break
	var n := p.a.distance_to(p.b)
	var r := 1.5
	var mid := p.a.lerp(p.b, 0.5)
	arena.show_candidate(p, false, r, mid)
	var hl := arena.highlight
	var length := hl.basis.y.length()
	near(length, 2.0 * r * ArenaBuilder.MARK_HALF, 0.01, "the bar is the catch reach long (%.2f m of a %.2f m branch)" % [length, n])
	check(Vector2(hl.position.x - mid.x, hl.position.z - mid.z).length() < 0.01, "centred on the landing point")
	near(hl.position.y, mid.y - p.thickness, 0.01, "round the branch (its axis, a radius under the grip line)")
	check(hl.basis.x.length() > 2.0 * p.thickness and hl.basis.x.length() < 2.0 * p.thickness + 0.05, "just proud of the branch all round")
	check(not (hl.material_override as StandardMaterial3D).no_depth_test, "hidden by the needles in front, as the branch is")
	check((hl.basis.y.normalized()).dot((p.b - p.a).normalized()) > 0.99, "along the branch")
	eq((hl.material_override as StandardMaterial3D).albedo_color, ArenaBuilder.MARK_OK, "green when slow enough")
	arena.show_candidate(p, true, r, mid)
	eq((hl.material_override as StandardMaterial3D).albedo_color, ArenaBuilder.MARK_FAST, "red when too fast")
	arena.show_candidate(p, false, r, p.b)
	var tip_end := hl.position + hl.basis.y * 0.5
	check(tip_end.distance_to(p.b - Vector3.UP * p.thickness) < 0.01, "cut at the branch's tip")
	near(hl.basis.y.length(), r * ArenaBuilder.MARK_HALF, 0.01, "half a bar at the tip")
	arena.show_candidate(null, false, r)
	check(not hl.visible, "nothing to catch: no bar")
	# Too fast: over the catch speed, in reach or not yet; at or under it, never.
	var b: Bird = game.bird
	var g := b.profile.grab_speed_max
	for c in [[Perch.Catch.OUT_OF_RANGE, 0.3, false], [Perch.Catch.OUT_OF_RANGE, 0.8, false], [Perch.Catch.OUT_OF_RANGE, 1.4, true], [Perch.Catch.OK, 0.8, false],
			[Perch.Catch.TOO_FAST, 1.4, true]]:
		b.candidate_status = c[0]
		b.model.velocity = Vector3(0, 0, -g * float(c[1]))
		eq(b.candidate_too_fast(), c[2], "status %d at %.1fx the catch speed: too fast %s" % [c[0], c[1], c[2]])
	b.model.velocity = Vector3.ZERO


func _loading_screen(game: Game) -> void:
	var screen: Loading = null
	for c in game.get_children():
		if c is Loading:
			screen = c
	check(screen != null and not game.is_loaded, "a loading screen is up while the arena grows")
	if screen == null:
		await game.loaded
		return
	var seen := []
	var steps := {}
	var last := -1.0
	var backwards := false
	while not game.is_loaded:
		backwards = backwards or screen.progress < last - 1e-6
		last = screen.progress
		seen.append(last)
		var st := screen.find_child("Step", true, false) as Label
		if st != null and st.text != "":
			steps[st.text] = true
		await get_tree().process_frame
	check(not backwards, "its bar only fills")
	check(seen.size() >= 8, "it moves while the wood goes up (%d frames)" % seen.size())
	check(steps.size() >= 4, "and says what it's doing (%s)" % ", ".join(steps.keys()))
	await frames(40)
	check(not is_instance_valid(screen), "it's gone once the game is ready")


func _zoom(game: Game) -> void:
	await frames(30)
	var d0 := game.camera.global_position.distance_to(game.bird.global_position)
	var wheel := func(button: MouseButton, n: int) -> void:
		for i in n:
			var e := InputEventMouseButton.new()
			e.button_index = button
			e.pressed = true
			game._unhandled_input(e)
	wheel.call(MOUSE_BUTTON_WHEEL_DOWN, 4)
	await frames(90)
	var d_out := game.camera.global_position.distance_to(game.bird.global_position)
	wheel.call(MOUSE_BUTTON_WHEEL_UP, 30)
	await frames(90)
	var d_in := game.camera.global_position.distance_to(game.bird.global_position)
	check(d_out > d0 * 1.5, "the wheel down zooms out (%.2f -> %.2f m)" % [d0, d_out])
	check(d_in < d0 * 0.6 and d_in > d0 * 0.3, "the wheel up zooms in, as far as its range (%.2f m)" % d_in)
	wheel.call(MOUSE_BUTTON_WHEEL_DOWN, 30)
	wheel.call(MOUSE_BUTTON_WHEEL_UP, 30)
	game.camera.zoom = 1.0
	await frames(60)
