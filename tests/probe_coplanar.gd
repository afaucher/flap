extends SceneTree
## Diagnostic: wing feather cards that lie in (nearly) the same plane and overlap -- z-fighting -- in a pose,
## per species. A pair counts when the normals agree within ~3 deg, the gap between the planes at the overlap
## is under `TOL`, and each card's centre-line passes over the other's outline.
##   & $godot --path . --headless --script res://tests/probe_coplanar.gd -- [pose]

const TOL := 0.0001   ## m, scaled by the bird (unit = L / 0.45)


func _initialize() -> void:
	Plumage.level = 6
	var args := OS.get_cmdline_user_args()
	var pose: String = args[0] if args.size() > 0 else "folded"
	for id in ["sparrow", "hawk", "owl", "crow", "falcon"]:
		var rig := BirdRig.new()
		root.add_child(rig)
		rig.build(BirdProfile.by_id(id))
		RigPoses.apply(rig, pose, 0.0)
		var n := rig.feather_xforms.size()
		var hits := 0
		for a in n:
			if rig.feather_kinds[a] >= 100 or rig.feather_kinds[a] == 6:
				continue
			var xa: Transform3D = rig.feather_xforms[a]
			var na := xa.basis.y.normalized()
			for b in range(a + 1, n):
				if rig.feather_kinds[b] >= 100 or rig.feather_kinds[b] == 6:
					continue
				var xb: Transform3D = rig.feather_xforms[b]
				var nb := xb.basis.y.normalized()
				if absf(na.dot(nb)) < 0.9985:
					continue
				# Sample b's centre line; where a sample lies over a's outline, measure its height off a's plane.
				var worst := INF
				for k in 9:
					var p := xb * Vector3(0.0, 0.0, 0.1 + 0.1 * k)
					var q := xa.affine_inverse() * p   # (a's unit space: x across +-0.5, z 0..1 along)
					if q.z > 0.05 and q.z < 0.95 and absf(q.x) < 0.45:
						worst = minf(worst, absf((p - xa.origin).dot(na)))
				if worst < TOL * rig._L / 0.45:
					hits += 1
					if hits <= 40:
						var nd := rig._defs.size()
						var da: Dictionary = rig._defs[a - nd]
						var db: Dictionary = rig._defs[b - nd]
						print("%s  %s i%d bone %d layer %.4f  ~  %s i%d bone %d layer %.4f   gap %.3f mm" % [id, _k(rig.feather_kinds[a]), da.i, da.bone, da.layer, _k(rig.feather_kinds[b]), db.i, db.bone, db.layer, worst * 1000.0])
		print("%s: %d coplanar overlapping pairs (%s)" % [id, hits, pose])
		rig.free()
	quit()


func _k(kind: int) -> String:
	return ["primary", "secondary", "tertial", "alula", "greater", "lesser", "tail", "under_covert"][kind % 100] if kind % 100 < 8 else str(kind)
