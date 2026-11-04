extends TestCase
## Diagnostic: the range's 3 v 3 match for 60 s, with the wood's ages on or off (PROBE_AGES=0): rounds fired every
## 10 s, the AI's modes, and each AI bird's state and height.

func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	Pinewood.ages = OS.get_environment("PROBE_AGES") != "0"
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	if not r.is_loaded:
		await r.loaded
	await frames(2)
	r.match_mode = true
	r.restart()
	var ai: Array = r.match_birds
	var avoid := 0
	for s in 6:
		for f in 600:
			await frames(1)
			for b in ai:
				avoid += int((b.controller as CombatPilot).brain.pilot.avoiding > 0.0)
		var shots := 0
		for l in r.world.launchers:
			if ai.has(l.bird):
				shots += l.shots
		var modes := []
		for b in ai:
			modes.append("%s %s y%.0f" % [(b.controller as CombatPilot).brain.intent.mode, Bird.State.keys()[b.state], b.global_position.y])
		var held := 0
		for l in r.world.launchers:
			if ai.has(l.bird) and l.get("ai") != null:
				held += (l.ai as AICombat).shots_held
		print("MATCH ages=%s t=%ds shots %d, avoiding %.0f%% of bird-ticks | %s" % [Pinewood.ages, (s + 1) * 10, shots, avoid * 100.0 / ((s + 1) * 600.0 * ai.size()), ", ".join(modes)])
	r.queue_free()
	await frames(2)
	finish()
