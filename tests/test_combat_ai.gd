extends TestCase
## The combat AI in the pine wood (docs/design/combat_ai.md, 8), pilot skill:
##   - against the range's racetrack target flying straight on, a rocket bird and a seeker bird each land hits, down
##     it and touch the trees rarely, 40 s in each of four pine woods (totals over the four, a few standard deviations
##     short of what each does: one match is chaotic -- over 16 woods, 2026-11-03, both landed ~5 hits a match, sd
##     1.3-1.5, downed it ~1.1-1.4 times and bonked 0.3-0.5; the hawk and the falcon, boom and zoom:
##     test_combat_boom_zoom);
##   - (against the target breaking when shot at, it beats the range's old demo shooter: test_combat_vs_demo);
##   - out of rounds, it flies home, lands on its base and rearms; it doesn't touch trees much doing all this; a base
##     it finds no way in to, it heads for without planning a route again every tick (or wandering off to plan one to
##     some other perch); sitting on its base facing the trunk or along the rail, it turns to face out before it
##     pushes off, and leaves without touching the deck, the hangar or the tree;
##   - in a long turning fight with a sparrow that breaks and turns (an AI with nothing to shoot), it banks no
##     harder than its lift holds at the speed it has: it never stalls, nor spirals down (a hawk and a sparrow,
##     the target turning either way);
##   - an owl (the ambusher) away from the racetrack target settles on a perch above where it flies, waits, drops on
##     it as it passes below and lands hits;
##   - tired, a crow comes down to rest well away from the target (on a perch, or on the ground when it can't make one
##     in reach), then goes back up rested;
##   - diving steeply with its target up behind it to one side, it pulls out and turns without stalling (both sides);
##   - resting on a perch, it stays put while an enemy flies at it nose-on (with nothing fired at it): a perched bird
##     has no break to fly.

const ARENA_SEED := 7
const SHARDS := 4   ## (the rocket bird straight on and the resting perch; the ambush and resting; rearming, leaving the
                    ## base, turning fights, pull-outs; the seeker bird straight on)
const STRAIGHT_WOODS := [1, 2, 3, 4]
const STRAIGHT := {"hits": 12, "downs": 2, "bonks": 6}   ## over the four woods (~20, ~4.5 and ~2 expected)


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	if in_shard(0):
		await _straight_on("sparrow")
		await _rest_holds()
	if in_shard(3):
		await _straight_on("crow")
	if in_shard(1):
		await _ambush()
		await _rests_out_of_sight()
		await _no_way_in()
	if in_shard(2):
		await _rearms_at_base()
		for turned in [180.0, 90.0, -90.0]:
			await _leaves_base(turned)
		for id in ["hawk", "sparrow"]:
			for dir in [1.0, -1.0]:
				await _turning_fight(id, dir)
		for id in ["sparrow", "hawk"]:
			for side in [1.0, -1.0]:
				for dive in [1.2, 2.0]:
					await _pull_out(id, side, dive)
	finish()


## `id` against the racetrack target flying straight on, 40 s in each of STRAIGHT_WOODS: hits, downs and bonks in all.
func _straight_on(id: String) -> void:
	var kind := "seekers" if CombatStyle.of(BirdProfile.by_id(id)).weapon == Launcher.Weapon.SEEKERS else "rockets"
	var tot := {"hits": 0, "downs": 0, "shots": 0, "bonks": 0}
	for s in STRAIGHT_WOODS:
		var r: Dictionary = await _versus_racetrack(id, false, false, s)
		for k in tot:
			tot[k] += r[k]
		print("%s (%s) vs the racetrack target, straight on, pine wood %d: %d hits, downed %d, %d shots, %d bonks" % [id, kind, s, r.hits, r.downs, r.shots, r.bonks])
	var n := STRAIGHT_WOODS.size()
	check(tot.hits >= int(STRAIGHT.hits), "%s lands hits on a target flying straight on (%d in %d woods)" % [id, tot.hits, n])
	check(tot.downs >= int(STRAIGHT.downs), "%s downs it (%d times in %d woods)" % [id, tot.downs, n])
	check(tot.bonks <= int(STRAIGHT.bonks), "%s touches trees rarely in the fight (%d bonks in %d woods)" % [id, tot.bonks, n])


## A bird (the combat AI, or with `demo` the range's old chase-and-trigger) against the range's racetrack target for
## 40 s in the pine wood of `arena_seed`. Returns {hits, downs, shots, bonks}.
func _versus_racetrack(id: String, evade: bool, demo: bool, arena_seed := ARENA_SEED) -> Dictionary:
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
	(me.bird as Bird).rig.visible = false   # (only the flying counts)
	(target.bird as Bird).rig.visible = false
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


## Sitting on its base turned `turned` deg from facing out (180: facing the trunk; +-90: along the rail, toward the
## hangar's end or away from it), rested and armed, with an enemy about: it turns out and pushes off clean.
func _leaves_base(turned: float) -> void:
	var layout := Pinewood.generate(ARENA_SEED)
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
	d.add_bird("crow", 1, cp, null, w[0], (w[1] as Vector3) - (w[0] as Vector3))
	var me: Dictionary = d.add_ai("crow", 0, Vector3.ZERO, Vector3.FORWARD, CombatSkill.preset("pilot"), 5, home)
	var b: Bird = me.bird
	b.facing = home.facing.rotated(Vector3.UP, deg_to_rad(turned))
	b.global_basis = b._sit_basis()
	var flew := false
	for f in 60 * 4:
		await d.step()
		flew = flew or b.state == Bird.State.FLYING
	print("on its base turned %.0f deg: flew %s, %d bonks, %.1f m out after 4 s" % [turned, flew, b.bonks, b.global_position.distance_to(home.position)])
	check(flew, "on its base turned %.0f deg from facing out: it leaves to fight" % turned)
	eq(b.bonks, 0, "and touches nothing leaving (turned %.0f deg)" % turned)
	d.cleanup()
	d.queue_free()
	await frames(2)


