class_name PlayerController
extends RefCounted
## Mouse + space -> FlightInput. The mouse (captured) moves a virtual stick: right banks right, toward you
## pulls back, away from you pushes forward. The stick holds where you leave it but drifts back to centre
## (wings level, best glide), so letting go of the mouse settles you on the ideal glide slope.
## C or the middle button snaps it to centre.

var sensitivity := 0.0045       ## stick per pixel (~220 px for full deflection)
var return_rate := Vector2(0.7, 1.1)   ## per second, exponential drift back to centre (x bank, y pitch)
var invert_pitch := false
var stick := Vector2.ZERO


func handle_event(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = e.relative
		stick.x += rel.x * sensitivity
		stick.y += rel.y * sensitivity * (-1.0 if invert_pitch else 1.0)
		stick = stick.clamp(Vector2(-1, -1), Vector2(1, 1))


func sample(_bird: Bird, dt: float) -> FlightInput:
	if Input.is_action_just_pressed("center_stick"):
		stick = Vector2.ZERO
	stick.x *= exp(-return_rate.x * dt)
	stick.y *= exp(-return_rate.y * dt)
	return FlightInput.new(stick, Input.is_action_just_pressed("flap"), Input.is_action_pressed("flap"))
