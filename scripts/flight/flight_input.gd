class_name FlightInput
extends RefCounted
## One tick of control, from the player (PlayerController) or the AI (AIPilot): both fly through this
## and nothing else, so the AI has exactly the player's authority.

## Steering stick. x: -1 full left bank .. +1 full right bank. y: -1 full push (nose down, speed up,
## wings tuck past -0.5) .. +1 full pull (nose up, bleeds speed, flares past the stall).
## 0 is the best-glide angle of attack and wings level. While perched or on the ground, x turns the bird
## to look around.
var stick := Vector2.ZERO
## Flap this tick (Space / left trigger). From a perch or the ground: take off.
var flap_pressed := false
## Flap held: keep flapping at the wingbeat rate.
var flap_held := false
## Catch held (Ctrl / A): the bird catches the first perch that comes into reach slow enough -- hold it
## through the approach.
var catch_held := false
## Catch pressed this tick: on a perch, let go and drop off (a fresh press, so holding catch through a
## landing doesn't drop you straight off again).
var catch_pressed := false


func _init(s := Vector2.ZERO, flap := false, held := false, catch := false, catch_hold := false) -> void:
	stick = s
	flap_pressed = flap
	flap_held = held
	catch_pressed = catch
	catch_held = catch_hold or catch
