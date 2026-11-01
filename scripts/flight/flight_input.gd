class_name FlightInput
extends RefCounted
## One tick of control, from the player (PlayerController) or the AI (AIPilot): both fly through this
## and nothing else, so the AI has exactly the player's authority.

## Virtual stick. x: -1 full left bank .. +1 full right bank. y: -1 full push (nose down, speed up,
## wings tuck past -0.5) .. +1 full pull (nose up, bleeds speed, flares past the stall).
## 0 is the best-glide angle of attack and wings level.
var stick := Vector2.ZERO
## Space this tick: flap in the air, grab a perch in range, release from a perch.
var action_pressed := false
## Space held: keep flapping at the wingbeat rate.
var action_held := false


func _init(s := Vector2.ZERO, pressed := false, held := false) -> void:
	stick = s
	action_pressed = pressed
	action_held = held
