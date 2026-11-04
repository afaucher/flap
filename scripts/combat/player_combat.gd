class_name PlayerCombat
extends RefCounted
## The player's weapon controls -> CombatInput. Fire: left mouse / F / right trigger. Switch weapon: Q / RB.
## The click that captures the mouse (the scene's _unhandled_input, while it's free) only captures it: it doesn't
## fire, nor does holding it -- the weapon waits for that button to come up. Nor does any left click while the mouse
## is free (one a screen or a panel took).

static var _swallowed := false   ## the capturing click is down: no fire until it's released
static var assume_captured := false   ## tests: take the mouse as captured (headless it never is)


## The scene passes every unhandled event here first, with whether the mouse is captured as it arrives.
static func handle_event(e: InputEvent, captured: bool) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and not captured:
			_swallowed = true
		elif not e.pressed:
			_swallowed = false


func sample(_launcher: Launcher, _dt: float) -> CombatInput:
	var captured := assume_captured or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _swallowed or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not captured):
		return CombatInput.new(false, false, Input.is_action_just_pressed("weapon_next"))
	return CombatInput.new(Input.is_action_just_pressed("fire"), Input.is_action_pressed("fire"), Input.is_action_just_pressed("weapon_next"))
