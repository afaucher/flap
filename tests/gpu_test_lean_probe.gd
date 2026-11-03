extends TestCase
## LeanProbe measures a sitting bird's deepest feather tip on the GPU as BirdRig._posture does on the CPU: for every
## species, folded as it sits, over a branch across and along it, a treetop disc and the ground, at heights with tips
## inside and every tip clear -- the probe's answer (read back asynchronously) equals the deepest tip of the rig's own
## placement, plus the margin. A GPU test: runs windowed.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	BirdRig.gpu_feathers = true
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # (posed by hand, as Bird's rig is: drawn as posed)
		add_child(rig)
		rig.build(p)
		check(rig.gpu_place, p.id + ": placed on the GPU")
		rig.fold = 1.0
		rig.tail_pitch = 0.2
		var margin := rig._L * 0.01
		var at := Vector3(3.0, 5.0, -2.0)
		rig.global_transform = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.5), at)
		rig._cpu_feathers = true
		rig.apply_pose()
		rig._cpu_feathers = false
		var low := Vector3.INF   # (the lowest tip: the surfaces are laid by it, into it and clear of it)
		for f in rig.feather_xforms:
			var q: Vector3 = rig.global_transform * (f.origin + f.basis.z)
			if q.y < low.y:
				low = q
		var cases := []
		for dy in [0.01, -0.06]:
			var r := 0.04
			var c := low + Vector3(0.0, dy - r, 0.0)
			cases.append({"kind": "branch", "a": c - Vector3(1, 0, 0), "b": c + Vector3(1, 0, 0), "radius": r})
			cases.append({"kind": "branch", "a": c - Vector3(0, 0, 1), "b": c + Vector3(0, 0, 1), "radius": r})
			cases.append({"kind": "disc", "centre": low + Vector3(0.0, dy, 0.0), "radius": 0.3})
			cases.append({"kind": "ground", "centre": low + Vector3(0.0, dy, 0.0)})
		cases.append({"kind": "disc", "centre": low + Vector3(5.0, 0.5, 0.0), "radius": 0.3})   # (off to the side: none over it)
		var inside := 0
		for srf in cases:
			rig._cpu_feathers = true
			rig.apply_pose()
			rig._cpu_feathers = false
			var want := -INF
			for f in rig.feather_xforms:
				want = maxf(want, BirdRig._depth(srf, rig.global_transform * (f.origin + f.basis.z)) + margin)
			want = maxf(want, -1000.0)
			if want > 0.0:
				inside += 1
			var f0 := rig.probe_frame
			LeanProbe.request(rig, srf, margin)
			for k in 12:
				await get_tree().process_frame
				if rig.probe_frame != f0:
					break
			check(rig.probe_frame != f0, "%s %s: the probe answered" % [p.id, srf.kind])
			check(absf(rig.probe_worst - want) < 1e-5, "%s %s: the deepest tip as the rig places them (probe %.6f, rig %.6f m)" % [p.id, srf.kind, rig.probe_worst, want])
		check(inside > 0 and inside < cases.size(), "%s: tips in it and all clear both tried (%d of %d inside)" % [p.id, inside, cases.size()])
		rig.queue_free()
	BirdRig.gpu_feathers = false
	finish()
