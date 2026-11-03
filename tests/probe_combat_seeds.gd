extends TestCase
## Diagnostic: the combat AI against the old demo shooter on the evading racetrack target, over several pine wood
## seeds (test_combat_ai's comparison, one seed there).
##   .	est_runner.ps1 -TestName probe_combat_seeds


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var tot := [0, 0]
	for s in [7, 3, 11, 21]:
		var ai: Dictionary = await _versus_racetrack("crow", true, false, s)
		var demo: Dictionary = await _versus_racetrack("crow", true, true, s)
		tot[0] += ai.hits
		tot[1] += demo.hits
		print("SEEDS pine wood %d, evading target: combat AI %d hits (%d shots), demo shooter %d hits (%d shots)" % [s, ai.hits, ai.shots, demo.hits, demo.shots])
	print("SEEDS total: combat AI %d, demo shooter %d" % tot)
	finish()


## (test_combat_ai's, with the arena seed a parameter)
func _versus_racetrack(id: String, evade: bool, demo: bool, arena_seed: int) -> Dictionary:
	var layout := Pinewood.generate(arena_seed)
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


