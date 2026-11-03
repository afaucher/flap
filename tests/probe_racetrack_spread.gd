extends TestCase
## Diagnostic: how a combat-AI bird does against the racetrack target flying straight on, across many pine woods, so
## the combat tests can check a skill over enough matches rather than one chaotic one. 16 woods over 8 shards.

const SHARDS := 8
const BIRDS := ["hawk", "falcon", "sparrow", "crow"]


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	for i in 8:
		if in_shard(i):
			for s in [1 + i * 2, 2 + i * 2]:
				for id in BIRDS:
					var r: Dictionary = await _run(id, s)
					print("SPREAD %s wood %d hits %d shots %d stoops %d bonks %d downs %d" % [id, s, r.hits, r.shots, r.stoops, r.bonks, r.downs])
	finish()


func _run(id: String, arena_seed: int) -> Dictionary:
	var layout := Pinewood.generate(arena_seed)
	var home := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: home, 1: CombatWorld.far_base(layout, home.position)})
	await frames(1)
	var cp := CircuitPilot.new()
	cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
	cp.evade = false
	cp.threat = d.world.threat_to
	cp.wp = 1
	var w: Array = cp.waypoints
	var target: Dictionary = d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary = d.add_ai(id, 0, Vector3(-20, 22, 0), Vector3.RIGHT, CombatSkill.preset("pilot"), 11)
	(me.bird as Bird).rig.visible = false
	(target.bird as Bird).rig.visible = false
	var out: Dictionary = await d.run(40.0)
	var r := {"hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "shots": int(out.birds[1].shots), "bonks": int(out.birds[1].bonks),
		"stoops": int((me.brain as CombatBrain).stats.get("stoops", 0))}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r
