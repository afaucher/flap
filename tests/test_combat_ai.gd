extends TestCase
## The combat AI in the pine wood (docs/design/combat_ai.md, 8), pilot skill:
##   - against the range's racetrack target flying straight on, a rocket bird and a seeker bird each land hits
##     and down it within 40 s; the hawk and the falcon, boom and zoom, stoop on it and land hits;
##   - against the target breaking when shot at, it lands more hits than the range's old demo shooter
##     (CircuitPilot's chase + the trigger-finger AICombat);
##   - out of rounds, it flies home, lands on its base and rearms; it doesn't touch trees much doing all this;
##   - in a long turning fight with a sparrow that breaks and turns (an AI with nothing to shoot), it banks no
##     harder than its lift holds at the speed it has: it never stalls, nor spirals down (a hawk and a sparrow,
##     the target turning either way);
##   - an owl (the ambusher) away from the racetrack target settles on a perch above where it flies, waits, drops on
##     it as it passes below and lands hits;
##   - tired, a crow comes down to rest well away from the target (on a perch, or on the ground when it can't make one
##     in reach), then goes back up rested.

const ARENA_SEED := 7


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	for id in ["sparrow", "crow"]:
		var r: Dictionary = await _versus_racetrack(id, false, false)
		var kind := "seekers" if CombatStyle.of(BirdProfile.by_id(id)).weapon == Launcher.Weapon.SEEKERS else "rockets"
		print("%s (%s) vs the racetrack target, straight on: %d hits, downed %d, %d shots, %d bonks" % [id, kind, r.hits, r.downs, r.shots, r.bonks])
		check(r.hits >= 3, "%s lands hits on a target flying straight on (%d)" % [id, r.hits])
		check(r.downs >= 1, "%s downs it within 40 s" % id)
		check(r.bonks <= 2, "%s touches trees rarely in the fight (%d bonks)" % [id, r.bonks])
	# The energy fighters can't turn with it: they boom and zoom (climb above, stoop through with rockets, zoom up).
	for id in ["hawk", "falcon"]:
		var r: Dictionary = await _versus_racetrack(id, false, false)
		print("%s (boom and zoom) vs the racetrack target, straight on: %d hits, %d shots, %d stoops, %d bonks" % [id, r.hits, r.shots, r.stoops, r.bonks])
		check(r.stoops >= 2 and r.hits >= 2, "%s stoops on it and lands hits (%d stoops, %d hits)" % [id, r.stoops, r.hits])
		check(r.bonks <= 2, "%s touches trees rarely in the fight (%d bonks)" % [id, r.bonks])
	var ai: Dictionary = await _versus_racetrack("crow", true, false)
	var demo: Dictionary = await _versus_racetrack("crow", true, true)
	print("against the evading target: the combat AI %d hits (%d shots), the old demo shooter %d hits (%d shots)" % [ai.hits, ai.shots, demo.hits, demo.shots])
	check(ai.hits > demo.hits, "the combat AI lands more hits on the evading target than the old demo shooter (%d vs %d)" % [ai.hits, demo.hits])
	await _rearms_at_base()
	for id in ["hawk", "sparrow"]:
		for dir in [1.0, -1.0]:
			await _turning_fight(id, dir)
	await _ambush()
	await _rests_out_of_sight()
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
	var r := {"hits": int(d.world.hits.get(target.bird, 0)), "downs": int(out.birds[0].downs), "shots": int(out.birds[1].shots), "bonks": int(out.birds[1].bonks),   # (the target was added first)
		"stoops": int((me.brain as CombatBrain).stats.get("stoops", 0)) if me.brain != null else 0}
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


## 40 s chasing a sparrow AI that turns and breaks (no rounds on either side: only the flying counts).
func _turning_fight(id: String, dir: float) -> void:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	var them: Dictionary = d.add_ai("sparrow", 1, Vector3(7, 20, 0), Vector3(0, 0, dir), CombatSkill.preset("pilot"), 2)
	var me: Dictionary = d.add_ai(id, 0, Vector3(-25, 24, 0), Vector3.RIGHT, CombatSkill.preset("pilot"), 4)
	for e in [them, me]:
		var l: Launcher = e.launcher
		l.capacity[l.weapon] = 0
		l.ammo[l.weapon] = 0
	var b: Bird = me.bird
	var stalled := 0
	var low := INF
	for f in 60 * 40:
		await get_tree().physics_frame
		if f > 60:
			low = minf(low, b.global_position.y)
			stalled += 1 if b.model.stalled else 0
	var what := "%s in a turning fight (the sparrow turning %s)" % [id, "right" if dir > 0 else "left"]
	print("%s: stalled %d ticks, lowest %.1f m, modes %s" % [what, stalled, low, (me.brain as CombatBrain).stats.modes])
	check(stalled == 0, "%s: never stalls (%d ticks)" % [what, stalled])
	check(low > 9.0, "%s: doesn't spiral down (lowest %.1f m, from 24)" % [what, low])
	d.cleanup()
	d.queue_free()
	await frames(2)


