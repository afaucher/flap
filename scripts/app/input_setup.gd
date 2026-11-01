class_name InputSetup
extends RefCounted
## Input actions, registered in code so project.godot stays readable.
##
## Keyboard + mouse: the mouse (captured) moves a virtual stick; Space flaps (hold to keep flapping),
## Ctrl catches a perch / lets go of one.
## Gamepad: left stick steers (absolute, springs to centre), right stick tilts the camera, left trigger
## flaps, A catches / lets go. Back cycles the bird, Start respawns, Y toggles the autopilot.

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
	"release_mouse": [KEY_ESCAPE],
}
const MOUSE := {
	"center_stick": MOUSE_BUTTON_MIDDLE,
}
const PAD_BUTTONS := {
	"catch": JOY_BUTTON_A,
	"cycle_bird": JOY_BUTTON_BACK,
	"respawn": JOY_BUTTON_START,
	"toggle_autopilot": JOY_BUTTON_Y,
}
## action: [axis, direction]
const PAD_AXES := {
	"flap": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"steer_left": [JOY_AXIS_LEFT_X, -1.0],
	"steer_right": [JOY_AXIS_LEFT_X, 1.0],
	"steer_push": [JOY_AXIS_LEFT_Y, -1.0],
	"steer_pull": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}
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
		InputMap.action_set_deadzone(action, TRIGGER_DEADZONE if action == "flap" else STICK_DEADZONE)


static func _add(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
