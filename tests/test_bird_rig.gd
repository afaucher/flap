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
		# One stacking order: no two overlapping feathers in one plane (z-fighting), either wing, spread.
		for i in 2:
			var ties := _ties(rig, 100 if i == 0 else 0)
			check(ties == 0, "%s spread wing (side %d): no overlapping feathers in one plane (%d pairs)" % [p.id, i, ties])
		# Lengths through a spread of poses.
		for pose in [[0.6, 0.0, 0.0, 0.0], [-0.5, 0.3, 0.0, 40.0], [0.1, 0.8, 10.0, 0.0], [0.0, 1.0, 0.0, 0.0], [-0.2, 0.65, -5.0, 25.0]]:
			_pose(rig, pose[0], pose[1], pose[2], pose[3])
			for i in 2:
				var j: Array = rig.wing_joints[i]
				near(j[0].distance_to(j[1]), l[0], 1e-4, "%s humerus length %s" % [p.id, pose])
				near(j[1].distance_to(j[2]), l[1], 1e-4, "%s forearm length %s" % [p.id, pose])
				near(j[2].distance_to(j[3]), l[2], 1e-4, "%s hand length %s" % [p.id, pose])
		# Wing thickness: the propatagium's leading edge runs straight from shoulder to wrist and reaches back
		# past the elbow; it slackens away folded. Each limb piece thins from root to tip (muscle near the
		# body, tendon and bone outward), and the arm is thicker than the hand.
		_pose(rig, 0.0, 0.0, 0.0, 0.0)
		var web: Dictionary = rig.arm_web[1]
		var wj: Array = rig.wing_joints[1]
		check(not web.is_empty() and (rig._fairings[1][0] as MeshInstance3D).visible, p.id + " arm wing surface spread")
		check((web.from as Vector3).distance_to(wj[0]) < 1e-4 and (web.to as Vector3).distance_to(wj[2]) < 1e-4, p.id + " its leading edge runs shoulder to wrist")
		check(float(web.chord_at_elbow) > float(web.depth) + 0.01, "%s it reaches back over the elbow (%.3f > %.3f)" % [p.id, web.chord_at_elbow, web.depth])
		_pose(rig, 0.0, 1.0, 0.0, 0.0)
		check(not (rig._fairings[1][0] as MeshInstance3D).visible, p.id + " the web slackens away when folded")
		for k in range(1, 4):
			check(BirdRig.limb_section(k, 0.0).y > BirdRig.limb_section(k, 1.0).y, "limb %d thins outward" % k)
		check(BirdRig.limb_section(1, 0.35).y > BirdRig.limb_section(3, 0.0).y * 2.0, "the arm is far thicker than the hand")
		check(BirdRig.limb_section(2, 0.15).y > BirdRig.limb_section(2, 0.9).y * 1.8, "forearm muscle by the elbow, tendon to the wrist")
		# The alula is rooted on the thumb: its base on the hand's leading edge (over the small coverts there),
		# deployed or not.
		for al in [0.0, 1.0]:
			rig.alula = al
			_pose(rig, 0.0, 0.0, 0.0, 0.0)
			for k in rig.feather_xforms.size():
				if rig.feather_kinds[k] == WingShape.Kind.ALULA:
					var o: Vector3 = (rig.feather_xforms[k] as Transform3D).origin
					var bone_d := o.distance_to(Geometry3D.get_closest_point_to_segment(o, rig.wing_joints[1][2], rig.wing_joints[1][3]))
					check(bone_d <= w.root_chord() * BirdRig.LIMB[3].t[0] * 0.5 + 0.006 * p.body_length / 0.45, "%s alula touches the hand (alula %.0f, %.1f mm)" % [p.id, al, bone_d * 1000.0])
		rig.alula = 0.0
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
				var gap := rig.body.gap(rig.wing_joints[i][k])
				check(absf(gap) < p.body_length * 0.05, "%s folded joint %d on the body (gap %.2f L)" % [p.id, k, gap / p.body_length])
			check(rig.wing_joints[i][1].z > rig.wing_joints[i][0].z, p.id + " folded elbow aft of the shoulder")
			check(rig.wing_joints[i][2].z < rig.wing_joints[i][0].z, p.id + " folded wrist forward of the shoulder")
			# The arm's pieces (humerus, forearm, hand) tuck into the fold: none rises above the back (the dorsal
			# outline at the same z), and each still shows its upper face outward, not its pale underside.
			var s: float = BirdRig.SIDES[i]
			var above := -INF
			for k in range(1, 4):
				var mi: MeshInstance3D = rig._fairings[i][k]
				if not mi.visible:
					continue
				for v in (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					var pt: Vector3 = mi.transform * v
					var ring: PackedFloat32Array = rig.body.ring_at(pt.z)
					if ring[1] > 1e-4:
						above = maxf(above, pt.y - (ring[0] + ring[2]))
				check(mi.transform.basis.y.x * s > 0.0, "%s folded limb piece %d (side %d) shows its upper face outward" % [p.id, k, i])
			check(above < p.body_length * 0.01, "%s folded arm pieces below the back (side %d: %.3f L above)" % [p.id, i, above / p.body_length])
			# Folded, the feathers lie in one ordered stack: no two overlapping cards tie in depth or cross (z-fighting).
			var ties := _ties(rig, 100 if i == 0 else 0)
			check(ties == 0, "%s folded wing (side %d): no overlapping feathers in one plane (%d pairs)" % [p.id, i, ties])
		# Every folded wing feather starts on the body, points aft (not fanned out sideways or up like a
		# propeller) and ends inside the body's silhouette, widened a little for the wingtips over the tail.
		var L := p.body_length
		var worst_dir := 1.0
		var worst_tip := 0.0
		for xf in rig.feather_xforms.slice(0, rig.feather_xforms.size() - BirdRig.TAIL_FEATHERS):
			var f: Transform3D = xf
			var gap := rig.body.gap(f.origin)
			check(gap < L * 0.08, "%s folded feather base on the body (gap %.2f L)" % [p.id, gap / L])
			worst_dir = minf(worst_dir, f.basis.z.normalized().z)
			var tip := f.origin + f.basis.z
			worst_tip = maxf(worst_tip, maxf(absf(tip.x) / (L * 0.15), absf(tip.y) / (L * 0.15)))
		check(worst_dir > 0.7, "%s folded feathers point aft (worst %.2f)" % [p.id, worst_dir])
		check(worst_tip < 1.6, "%s folded feather tips inside the body outline (worst %.2f radii)" % [p.id, worst_tip])
		check(_tip_x(rig, 1.0) < half * 0.5, "%s folded feathers stay near the body (%.2f of %.2f)" % [p.id, _tip_x(rig, 1.0), half])
		# Skeleton mirrors the solve.
		var fr := rig.skeleton.find_bone("forearm.R")
		check(rig.skeleton.get_bone_global_pose(fr).origin.distance_to(rig.wing_joints[1][1]) < 1e-4, p.id + " skeleton forearm at the elbow")
		var hl := rig.skeleton.find_bone("hand.L")
		check(rig.skeleton.get_bone_global_pose(hl).origin.distance_to(rig.wing_joints[0][2]) < 1e-4, p.id + " skeleton hand at the wrist")
		# Legs: hip -> knee (femur) -> ankle -> foot. A reachable target is reached, the ankle bends aft, lengths
		# kept, the knee hidden inside the body.
		var hip: Vector3 = rig._hip[1]
		rig.foot_targets[1] = hip + Vector3(0.0, -p.body_length * 0.3, -p.body_length * 0.05)
		rig.apply_pose()
		var lj: Array = rig.leg_joints[1]
		var sole := rig.legs.sole_height() if rig.legs != null else 0.0   # (the detailed foot's pad stands on the target)
		var want: Vector3 = rig.foot_targets[1] + (rig._world_frame()[0] as Vector3) * sole
		check(lj[3].distance_to(want) < 1e-4, p.id + " foot on its target")
		near(lj[0].distance_to(lj[1]), rig.body.femur, 1e-4, "femur length")
		near(lj[1].distance_to(lj[2]), rig._tib, 1e-4, "tibiotarsus length")
		near(lj[2].distance_to(lj[3]), rig._tars, 1e-4, "tarsus length")
		check(lj[2].z > (lj[1].z + lj[3].z) * 0.5, p.id + " ankle bends aft")
		check(rig.body.gap(lj[1]) < 0.0, "%s knee inside the body (gap %.3f m)" % [p.id, rig.body.gap(lj[1])])
		check(rig.body.gap(lj[0]) < 0.0, p.id + " hip inside the body")
		var fm := rig.skeleton.find_bone("tibia.R")
		check(rig.skeleton.get_bone_global_pose(fm).origin.distance_to(lj[1]) < 1e-4, p.id + " skeleton tibia at the knee")
		# Out of reach: as far as the leg goes, toward it.
		rig.foot_targets[1] = hip + Vector3(0.0, -5.0, 0.0)
		rig.apply_pose()
		near(rig.leg_joints[1][1].distance_to(rig.leg_joints[1][3]), rig._tib + rig._tars, 1e-3, p.id + " straight leg toward a far target")
		# The shell: fitted to the landmarks, about the old capsule's volume (the silhouette doesn't jump).
		var bs := rig.body
		var cap := PI * pow(p.body_length * 0.15, 2.0) * p.body_length * 0.32 + 4.0 / 3.0 * PI * pow(p.body_length * 0.15, 3.0)
		check(absf(bs.volume() / cap - 1.0) < 0.12, "%s shell volume %.2f of the old capsule's" % [p.id, bs.volume() / cap])
		check(absf(bs.gap(rig.wing_joints[1][0])) < p.body_length * 0.02, p.id + " shoulder on the shell")
		check(bs.gap(rig._tail_base) < p.body_length * 0.02, p.id + " tail base at the shell")
		check(bs.gap(Vector3(0, 0, 0)) < 0.0 and bs.gap(Vector3(0, p.body_length, 0)) > 0.0, p.id + " gap sign")
		# Neck: three bones keep their lengths from retracted to reaching; the head rides on the end; reaching
		# puts the head further out and further forward.
		var heads: Array = []
		for ext in [0.0, 0.5, 1.0]:
			rig.neck_ext = ext
			rig.apply_pose()
			var nj: Array = rig.neck_joints
			for k in 3:
				near(nj[k].distance_to(nj[k + 1]), bs.neck_bone, 1e-4, "%s neck bone %d length at %.1f" % [p.id, k, ext])
			check(rig._head.position.distance_to(nj[3]) < 1e-5, p.id + " head on the neck")
			heads.append(nj[3])
		check(heads[2].distance_to(bs.neck_base) > heads[0].distance_to(bs.neck_base) + p.body_length * 0.05, p.id + " reaching neck is longer")
		check(heads[2].z < heads[0].z, p.id + " reaching neck puts the head forward")
		check(rig.body.gap(rig.neck_joints[0]) < 0.0, p.id + " neck leaves from inside the trunk")
		# The neck bones inside the drawn neck: their inner joints near its centreline, retracted and reaching, the
		# head turned up, down and aside (the bones once folded their own S out through the feathers).
		var neck_r: float = rig.body.ring_at(rig.body.collar_z)[1]
		for ext in [0.0, 1.0]:
			for look: Vector3 in [Vector3.FORWARD, Vector3(0, 0.8, -0.6), Vector3(0, -0.6, -0.8), Vector3(0.8, 0, -0.6)]:
				rig.neck_ext = ext
				rig.look_dir = look.normalized()
				rig.apply_pose()
				var cv := rig._neck_curve()
				for k in [1, 2]:
					var far := INF
					for u in 41:
						far = minf(far, (rig.neck_joints[k] as Vector3).distance_to(BirdRig._bezier(cv[0], cv[1], cv[2], cv[3], u / 40.0)))
					check(far < neck_r * 0.75, "%s neck joint %d inside the drawn neck (ext %.0f, look %s: %.4f m off its centreline, neck %.4f)" % [p.id, k, ext, look, far, neck_r])
		rig.look_dir = Vector3.FORWARD
		# Told to look behind and below (the horizon, to a body pitched past vertical), the head pitches down to its
		# limit; it doesn't swing round to look backward.
		rig.look_dir = Vector3(0.0, -0.6, 0.8)
		rig.apply_pose()
		check((rig.head_basis * Vector3.FORWARD).z < 0.0, p.id + " behind and below: the head pitches down, not round")
		rig.look_dir = Vector3.FORWARD
		var hb := rig.skeleton.find_bone("head")
		check(rig.skeleton.get_bone_global_pose(hb).origin.distance_to(rig.neck_joints[3]) < 1e-4, p.id + " skeleton head at the atlas")
		rig.neck_ext = 0.3
		# Head: looks right when told; clamps when told to look straight back.
		rig.look_dir = Vector3.RIGHT
		rig.apply_pose()
		check((-rig.head_basis.z).x > 0.9, p.id + " head looks right")
		rig.look_dir = Vector3.BACK
		rig.apply_pose()
		var hf := -rig.head_basis.z
		check(absf(atan2(hf.x, -hf.z)) <= deg_to_rad(rig.body.head_yaw + 0.5), p.id + " head yaw clamped")
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
		# Drawn width: the instance's width scale times the mesh's own outline (once drawn at half width
		# because the outline peaked at 0.5 instead of 1).
		var tail_w: float = rig.feather_xforms[rig.feather_xforms.size() - 1].basis.x.length() * _mesh_width(rig._plain.mesh, 0.5)
		var tail_l: float = rig.feather_xforms[rig.feather_xforms.size() - 1].basis.z.length()
		near(tail_w / tail_l, BirdRig.TAIL_WIDTH, 0.01, p.id + " tail feathers are drawn a fifth as wide as long")
		# Every feather transform is finite.
		var ok := true
		for t in rig.feather_xforms:
			ok = ok and t.origin.is_finite() and t.basis.x.is_finite() and t.basis.z.is_finite()
		check(ok, p.id + " finite feathers")
		eq(rig.feather_xforms.size(), rig._plain_count + rig._emarg_count, p.id + " every feather placed")
		check(rig.feather_material == null, p.id + " plain feathers by default (the shader is parked)")
		# Plumage (default level 5): both faces drawn, each culling its back, coloured by the mark strip.
		check(rig.marks_material != null and rig._plain_u != null, p.id + " two-sided feathers with marks")
		check((rig.get_node("FeathersUnder") as MultiMeshInstance3D).multimesh.instance_count == rig._plain_count, p.id + " an underside for every feather")
		check(rig.feather_kinds.has(WingShape.Kind.UNDER_COVERT), p.id + " underwing coverts")
		# Below level 5 the colours are flat per feather, authored in sRGB (read as linear they wash out pale).
		Plumage.level = 3
		var flat := BirdRig.new()
		add_child(flat)
		flat.build(p)
		Plumage.level = 5
		var feather_mat := (flat.get_node("Feathers") as MultiMeshInstance3D).material_override as StandardMaterial3D
		check(feather_mat != null and feather_mat.vertex_color_use_as_albedo and feather_mat.vertex_color_is_srgb and feather_mat.cull_mode == BaseMaterial3D.CULL_BACK, p.id + " feather colours are sRGB, one face per copy")
		flat.queue_free()
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

	# A perched bird of every species: feet on its perch, knees inside the body, wings folded, neck retracted,
	# the touchdown dip settled; an owl grips 2 + 2.
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var perch := layout.start_perch()
	for p in BirdProfile.all():
		var b := Bird.new()
		add_child(b)
		b.setup(p, layout, ScriptedInput.new())
		b.perch_at(perch)
		await frames(60)
		for i in 2:
			var foot_world: Vector3 = b.rig.global_transform * (b.rig.leg_joints[i][3] as Vector3)
			check(foot_world.distance_to(perch.position) < p.body_length * 0.1, "%s perched foot %d on the perch (%.3f m)" % [p.id, i, foot_world.distance_to(perch.position)])
			check(b.rig.body.gap(b.rig.leg_joints[i][1]) < 0.0, p.id + " perched knee inside the body")
		check(b.rig.fold > 0.95, p.id + " perched wings folded")
		check(b.rig.neck_ext < 0.15, p.id + " perched neck retracted")
		check(absf(b.rig.position.length() - absf(b.rig._stance)) < 1e-3, p.id + " touchdown dip settled (only the stance offset left)")
		check(b.rig.head_offset.length() < p.body_length * 0.02, p.id + " head settled on its neck")
		var toe_back: float = (b.rig.toe_tips[1][2] as Vector3).z - b.rig.leg_joints[1][3].z
		check((toe_back > 0.0) == (p.id == "owl"), p.id + " outer toe back only on the owl")
		b.queue_free()
		await frames(1)
	finish()


func _pose(rig: BirdRig, flap: float, fold: float, sweep: float, hand_lift: float) -> void:
	rig.flap = flap
	rig.fold = fold
	rig.sweep = sweep
	rig.hand_lift = hand_lift
	rig.twist = 0.0
	rig.slot = 0.0
	rig.apply_pose()


## Pairs of overlapping wing feathers on one side (`offset` 0 right, 100 left: feather_kinds' codes) that lie in
## nearly one plane -- normals within ~3 deg, the gap between them somewhere under 0.1 mm (scaled to a 45 cm bird):
## they z-fight or cross.
func _ties(rig: BirdRig, offset: int) -> int:
	var tol := 0.0001 * rig._L / 0.45
	var idx: Array[int] = []
	for k in rig.feather_xforms.size():
		if rig.feather_kinds[k] != 6 and rig.feather_kinds[k] >= offset and rig.feather_kinds[k] < offset + 100:
			idx.append(k)
	var n := 0
	for a in idx:
		var xa: Transform3D = rig.feather_xforms[a]
		var na := xa.basis.y.normalized()
		var inv := xa.affine_inverse()
		for b in idx:
			if b <= a:
				continue
			var xb: Transform3D = rig.feather_xforms[b]
			if absf(na.dot(xb.basis.y.normalized())) < 0.9985:
				continue
			for k in 9:
				var pt := xb * Vector3(0.0, 0.0, 0.1 + 0.1 * k)
				var q := inv * pt
				if q.z > 0.05 and q.z < 0.95 and absf(q.x) < 0.45 and absf((pt - xa.origin).dot(na)) < tol:
					n += 1
					break
	return n


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
		var half := _mesh_width(rig._plain.mesh, 0.85) * 0.5   # the drawn outline's width there, halved
		var g := pa.distance_to(pb) - (a.basis.x.length() + b.basis.x.length()) * half
		worst = maxf(worst, g)
	return worst


## A feather mesh's full width (in units of its width scale) at fraction `t` of its length, from its vertices.
func _mesh_width(mesh: Mesh, t: float) -> float:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pts: Array[Vector2] = []
	for v in verts:
		pts.append(Vector2(v.z, absf(v.x)))
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for k in range(1, pts.size()):
		if pts[k].x >= t and pts[k - 1].x <= t:
			var u := (t - pts[k - 1].x) / maxf(pts[k].x - pts[k - 1].x, 1e-6)
			return lerpf(pts[k - 1].y, pts[k].y, u) * 2.0
	return 0.0


## The furthest feather tip on one side (x * side), from the rig's feather transforms.
func _tip_x(rig: BirdRig, side: float) -> float:
	var m := 0.0
	for t in rig.feather_xforms:
		m = maxf(m, (t.origin + t.basis.z).x * side)
	return m
