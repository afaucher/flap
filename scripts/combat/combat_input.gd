class_name CombatInput
extends RefCounted
## One tick of weapon control, alongside FlightInput: the player (PlayerCombat) and the AI (AICombat) both
## fight through this and nothing else, so the AI has exactly the player's authority.

var fire_pressed := false   ## fire this tick
var fire_held := false      ## held: rockets keep firing at their cadence
var weapon_next := false    ## switch weapon this tick


func _init(pressed := false, held := false, next := false) -> void:
	fire_pressed = pressed
	fire_held = held or pressed
	weapon_next = next
