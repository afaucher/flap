class_name SettingsPanel
extends HBoxContainer
## The Settings screen's body, the start menu's and the pause menu's: which way the mouse and the gamepad's stick climb
## (Settings, saved at once; the game's controllers take them when the pause menu resumes) and every control, read from
## InputSetup's bindings. Its choices are buttons MouseY<i> and PadY<i>, the controls table the GridContainer "Controls".

const MOUSE_Y := [   ## the mouse's choice: [label, what it means] (Settings.invert_mouse_y off, on)
	["Toward you", "Move the mouse toward you to climb, away to dive: a flight stick's pull and push."],
	["Away", "Move the mouse away from you to climb, toward you to dive: the nose follows the mouse."],
]
const PAD_Y := [     ## and the stick's (Settings.invert_pad_y)
	["Back", "Pull the left stick back to climb, push it forward to dive, as a flight stick."],
	["Forward", "Push the left stick forward to climb, pull it back to dive."],
]
const CONTROL_ROWS := [   ## [what, InputSetup action] or [what, keyboard and mouse, gamepad], each an action or the text
	["Steer", "Mouse", "Left stick"],
	["Look about", "", "Right stick"],
	["Flap (hold to keep flapping)", "flap"],
	["Catch a perch, or let go", "catch"],
	["Centre the stick", "center_stick"],
	["Fire", "fire"],
	["Switch weapon", "weapon_next"],
	["Zoom the camera", "Mouse wheel", ""],
	["Start over", "respawn"],
	["Change bird", "1 - 5", "cycle_bird"],
	["Autopilot", "toggle_autopilot"],
	["Instruments", "toggle_debug"],
	["Pause: resume, settings, leave", "pause"],
]


var _mouse_note: Label
var _pad_note: Label


func _init() -> void:
	add_theme_constant_override("separation", 48)
	var pick := MenuStyle.column(380.0)
	var side := MenuStyle.column(560.0)
	add_child(pick)
	add_child(side)
	pick.add_child(MenuStyle.heading("To climb, move the mouse"))
	pick.add_child(MenuStyle.row(MOUSE_Y.map(func(m: Array) -> String: return m[0]), 1 if Settings.invert_mouse_y else 0,
		func(i: int) -> void:
			Settings.invert_mouse_y = i == 1
			Settings.save()
			refresh(), "MouseY"))
	_mouse_note = MenuStyle.note(380.0)
	pick.add_child(_mouse_note)
	pick.add_child(MenuStyle.heading("To climb, move the stick"))
	pick.add_child(MenuStyle.row(PAD_Y.map(func(m: Array) -> String: return m[0]), 1 if Settings.invert_pad_y else 0,
		func(i: int) -> void:
			Settings.invert_pad_y = i == 1
			Settings.save()
			refresh(), "PadY"))
	_pad_note = MenuStyle.note(380.0)
	pick.add_child(_pad_note)
	side.add_child(MenuStyle.heading("Controls"))
	var grid := GridContainer.new()
	grid.name = "Controls"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	for text in ["", "Keyboard and mouse", "Gamepad"]:
		grid.add_child(MenuStyle.cell(text, true))
	for r: Array in CONTROL_ROWS:
		grid.add_child(MenuStyle.cell(r[0], false))
		var keys: String = r[1]
		var pad: String = r[2] if r.size() > 2 else r[1]
		grid.add_child(MenuStyle.cell(InputSetup.keys_for(keys) if _is_action(keys) else keys, false))
		grid.add_child(MenuStyle.cell(InputSetup.pad_for(pad) if _is_action(pad) else pad, false))
	side.add_child(grid)
	refresh()


## The notes say what the choices mean.
func refresh() -> void:
	_mouse_note.text = MOUSE_Y[1 if Settings.invert_mouse_y else 0][1]
	_pad_note.text = PAD_Y[1 if Settings.invert_pad_y else 0][1]


static func _is_action(s: String) -> bool:
	return InputSetup.KEYS.has(s) or InputSetup.MOUSE.has(s) or InputSetup.PAD_BUTTONS.has(s) or InputSetup.PAD_AXES.has(s)
