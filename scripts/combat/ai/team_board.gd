class_name TeamBoard
extends RefCounted
## What a team's birds tell each other (docs/design/combat_ai.md, 4.8): each member's target and mode, as they could
## call them out by sight and call. It never carries an enemy's position: each member sees for itself (CombatSense).
## The brains read it to spread their targets (a bird already taken by teammates scores lower, unless it's after me).

var team := 0
var _calls := {}             ## Bird -> {target: Bird or null, mode: String}


func _init(t := 0) -> void:
	team = t


## A member's call this tick: what it's after and what it's doing.
func report(b: Bird, target: Bird, mode: String) -> void:
	_calls[b] = {"target": target, "mode": mode}


func leave(b: Bird) -> void:
	_calls.erase(b)


## How many members other than `me` are fighting `target` (engaging or attacking it).
func on_target(target: Bird, me: Bird) -> int:
	var n := 0
	for b in _calls:
		if b == me or not is_instance_valid(b) or b.is_down():
			continue
		var c: Dictionary = _calls[b]
		if c.target == target and String(c.mode) in ["engage", "attack"]:
			n += 1
	return n


## A member's last call (or {}).
func call_of(b: Bird) -> Dictionary:
	return _calls.get(b, {})
