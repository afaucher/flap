extends TestCase
## The wing root from above, glide pose: where the body's side, the arm wing's trailing edge and the innermost
## secondaries and tertials are, and the scapular cards' footprint (rig space, metres). `--bird <id>` (all by default).


func setup() -> void:
	Plumage.level = 6
	var args := OS.get_cmdline_user_args()
	var only := Boot.arg_value(args, "--bird") if args.has("--bird") else ""
	for p in BirdProfile.all():
		if only != "" and p.id != only:
			continue
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		RigPoses.apply(rig, "glide", 0.0)
		rig.apply_pose()
		var tr: Transform3D = rig._trunk.transform
		var sh: Vector3 = rig.wing_joints[0][0]
		print("%s  L %.3f  shoulder %s  trunk xf origin %s" % [p.id, rig._L, sh, tr.origin])
		print("  arm_web: %s" % [rig.arm_web[0]])
		var z0 := rig.body.front_z()
		var z1 := rig.body.back_z()
		for k in 9:
			var z := lerpf(z0, z1, k / 8.0)
			var r := rig.body.ring_at(z)
			var pw := tr * Vector3(r[1], r[0], z)
			print("  body side at u %.2f: rig x %.3f y %.3f z %.3f (top y %.3f)" % [k / 8.0, pw.x, pw.y, pw.z, (tr * Vector3(0, r[0] + r[2], z)).y])
		var inner: Array = []
		for fi in rig.feather_xforms.size():
			var kd := rig.feather_kinds[fi]
			if kd == WingShape.Kind.SECONDARY or kd == WingShape.Kind.TERTIAL:
				var xf: Transform3D = rig.feather_xforms[fi]
				inner.append([absf(xf.origin.x), xf, kd])
		inner.sort_custom(func(a, b): return a[0] < b[0])
		for e in inner.slice(0, 6):
			var xf: Transform3D = e[1]
			print("  kind %d root %s tip %s" % [e[2], xf.origin, xf * Vector3(0, 0, 1)])
		var sc := 0
		for ci in rig.card_xforms.size():
			if rig.card_tracts[ci] == "scapular":
				var cx: Transform3D = tr * rig.card_xforms[ci]
				if cx.origin.x > 0.0 and sc < 12:
					print("  scap root %s tip %s" % [cx.origin, cx * Vector3(0, 0, 1)])
					sc += 1
		rig.queue_free()
	finish()
