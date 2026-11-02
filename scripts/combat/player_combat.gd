class_name PlayerCombat
extends RefCounted
## The player's weapon controls -> CombatInput. Fire: left mouse / F / right trigger. Switch weapon: Q / RB.

func sample(_launcher: Launcher, _dt: float) -> CombatInput:
	return CombatInput.new(Input.is_action_just_pressed("fire"), Input.is_action_pressed("fire"), Input.is_action_just_pressed("weapon_next"))
