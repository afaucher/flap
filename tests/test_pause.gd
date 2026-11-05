extends TestCase
## Esc in the game pauses it: the scene tree stops (a bird in flight holds still), the mouse is freed and the pause
## menu shows Resume, Settings and Leave. Settings is the start menu's; a choice there reaches the player's controller
## when play resumes, Esc going back to the pause page first. Esc again resumes and the bird flies on. The window losing
## focus pauses too, and so does the gamepad's Start; Start over resumes with the bird back on a perch. Leave unpauses
## and leaves. The range pauses the same way, and its Start over starts the match again.

const SHARDS := 2   ## (the game, the range)
const PATH := "user://test_pause_settings.cfg"


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	InputSetup.ensure_actions()
	var saved_path := Settings.path
	Settings.path = PATH
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = false
	if in_shard(0):
		await _game()
	if in_shard(1):
		await _range()
	get_tree().paused = false
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Settings.path = saved_path
	Boot.extra = PackedStringArray()
	finish()


func _game() -> void:
	Boot.extra = PackedStringArray(["--ai", "0", "--no-rider", "--forest", "greybox"])
	var game: Game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	if not game.is_loaded:
		await game.loaded
	await frames(3)
	var pause := game.pause
	check(pause != null and not pause.is_open() and not get_tree().paused, "the game starts unpaused")
	var b := game.bird
	b.rig.visible = false
	b.fly_from(game.layout.start_perch().position + Vector3(0, 6, 0), Vector3(1, 0, 0), b.profile.v_best)
	await frames(5)
	# Esc: paused.
	await _esc()
	check(get_tree().paused and pause.is_open(), "Esc pauses")
	check(_shown(pause, "PauseResume") and _shown(pause, "PauseSettings") and _shown(pause, "PauseLeave"),
		"and shows Resume, Settings and Leave")
	eq(PauseMenu.mouse_wanted, Input.MOUSE_MODE_VISIBLE, "the mouse is freed")
	var at := b.global_position
	for i in 10:
		await get_tree().physics_frame
	check(b.global_position.distance_to(at) < 1e-4, "the bird holds still while paused (moved %.4f m)" % b.global_position.distance_to(at))
	# Settings, from the pause menu.
	(pause.find_child("PauseSettings", true, false) as Button).pressed.emit()
	await frames(1)
	check(_shown(pause, "Tab1") and not _shown(pause, "PauseResume"), "Settings opens the settings")
	(pause.find_child("Tab1", true, false) as Button).pressed.emit()
	(pause.find_child("MouseY1", true, false) as Button).pressed.emit()
	check(Settings.invert_mouse_y, "a choice there sets it")
	await _esc()
	check(get_tree().paused and _shown(pause, "PauseResume"), "Esc on Settings goes back to the pause page, still paused")
	check(not game.player.invert_mouse, "(the controller takes it when play resumes)")
	await _esc()
	check(not get_tree().paused and not pause.is_open(), "Esc again resumes")
	check(game.player.invert_mouse, "with the new setting in the player's controller")
	eq(PauseMenu.mouse_wanted, Input.MOUSE_MODE_CAPTURED, "and the mouse captured at once")
	at = b.global_position
	for i in 10:
		await get_tree().physics_frame
	check(b.global_position.distance_to(at) > 0.5, "the bird flies on (%.2f m)" % b.global_position.distance_to(at))
	# The window losing focus.
	pause.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(get_tree().paused and pause.is_open(), "the window losing focus pauses")
	(pause.find_child("PauseResume", true, false) as Button).pressed.emit()
	check(not get_tree().paused and not pause.is_open(), "Resume resumes")
	# The gamepad's Start, and Start over.
	check(game.bird.state == Bird.State.FLYING, "(the bird's in the air)")
	await _pad_start()
	check(get_tree().paused and pause.is_open() and _shown(pause, "PauseStartOver"), "the gamepad's Start pauses, with Start over on the menu")
	(pause.find_child("PauseStartOver", true, false) as Button).pressed.emit()
	await frames(2)
	check(not get_tree().paused and not pause.is_open(), "Start over resumes")
	check(game.bird.state == Bird.State.PERCHED, "with the bird back on a perch (%s)" % Bird.State.keys()[game.bird.state])
	# Leave.
	pause.change_scene = false
	var gone := [false]
	pause.left.connect(func(): gone[0] = true)
	await _esc()
	(pause.find_child("PauseLeave", true, false) as Button).pressed.emit()
	check(gone[0] and not get_tree().paused and not pause.is_open(), "Leave unpauses and leaves")
	game.queue_free()
	await frames(2)


func _range() -> void:
	Boot.extra = PackedStringArray()
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	if not r.is_loaded:
		await r.loaded
	await frames(3)
	var pause: PauseMenu = r.pause
	check(pause != null and not get_tree().paused, "the range starts unpaused")
	check(pause.controllers.has(r.player_ctl), "its pause menu hands the settings to your controller")
	await _esc()
	check(get_tree().paused and pause.is_open() and _shown(pause, "PauseLeave"), "Esc pauses the range")
	await _esc()
	check(not get_tree().paused and not pause.is_open(), "and Esc resumes it")
	r.world.stats.shots = 5
	var was: Bird = r.bird
	await _esc()
	(pause.find_child("PauseStartOver", true, false) as Button).pressed.emit()
	await frames(3)
	check(not get_tree().paused and r.world.stats.shots == 0 and r.bird != was, "Start over starts the range again (shots %d)" % r.world.stats.shots)
	r.queue_free()
	await frames(2)


func _shown(pause: PauseMenu, button: String) -> bool:
	var n := pause.find_child(button, true, false) as Control
	return n != null and n.is_visible_in_tree()


## The gamepad's Start pressed and let go.
func _pad_start() -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = JOY_BUTTON_START
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await get_tree().process_frame


## Esc pressed and let go, as the engine delivers it.
func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await get_tree().process_frame
