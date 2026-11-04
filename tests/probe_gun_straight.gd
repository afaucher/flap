extends TestCase
## Diagnostic: an AI crow with the gun (each skill) against the range's racetrack target flying straight on, 40 s, woods
## 1-4: rounds, hits; and the aimed bullet's miss in attack (median) -- can it hit at all.

const SHARDS := 9


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var skills := ["recruit", "pilot", "ace"]
	var weapons := [Launcher.Weapon.ROCKETS, Launcher.Weapon.SEEKERS, Launcher.Weapon.GUN]
	for k in 9:
		var si := k / 3
		var wpn: int = weapons[k % 3]
		if in_shard(k):
			var rounds := 0
			var hits := 0
			var downs := 0
			var misses := []
			for wood in [1, 2, 3, 4]:
				var r: Dictionary = await _run(skills[si], wood, wpn)
				rounds += r.rounds
				hits += r.hits
				downs += r.downs
				misses.append_array(r.misses)
			misses.sort()
			print("STRAIGHT %s %s: rounds %d, hits %d, downs %d; aimed miss in attack within 25 m: p10 %.2f p50 %.2f (n %d)" % [skills[si], ["rockets", "seekers", "gun"][wpn], rounds, hits, downs, misses[int(misses.size() * 0.1)] if misses.size() > 0 else -1.0, misses[int(misses.size() * 0.5)] if misses.size() > 0 else -1.0, misses.size()])
	finish()


func _run(skill: String, wood: int, wpn: int) -> Dictionary:
	var layout := Pinewood.generate(wood)
	var home := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: home, 1: CombatWorld.far_base(layout, home.position)})
	await frames(1)
	var cp := CircuitPilot.new()
	cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
	cp.evade = false
	cp.wp = 1
	var w: Array = cp.waypoints
	var target: Dictionary = d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary = d.add_ai("crow", 0, Vector3(-20, 22, 0), Vector3.RIGHT, CombatSkill.preset(skill), 11)
	var l: Launcher = me.launcher
	CombatBrain.arm_with(l, wpn)
	var br: CombatBrain = me.brain
	var misses := []
	for f in 2400:
		await d.step()
		if br.intent.mode == "attack" and br.picture != null:
			var t := br.picture.track_of(br.intent.target)
			if t != null and t.visible and l.muzzle().distance_to(t.pos) < 25.0:
				misses.append(FireControl.miss(br.round_kind(), l.muzzle(), (me.bird as Bird).model.velocity, l.aim(), t.pos, t.vel, t.turn))
	var out: Dictionary = d.outcome()
	var r := {"rounds": l.shots, "hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "misses": misses}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r
