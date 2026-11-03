class_name CombatPilot
extends RefCounted
## A combat AI bird's flight controller (docs/design/combat_ai.md, 3): sample(bird, dt) -> FlightInput, like
## every controller. It ticks the brain, then flies its Intent: toward the intent's aim through AIPilot.steer
## (the guidance law and the tree avoidance), or -- resting or rearming -- to the intent's perch with AIPilot's
## own perch flight, where it sits until the brain wants to fight again, then pushes off (on the ground, likewise,
## if it came down there to rest).

var brain: CombatBrain


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
			return FlightInput.new(Vector2.ZERO, true, false)   # push off with a wingbeat
		Bird.State.GROUNDED:
			if i.mode == "rest":
				return FlightInput.new()   # (resting on the ground)
			return FlightInput.new(Vector2.ZERO, true, true)
		Bird.State.LANDING:
			return FlightInput.new()
	if i.perch != null:
		if ai.target != i.perch:
			ai.go_to_perch(bird, i.perch)
		return ai.sample(bird, dt)
	if ai.target != null:
		ai.target = null   # (left its perch flight: steering again)
	return ai.steer(bird, i.aim, dt, i.opts)
