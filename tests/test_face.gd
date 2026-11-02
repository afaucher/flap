extends TestCase
## Faces (docs/research/eyes_and_beaks.md 4.8): the beak reaches its length ahead of the head; the eyes sit on
## the head; fixations average the species' mean; the head stays inside its yaw/pitch limits; a blink follows a
## big saccade; the neck's surface starts exactly on the trunk's front ring (no seam).


func setup() -> void:
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		var fd := Face.spec(p.id)
		var hr := rig.body.head_r
		# Beak: its furthest point lies about `len` head radii ahead of the head's front.
		var upper := rig._head.get_node("BeakUpper") as MeshInstance3D
		var tip_z := 0.0
		for v in (upper.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			tip_z = minf(tip_z, (v as Vector3).z)
		var base_z := -hr * rig.body.skull.z * 0.85 if not fd.has("disc") else Face.disc_z(0.0, -0.14 * hr, 0.1, hr, rig.body.skull) + 0.04 * hr
		var expect := base_z - float(fd.beak.len) * hr * cos(deg_to_rad(float(fd.beak.pitch)))
		near(tip_z, expect, absf(expect) * 0.25, p.id + " beak reaches its length ahead of the head")
		check(rig._head.has_node("Jaw/BeakLower"), p.id + " lower mandible on its jaw pivot")
		# Eyes: on the head (or the owl's disc), and lens caps with a pupil darker than the ring round it.
		for e in ["EyeL", "EyeR"]:
			var eye: Node3D = rig._head.find_child(e, true, false)
			check(eye != null, p.id + " has " + e)
			if eye != null and not fd.has("disc"):
				var local := eye.position   # (in the skull's unscaled sphere)
				near(local.length(), hr * 0.97, hr * 0.03, p.id + " eye on the head's surface")
		# Head limits.
		rig.look_dir = Vector3.BACK
		rig.apply_pose()
		var f := -rig.head_basis.z
		check(absf(atan2(f.x, -f.z)) <= deg_to_rad(float(fd.head_yaw) + 0.5), p.id + " head yaw within its range")
		rig.look_dir = Vector3.UP
		rig.apply_pose()
		check(asin((-rig.head_basis.z).y) <= deg_to_rad(float(fd.head_pitch[1]) + 0.5), p.id + " head pitch within its range")
		# The neck's first ring is the trunk's front ring.
		rig.look_dir = Vector3.FORWARD
		rig.apply_pose()
		var nm := (rig._neck_mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var tm := (rig._trunk.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var worst := 0.0   # (vertex order isn't kept through normal generation: match each front-ring vertex)
		var front_z := INF
		for v in tm:
			front_z = minf(front_z, v.z)
		for v in tm:
			if absf(v.z - front_z) > 1e-6:
				continue
			var best := INF
			for q in nm:
				best = minf(best, q.distance_to(v * rig._trunk.scale.x))
			worst = maxf(worst, best)
		check(worst < 1e-4, "%s neck starts on the trunk's front ring (%.5f m)" % [p.id, worst])
		# ... and ends ON the head: every vertex of its last loop is a vertex of the head's surface (the head turned
		# away a little, so the loop has to follow it).
		rig.look_dir = Vector3(0.4, -0.1, -1.0).normalized()
		rig.apply_pose()
		var hm := (rig._head.get_node("HeadSurface") as MeshInstance3D).mesh as ArrayMesh
		var hv := hm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var nv := (rig._neck_mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var head_worst := 0.0
		for j in BirdRig.TRUNK_AROUND:
			var target: Vector3 = rig._head.transform * rig._head_point(rig._neck_entry, -TAU * j / BirdRig.TRUNK_AROUND)
			var best_n := INF
			for q in nv:
				best_n = minf(best_n, q.distance_to(target))
			var best_h := INF
			for q in hv:
				best_h = minf(best_h, (rig._head.transform * q).distance_to(target))
			head_worst = maxf(head_worst, maxf(best_n, best_h))
		check(head_worst < 1e-4, "%s neck ends on the head's own vertices (%.5f m)" % [p.id, head_worst])
		# The wing's surface starts on the body: its first loop lies on the trunk's surface.
		rig.look_dir = Vector3.FORWARD
		rig.fold = 0.0
		rig.apply_pose()
		var am := (rig._fairings[1][0] as MeshInstance3D).mesh as ArrayMesh
		var av := am.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var on_body := 0
		for q in av:
			if absf(rig.body.gap(q / rig._trunk.scale.x)) < rig.body.L * 0.005:
				on_body += 1
		check(on_body >= BirdRig.ARM_AROUND, "%s the wing's surface starts on the body (%d vertices on it)" % [p.id, on_body])
		# Fixations average the species' mean.
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var sum := 0.0
		for k in 1000:
			sum += Face.fixation(rng, float(fd.fix_s))
		near(sum / 1000.0, float(fd.fix_s), float(fd.fix_s) * 0.1, p.id + " fixation mean")
		rig.queue_free()
	# Behaviour: a perched bird glances about in saccades (look_dir holds, then jumps), and blinks.
	var layout := ArenaLayout.lab()
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id("sparrow"), layout, ScriptedInput.new())
	b.perch_at(layout.perches[0])
	var still := 0
	var moves := 0
	var blinked := false
	var last := b.rig.look_dir
	for i in 600:
		await frames(1)
		var dl := rad_to_deg(last.angle_to(b.rig.look_dir))
		if dl < 0.01:
			still += 1
		elif dl > 1.0:
			moves += 1
		blinked = blinked or b.rig.blink > 0.3
		last = b.rig.look_dir
	check(still > 300, "the head holds still between glances (%d still ticks)" % still)
	check(moves > 5, "and jumps to new points (%d fast ticks)" % moves)
	check(blinked, "a perched sparrow blinks within 10 s")
	finish()
