extends TestCase
## The rig: bone lengths survive every pose (flap, fold, IK, upstroke); the spread wing spans the model's
## span; folding puts the wrist on its flank anchor and packs the feathers in; left mirrors right; flap
## raises and lowers the tips; legs reach their targets with the ankle bent aft; the head clamps to the
## neck's range; the Skeleton3D matches the solve; a perched bird's feet are on the perch.


func setup() -> void:
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		var w := rig.shape
		var l := w.bone_lengths()
		var half := p.span * 0.5
		# Spread, level: tips at span / 2, mirrored.
		_pose(rig, 0.0, 0.0, 0.0, 0.0)
		near(_tip_x(rig, 1.0), half, half * 0.02, p.id + " right tip at span / 2")
		near(_tip_x(rig, -1.0), half, half * 0.02, p.id + " left tip at span / 2")
		for k in 4:
			var r: Vector3 = rig.wing_joints[1][k]
			var lft: Vector3 = rig.wing_joints[0][k]
			near(lft.x, -r.x, 1e-4, p.id + " left mirrors right (x)")
			near(lft.y, r.y, 1e-4, p.id + " left mirrors right (y)")
			near(lft.z, r.z, 1e-4, p.id + " left mirrors right (z)")
		# Lengths through a spread of poses.
		for pose in [[0.6, 0.0, 0.0, 0.0], [-0.5, 0.3, 0.0, 40.0], [0.1, 0.8, 10.0, 0.0], [0.0, 1.0, 0.0, 0.0], [-0.2, 0.65, -5.0, 25.0]]:
			_pose(rig, pose[0], pose[1], pose[2], pose[3])
			for i in 2:
				var j: Array = rig.wing_joints[i]
				near(j[0].distance_to(j[1]), l[0], 1e-4, "%s humerus length %s" % [p.id, pose])
				near(j[1].distance_to(j[2]), l[1], 1e-4, "%s forearm length %s" % [p.id, pose])
				near(j[2].distance_to(j[3]), l[2], 1e-4, "%s hand length %s" % [p.id, pose])
		# Flap up: tips above the shoulder; down: below.
		_pose(rig, deg_to_rad(50.0), 0.0, 0.0, 0.0)
		check(rig.wing_joints[1][3].y > rig.wing_joints[1][0].y + half * 0.3, p.id + " flap up raises the hand")
		_pose(rig, deg_to_rad(-30.0), 0.0, 0.0, 0.0)
		check(rig.wing_joints[1][3].y < rig.wing_joints[1][0].y, p.id + " flap down lowers the hand")
		# Folded: wrist on the anchor, everything packed against the body.
		_pose(rig, 0.0, 1.0, 0.0, 0.0)
		for i in 2:
			check(rig.wing_joints[i][2].distance_to(rig.fold_anchor[i]) < 1e-3, p.id + " folded wrist on its flank anchor")
			# The folded wing lies on the body: every joint on the capsule's surface, the elbow aft of the
			# shoulder and the wrist forward of it (a Z-fold, not a "V" raised above the back).
			for k in 4:
				var gap := _body_gap(rig.wing_joints[i][k], p.body_length)
				check(absf(gap) < p.body_length * 0.05, "%s folded joint %d on the body (gap %.2f L)" % [p.id, k, gap / p.body_length])
			check(rig.wing_joints[i][1].z > rig.wing_joints[i][0].z, p.id + " folded elbow aft of the shoulder")
			check(rig.wing_joints[i][2].z < rig.wing_joints[i][0].z, p.id + " folded wrist forward of the shoulder")
		for xf in rig.feather_xforms.slice(0, rig.feather_xforms.size() - BirdRig.TAIL_FEATHERS):
			var gap := _body_gap((xf as Transform3D).origin, p.body_length)
			check(gap < p.body_length * 0.08, "%s folded feather base on the body (gap %.2f L)" % [p.id, gap / p.body_length])
		check(_tip_x(rig, 1.0) < half * 0.5, "%s folded feathers stay near the body (%.2f of %.2f)" % [p.id, _tip_x(rig, 1.0), half])
		# Skeleton mirrors the solve.
		var fr := rig.skeleton.find_bone("forearm.R")
		check(rig.skeleton.get_bone_global_pose(fr).origin.distance_to(rig.wing_joints[1][1]) < 1e-4, p.id + " skeleton forearm at the elbow")
		var hl := rig.skeleton.find_bone("hand.L")
		check(rig.skeleton.get_bone_global_pose(hl).origin.distance_to(rig.wing_joints[0][2]) < 1e-4, p.id + " skeleton hand at the wrist")
		# Legs: a reachable target is reached, the ankle bends aft, lengths kept.
		var hip: Vector3 = rig._hip[1]
		rig.foot_targets[1] = hip + Vector3(0.0, -p.body_length * 0.25, -p.body_length * 0.05)
		rig.apply_pose()
		var lj: Array = rig.leg_joints[1]
		check(lj[2].distance_to(rig.foot_targets[1]) < 1e-4, p.id + " foot on its target")
		near(lj[0].distance_to(lj[1]), rig._tib, 1e-4, "tibia length")
		near(lj[1].distance_to(lj[2]), rig._tars, 1e-4, "tarsus length")
		check(lj[1].z > (lj[0].z + lj[2].z) * 0.5, p.id + " ankle bends aft")
		# Out of reach: as far as the leg goes, toward it.
		rig.foot_targets[1] = hip + Vector3(0.0, -5.0, 0.0)
		rig.apply_pose()
		near(rig.leg_joints[1][0].distance_to(rig.leg_joints[1][2]), rig._tib + rig._tars, 1e-3, p.id + " straight leg toward a far target")
		# Head: looks right when told; clamps when told to look straight back.
		rig.look_dir = Vector3.RIGHT
		rig.apply_pose()
		check((-rig.head_basis.z).x > 0.9, p.id + " head looks right")
		rig.look_dir = Vector3.BACK
		rig.apply_pose()
		var hf := -rig.head_basis.z
		check(absf(atan2(hf.x, -hf.z)) <= deg_to_rad(110.5), p.id + " head yaw clamped")
		# Solid surfaces: neighbouring tail feathers overlap even fully fanned, and neighbouring secondaries
		# overlap in the spread wing, out to 85% of their length (only the slotted wingtip may gap).
		for spread in [0.3, 1.0]:
			rig.tail_spread = spread
			_pose(rig, 0.0, 0.0, 0.0, 0.0)
			var gap := _worst_gap(rig, 6)
			check(gap <= 0.0, "%s tail fan solid at spread %.1f (worst gap %.1f mm)" % [p.id, spread, gap * 1000.0])
		rig.tail_spread = 0.2
		_pose(rig, 0.0, 0.0, 0.0, 0.0)
		var sgap := _worst_gap(rig, WingShape.Kind.SECONDARY)
		check(sgap <= 0.0, "%s secondaries overlap (worst gap %.1f mm)" % [p.id, sgap * 1000.0])
		var tail_w: float = rig.feather_xforms[rig.feather_xforms.size() - 1].basis.x.length()
		var tail_l: float = rig.feather_xforms[rig.feather_xforms.size() - 1].basis.z.length()
		near(tail_w / tail_l, BirdRig.TAIL_WIDTH, 1e-4, p.id + " tail feathers are a fifth as wide as long")
		# Every feather transform is finite.
		var ok := true
		for t in rig.feather_xforms:
			ok = ok and t.origin.is_finite() and t.basis.x.is_finite() and t.basis.z.is_finite()
		check(ok, p.id + " finite feathers")
		eq(rig.feather_xforms.size(), rig._plain_count + rig._emarg_count, p.id + " every feather placed")
		check(rig.feather_material == null, p.id + " plain feathers by default (the shader is parked)")
		# The parked shader still builds and gets its species look.
		BirdRig.plain_feathers = false
		var shaded := BirdRig.new()
		add_child(shaded)
		shaded.build(p)
		BirdRig.plain_feathers = true
		check(shaded.feather_material != null and shaded.feather_material.shader == BirdRig.FEATHER_SHADER, p.id + " shader path builds")
		check(shaded._plain.use_custom_data, p.id + " per-feather kind and seed reach the shader")
		for key in BirdRig.FEATHER_LOOK[p.id]:
			near(float(shaded.feather_material.get_shader_parameter(key)), float(BirdRig.FEATHER_LOOK[p.id][key]), 1e-6, "%s look: %s" % [p.id, key])
		shaded.queue_free()
		rig.queue_free()

	# A perched bird's feet are on its perch.
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	var perch := layout.start_perch()
	b.perch_at(perch)
	await frames(30)
	for i in 2:
		var foot_world: Vector3 = b.rig.global_transform * (b.rig.leg_joints[i][2] as Vector3)
		check(foot_world.distance_to(perch.position) < 0.04, "perched foot %d on the perch (%.3f m)" % [i, foot_world.distance_to(perch.position)])
	check(b.rig.fold > 0.95, "perched wings folded")
	finish()


