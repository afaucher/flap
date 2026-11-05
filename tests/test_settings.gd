extends TestCase
## The player's settings: which way the mouse and the gamepad's stick climb. The mouse toward you pulls (climbs) by
## default and away climbs with invert_mouse; the stick back climbs by default and forward with invert_pad -- each
## checked both ways, through to the bird's angle of attack. A PlayerController takes the settings when it's made;
## they're saved and come back on load. The menu's Settings screen sets them (saving at once) and lists the controls
## from the real bindings.

const PATH := "user://test_settings.cfg"


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	InputSetup.ensure_actions()
	var saved_path := Settings.path
	Settings.path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_mouse()
	_pad()
	await _flies()
	_saved()
	await _screen()
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	Settings.path = saved_path
	Boot.extra = PackedStringArray()
	finish()


## The mouse's virtual stick, both ways.
func _mouse() -> void:
	for inv in [false, true]:
		var pc := PlayerController.new()
		pc.invert_mouse = inv
		pc.mouse_moved(Vector2(0, 60))   # toward you
		var toward := pc.sample(null, 1.0 / 60.0).stick.y
		pc.stick = Vector2.ZERO
		pc.mouse_moved(Vector2(0, -60))  # away
		var away := pc.sample(null, 1.0 / 60.0).stick.y
		if inv:
			check(away > 0.1 and toward < -0.1, "inverted: the mouse away pulls, toward you pushes (%.2f, %.2f)" % [away, toward])
		else:
			check(toward > 0.1 and away < -0.1, "the mouse toward you pulls, away pushes (%.2f, %.2f)" % [toward, away])
		pc.stick = Vector2.ZERO
		pc.mouse_moved(Vector2(60, 0))
		check(pc.stick.x > 0.1 and absf(pc.stick.y) < 1e-6, "the mouse right banks right, inverted or not (invert %s)" % inv)


## The gamepad's left stick, both ways.
func _pad() -> void:
	for inv in [false, true]:
		var pc := PlayerController.new()
		pc.invert_pad = inv
		_axis(JOY_AXIS_LEFT_Y, 1.0)   # back
		var back := pc.sample(null, 1.0 / 60.0).stick.y
		_axis(JOY_AXIS_LEFT_Y, -1.0)  # forward
		var fwd := pc.sample(null, 1.0 / 60.0).stick.y
		_axis(JOY_AXIS_LEFT_Y, 0.0)
		if inv:
			check(fwd > 0.6 and back < -0.6, "inverted: the stick forward pulls, back pushes (%.2f, %.2f)" % [fwd, back])
		else:
			check(back > 0.6 and fwd < -0.6, "the stick back pulls, forward pushes (%.2f, %.2f)" % [back, fwd])


## The mouse toward you raises the bird's angle of attack, and with the setting the mouse away does.
func _flies() -> void:
	for inv in [false, true]:
		var alpha := {}
		for dir in [1.0, -1.0]:
			var pc := PlayerController.new()
			pc.invert_mouse = inv
			var m := FlightModel.new(BirdProfile.by_id("crow"))
			m.velocity = Vector3(0, 0, -BirdProfile.by_id("crow").v_best)
			for t in 30:
				pc.mouse_moved(Vector2(0, 8.0 * dir))
				var inp := pc.sample(null, 1.0 / 60.0)
				m.step(1.0 / 60.0, inp)
			alpha[dir] = m.alpha
		var climb: float = -1.0 if inv else 1.0   # the mouse's way that should pull
		check(alpha[climb] > alpha[-climb] + 0.05, "%s: the mouse %s raises the angle of attack (%.3f v %.3f rad)" % [
			"inverted" if inv else "default", "away" if inv else "toward you", alpha[climb], alpha[-climb]])
	await frames(1)


## Saved, loaded and taken by a new controller.
func _saved() -> void:
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = false
	Settings.load_saved()
	check(not Settings.invert_mouse_y and not Settings.invert_pad_y, "no file: the defaults")
	Settings.invert_mouse_y = true
	Settings.invert_pad_y = false
	Settings.save()
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = true
	Settings.load_saved()
	check(Settings.invert_mouse_y and not Settings.invert_pad_y, "the mouse's setting comes back from the file, the stick's too")
	var pc := PlayerController.new()
	check(pc.invert_mouse and not pc.invert_pad, "a new controller takes the settings")
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = true
	pc = PlayerController.new()
	check(not pc.invert_mouse and pc.invert_pad, "both ways")


