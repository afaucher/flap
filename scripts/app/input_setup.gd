class_name InputSetup
extends RefCounted
## Input actions, registered in code so project.godot stays readable.
## Mouse (captured) is the virtual stick: left/right banks, toward you pulls back, away pushes forward.
## Space flaps in the air, grabs a perch in range, and releases from a perch.

const KEYS := {
	"flap": [KEY_SPACE],
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


static func ensure_actions() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in MOUSE:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE[action]
		InputMap.action_add_event(action, m)
