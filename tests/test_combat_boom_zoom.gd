extends TestCase
## Boom and zoom (docs/design/combat_ai.md, 4.4 and 5): the energy fighters, a hawk and a falcon (pilot skill), against
## the range's racetrack target flying straight on, 40 s each in eight pine woods (one shard each): they stoop on it in
## every wood, and again and again over all of them, land hits, and touch the trees rarely.
## One 40 s match is chaotic (a perch moved 2 mm changes how it goes), so each check is a total over the eight, set
## about three standard deviations short of what the bird does: over 16 woods (2026-11-03, probe_racetrack_spread) the
## hawk landed 2.7 hits a match (sd 1.2) and the falcon 1.25 (sd 1.0), both stooped 2.5 times (sd 0.7) and bonked 0.3-0.6.

const SHARDS := 2   ## (the hawk; the falcon)
const WOODS := [1, 2, 3, 4, 5, 6, 7, 8]
const STOOPS := 14   ## over the eight (~20 expected)
const HITS := {"hawk": 12, "falcon": 4}   ## over the eight (~21 and ~10 expected)
const BONKS := 10    ## over the eight (~3-5 expected)


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	var birds := ["hawk", "falcon"]
	for i in birds.size():
		if not in_shard(i):
			continue
		var id: String = birds[i]
		var tot := {"hits": 0, "shots": 0, "stoops": 0, "bonks": 0}
		var no_stoop := []
		for s in WOODS:
			var r: Dictionary = await _versus_racetrack(id, false, false, s)
			for k in tot:
				tot[k] += r[k]
			if r.stoops == 0:
				no_stoop.append(s)
			print("%s, pine wood %d: %d hits, %d shots, %d stoops, %d bonks" % [id, s, r.hits, r.shots, r.stoops, r.bonks])
		print("%s in all: %s" % [id, tot])
		check(no_stoop.is_empty(), "%s stoops on it in every wood (none in %s)" % [id, no_stoop])
		check(tot.stoops >= STOOPS, "%s stoops on it again and again (%d stoops in %d woods)" % [id, tot.stoops, WOODS.size()])
		check(tot.hits >= int(HITS[id]), "%s lands hits from its stoops (%d in %d woods)" % [id, tot.hits, WOODS.size()])
		check(tot.bonks <= BONKS, "%s touches trees rarely (%d bonks in %d woods)" % [id, tot.bonks, WOODS.size()])
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
	(target.bird as Bird).rig.visible = false   # (only the flying counts)
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
	(me.bird as Bird).rig.visible = false
	var out: Dictionary = await d.run(40.0)
	var r := {"hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "shots": int(out.birds[1].shots), "bonks": int(out.birds[1].bonks),   # (the target was added first)
		"stoops": int((me.brain as CombatBrain).stats.get("stoops", 0)) if me.brain != null else 0}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r


