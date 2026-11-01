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
