extends TestCase
## A bird falling slowly onto wood (after a bonk, say) is drawn where it is: onto a perch's branch it perches there
## (PERCHED, its drawn feet on the branch); onto a flat top that is no perch (a bar, a deck) it stands on it
## (GROUNDED, at that height, the drawn bird standing on its top, not on the ground far below, and not "on the
## ground" to the HUD); on the ground itself it stands on the ground.

const BAR_Y := 8.0
const BAR_R := 0.08


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	for case in ["perch", "bar", "ground"]:
		var layout := ArenaLayout.new()
		var top := BAR_Y + BAR_R
		if case == "perch":
			layout._add_perch(Perch.branch(0, Vector3(-1.2, top, 0), Vector3(1.2, top, 0), Vector3.FORWARD, 0, BAR_R))
		var world := Node3D.new()
		add_child(world)
		if case != "ground":
			var body := StaticBody3D.new()
			body.collision_layer = ArenaBuilder.WORLD_LAYER
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = BAR_R
			cap.height = 3.0
			cs.shape = cap
			cs.rotation_degrees = Vector3(0, 0, 90)
			body.add_child(cs)
			body.position = Vector3(0, BAR_Y, 0)
			world.add_child(body)
		else:
			var g := StaticBody3D.new()
			g.collision_layer = ArenaBuilder.WORLD_LAYER
			var gs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(20, 2, 20)
			gs.shape = box
			gs.position.y = ArenaLayout.GROUND_Y - 1.0
			g.add_child(gs)
			world.add_child(g)
			top = ArenaLayout.GROUND_Y
		var b := Bird.new()
		world.add_child(b)
		b.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
		b.global_position = Vector3(0.1, top + 0.5, 0.0)
		b.model.launch(b.global_position, Vector3(0.0, -1.0, 0.25), 0.5)   # (falling, nearly still)
		for f in 150:
			await get_tree().physics_frame
		var t := b.telemetry()
		var want := Bird.State.PERCHED if case == "perch" else Bird.State.GROUNDED
		eq(Bird.State.keys()[b.state], Bird.State.keys()[want], "%s: the bird settles %s" % [case, "perched" if case == "perch" else "standing"])
		# What is drawn: the rig's meshes end at the wood's top (feet on it), within a few cm, not metres below.
		var low := INF
		for mi in b.rig.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh != null and m.is_visible_in_tree():
				low = minf(low, (m.global_transform * m.get_aabb()).position.y)
		check(absf(low - top) < 0.05, "%s: the drawn bird stands on it (its lowest point %.2f m, the top %.2f m)" % [case, low, top])
		if case == "bar":
			check(float(t.stand_height) > 0.5, "on the bar it stands %.1f m up: the HUD doesn't say on the ground" % float(t.stand_height))
		elif case == "ground":
			check(float(t.stand_height) < 0.1, "on the ground it's on the ground (%.2f m)" % float(t.stand_height))
		world.queue_free()
		await get_tree().process_frame
	finish()
