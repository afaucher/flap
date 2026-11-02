extends TestCase
## Diagnostic: where a saddle can go. Per species and pose, the back's profile, the head, and how close the
## wings come to the dorsal strip (folded: the open strip's half angle; upstroke: the wings' height over it).


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	for id in ["falcon", "crow", "hawk", "owl"]:
		var p := BirdProfile.by_id(id)
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		var b := rig.body
		print("== %s  L %.3f  shoulder %s  hip %s  neck_base %s  head_r %.3f" % [id, b.L, b.shoulder, b.hip, b.neck_base, b.head_r])
		for z in [-0.2, -0.15, -0.1, -0.05, 0.0, 0.05, 0.1, 0.15]:
			var r := b.ring_at(z * b.L)
			print("  z %.2fL  top y %.3f  half w %.3f  centre %.3f" % [z, r[0] + r[2], r[1], r[0]])
		for pose in ["folded", "glide", "upstroke", "flap"]:
			for k in (8 if pose == "flap" else 1):
				RigPoses.apply(rig, pose, k / 16.0)
				var head: Vector3 = rig.neck_joints[3] + rig.head_offset
				var free := {}
				var over := INF
				for xf in rig.feather_xforms.slice(0, rig.feather_xforms.size() - BirdRig.TAIL_FEATHERS):
					var t := xf as Transform3D
					for u in [0.0, 0.25, 0.5, 0.75, 1.0]:
						for w in [-0.5, 0.0, 0.5]:
							var q: Vector3 = t.origin + t.basis.z * u + t.basis.x * w
							var r := b.ring_at(q.z)
							var ang := rad_to_deg(atan2(q.y - r[0], absf(q.x)))   # 90 = over the spine
							var zb := int(floor(q.z / (b.L * 0.05)))
							if b.gap(q) < b.L * 0.06:
								free[zb] = maxf(free.get(zb, -90.0), ang)
							if absf(q.x) < b.L * 0.12 and q.z > -b.L * 0.15 and q.z < b.L * 0.1:
								over = minf(over, q.y - (r[0] + r[2]))
				var s := ""
				var keys := free.keys()
				keys.sort()
				for zb in keys:
					s += " %.2f:%.0f" % [zb * 0.05, free[zb]]
				print("  %s t%d  head %s (above back %.3f)  wing over mid-back %.3f  max wing angle by z:%s" % [pose, k, head, head.y - (b.ring_at(head.z)[0] + b.ring_at(head.z)[2]), over, s])
		rig.queue_free()
	check(true)
	finish()
