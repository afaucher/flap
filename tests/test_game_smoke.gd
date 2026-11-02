extends TestCase
## The whole game scene runs: arena, player bird on its start perch, AI birds, camera, HUD. The player's
## bird is put on autopilot and flies for a while; every bird switch works.


func setup() -> void:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await frames(5)
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
