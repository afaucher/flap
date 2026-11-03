extends TestCase
## The combat AI in the pine wood (docs/design/combat_ai.md, 8), pilot skill:
##   - against the range's racetrack target flying straight on, a rocket bird and a seeker bird each land hits
##     and down it within 40 s;
##   - against the target breaking when shot at, it lands more hits than the range's old demo shooter
##     (CircuitPilot's chase + the trigger-finger AICombat);
##   - out of rounds, it flies home, lands on its base and rearms; it doesn't touch trees much doing all this.

const ARENA_SEED := 7


func _init() -> void:
	timeout_sec = 400.0


func setup() -> void:
	for id in ["sparrow", "crow"]:
		var r: Dictionary = await _versus_racetrack(id, false, false)
		var kind := "seekers" if CombatStyle.of(BirdProfile.by_id(id)).weapon == Launcher.Weapon.SEEKERS else "rockets"
		print("%s (%s) vs the racetrack target, straight on: %d hits, downed %d, %d shots, %d bonks" % [id, kind, r.hits, r.downs, r.shots, r.bonks])
		check(r.hits >= 3, "%s lands hits on a target flying straight on (%d)" % [id, r.hits])
		check(r.downs >= 1, "%s downs it within 40 s" % id)
		check(r.bonks <= 2, "%s touches trees rarely in the fight (%d bonks)" % [id, r.bonks])
	var ai: Dictionary = await _versus_racetrack("crow", true, false)
	var demo: Dictionary = await _versus_racetrack("crow", true, true)
	print("against the evading target: the combat AI %d hits (%d shots), the old demo shooter %d hits (%d shots)" % [ai.hits, ai.shots, demo.hits, demo.shots])
	check(ai.hits > demo.hits, "the combat AI lands more hits on the evading target than the old demo shooter (%d vs %d)" % [ai.hits, demo.hits])
	await _rearms_at_base()
	finish()


## A bird (the combat AI, or with `demo` the range's old chase-and-trigger) against the range's racetrack target for
## 40 s. Returns {hits, downs, shots, bonks}.
func _versus_racetrack(id: String, evade: bool, demo: bool) -> Dictionary:
	var layout := Pinewood.generate(ARENA_SEED)
	var home := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: home, 1: CombatWorld.far_base(layout, home.position)})
	await frames(1)
	var cp := CircuitPilot.new()
	cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
	cp.evade = evade
	cp.threat = d.world.threat_to
	cp.wp = 1
	var w: Array = cp.waypoints
	var target: Dictionary = d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary
	if demo:
		var chase := CircuitPilot.new()
		chase.mode = CircuitPilot.Mode.CHASE
		chase.quarry = target.bird
		chase.cruise = 1.1
		var trigger := AICombat.new()
		trigger.prefer = CombatStyle.of(BirdProfile.by_id(id)).weapon
		me = d.add_bird(id, 0, chase, trigger, Vector3(-20, 22, 0), Vector3.RIGHT)
		CombatBrain.arm(me.launcher, CombatStyle.of(BirdProfile.by_id(id)))
	else:
		me = d.add_ai(id, 0, Vector3(-20, 22, 0), Vector3.RIGHT, CombatSkill.preset("pilot"), 11)
	var out: Dictionary = await d.run(40.0)
	var r := {"hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "shots": int(out.birds[1].shots), "bonks": int(out.birds[1].bonks)}   # (the target was added first)
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r


## Empty, it flies home to its base (across the wood), lands, rearms and goes back up; a perch that isn't its base
## would not have rearmed it (Launcher.rearm_perch).
func _rearms_at_base() -> void:
	var layout := Pinewood.generate(ARENA_SEED)
	var home := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: home})
	await frames(1)
	var start := home.position + Vector3(25.0, 10.0, 0.0)
	var me: Dictionary = d.add_ai("crow", 0, start, Vector3.RIGHT, CombatSkill.preset("pilot"), 5)
	var l: Launcher = me.launcher
	l.ammo[l.weapon] = 0
	var b: Bird = me.bird
	var landed_at: Perch = null
	var rearmed_at := -1.0
	var took_off_full := false
	for f in 60 * 45:
		await get_tree().physics_frame
		if b.state == Bird.State.PERCHED and landed_at == null:
			landed_at = b.perch
		if rearmed_at < 0.0 and int(l.ammo[l.weapon]) == int(l.capacity[l.weapon]):
			rearmed_at = f / 60.0
		if rearmed_at >= 0.0 and b.state == Bird.State.FLYING:
			took_off_full = true
			break
	print("out of rounds 25 m from base: landed on %s, rearmed at %.1f s, took off again: %s" % [str(landed_at.id) if landed_at != null else "-", rearmed_at, took_off_full])
	check(landed_at == home, "out of rounds: it lands on its own base")
	check(rearmed_at > 0.0, "and rearms there")
	check(took_off_full, "then goes back up")
	d.cleanup()
	d.queue_free()
	await frames(2)
