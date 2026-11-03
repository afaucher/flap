extends TestCase
## The bird lab's scenarios fly as described, for every species: landings from each approach end perched
## (the too-fast one never catches at speed), take-offs leave the perch and climb, the drop-off falls away,
## the ground take-off gets airborne. The lab scene itself loads, runs a scenario, leaves ghosts, steps
## while paused and switches species.

const SHARDS := 2   ## (the species split over two processes; the lab scene with the second)


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
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
	lab.queue_free()
	Engine.time_scale = 1.0
	finish()
