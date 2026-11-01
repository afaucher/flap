extends TestCase
## Gamepad mapping through the real input actions: left stick steers (absolute, shaped), right stick looks,
## left trigger flaps (press and hold), A catches (press and hold); keyboard Space / Ctrl do the same.


func setup() -> void:
	InputSetup.ensure_actions()
	var pc := PlayerController.new()
	# Shaping: 0 -> 0, edge -> edge, gentle in between, direction kept.
	eq(PlayerController.shape(Vector2.ZERO), Vector2.ZERO, "shape(0)")
	near(PlayerController.shape(Vector2(1, 0)).x, 1.0, 1e-6, "shape(1)")
	check(PlayerController.shape(Vector2(0.3, 0)).x < 0.3, "gentle near centre")
	near(PlayerController.shape(Vector2(0, -0.6)).normalized().y, -1.0, 1e-6, "direction kept")

	# Left stick: right and back (pull).
	_axis(JOY_AXIS_LEFT_X, 1.0)
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	pc.handle_event(_motion(JOY_AXIS_LEFT_X, 1.0))
	var inp := pc.sample(null, 1.0 / 60.0)
	check(pc.using_gamepad, "the stick makes the gamepad the active device")
	check(inp.stick.x > 0.6 and inp.stick.y > 0.6, "left stick right + back -> bank right + pull (%s)" % inp.stick)
	# Centred stick: centred input (no drift, no memory).
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	inp = pc.sample(null, 1.0 / 60.0)
	eq(inp.stick, Vector2.ZERO, "released stick is centre")

	# Right stick: look.
	_axis(JOY_AXIS_RIGHT_X, -1.0)
	pc.sample(null, 1.0 / 60.0)
	check(pc.look.x < -0.9, "right stick left looks left")
	_axis(JOY_AXIS_RIGHT_X, 0.0)

	# Left trigger: flap held.
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	inp = pc.sample(null, 1.0 / 60.0)
	check(inp.flap_held, "left trigger flaps")
	check(not inp.catch_held, "the trigger isn't catch")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	inp = pc.sample(null, 1.0 / 60.0)
	check(not inp.flap_held, "trigger released")

	# A: catch held.
	_button(JOY_BUTTON_A, true)
	inp = pc.sample(null, 1.0 / 60.0)
	check(inp.catch_held, "A catches")
	check(not inp.flap_held, "A isn't flap")
	_button(JOY_BUTTON_A, false)

	# Keyboard: Space flaps, Ctrl catches.
	_key(KEY_SPACE, true)
	_key(KEY_CTRL, true)
	inp = pc.sample(null, 1.0 / 60.0)
	check(inp.flap_held and inp.catch_held, "space flaps, ctrl catches")
	_key(KEY_SPACE, false)
	_key(KEY_CTRL, false)
	finish()


func _motion(axis: int, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = v
	return e


func _axis(axis: int, v: float) -> void:
	Input.parse_input_event(_motion(axis, v))
	Input.flush_buffered_events()


func _button(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
