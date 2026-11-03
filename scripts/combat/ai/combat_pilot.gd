class_name CombatPilot
extends RefCounted
## A combat AI bird's flight controller (docs/design/combat_ai.md, 3): sample(bird, dt) -> FlightInput, like
## every controller. It ticks the brain, then flies its Intent: toward the intent's aim through AIPilot.steer
## (the guidance law and the tree avoidance), or -- resting or rearming -- to the intent's perch with AIPilot's
## own perch flight, where it sits until the brain wants to fight again, then turns to face out from the tree
## (TURN_OUT_TIME at most) and pushes off (on the ground, likewise, if it came down there to rest). A perch it finds no way in to, it heads for regardless (no other perch will do
## for a base), planning again once the pilot's given that one up for a while.

const TURN_OUT_TIME := 1.5   ## s it may spend turning on its perch to face out before it pushes off

var brain: CombatBrain
var _turning := 0.0


func _init(b: CombatBrain) -> void:
	brain = b


func sample(bird: Bird, dt: float) -> FlightInput:
	brain.tick(dt)
	var i := brain.intent
	var ai := brain.pilot
	match bird.state:
		Bird.State.PERCHED:
			if i.perch != null and bird.perch == i.perch:
				return FlightInput.new()   # (resting, rearming)
			ai.target = null
			# Face out first (it may have landed facing the trunk): pushing off straight ahead would fly into the tree.
			var err := AIPilot._signed_heading(bird.facing, bird.perch.facing)
			if absf(err) > deg_to_rad(20.0) and _turning < TURN_OUT_TIME:
				_turning += dt
				return FlightInput.new(Vector2(clampf(err * 1.5, -1.0, 1.0), 0.0))
			_turning = 0.0
			return FlightInput.new(Vector2.ZERO, true, false)   # push off with a wingbeat
		Bird.State.GROUNDED:
			if i.mode == "rest":
				return FlightInput.new()   # (resting on the ground)
			return FlightInput.new(Vector2.ZERO, true, true)
		Bird.State.LANDING:
			return FlightInput.new()
	if i.perch != null:
		if ai.target != i.perch and not ai.gave_up_on(i.perch):
			ai.go_to_perch(bird, i.perch)
		if ai.target == i.perch:
			return ai.sample(bird, dt)
		ai.clock += dt   # (its give-up timers run on while it steers)
		return ai.steer(bird, i.perch.position + Vector3.UP * 3.0, dt, i.opts)
	if ai.target != null:
		ai.target = null   # (left its perch flight: steering again)
	return ai.steer(bird, i.aim, dt, i.opts)
