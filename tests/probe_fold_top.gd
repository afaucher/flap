extends SceneTree
## Diagnostic: how far each piece of the folded wing rises above the back (the dorsal outline at the same z), per
## species, perched. Positive = above the back, as a share of the body length L.
##   & $godot --path . --headless --script res://tests/probe_fold_top.gd

const KIND_NAMES := {0: "primary", 1: "secondary", 2: "tertial", 3: "greater", 4: "lesser", 5: "alula", 6: "tail", 7: "under_covert"}


func _initialize() -> void:
	Plumage.level = 6
	for id in ["hawk", "owl", "crow", "falcon", "sparrow"]:
		var rig := BirdRig.new()
		root.add_child(rig)
		rig.build(BirdProfile.by_id(id))
		RigPoses.apply(rig, "folded", 0.0)
		var sc: float = rig._trunk.scale.x
		var top := func(p: Vector3) -> float:
			var r: PackedFloat32Array = rig.body.ring_at(p.z / sc)
			if r[1] < 1e-4:
				return -INF
			return (p.y - sc * (r[0] + r[2])) / rig._L
		var worst := {}
		var note := func(key: String, p: Vector3) -> void:
			var e: float = top.call(p)
			if not worst.has(key) or e > worst[key][0]:
				worst[key] = [e, p]
		for k in rig.feather_xforms.size():
			var kind: int = rig.feather_kinds[k]
			if kind % 100 == 6 or kind >= 100:
				continue   # (right wing only; the tail is not the wing)
			var xf: Transform3D = rig.feather_xforms[k]
			for q in BirdRig.PLAIN_PROFILE:
				for sgn in [-0.5, 0.5]:
					note.call(KIND_NAMES.get(kind % 100, str(kind)), xf * Vector3(sgn * float(q[1]), 0.0, float(q[0])))
		var names := ["arm_loft", "humerus", "forearm", "hand"]
		for k in 4:
			var mi: MeshInstance3D = rig._fairings[1][k]
			if not mi.visible or mi.mesh == null or mi.mesh.get_surface_count() == 0:
				continue
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v in verts:
				note.call(names[k], mi.transform * v)
		var j: Array = rig.wing_joints[1]
		print("%s  L %.3f  fluff %.2f  shoulder %+.3f elbow %+.3f wrist %+.3f (above back, L)" % [id, rig._L, sc, top.call(j[0]), top.call(j[1]), top.call(j[2])])
		for key in worst:
			var p: Vector3 = worst[key][1]
			print("   %-13s %+.3f  at z %+.3f (u %.2f)" % [key, worst[key][0], p.z, rig.body.u_at(p.z / sc)])
		rig.free()
	quit()
