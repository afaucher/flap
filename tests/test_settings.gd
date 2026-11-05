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
	check((menu.find_child("MouseY0", true, false) as Button).button_pressed, "the mouse's default is shown")
	check(_text(menu).contains(SettingsPanel.MOUSE_Y[0][1]), "with what it means")
	(menu.find_child("MouseY1", true, false) as Button).pressed.emit()
	await frames(1)
	check(Settings.invert_mouse_y, "picking Away sets the mouse to climb away")
	check(_text(menu).contains(SettingsPanel.MOUSE_Y[1][1]) and not _text(menu).contains(SettingsPanel.MOUSE_Y[0][1]), "and says so")
	Settings.invert_mouse_y = false
	Settings.load_saved()
	check(Settings.invert_mouse_y, "and saves it at once")
	(menu.find_child("PadY1", true, false) as Button).pressed.emit()
	(menu.find_child("MouseY0", true, false) as Button).pressed.emit()
	Settings.load_saved()
	check(Settings.invert_pad_y and not Settings.invert_mouse_y, "the stick's choice too, and back again")
	# The controls, from the bindings: each row's cells as drawn.
	var grid := menu.find_child("Controls", true, false) as GridContainer
	var rows := {}
	var cells := grid.get_children()
	for r in cells.size() / 3:
		rows[(cells[r * 3] as Label).text] = [(cells[r * 3 + 1] as Label).text, (cells[r * 3 + 2] as Label).text]
	eq(rows.get("Flap (hold to keep flapping)"), ["Space", "LT"], "flap: Space, LT")
	eq(rows.get("Fire"), ["Left mouse / F", "RT"], "fire: the left mouse or F, RT")
	eq(rows.get("Catch a perch, or let go"), ["Ctrl", "A"], "catch: Ctrl, A")
	eq(rows.get("Change bird"), ["1 - 5", "Back"], "change bird: 1-5, Back")
	for r: Array in SettingsPanel.CONTROL_ROWS:
		check(rows.has(r[0]) and (rows[r[0]][0] != "" or rows[r[0]][1] != ""), "a row for %s, set off by something" % r[0])
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	await frames(1)
	check(not back.is_visible_in_tree() and (menu.find_child("Choice0", true, false) as Button).is_visible_in_tree(), "Esc goes back")
	menu.queue_free()
	await frames(2)


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
