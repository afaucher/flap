extends TestCase
## The bird lab's scenarios fly as described, for every species: landings from each approach end perched
## (the too-fast one never catches at speed), take-offs leave the perch and climb, the drop-off falls away,
## the ground take-off gets airborne. The lab scene itself loads, runs a scenario, leaves ghosts, steps
## while paused and switches species.
## Combat scenarios (LabFight), for a crow and a hawk: the gun burst fires from the lab bird's pods and chips the bird
## ahead; the rocket knocks feathers out of the lab bird, a burst beside it; the seeker locks (no sooner than
## LOCK_TIME) then launches and hits; the downed bird flutters down (its wings flailing, as drawn) and comes down on the ground, and
## sits there, no bonk -- with CombatWorld.down_flutter off, it only glides down, stunned; respawned onto its base mid-fall,
## the flutter is over (it sits there, its wings' lift whole); on the base the empty pods refill
## and the lost feathers grow back, after RESTOCK_TIME and not before. The lab scene opens on one with its fight.

const SHARDS := 3   ## (the species split over two processes, the lab scene with the second; the combat scenes a third)


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(2):
		await _fights()
	if not in_shard(0) and not in_shard(1):
		finish()
		return
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var perch: Perch = layout.perches[0]
	var all := BirdProfile.all()
	for k in all.size():
		if not in_shard(k % SHARDS):
			continue
		var p: BirdProfile = all[k]
		var row := []
		for s in LabScenarios.LIST:
			if LabScenarios.is_pose(s):
				continue
			var b := Bird.new()
			add_child(b)
			b.setup(p, layout, null)
			b.arena = arena
			b.rig.visible = false   # (only the flight is measured here; skip the feather maths)
			LabScenarios.start(s, b, layout)
			var start_y := b.global_position.y
			var perched_at := -1.0
			var caught_speed := -1.0
			var top := start_y
			var left := false
			var low := INF
			var kind: String = s.kind
			for i in 600:
				var was: int = b.state
				await frames(1)
				top = maxf(top, b.global_position.y)
				left = left or b.state == Bird.State.FLYING
				if left:
					low = minf(low, b.global_position.y)
				if was == Bird.State.FLYING and b.state == Bird.State.LANDING:
					caught_speed = b.model.velocity.length()
				if kind == "land" and b.state == Bird.State.PERCHED:
					perched_at = i / 60.0
					break
				if kind != "land" and i > 300:
					break
			var outcome := "perched %.1fs" % perched_at if perched_at >= 0.0 else "%s top %.1f" % [Bird.State.keys()[b.state], top]
			row.append("%s: %s" % [s.id, outcome])
			if kind == "land":
				if s.get("bleed", true):
					check(perched_at >= 0.0, "%s lands from %s" % [p.id, s.id])
				check(caught_speed <= p.grab_speed_max + 0.01, "%s %s never caught faster than its catch speed" % [p.id, s.id])
			elif kind == "takeoff":
				check(left and b.state == Bird.State.FLYING and low > 1.0, "%s takes off and stays up (lowest %.1f m)" % [p.id, low])
			elif kind == "drop":
				check(left, p.id + " drops off the perch")
			elif kind == "ground":
				check(left and top > 1.0, "%s gets off the ground (top %.1f)" % [p.id, top])
			b.queue_free()
			await frames(1)
		print(p.id, "  ", ", ".join(row))
	if not in_shard(1):
		finish()
		return
	# The scene: loads, runs, pauses, steps, switches.
	var lab: Node = load("res://scenes/bird_lab.tscn").instantiate()
	add_child(lab)
	await frames(10)
	check(lab.bird == null and lab.pose_rig != null, "lab opens on a pose")
	lab.speed = 1.0
	lab._pick_scenario(LabScenarios.LIST.find(LabScenarios.by_id("land_level")))
	lab._set_onion(true)
	await frames(60)
	check(lab.bird != null and lab.bird.state != Bird.State.PERCHED, "lab flies the landing")
	check(lab._ghosts.size() > 3, "onion-skin ghosts left along the way")
	get_tree().paused = true
	var t0: float = lab.sim_t
	await lab.step()
	check(get_tree().paused and lab.sim_t > t0, "a step advances one tick and stays paused")
	get_tree().paused = false
	lab._pick_bird(3)
	await frames(5)
	check(lab.bird.profile.id == BirdProfile.IDS[3], "switching species restarts with that bird")
	lab._pick_scenario(LabScenarios.LIST.find(LabScenarios.by_id("fight_gun")))
	await frames(90)
	check(lab.fight != null and lab.fight.shooter.shots > 0, "the lab opens a combat scene with its fight (%d rounds)" % (lab.fight.shooter.shots if lab.fight != null else -1))
	lab.queue_free()
	Engine.time_scale = 1.0
	finish()


