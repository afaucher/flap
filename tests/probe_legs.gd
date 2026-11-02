extends TestCase
## Diagnostic (run by name): what the detailed legs cost per bird -- vertex and triangle counts, and the CPU time of
## a full rebuild (both legs, every frame the legs move: a landing, a take-off, a turn on the perch) against
## apply_pose with the legs cached (a bird holding still, or flying straight) and with the capsule legs.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var was := LegRig.enabled
	for id: String in ["sparrow", "crow", "hawk", "falcon", "owl"]:
		var line := id
		for detail: bool in [false, true]:
			LegRig.enabled = detail
			var rig := BirdRig.new()
			add_child(rig)
			rig.build(BirdProfile.by_id(id))
			RigPoses.apply(rig, "folded", 0.0)
			var n := 60
			var t0 := Time.get_ticks_usec()
			for k in n:
				rig.apply_pose()
			var cached := (Time.get_ticks_usec() - t0) / float(n) / 1000.0
			line += "  | %s: apply_pose %.2f ms" % ["detail" if detail else "capsules", cached]
			if detail:
				var lr := rig.legs
				var verts := 0
				var tris := 0
				for i in 2:
					for mi in [lr.feather_mi[i], lr.skin_mi[i]]:
						var m := (mi as MeshInstance3D).mesh as ArrayMesh
						if m.get_surface_count() > 0:
							verts += (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
							tris += (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				t0 = Time.get_ticks_usec()
				for k in n:   # (every frame a moving leg: the foot target shifts, so both legs rebuild)
					rig.foot_targets[0] += Vector3(0.0, 0.0, 1e-4 * (1 if k % 2 == 0 else -1))
					rig.foot_targets[1] += Vector3(0.0, 0.0, 1e-4 * (1 if k % 2 == 0 else -1))
					rig.toe_grip = 1.0 - 0.001 * (k % 2)
					rig.apply_pose()
				var moving := (Time.get_ticks_usec() - t0) / float(n) / 1000.0
				line += ", legs moving %.2f ms; %d vertices, %d triangles, 4 draw calls" % [moving, verts, tris]
			rig.queue_free()
		print(line)
	LegRig.enabled = was
	finish()
