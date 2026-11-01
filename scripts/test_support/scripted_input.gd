class_name ScriptedInput
extends RefCounted
## A bird controller for tests: returns whatever `next` holds, and clears the press after one tick.

var stick := Vector2.ZERO
var press := false
var hold := false


func sample(_bird: Bird, _dt: float) -> FlightInput:
	var i := FlightInput.new(stick, press, hold)
	press = false
	return i
