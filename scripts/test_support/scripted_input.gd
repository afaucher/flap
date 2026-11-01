class_name ScriptedInput
extends RefCounted
## A bird controller for tests: returns whatever these hold, and clears the presses after one tick.

var stick := Vector2.ZERO
var flap := false        ## press (one tick)
var hold := false        ## flap held
var catch := false       ## press (one tick)
var catch_hold := false  ## catch held


func sample(_bird: Bird, _dt: float) -> FlightInput:
	var i := FlightInput.new(stick, flap, hold, catch, catch_hold)
	flap = false
	catch = false
	return i
