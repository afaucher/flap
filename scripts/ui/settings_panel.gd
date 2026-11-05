class_name SettingsPanel
extends VBoxContainer
## The Settings screen's body, the start menu's and the pause menu's, in three tabs (buttons Tab<i>): Keyboard, Mouse and
## Gamepad. Each lists what its device does, the binding on a plate as a rebinding screen would show it (the plates
## don't rebind yet: disabled), read from InputSetup's bindings into the GridContainer "Controls<tab>". The Mouse tab
## also has which way the mouse climbs (buttons MouseY<i>), the Gamepad tab which way the stick does (PadY<i>): Settings,
## saved at once; the game's controllers take them when the pause menu resumes. The tab shown last is shown again.

const TABS := ["Keyboard", "Mouse", "Gamepad"]
const DEVICES := ["keys", "mouse", "pad"]   ## (each tab's, for binding_for)
const MOUSE_Y := [   ## the mouse's choice: [label, what it means] (Settings.invert_mouse_y off, on)
	["Toward you", "Move the mouse toward you to climb, away to dive: a flight stick's pull and push."],
	["Away", "Move the mouse away from you to climb, toward you to dive: the nose follows the mouse."],
]
const PAD_Y := [     ## and the stick's (Settings.invert_pad_y)
	["Back", "Pull the left stick back to climb, push it forward to dive, as a flight stick."],
	["Forward", "Push the left stick forward to climb, pull it back to dive."],
]
## [what, InputSetup action] or [what, {device: action or the text}]; a tab lists the rows its device has a binding for.
const CONTROL_ROWS := [
	["Steer", {"mouse": "Move the mouse", "pad": "Left stick"}],
	["Look about", {"pad": "Right stick"}],
	["Flap (hold to keep flapping)", "flap"],
	["Catch a perch, or let go", "catch"],
	["Centre the stick", "center_stick"],
	["Fire", "fire"],
	["Switch weapon", "weapon_next"],
	["Zoom the camera", {"mouse": "Wheel"}],
	["Start over", "respawn"],
	["Change bird", {"keys": "1 - 5", "pad": "cycle_bird"}],
	["Autopilot", "toggle_autopilot"],
	["Instruments", "toggle_debug"],
	["Pause: resume, settings, leave", "pause"],
]
const W := 620.0

static var tab := -1   ## the tab shown last (-1, the first time: the gamepad's if one is connected, else the keyboard's)

var _pages: Array[VBoxContainer] = []
var _mouse_note: Label
var _pad_note: Label


func _init() -> void:
	add_theme_constant_override("separation", 16)
	custom_minimum_size.x = W
	var t := tab if tab >= 0 else (2 if Input.get_connected_joypads().size() > 0 else 0)
	add_child(MenuStyle.row(TABS, t, show_tab, "Tab"))
	for d in TABS.size():
		var page := MenuStyle.column(W)
		_pages.append(page)
		add_child(page)
		if d == 1:
			page.add_child(MenuStyle.heading("To climb, move the mouse"))
			page.add_child(MenuStyle.row(MOUSE_Y.map(func(m: Array) -> String: return m[0]), 1 if Settings.invert_mouse_y else 0,
				func(i: int) -> void:
					Settings.invert_mouse_y = i == 1
					Settings.save()
					refresh(), "MouseY"))
			_mouse_note = MenuStyle.note(W)
			page.add_child(_mouse_note)
		elif d == 2:
			page.add_child(MenuStyle.heading("To climb, move the stick"))
			page.add_child(MenuStyle.row(PAD_Y.map(func(m: Array) -> String: return m[0]), 1 if Settings.invert_pad_y else 0,
				func(i: int) -> void:
					Settings.invert_pad_y = i == 1
					Settings.save()
					refresh(), "PadY"))
			_pad_note = MenuStyle.note(W)
			page.add_child(_pad_note)
		page.add_child(MenuStyle.heading("Controls"))
		var grid := GridContainer.new()
		grid.name = "Controls" + TABS[d]
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 6)
		for r: Array in CONTROL_ROWS:
			var bound := binding_for(r, DEVICES[d])
			if bound == "":
				continue
			var what := MenuStyle.cell(r[0], false)
			what.custom_minimum_size.x = 300
			grid.add_child(what)
			var plate := MenuStyle.button(bound, 16, Vector2(200, 32))   # (a rebinding screen's plate; not yet)
			plate.disabled = true
			plate.focus_mode = Control.FOCUS_NONE
			grid.add_child(plate)
		page.add_child(grid)
	refresh()
	show_tab(t)


func show_tab(i: int) -> void:
	tab = i
	for d in _pages.size():
		_pages[d].visible = d == i


## The notes say what the choices mean.
func refresh() -> void:
	_mouse_note.text = MOUSE_Y[1 if Settings.invert_mouse_y else 0][1]
	_pad_note.text = PAD_Y[1 if Settings.invert_pad_y else 0][1]


## What sets off a CONTROL_ROWS row on `device` ("keys" | "mouse" | "pad"), from the bindings; "" for nothing.
static func binding_for(r: Array, device: String) -> String:
	var v: String = r[1] if r[1] is String else (r[1] as Dictionary).get(device, "")
	if _is_action(v):
		match device:
			"keys": return InputSetup.keys_for(v)
			"mouse": return InputSetup.mouse_for(v)
			_: return InputSetup.pad_for(v)
	return v if r[1] is Dictionary else ""


static func _is_action(s: String) -> bool:
	return InputSetup.KEYS.has(s) or InputSetup.MOUSE.has(s) or InputSetup.PAD_BUTTONS.has(s) or InputSetup.PAD_AXES.has(s)