func _pose(rig: BirdRig, flap: float, fold: float, sweep: float, hand_lift: float) -> void:
	rig.flap = flap
	rig.fold = fold
	rig.sweep = sweep
	rig.hand_lift = hand_lift
	rig.twist = 0.0
	rig.slot = 0.0
	rig.apply_pose()


## The widest gap between neighbouring feathers of `kind` (right wing / tail), measured between their edges at
## 85% of their length; negative = they overlap.
func _worst_gap(rig: BirdRig, kind: int) -> float:
	var picks: Array[Transform3D] = []
	for k in rig.feather_xforms.size():
		if rig.feather_kinds[k] == kind:
			picks.append(rig.feather_xforms[k])
	var worst := -INF
	for k in range(1, picks.size()):
		var a: Transform3D = picks[k - 1]
		var b: Transform3D = picks[k]
		var pa := a.origin + a.basis.z * 0.85
		var pb := b.origin + b.basis.z * 0.85
		var half := 0.9 * 0.5   # the outline's width at 85% of the length, halved
		var g := pa.distance_to(pb) - (a.basis.x.length() + b.basis.x.length()) * half
		worst = maxf(worst, g)
	return worst


## Distance of a rig-space point outside the body capsule (radius 0.15 L along Z, 0.62 L long); - = inside.
func _body_gap(pt: Vector3, length: float) -> float:
	var half := length * (0.31 - 0.15)
	return pt.distance_to(Vector3(0.0, 0.0, clampf(pt.z, -half, half))) - length * 0.15


## The furthest feather tip on one side (x * side), from the rig's feather transforms.
func _tip_x(rig: BirdRig, side: float) -> float:
	var m := 0.0
	for t in rig.feather_xforms:
		m = maxf(m, (t.origin + t.basis.z).x * side)
	return m