## An owl 55 m off the racetrack target: it perches above the target's height, sits, drops on it and hits it.
func _ambush() -> void:
	var layout := Pinewood.generate(ARENA_SEED)
	var home := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: home, 1: CombatWorld.far_base(layout, home.position)})
	await frames(1)
	var cp := CircuitPilot.new()
	cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
	cp.wp = 1
	var w: Array = cp.waypoints
	var target: Dictionary = d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary = d.add_ai("owl", 0, Vector3(-55, 22, 25), Vector3.LEFT, CombatSkill.preset("pilot"), 6)
	var b: Bird = me.bird
	var br: CombatBrain = me.brain
	var sat := 0.0
	var perch_y := -INF
	for f in 60 * 90:
		await get_tree().physics_frame
		if b.state == Bird.State.PERCHED and br.intent.mode == "ambush":
			sat += 1.0 / 60.0
			perch_y = b.global_position.y
	var hits := int(d.world.hits.get(target.bird, 0))
	var drops := int(br.stats.get("ambushes", 0))
	print("owl ambush: sat %.1f s on a perch at %.1f m (the target flies at ~20 m), dropped %d times, %d hits (%d shots)" % [sat, perch_y, drops, hits, me.launcher.shots])
	check(sat > 2.0 and perch_y > 23.0, "the owl sits in ambush above the target's height (%.1f s at %.1f m)" % [sat, perch_y])
	check(drops >= 1, "it drops on the target passing below (%d)" % drops)
	check(hits >= 1, "and hits it (%d)" % hits)
	d.cleanup()
	d.queue_free()
	await frames(2)


## A crow near the racetrack target with its stamina nearly gone: it comes down away from the target (to the safe
## perch -- far from it, out of its sight where the trunks allow -- or, failing that, the ground), rests until it has
## its stamina back, and goes back up.
func _rests_out_of_sight() -> void:
	var layout := Pinewood.generate(ARENA_SEED)
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var cp := CircuitPilot.new()
	cp.waypoints = CircuitPilot.clear_racetrack(layout, Vector3(0, 20, 0), 40.0, 12.0)
	cp.wp = 1
	var w: Array = cp.waypoints
	var target: Dictionary = d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary = d.add_ai("crow", 0, Vector3(-30, 22, 10), Vector3.RIGHT, CombatSkill.preset("pilot"), 8)
	var b: Bird = me.bird
	var tb: Bird = target.bird
	b.model.energy.stamina = 0.2
	var rested := 0
	var hidden := 0
	var landed_on := ""
	var back_up := false
	var nearest := INF
	for f in 60 * 60:
		await get_tree().physics_frame
		var down := b.state == Bird.State.PERCHED or b.state == Bird.State.GROUNDED
		if down:
			landed_on = "perch %d" % b.perch.id if b.state == Bird.State.PERCHED else "the ground"
			rested += 1
			nearest = minf(nearest, b.global_position.distance_to(tb.global_position))
			if not layout.segment_clear(tb.global_position, b.global_position + Vector3.UP * 0.3, 0.0, b.perch.tree_id if b.perch != null else -1):
				hidden += 1
		elif landed_on != "" and b.state == Bird.State.FLYING:
			back_up = true
			break
	var share := float(hidden) / maxf(rested, 1.0)
	print("tired: rested %.1f s on %s, the target never nearer than %.1f m, out of its sight %.0f%% of the time, stamina %.2f, back up %s" % [rested / 60.0, landed_on if landed_on != "" else "-", nearest, share * 100.0, b.model.energy.stamina, back_up])
	check(landed_on != "", "tired, it comes down to rest")
	check(back_up and b.model.energy.stamina >= 0.55, "and goes back up rested (stamina %.2f)" % b.model.energy.stamina)
	check(nearest > 25.0, "resting well away from the target (never nearer than %.1f m)" % nearest)
	d.cleanup()
	d.queue_free()
	await frames(2)
