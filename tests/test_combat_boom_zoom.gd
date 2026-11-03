extends TestCase
## Boom and zoom (docs/design/combat_ai.md, 4.4 and 5): the energy fighters, a hawk and a falcon (pilot skill), against
## the range's racetrack target flying straight on, 40 s each in three pine woods: they stoop on it again and again and
## land hits (counted over the three: one wood can leave a bird few clean passes), and touch the trees rarely.

const WOODS := [7, 11, 3]


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	for id in ["hawk", "falcon"]:
		var tot := {"hits": 0, "shots": 0, "stoops": 0, "bonks": 0}
		for s in WOODS:
			var r: Dictionary = await _versus_racetrack(id, false, false, s)
			for k in tot:
				tot[k] += r[k]
			print("%s, pine wood %d: %d hits, %d shots, %d stoops, %d bonks" % [id, s, r.hits, r.shots, r.stoops, r.bonks])
		print("%s in all: %s" % [id, tot])
		check(tot.stoops >= 6, "%s stoops on it again and again (%d stoops)" % [id, tot.stoops])
		check(tot.hits >= 3, "%s lands hits from its stoops (%d)" % [id, tot.hits])
		check(tot.bonks <= 4, "%s touches trees rarely (%d bonks)" % [id, tot.bonks])
	finish()


## One bird (the combat AI, or with `demo` the old chase-and-trigger) against the racetrack target for 40 s in the pine
## wood of `arena_seed`.
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
	var r := {"hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "shots": int(out.birds[1].shots), "bonks": int(out.birds[1].bonks),   # (the target was added first)
		"stoops": int((me.brain as CombatBrain).stats.get("stoops", 0)) if me.brain != null else 0}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r


