extends TestCase
## Diagnostic: the game with the pause menu open (PAUSE_PAGE=settings: its Settings page), saved to PAUSE_SHOT (default
## user://pause.png). .\probe.ps1 probe_pause_shot


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	if not game.is_loaded:
		await game.loaded
	await frames(60)
	game.pause.open()
	if OS.get_environment("PAUSE_PAGE") == "settings":
		(game.pause.find_child("PauseSettings", true, false) as Button).pressed.emit()
	await frames(10)
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("PAUSE_SHOT")
	if out == "":
		out = "user://pause.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("screenshot: ", out)
	get_tree().paused = false
	finish()