## The menu's Settings screen.
func _screen() -> void:
	Settings.invert_mouse_y = false
	Settings.invert_pad_y = false
	Boot.extra = PackedStringArray(["--no-backdrop"])
	SettingsPanel.tab = 0
	var menu: Menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var i := Menu.CHOICES.map(func(c: Array) -> String: return c[0]).find("Settings")
	check(i >= 0, "the menu offers Settings")
	(menu.find_child("Choice%d" % i, true, false) as Button).pressed.emit()
	await frames(2)
	var back := menu.find_child("SettingsBack", true, false) as Button
	check(back.is_visible_in_tree() and not (menu.find_child("Choice0", true, false) as Button).is_visible_in_tree(),
		"Settings opens its own screen")
	# The tabs: Keyboard first, Mouse with the mouse's choice, Gamepad with the stick's.
	check(_shown(menu, "Tab0") and _shown(menu, "Tab1") and _shown(menu, "Tab2"), "tabs for the keyboard, the mouse and the gamepad")
	check(_shown(menu, "ControlsKeyboard") and not _shown(menu, "MouseY0") and not _shown(menu, "PadY0"), "the keyboard's shown, no choices on it")
	(menu.find_child("Tab2", true, false) as Button).pressed.emit()
	check(_shown(menu, "PadY0") and _shown(menu, "ControlsGamepad") and not _shown(menu, "MouseY0") and not _shown(menu, "ControlsKeyboard"), "the gamepad's tab: the stick's choice and its controls")
	(menu.find_child("Tab1", true, false) as Button).pressed.emit()
	check(_shown(menu, "MouseY0") and _shown(menu, "ControlsMouse") and not _shown(menu, "PadY0"), "the mouse's tab: its choice and controls")
	check((menu.find_child("MouseY0", true, false) as Button).button_pressed, "the mouse's default is shown")
	check(_text(menu).contains(SettingsPanel.MOUSE_Y[0][1]), "with what it means")
	(menu.find_child("MouseY1", true, false) as Button).pressed.emit()
	await frames(1)
	check(Settings.invert_mouse_y, "picking Away sets the mouse to climb away")
	check(_text(menu).contains(SettingsPanel.MOUSE_Y[1][1]) and not _text(menu).contains(SettingsPanel.MOUSE_Y[0][1]), "and says so")
	Settings.invert_mouse_y = false
	Settings.load_saved()
	check(Settings.invert_mouse_y, "and saves it at once")
	(menu.find_child("Tab2", true, false) as Button).pressed.emit()
	(menu.find_child("PadY1", true, false) as Button).pressed.emit()
	(menu.find_child("MouseY0", true, false) as Button).pressed.emit()
	Settings.load_saved()
	check(Settings.invert_pad_y and not Settings.invert_mouse_y, "the stick's choice too, and back again")
	# The controls, from the bindings: each row's cells as drawn.
	var keys := _rows(menu, "Keyboard")
	var mouse := _rows(menu, "Mouse")
	var pad := _rows(menu, "Gamepad")
	eq([keys.get("Flap (hold to keep flapping)"), mouse.get("Flap (hold to keep flapping)"), pad.get("Flap (hold to keep flapping)")],
		["Space", null, "LT"], "flap: Space, LT, nothing on the mouse")
	eq([keys.get("Fire"), mouse.get("Fire"), pad.get("Fire")], ["F", "Left mouse", "RT"], "fire: F, the left mouse, RT")
	eq([keys.get("Centre the stick"), mouse.get("Centre the stick"), pad.get("Centre the stick")], ["C", "Middle mouse", null], "centre: C, the middle mouse")
	eq([keys.get("Steer"), mouse.get("Steer"), pad.get("Steer")], [null, "Move the mouse", "Left stick"], "steer: the mouse, the left stick")
	eq([keys.get("Change bird"), pad.get("Change bird")], ["1 - 5", "Back"], "change bird: 1-5, Back")
	eq([keys.get("Pause: resume, start over, settings, leave"), pad.get("Pause: resume, start over, settings, leave")], ["Escape", "Start"], "pause: Escape, Start")
	eq([keys.get("Start over"), pad.get("Start over")], ["R", "Pause menu"], "start over: R, or the pause menu")
	for r: Array in SettingsPanel.CONTROL_ROWS:
		check(keys.has(r[0]) or mouse.has(r[0]) or pad.has(r[0]), "%s is on a tab" % r[0])
	var plates := (menu.find_child("ControlsKeyboard", true, false) as GridContainer).find_children("*", "Button", true, false)
	check(plates.size() > 5 and plates.all(func(b: Button) -> bool: return b.disabled), "the bindings are plates, not rebindable yet")
	# The tab shown last is shown next time.
	var again := SettingsPanel.new()
	check((again.find_child("Tab2", true, false) as Button).button_pressed, "the tab shown last (the gamepad's) comes up again")
	again.free()
	SettingsPanel.tab = -1
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	await frames(1)
	check(not back.is_visible_in_tree() and (menu.find_child("Choice0", true, false) as Button).is_visible_in_tree(), "Esc goes back")
	menu.queue_free()
	await frames(2)


## A tab's controls, what -> binding as drawn on its plate.
func _rows(menu: Node, tab: String) -> Dictionary:
	var cells := (menu.find_child("Controls" + tab, true, false) as GridContainer).get_children()
	var rows := {}
	for r in cells.size() / 2:
		rows[(cells[r * 2] as Label).text] = (cells[r * 2 + 1] as Button).text
	return rows


func _shown(n: Node, child: String) -> bool:
	var c := n.find_child(child, true, false) as Control
	return c != null and c.is_visible_in_tree()


func _text(n: Node) -> String:
	var t := ""
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			t += (l as Label).text + "\n"
	return t


func _axis(axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()
