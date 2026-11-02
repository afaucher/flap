extends TestCase
## Diagnostic: run the combat range in demo mode and print the shooter's bearing to the target over time.

func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	await frames(2)
	r.demo = true
	r.start_seekers = OS.get_environment("FLAP_SEEKERS") == "1"
	r.evade = OS.get_environment("FLAP_EVADE") != "0"
	if OS.get_environment("FLAP_TARGET") != "":
		r.target_id = OS.get_environment("FLAP_TARGET")
	if OS.get_environment("FLAP_FUSE") != "":
		Projectile.fuse = float(OS.get_environment("FLAP_FUSE"))
		CombatWorld.blast = float(OS.get_environment("FLAP_BLAST"))
	r.restart()
	var l: Launcher = r.world.player
	for i in 1200:
		await frames(1)
		if i % 30 == 0:
			var br := l.bearing(r.target)
			print("%.1fs  off-aim %.0f deg  range %.1f m  lock %.2f  ammo %s  bird %s  target %s" % [i / 60.0, br.x, br.y, l.lock, l.ammo, Bird.State.keys()[r.bird.state], Bird.State.keys()[r.target.state]])
	print("stats ", r.world.stats, "  breaks ", r.target_pilot.breaks)
	check(true)
	finish()
