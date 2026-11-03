extends TestCase
## Diagnostic: the cost of a 3 v 3 of combat-AI birds (pilot skill, crow/sparrow/hawk each side) in the pine wood,
## per physics tick and per Perf section. TEAM_SECONDS=60.

func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var secs := float(OS.get_environment("TEAM_SECONDS")) if OS.get_environment("TEAM_SECONDS") != "" else 180.0
	var layout := Pinewood.generate(7)
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
			d.add_ai(["crow", "sparrow", "hawk"][i], team, at, toward, CombatSkill.preset("pilot"), 20 + team * 10 + i)
	print("LAYOUT trees %d outposts %d perches %d max_tree_reach %.1f" % [layout.trees.size(), layout.outposts.size(), layout.perches.size(), layout.max_tree_reach])
	Perf.on = true
	Perf._acc.clear()
	var worst := 0.0
	var total := 0.0
	var worst_at := 0.0
	var over := 0
	var over2 := 0
	var fp := 0
	var worst_parts := {}
	var ticks := int(secs * 60.0)
	for f in ticks:
		var before := Perf._acc.duplicate()
		var t0 := Time.get_ticks_usec()
		await d.step()
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		for e in d.entries:   # (the fingerprint: every bird's position and speed, every tick, to the bit)
			var bd: Bird = e.bird
			fp = hash([fp, bd.global_position, bd.model.speed])
		if f % 600 == 599:
			print("FP %3.0f s %d" % [(f + 1) / 60.0, fp])
		total += ms
		if ms > worst:
			worst = ms
			worst_at = f / 60.0
			worst_parts = {}
			for k in Perf._acc:
				var dk := int(Perf._acc[k]) - int(before.get(k, 0))
				if dk > 500 or k.begins_with("x.plan"):
					worst_parts[k] = dk / 1000.0
			for e in d.entries:
				var brw: CombatBrain = e.brain
				worst_parts[(e.bird as Bird).profile.id + "%d" % e.team] = brw.intent.mode
		if ms > 16.7:
			over += 1
		if ms > 33.3:
			over2 += 1
	print("TICK mean %.2f ms, worst %.2f ms at %.1f s; %d ticks over 16.7 ms, %d over 33.3 ms (of %d)" % [total / ticks, worst, worst_at, over, over2, ticks])
	print("WORST TICK parts (ms) ", worst_parts)
	var keys := Perf._acc.keys()
	keys.sort()
	for k in keys:
		if k.begins_with("n.") or k.begins_with("max.") or k.begins_with("us."):
			print("COUNT %s: %d" % [k, Perf._acc[k]])
		else:
			print("PERF %s: %.0f us per tick" % [k, float(Perf._acc[k]) / ticks])
	print("OUTCOME ", d.outcome().score)
	Perf.on = false
	d.cleanup()
	await frames(2)
	finish()