func _fights() -> void:
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	for id in ["crow", "hawk"]:
		var p := BirdProfile.by_id(id)
		for s in LabScenarios.LIST:
			if s.get("kind", "") != "fight":
				continue
			var b := Bird.new()
			add_child(b)
			b.setup(p, layout, null)
			b.arena = arena
			LabScenarios.start(s, b, layout)
			var f := LabFight.start(s, b, layout, self, arena)
			var what := "%s, %s" % [id, s.id]
			var locked_at := -1.0
			var hit_at := -1.0
			var down_at := -1.0
			var down_y := 0.0
			var fell := 0.0
			var low := INF
			var flail := Vector2(INF, -INF)   # (the drawn wings' flap angle, its range while tumbling)
			var full_at := -1.0
			var seeker_flew := false
			for i in 270:
				await frames(1)
				var t := i / 60.0
				if f.shooter.locked() and locked_at < 0.0:
					locked_at = t
				if f.knocked_out() > 0 and hit_at < 0.0:
					hit_at = t
				for pr in f.world.projectiles:
					seeker_flew = seeker_flew or (pr as Projectile).kind == Projectile.Kind.SEEKER
				if f.target != null and f.target.is_down():
					if down_at < 0.0:
						down_at = t
						down_y = f.target.global_position.y
					low = minf(low, f.target.global_position.y)
					fell = down_y - low
					if f.target.tumbling():
						flail = Vector2(minf(flail.x, f.target.rig.flap), maxf(flail.y, f.target.rig.flap))
				if f.what == "rearm" and f.shooter.full() and full_at < 0.0:
					full_at = t
			var gun := Launcher.Weapon.GUN
			match f.what:
				"gun":
					check(f.shooter.carried(gun) > 0 and f.shooter.shots >= 8, "%s: the lab bird fires a burst from its gun pods (%d rounds)" % [what, f.shooter.shots])
					check(f.knocked_out() >= 1 and not f.target.is_down(), "%s: and chips the bird ahead (%d feathers out)" % [what, f.knocked_out()])
				"rocket":
					check(f.knocked_out() >= 2, "%s: the rocket knocks feathers out of the lab bird (%d)" % [what, f.knocked_out()])
				"seeker":
					check(locked_at >= LabFight.FIRE_AT + Launcher.LOCK_TIME - 0.05 or (locked_at >= Launcher.LOCK_TIME - 0.05), "%s: it locks, no sooner than LOCK_TIME (%.2f s)" % [what, locked_at])
					check(seeker_flew and hit_at > locked_at and locked_at > 0.0, "%s: then launches, and the seeker hits (at %.2f s)" % [what, hit_at])
				"downed":
					check(f.target.is_down(), "%s: the burst downs the lab bird" % what)
					check(fell > 5.0, "%s: and flutters down out of the fight (%.1f m)" % [what, fell])
					check(rad_to_deg(flail.y - flail.x) > 40.0, "%s: its wings flailing as it goes (%.0f deg of flap)" % [what, rad_to_deg(flail.y - flail.x)])
					check(not f.target.tumbling() and f.target.state == Bird.State.GROUNDED and f.target.bonks == 0, "%s: then comes down on the ground and sits there (%s, %d bonks)" % [what, Bird.State.keys()[f.target.state], f.target.bonks])
				"rearm":
					check(full_at >= Launcher.RESTOCK_TIME - 0.05, "%s: on the base, rearmed and mended after %.1f s (%.2f s)" % [what, Launcher.RESTOCK_TIME, full_at])
			f.free_all()
			b.queue_free()
			await frames(2)
		# Without the flutter (the range, for now): downed, it only glides on, stunned.
		var g := Bird.new()
		add_child(g)
		g.setup(p, layout, null)
		g.arena = arena
		var sd: Dictionary = LabScenarios.by_id("fight_downed")
		LabScenarios.start(sd, g, layout)
		var gf := LabFight.start(sd, g, layout, self, arena)
		gf.world.down_flutter = false
		var g_y := INF
		var g_low := INF
		for i in 240:
			await frames(1)
			if g.is_down():
				g_y = minf(g_y, g.global_position.y) if g_y == INF else g_y
				g_low = minf(g_low, g.global_position.y)
		check(not g.tumbling() and g_y - g_low < 3.0, "%s, down_flutter off: downed, it only glides on (%.1f m)" % [id, g_y - g_low])
		gf.free_all()
		g.queue_free()
		await frames(2)
		# Respawned onto its base while still fluttering down: the flutter ends there.
		var r := Bird.new()
		add_child(r)
		r.setup(p, layout, null)
		r.arena = arena
		LabScenarios.start(sd, r, layout)
		var rf := LabFight.start(sd, r, layout, self, arena)
		rf.world.bases = {1: layout.perches[0]}
		var mid := false
		for i in 120:
			await frames(1)
			if r.tumbling() and r.global_position.y < LabFight.FLY_Y - 2.0:
				mid = true
				break
		check(mid, "%s: (fluttering down, mid-fall)" % id)
		rf.world.respawn(r)
		await frames(3)
		check(not r.tumbling() and is_equal_approx(r.model.lift_scale, 1.0) and r.state == Bird.State.PERCHED, "%s: respawned onto its base mid-fall, the flutter is over (%s, lift x%.1f)" % [id, Bird.State.keys()[r.state], r.model.lift_scale])
		rf.free_all()
		r.queue_free()
		await frames(2)
