class_name PlayerController
extends RefCounted
## Gamepad or mouse + keyboard -> FlightInput.
##
## GAMEPAD (preferred): the left stick IS the stick -- absolute, springs to centre, so centre is always
## wings level and best glide. A gentle response curve keeps small corrections fine. The right stick tilts
## the camera (`look`), springing back when released.
## MOUSE: the captured mouse moves a virtual stick that holds where you leave it and drifts back to centre;
## C or the middle button snaps it to centre.
## Whichever device moved last is in charge (`using_gamepad`, also shown in the HUD's hints).

var sensitivity := 0.0045       ## mouse: stick per pixel (~220 px for full deflection)
var return_rate := Vector2(0.7, 1.1)   ## mouse: per second, exponential drift back to centre (x bank, y pitch)
var invert_mouse := Settings.invert_mouse_y   ## mouse: up climbs (default: toward you climbs, a stick's pull)
var invert_pad := Settings.invert_pad_y       ## gamepad: the stick forward climbs (default: back climbs)
var stick := Vector2.ZERO       ## mouse virtual stick
var look := Vector2.ZERO        ## right stick, -1..1 (x: look right, y: look down)
var using_gamepad := false
var assist := FlightAssist.new()   ## novice flying's landing assist (FlightAssist.novice; off: the input as it is)


func handle_event(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = e.relative
		if rel.length() > 0.5:
			using_gamepad = false
		mouse_moved(rel)
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.3:
		using_gamepad = true
	elif e is InputEventJoypadButton and e.pressed:
		using_gamepad = true
	elif e is InputEventKey and e.pressed:
		using_gamepad = false


## The captured mouse moved `rel` px: the virtual stick follows (down, toward you, pulls; up with invert_mouse).
func mouse_moved(rel: Vector2) -> void:
	stick.x += rel.x * sensitivity
	stick.y += rel.y * sensitivity * (-1.0 if invert_mouse else 1.0)
	stick = stick.clamp(Vector2(-1, -1), Vector2(1, 1))


## Gentle near centre, full at the edge: v * (0.35 + 0.65 |v|), applied to the radius.
static func shape(v: Vector2) -> Vector2:
	var r := minf(v.length(), 1.0)
	if r < 1e-4:
		return Vector2.ZERO
	return v / v.length() * r * (0.35 + 0.65 * r)


func sample(bird: Bird, dt: float) -> FlightInput:
	if Input.is_action_just_pressed("center_stick"):
		stick = Vector2.ZERO
	stick.x *= exp(-return_rate.x * dt)
	stick.y *= exp(-return_rate.y * dt)
	var pad := Input.get_vector("steer_left", "steer_right", "steer_push", "steer_pull", InputSetup.STICK_DEADZONE)
	look = Input.get_vector("look_left", "look_right", "look_up", "look_down", InputSetup.STICK_DEADZONE)
	var s := stick
	if using_gamepad or pad.length() > 0.0:
		s = shape(pad)
		if invert_pad:
			s.y = -s.y
		stick = Vector2.ZERO
	var inp := FlightInput.new(s, Input.is_action_just_pressed("flap"), Input.is_action_pressed("flap"),
		Input.is_action_just_pressed("catch"), Input.is_action_pressed("catch"))
	return assist.apply(bird, inp, dt)
