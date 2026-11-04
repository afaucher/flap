extends TestCase
## The combat AI with the machine gun (Launcher.Weapon.GUN): a pilot-skill crow carrying only the gun, against the
## range's racetrack target flying straight on, 40 s in each of two pine woods: it flies the bullet's lead pursuit and
## fires bursts when one has a fair chance: it lands hits (totals over the two: ~27 expected, probe_gun_straight), and
## its bullets hit at a fair rate for the scatter (~0.15 a round measured), not sprayed.

const WOODS := [1, 2]
const HITS := 10
const PER_ROUND := 0.07


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var hits := 0
	var rounds := 0
	for wood in WOODS:
		var r: Dictionary = await _run(wood)
		hits += r.hits
		rounds += r.rounds
		print("gun crow vs the racetrack target, pine wood %d: %d rounds, %d hits" % [wood, r.rounds, r.hits])
	check(hits >= HITS, "the AI with the gun lands hits on a target flying straight on (%d in %d woods)" % [hits, WOODS.size()])
	check(rounds > 0 and float(hits) / rounds >= PER_ROUND, "its bullets hit at a fair rate, not sprayed (%d of %d rounds, %.2f)" % [hits, rounds, float(hits) / maxf(rounds, 1)])
	finish()


func _run(wood: int) -> Dictionary:
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
	var me: Dictionary = d.add_ai("crow", 0, Vector3(-20, 22, 0), Vector3.RIGHT, CombatSkill.preset("pilot"), 11)
	var l: Launcher = me.launcher
	CombatBrain.arm_with(l, Launcher.Weapon.GUN)
	(me.bird as Bird).rig.visible = false
	(target.bird as Bird).rig.visible = false
	await d.run(40.0)
	var r := {"rounds": l.shots, "hits": int(d.world.hits.get(target.bird, 0))}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r
