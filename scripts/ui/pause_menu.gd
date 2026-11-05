class_name PauseMenu
extends CanvasLayer
## Esc in the game or the range: everything stops (the scene tree pauses: birds, AI, sound) and the mouse is freed,
## and over the dimmed view, Resume, Start over (the scene's own: the game's bird back on its perch, the range's
## match from the top; resumes first), Settings (the start menu's, SettingsPanel) and Leave (to the start menu).
## Esc or the gamepad's Start opens it.
## Resume, or Esc, carries on: the mouse captured at once (no capturing click, so no stray shot) and the controllers
## given the settings as they now stand (PlayerController.take_settings). Esc on Settings goes back to the pause page.
## The window losing focus (alt-tab) opens it too, so the game never runs on with the mouse free
## (`pause_on_focus_out`; off for --shot and --perf runs, which go on unwatched). In MenuStyle's look.

signal left   ## Leave pressed (the start menu opens next, unless `change_scene` is off)

const MENU := "res://scenes/menu.tscn"

var controllers: Array = []       ## PlayerControllers given the settings on resuming
var start_over := Callable()      ## the scene's Start over
var pause_on_focus_out := true
var change_scene := true          ## Leave opens the start menu (a test turns it off and watches `left`)
var page := ""                    ## "" closed | "pause" | "settings"
static var mouse_wanted := -1     ## the mouse mode last asked for (headless, Input.mouse_mode never captures: tests read this)
var _ui: Control
var _pause: VBoxContainer
var _settings: VBoxContainer


## A pause menu for `scene` (once it's loaded), giving `controllers` the settings when play resumes; `start_over`, the
## scene's Start over.
static func attach(scene: Node, controllers: Array, start_over: Callable) -> PauseMenu:
	var p := PauseMenu.new()
	p.controllers = controllers
	p.start_over = start_over
	var args := Boot.args()
	p.pause_on_focus_out = not (args.has("--shot") or args.has("--perf"))
	scene.add_child(p)
	return p


func _init() -> void:
	name = "PauseMenu"
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.theme = MenuStyle.theme()
	add_child(_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	_pause = MenuStyle.page(_ui, "PAUSED", false)
	for b in [["Resume  (Esc)", "PauseResume", resume], ["Start over", "PauseStartOver", restart],
			["Settings", "PauseSettings", _show.bind("settings")],
			["Leave", "PauseLeave", leave]]:
		var button := MenuStyle.button(b[0], 22, Vector2(320, 48))
		button.name = b[1]
		button.pressed.connect(b[2])
		_pause.add_child(button)
	_settings = MenuStyle.page(_ui, "SETTINGS", false)
	_settings.add_child(SettingsPanel.new())
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := MenuStyle.button("Back  (Esc)", 20, Vector2(200, 48))
	back.name = "PauseSettingsBack"
	back.pressed.connect(_show.bind("pause"))
	go.add_child(back)
	_settings.add_child(go)
	_show("")


func is_open() -> bool:
	return page != ""


## Pause: everything stops, the mouse is freed.
func open() -> void:
	if is_open() or not is_inside_tree():
		return
	get_tree().paused = true
	_mouse(Input.MOUSE_MODE_VISIBLE)
	_show("pause")


## Carry on, with the settings as they now stand and the mouse captured.
func resume() -> void:
	if not is_open():
		return
	_show("")
	get_tree().paused = false
	for c in controllers:
		c.take_settings()
	_mouse(Input.MOUSE_MODE_CAPTURED)


## Start over: play resumes and the scene starts over.
func restart() -> void:
	resume()
	if start_over.is_valid():
		start_over.call()


## Back to the start menu.
func leave() -> void:
	_show("")
	get_tree().paused = false
	left.emit()
	if change_scene:
		Boot.extra = PackedStringArray()
		get_tree().change_scene_to_file(MENU)


static func _mouse(mode: Input.MouseMode) -> void:
	mouse_wanted = mode
	Input.mouse_mode = mode


func _unhandled_input(e: InputEvent) -> void:
	if not e.is_action_pressed("pause") or (e is InputEventKey and (e as InputEventKey).echo):
		return
	if page == "":
		open()
	elif page == "settings":
		_show("pause")
	else:
		resume()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_out:
		open()


func _show(p: String) -> void:
	page = p
	_ui.visible = p != ""
	_pause.get_meta("page").visible = p == "pause"
	_settings.get_meta("page").visible = p == "settings"
	if p == "pause":
		(_pause.find_child("PauseResume", true, false) as Button).grab_focus.call_deferred()
	elif p == "settings":
		(_settings.find_child("PauseSettingsBack", true, false) as Button).grab_focus.call_deferred()