## Empty, with a base it can't plan the final swoop onto (a branch perch with the wood in the way): it heads that way
## and tries again now and then, rather than planning routes every tick -- to its base, then to any other perch.
func _no_way_in() -> void:
	var layout := Pinewood.generate(ARENA_SEED)
	var prof := BirdProfile.by_id("crow")
	var planner := FlightPlanner.new(layout, AIPilot.plan_clearance(prof))
	var base: Perch = null
	var start := Vector3.ZERO
	for p in layout.perches:
		if p.position.y < 8.0 or p.position.y > 20.0 or Vector2(p.position.x, p.position.z).length() > 50.0 or planner.swoop_clear(p, prof):
			continue
		start = p.position + p.facing * 20.0 + Vector3.UP * 6.0
		if layout.obstacle_distance(start) > 3.0:
			base = p
			break
	check(base != null, "a perch with no way in for a crow")
	if base == null:
		return
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: base})
	await frames(1)
	var me: Dictionary = d.add_ai("crow", 0, start, -base.facing, CombatSkill.preset("pilot"), 5)
	var l: Launcher = me.launcher
	l.ammo[l.weapon] = 0
	var b: Bird = me.bird
	var pilot: AIPilot = (me.brain as CombatBrain).pilot
	var plans := 0
	var last := pilot.replans
	var nearest := INF
	for f in 60 * 12:
		await get_tree().physics_frame
		plans += maxi(0, pilot.replans - last)
		last = pilot.replans
		if f > 60 * 6:
			nearest = minf(nearest, b.global_position.distance_to(base.position))
	print("base %d with no way in: %d route plans in 12 s, within %.1f m of it after 6 s, %d bonks" % [base.id, plans, nearest, b.bonks])
	check(plans <= 3, "no way in to its base: it doesn't plan a route every tick (%d plans)" % plans)
	check(nearest < 25.0, "and keeps to its base rather than flying off to another perch (%.1f m)" % nearest)
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
		if b.state == Bird.State.PERCHED and br.intent.mode == "ambush" and b.perch == br.amb_perch:   # (not its base, about to leave for one)
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


## `id` diving at 50 or 63 deg (`dive`: drop per metre forward), an enemy behind it, up and to one side, lining up on
## it: it breaks, and the break, the pull out of the dive and the turn share the lift -- it comes round without stalling.
func _pull_out(id: String, side: float, dive: float) -> void:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	var from := Vector3(side * 4.0, 33, 16)
	d.add_bird("crow", 1, ScriptedInput.new(), null, from, Vector3(0, 30, 0) - from)
	var me: Dictionary = d.add_ai(id, 0, Vector3(0, 30, 0), Vector3.FORWARD, CombatSkill.preset("pilot"), 4)
	(me.launcher as Launcher).ammo[(me.launcher as Launcher).weapon] = 0
	(me.launcher as Launcher).capacity[(me.launcher as Launcher).weapon] = 0
	var b: Bird = me.bird
	b.fly_from(Vector3(0, 30, 0), Vector3(0, -dive, -1.0).normalized(), b.profile.v_best)
	var stalled := 0
	var broke := false
	for f in 60 * 4:
		await get_tree().physics_frame
		stalled += 1 if b.model.stalled else 0
		broke = broke or (me.brain as CombatBrain).intent.mode == "defend"
	var what := "a %s pulling out of a %.0f deg dive, an enemy up behind to the %s" % [id, rad_to_deg(atan(dive)), "right" if side > 0 else "left"]
	print("%s: broke %s, stalled %d ticks, path angle now %.0f deg" % [what, broke, stalled, rad_to_deg(b.model.path_angle)])
	check(broke, "%s: it breaks (the enemy lines up on it)" % what)
	check(stalled == 0, "%s: never stalls (%d ticks)" % [what, stalled])
	d.cleanup()
	d.queue_free()
	await frames(2)


## A tired crow resting on a perch; an enemy flies straight at it from 30 m, nose on, and fires nothing: it stays
## perched (a bird in firing position is a reason to break in flight, not to leave a perch).
func _rest_holds() -> void:
	var layout := Pinewood.generate(ARENA_SEED)
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var perch: Perch = null
	for p in layout.perches:
		if p.position.y > 12.0 and p.position.y < 20.0 and layout.segment_clear(p.position + Vector3.UP * 0.5, p.position + Vector3(0, 1.5, 30), 0.0, p.tree_id):
			perch = p
			break
	var me: Dictionary = d.add_ai("crow", 0, Vector3.ZERO, Vector3.FORWARD, CombatSkill.preset("pilot"), 5, perch)
	var b: Bird = me.bird
	b.model.energy.stamina = 0.2
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, perch.position + Vector3(0, 1.5, 30), Vector3.FORWARD)
	(them.launcher as Launcher).ammo = {Launcher.Weapon.ROCKETS: 0, Launcher.Weapon.SEEKERS: 0}
	var left_at := -1.0
	for f in 60 * 2:
		await get_tree().physics_frame
		if b.state != Bird.State.PERCHED and left_at < 0.0:
			left_at = f / 60.0
	print("resting crow, an enemy coming at it nose-on: %s" % ("left its perch at %.2f s" % left_at if left_at >= 0.0 else "stayed perched"))
	check(left_at < 0.0, "resting, it stays on its perch while an enemy noses at it (left at %.2f s)" % left_at)
	d.cleanup()
	d.queue_free()
	await frames(2)
