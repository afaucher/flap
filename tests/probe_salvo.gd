extends TestCase
## Diagnostic: how birds go down in a 3 v 3 of combat-AI birds (pilot skill; crow / sparrow / hawk a side) in the
## pine wood. For every down: the hits it took since it was last whole, and the seconds from the first of them to the
## down; and how many hits landed while the bird was still stunned by the one before. SALVO_SECONDS (180),
## SALVO_SEEDS (2), SALVO_SKILL (pilot). SALVO_TARGET=circuit: your side's crow is a stand-in for a player who
## doesn't dodge (the range's racetrack target, no evasion), reported on its own. SALVO_RECOVER: CombatWorld.recover
## (0: the window off).

func _init() -> void:
	timeout_sec = 2000.0


func setup() -> void:
	var secs := float(OS.get_environment("SALVO_SECONDS")) if OS.get_environment("SALVO_SECONDS") != "" else 180.0
	var seeds := int(OS.get_environment("SALVO_SEEDS")) if OS.get_environment("SALVO_SEEDS") != "" else 2
	var skill := OS.get_environment("SALVO_SKILL") if OS.get_environment("SALVO_SKILL") != "" else "pilot"
	var circuit := OS.get_environment("SALVO_TARGET") == "circuit"
	if OS.get_environment("SALVO_RECOVER") != "":
		CombatWorld.recover = float(OS.get_environment("SALVO_RECOVER"))
	var downs: Array = []   # [hits, seconds from first hit, the stand-in?]
	var n := {"hits": 0, "stunned": 0}   # (a dict: lambdas capture ints by value)
	var stand_ins := {}
	var gaps: Array = []    # s between consecutive hits on one bird while it's hurt
	for s in seeds:
		var layout := Pinewood.generate(7 + s)
		var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
		var b := CombatWorld.far_base(layout, a.position)
		var d := Duel.new()
		add_child(d)
		d.setup(layout, {0: a, 1: b})
		await frames(1)
		for team in [0, 1]:
			var base: Perch = d.world.bases[team]
			var other: Perch = d.world.bases[1 - team]
			var toward := Vector3(other.position.x - base.position.x, 0.0, other.position.z - base.position.z).normalized()
			var across := Vector3(-toward.z, 0.0, toward.x)
			for i in 3:
				var at := base.position + toward * 12.0 + across * (float(i) - 1.0) * 6.0 + Vector3.UP * (6.0 + 2.0 * i)
				if circuit and team == 0 and i == 0:
					var cp := CircuitPilot.new()
					cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
					cp.evade = false
					var w: Array = cp.waypoints
					cp.wp = 1
					var e := d.add_bird("crow", 0, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
					stand_ins[e.bird] = true
					continue
				d.add_ai(["crow", "sparrow", "hawk"][i], team, at, toward, CombatSkill.preset(skill), 20 + team * 10 + i + 100 * s)
		var clock := [0.0]
		var run := {}   # Bird -> [hits, first hit time, last hit time]
		d.world.struck.connect(func(bd: Bird, _at: Vector3, _keys: Array):
			n.hits += 1
			if bd.stun > CombatWorld.HIT_STUN - 1e-3 and run.has(bd) and clock[0] - float(run[bd][2]) < CombatWorld.HIT_STUN:
				n.stunned += 1
			if not run.has(bd) or bd.lost_feathers.size() <= _keys.size():
				run[bd] = [0, clock[0], clock[0]]
			else:
				gaps.append(clock[0] - float(run[bd][2]))
			run[bd][0] = int(run[bd][0]) + 1
			run[bd][2] = clock[0])
		d.world.downed.connect(func(bd: Bird):
			if run.has(bd):
				downs.append([int(run[bd][0]), clock[0] - float(run[bd][1]), stand_ins.has(bd)])
				run.erase(bd))
		for f in int(secs * 60.0):
			await d.step()
			clock[0] += 1.0 / 60.0
		print("WOOD %d score %s" % [7 + s, str(d.world.score)])
		d.cleanup()
		await frames(2)
	print("HITS %d, %d landed while the bird was still stunned by the hit before (%.0f%%)" % [n.hits, n.stunned, 100.0 * n.stunned / maxf(n.hits, 1)])
	var quick := 0
	var by_hits := {}
	for dn in downs:
		by_hits[dn[0]] = int(by_hits.get(dn[0], 0)) + 1
		if float(dn[1]) < 1.5:
			quick += 1
	print("DOWNS %d; within 1.5 s of the first hit: %d (%.0f%%); hits to down: %s" % [downs.size(), quick, 100.0 * quick / maxf(downs.size(), 1), str(by_hits)])
	var times := downs.map(func(dn): return ("*" if dn[2] else "") + str(snappedf(float(dn[1]), 0.1)))
	times.sort()
	print("SECONDS first hit -> down (* the stand-in): ", times)
	gaps.sort()
	print("GAPS between hits on a hurt bird (s): ", gaps.map(func(g): return snappedf(g, 0.05)))
	finish()
