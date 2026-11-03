extends TestCase
## Diagnostic: 1 v 1 duels between combat-AI birds (and an AI against the range's racetrack target), printing the
## outcomes. DUEL=crow,hawk (the two species), DUEL_SECONDS=60, DUEL_SKILL=pilot, DUEL_FOREST=greybox.

func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var ids := (OS.get_environment("DUEL") if OS.get_environment("DUEL") != "" else "crow,crow").split(",")
	var secs := float(OS.get_environment("DUEL_SECONDS")) if OS.get_environment("DUEL_SECONDS") != "" else 60.0
	var skill := CombatSkill.preset(OS.get_environment("DUEL_SKILL"))
	var layout := ArenaLayout.generate(7) if OS.get_environment("DUEL_FOREST") == "greybox" else Pinewood.generate(7)
	for id in ids:
		print(CombatStyle.of(BirdProfile.by_id(id)).describe())
	var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var bases := {0: a, 1: CombatWorld.far_base(layout, a.position)}
	var d := Duel.new()
	add_child(d)
	d.setup(layout, bases)
	await frames(2)
	d.add_ai(ids[0], 0, Vector3(-20, 22, 0), Vector3.RIGHT, skill, 11)
	if OS.get_environment("DUEL_TARGET") == "circuit":   # (the range's racetrack target, flying straight on)
		var cp := CircuitPilot.new()
		cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
		cp.evade = OS.get_environment("DUEL_EVADE") == "1"
		cp.threat = d.world.threat_to
		var w: Array = cp.waypoints
		cp.wp = 1
		d.add_bird(ids[1], 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	else:
		d.add_ai(ids[1], 1, Vector3(20, 22, 8), Vector3.LEFT, skill, 12)
	Perf.on = true
	Perf._acc.clear()
	var trace := OS.get_environment("DUEL_TRACE") != ""   # (every half second: the first bird's mode and geometry)
	for k in int(secs / 5.0):
		var out: Dictionary
		if trace:
			for h in 10:
				out = await d.run(0.5)
				var e0: Dictionary = d.entries[0]
				var br0: CombatBrain = e0.brain
				var me: Bird = e0.bird
				var tb: Bird = d.entries[1].bird
				var ata := rad_to_deg(Engagement.ata(me.global_position, me.model.flight_dir(), tb.global_position))
				var l0: Launcher = e0.launcher
				var miss := FireControl.miss(Projectile.Kind.ROCKET, l0.muzzle(), me.model.velocity, l0.aim(), tb.global_position, tb.model.velocity) if l0.weapon == Launcher.Weapon.ROCKETS else -1.0
				var lead_off := rad_to_deg(l0.aim().angle_to(br0.intent.aim - l0.muzzle()))
				print("  %5.1f %s/%s above %5.1f range %5.1f ata %4.0f v %4.1f gamma %4.0f shots %d miss %.1f off-aim %.0f avoiding %s" % [k * 5.0 + (h + 1) * 0.5, br0.intent.mode, br0.bz_phase, me.global_position.y - tb.global_position.y, me.global_position.distance_to(tb.global_position), ata, me.model.speed, rad_to_deg(me.model.path_angle), l0.shots, miss, lead_off, br0.pilot.avoiding > 0.0])
		else:
			out = await d.run(5.0)
		var line := "t %3.0f" % ((k + 1) * 5.0)
		for e in d.entries:
			var b: Bird = e.bird
			var br: CombatBrain = e.brain
			if br == null:
				line += " | %s y%4.1f hp %.2f" % [b.profile.id, b.global_position.y, b.health()]
				continue
			var held: int = (e.launcher.controller as AICombat).shots_held
			line += " | %s %s y%4.1f v%4.1f hp %.2f ammo %d st %.2f tgt %s held %d lock %.1f" % [b.profile.id, br.intent.mode, b.global_position.y, b.model.speed, b.health(), br.ammo_left(), b.model.energy.stamina, "y" if br.target != null else "-", held, e.launcher.lock]
		print(line, "  ms/tick %.2f" % out.ms_per_tick)
	print("OUTCOME ", d.outcome())
	for k in Perf._acc:
		print("PERF %s: %.0f us per tick" % [k, float(Perf._acc[k]) / (secs * 60.0)])
	Perf.on = false
	d.cleanup()
	await frames(2)
	finish()
