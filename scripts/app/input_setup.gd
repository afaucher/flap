class_name InputSetup
extends RefCounted
## Input actions, registered in code so project.godot stays readable.
##
## Keyboard + mouse: the mouse (captured) moves a virtual stick; Space flaps (hold to keep flapping),
## Ctrl catches a perch / lets go of one.
## Gamepad: left stick steers (absolute, springs to centre), right stick tilts the camera, left trigger
## flaps, A catches / lets go. Back cycles the bird, Start respawns, Y toggles the autopilot.
## Combat (scripts/combat): left mouse / F / right trigger fires, Q / RB switches weapon.

const KEYS := {
	"flap": [KEY_SPACE],
	"catch": [KEY_CTRL],
	"center_stick": [KEY_C],
	"respawn": [KEY_R],
	"toggle_autopilot": [KEY_P],
	"toggle_debug": [KEY_F3],
	"bird_1": [KEY_1],
	"bird_2": [KEY_2],
	"bird_3": [KEY_3],
	"bird_4": [KEY_4],
	"bird_5": [KEY_5],
	"pause": [KEY_ESCAPE],
	"fire": [KEY_F],
	"weapon_next": [KEY_Q],
}
const MOUSE := {
	"center_stick": MOUSE_BUTTON_MIDDLE,
	"fire": MOUSE_BUTTON_LEFT,
}
const PAD_BUTTONS := {
	"catch": JOY_BUTTON_A,
	"cycle_bird": JOY_BUTTON_BACK,
	"respawn": JOY_BUTTON_START,
	"toggle_autopilot": JOY_BUTTON_Y,
	"weapon_next": JOY_BUTTON_RIGHT_SHOULDER,
}
## action: [axis, direction]
const PAD_AXES := {
	"flap": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"steer_left": [JOY_AXIS_LEFT_X, -1.0],
	"steer_right": [JOY_AXIS_LEFT_X, 1.0],
	"steer_push": [JOY_AXIS_LEFT_Y, -1.0],
	"steer_pull": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Left mouse", MOUSE_BUTTON_MIDDLE: "Middle mouse", MOUSE_BUTTON_RIGHT: "Right mouse"}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB"}
const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_LEFT_X: "Left stick",
	JOY_AXIS_LEFT_Y: "Left stick", JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick"}
const STICK_DEADZONE := 0.12
const TRIGGER_DEADZONE := 0.35


static func ensure_actions() -> void:
	for action in KEYS:
		_add(action)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in MOUSE:
		_add(action)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE[action]
		InputMap.action_add_event(action, m)
	for action in PAD_BUTTONS:
		_add(action)
		var b := InputEventJoypadButton.new()
		b.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, b)
	for action in PAD_AXES:
		_add(action)
		var j := InputEventJoypadMotion.new()
		j.axis = PAD_AXES[action][0]
		j.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, j)
		InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if action == "flap" or action == "fire" else STICK_DEADZONE)


static func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


## What sets off `action` on the keyboard and mouse ("Left mouse / F"), from the bindings above; "" for none.
static func keys_for(action: String) -> String:
	var names := []
	if MOUSE.has(action):
		names.append(MOUSE_NAMES.get(MOUSE[action], "Mouse %d" % MOUSE[action]))
	for k in KEYS.get(action, []):
		names.append(OS.get_keycode_string(k))
	return " / ".join(names)


## What sets it off on a gamepad ("RT"); "" for none.
static func pad_for(action: String) -> String:
	if PAD_BUTTONS.has(action):
		return PAD_NAMES.get(PAD_BUTTONS[action], "Button %d" % PAD_BUTTONS[action])
	if PAD_AXES.has(action):
		return AXIS_NAMES.get(PAD_AXES[action][0], "Axis %d" % PAD_AXES[action][0])
	return ""
