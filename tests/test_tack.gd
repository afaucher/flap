extends TestCase
## The war tack (scripts/tack), measured on what's built and posed, for each species big enough to ride:
## the pad and skirt sit snugly on the trunk (on it, never in it) and stay on the strip of back the wings
## never reach; the harness straps lie flat on the body; no wing feather, folded or beating, comes into the
## saddle's space; the head misses the launcher and the rider, perched (neck retracted) and in flight; the
## rider rides the seat in a racer's tuck in flight (knees into the tank, feet on the side pegs) and stands upright on the footrest perched, knees hinging like knees
## (bent forward, within a human range) left and right, hands within reach of the grips; on a shallow perch
## (the crow) the rider kneels up instead of standing; every species carries one (narrower on a sparrow, further back behind an owl's head); the launcher points
## each side of the rider (outboard of their limbs, clear of the bird), their lines of fire over the bird's head;
## loadouts and tilt do what they say; the pods show the rounds left. The rider's head: the helmet sits snugly on the skull and leaves the
## face open; the face has a nose and eyes under a brow; the goggles sit on the face, or raised on the helmet.



func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	for id in Tack.RIDDEN:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		var tack := Tack.fit(rig, null, ["rockets", "seekers"])   # (one of each kind: both mounts measured)
		_fit(id, rig, tack)
		for pose in ["glide", "folded"]:
			RigPoses.apply(rig, pose, 0.0)
			tack.sitting = pose == "folded"
			tack.update(0.0)
			_rider(id, pose, rig, tack)
			_head(id, pose, rig, tack)
			_footing(id, pose, tack)
			_arms(id, pose, tack)
			_hands(id, pose, tack)
			_scarf(id, pose, rig, tack)
			_goggles(id, pose, tack)
		_wings(id, rig, tack)
		_launcher(id, rig, tack)
		_loadouts(id, rig)
		_head_shape(id, tack)
		rig.queue_free()
		await frames(1)
	finish()


## Vertices (head frame, real cm) of the head mesh's surfaces drawn in material `mat`.
func _head_verts(tack: Tack, mat: String) -> PackedVector3Array:
	var m := (tack.rider.get_node("head/head_mesh") as MeshInstance3D).mesh as ArrayMesh
	var out := PackedVector3Array()
	for sfc in m.get_surface_count():
		if m.surface_get_material(sfc) == TackMaterials.get_mat(mat):
			for v in (m.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				out.append(v / tack.rider.k)
	return out


## The head (HeadShape, as drawn): the helmet sits on the skull, its padding's depth out, never in it; it
## leaves the face open (brows, eyes, nose, mouth) and its flaps come down both cheeks to the jaw; the nose
## stands out from the cheeks; each eye shows (in front of the skin round it) under a brow ridge that stands
## further forward.
func _head_shape(id: String, tack: Tack) -> void:
	var helm := _head_verts(tack, "helmet")
	var lo := INF
	var gaps := []
	var over_face := 0
	var flaps := [0, 0]
	for p in helm:
		var g := HeadShape.gap(p)
		lo = minf(lo, g)
		gaps.append(g)
		if p.z < -5.0 and p.y < 2.9 and absf(p.x) < 5.6:
			over_face += 1
		if p.y < -6.0 and absf(p.x) > 5.0:
			flaps[0 if p.x < 0.0 else 1] += 1
	for p in _head_verts(tack, "lining"):
		if p.z < -5.0 and p.y < 2.9 and absf(p.x) < 5.6:
			over_face += 1
	gaps.sort()
	check(lo > 0.4, "%s: the helmet never dips into the head (closest %.2f cm)" % [id, lo])
	check(gaps[gaps.size() / 2] < 1.3, "%s: the helmet's shell hugs the skull (median gap %.2f cm)" % [id, gaps[gaps.size() / 2]])
	eq(over_face, 0, "%s: the helmet leaves the face open" % id)
	check(flaps[0] > 0 and flaps[1] > 0, "%s: the helmet's flaps come down both cheeks" % id)
	var skin := _head_verts(tack, "skin")
	var tip := Vector3(0, 0, INF)
	for p in skin:
		if absf(p.x) < 1.0 and p.z < tip.z:
			tip = p
	check(tip.y > -4.0 and tip.y < -1.5, "%s: the face's frontmost point is the nose's tip (y %.1f)" % [id, tip.y])
	var eyes := _head_verts(tack, "eye")
	for s in [-1.0, 1.0]:
		var cheek := INF
		var brow := INF
		var apex := Vector3(0, 0, INF)
		for p in skin:
			if absf(p.x - s * 4.6) < 0.5 and absf(p.y + 2.0) < 0.5:
				cheek = minf(cheek, p.z)
			if absf(p.x - s * 3.2) < 0.6 and p.y > 1.5 and p.y < 3.0:
				brow = minf(brow, p.z)
		for p in eyes:
			if p.x * s > 0.0 and p.z < apex.z:
				apex = p
		check(cheek - tip.z > 1.8, "%s: the nose stands out from the cheek (%.1f cm, side %d)" % [id, cheek - tip.z, int(s)])
		check(HeadShape.gap(apex) > 0.1, "%s: the eye shows in front of the skin (side %d)" % [id, int(s)])
		check(brow < apex.z, "%s: the brow ridge stands in front of the eye (side %d)" % [id, int(s)])


## The goggles, as posed: down (flying), the cushions sit on the face round the eyes; raised (at rest), the
## cups rest on the helmet, not in it. The strap runs from each cup's outer rim round the back of the helmet,
## on it, down or raised -- nothing of it across the face.
func _goggles(id: String, pose: String, tack: Tack) -> void:
	var k := tack.rider.k
	var g := tack.rider.get_node("head/goggles") as Node3D
	var cups := (g.get_node("cups") as MeshInstance3D).mesh as ArrayMesh
	var up := tack.rider.goggles_up > 0.5
	var cush := cups.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for s in [-1.0, 1.0]:
		var lo := INF
		for v in cush:
			var p := g.transform * v / k
			if p.x * s > 0.0:
				lo = minf(lo, HeadShape.helmet_gap(p) if up else HeadShape.gap(p))
		if up:
			check(lo > -0.15 and lo < 0.8, "%s %s: the raised goggles rest on the helmet (gap %.2f, side %d)" % [id, pose, lo, int(s)])
		else:
			check(lo > -0.6 and lo < 0.2, "%s %s: the goggles' cushion sits on the face (gap %.2f, side %d)" % [id, pose, lo, int(s)])
	var smi := tack.rider.get_node("head/goggle_strap") as MeshInstance3D
	var sm := smi.mesh as ArrayMesh
	var w := smi.get_blend_shape_value(0)
	var base := sm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var raised := (sm.surface_get_blend_shape_arrays(0)[0] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var across := 0
	var ends := [0, 0]
	var behind := 0
	var sunk := 0
	for i in base.size():
		var p := base[i].lerp(raised[i], w) / k
		if p.z < -6.0 and p.y < 2.9:
			if absf(p.x) < 5.5:
				across += 1
			else:
				ends[0 if p.x < 0.0 else 1] += 1
		if p.z > 8.0:
			behind += 1
		var d := p.normalized()
		if acos(d.y) < HeadShape.helmet_edge(atan2(d.x, -d.z)) - 0.05 and HeadShape.helmet_gap(p) < -0.15:
			sunk += 1
	eq(across, 0, "%s %s: no goggle strap across the face" % [id, pose])
	if not up:
		check(ends[0] > 0 and ends[1] > 0, "%s %s: the goggle strap reaches both cups" % [id, pose])
	check(behind > 0, "%s %s: the goggle strap goes round the back" % [id, pose])
	eq(sunk, 0, "%s %s: the goggle strap lies on the helmet, not in it" % [id, pose])


## Each fist closes round its grip, as drawn: the grip's centre inside the hand (hand frame: across the palm,
## within its width and depth), the grip's axis across the hand (along its width, within 25 deg), the grip
## showing out of the fist each side; flying, the firing button on top of the bar over the fist, within the
## thumb's reach (its tip, 5 real cm).
func _hands(id: String, pose: String, tack: Tack) -> void:
	var r := tack.rider
	var sv := tack.saddle
	var sc := sv.scale.x
	var st := r.stand
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var mi := r.get_node("hand%d" % i) as MeshInstance3D
		var xf := mi.transform
		var target: Vector3 = sv.grips[i].lerp(sv.holds[i], st) * sc
		var axis: Vector3 = sv.grip_dirs[i].slerp(sv.hold_dirs[i], st).normalized()
		var l := xf.affine_inverse() * target / r.k
		check(l.y > 2.0 and l.y < 8.5 and absf(l.x) < 4.2 and absf(l.z) < 3.5, "%s %s: hand %d closes round its grip (grip at %.1f, %.1f, %.1f in the hand)" % [id, pose, i, l.x, l.y, l.z])
		var across := rad_to_deg(acos(clampf(absf((xf.basis.x.normalized()).dot(axis)), 0.0, 1.0)))
		if st < 0.01:
			# (the grip shows past the fist both sides: a glove is ~8.4 real cm across)
			var ends := [(sv.grips[i] - sv.grip_dirs[i] * 100.0), (sv.grips[i] + sv.grip_dirs[i] * 100.0)]
			var g_in: float = -INF
			var g_outr: float = -INF
			for v in (sv.grip_ends[i] as Array):
				var d := ((v as Vector3) - sv.grips[i]).dot(sv.grip_dirs[i]) / sc * sc / r.k
				if d < 0.0:
					g_in = maxf(g_in, -d)
				else:
					g_outr = maxf(g_outr, d)
			check(g_in > 6.5 and g_outr > 6.5, "%s %s: grip %d shows past the fist both sides (%.1f / %.1f real cm from its middle)" % [id, pose, i, g_in, g_outr])
		check(across < 25.0, "%s %s: grip %d runs across the palm (%.0f deg off)" % [id, pose, i, across])
		if pose != "folded":   # (flying: where the buttons are pressed)
			var top := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
			check((sv.buttons[i] - sv.grips[i]).dot(top) > 0.0 and absf((sv.buttons[i] - sv.grips[i]).dot(axis)) / sc / r.k * sc < 4.2, "%s %s: button %d on top of the bar, over the fist" % [id, pose, i])
			var thumb := xf * (Vector3(s * -3.4, 5.5, -2.6) * r.k)
			var btn: Vector3 = sv.buttons[i] * sc
			check(thumb.distance_to(btn) < 5.0 * r.k, "%s %s: button %d within the thumb's reach (%.1f real cm)" % [id, pose, i, thumb.distance_to(btn) / r.k])


## The arms stay out of the body: along each upper arm (past the shoulder) and forearm, no point comes within
## the torso's girth of its axis (pelvis to chest), and the hands stay in front of the chest.
func _arms(id: String, pose: String, tack: Tack) -> void:
	var r := tack.rider
	var j := r.joints
	var pel: Vector3 = j.pelvis
	var che: Vector3 = j.chest
	var girth := 11.0 * r.k   # (the coat's half depth, about; its half width is ~18 but arms hang beside it)
	for i in 2:
		var sh: Vector3 = j["shoulder%d" % i]
		var el: Vector3 = j["elbow%d" % i]
		var ha: Vector3 = j["hand%d" % i]
		var worst := INF
		for u in range(3, 11):
			var p := sh.lerp(el, u / 10.0)
			worst = minf(worst, p.distance_to(Geometry3D.get_closest_point_to_segment(p, pel, che)))
		for u in 11:
			var p := el.lerp(ha, u / 10.0)
			worst = minf(worst, p.distance_to(Geometry3D.get_closest_point_to_segment(p, pel, che)))
		check(worst > girth, "%s %s: arm %d stays out of the chest (%.1f real cm from the spine)" % [id, pose, i, worst / r.k])
		var front := -(r.get_node("pelvis") as MeshInstance3D).transform.basis.z
		check((ha - che).dot(front) > 0.0, "%s %s: hand %d in front of the chest" % [id, pose, i])


## Riding, each boot comes down onto its rear-set peg. Standing on the footrest, each boot as drawn rests on the bar: its sole within a centimetre of the bar's top
## (world up), the bar under it between heel and toe, nearer the heel (the arch).
func _footing(id: String, pose: String, tack: Tack) -> void:
	if tack.rider.stand < 0.01 and tack.rider.upright < 0.01:
		# Riding: each boot stands on its rear-set peg (the drawn boot within 1.2 real cm of the peg's top).
		for i in 2:
			var mi := tack.rider.get_node("foot%d" % i) as MeshInstance3D
			var peg: Vector3 = tack.saddle.ride_pegs[i] * tack.saddle.scale.x
			# (along the sole's centre line, as drawn: its lowest vertices down the boot's middle, joined up)
			var sole := []
			var m := mi.mesh as ArrayMesh
			for v in (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if absf(v.x) < 0.3 * tack.rider.k and v.y < -3.3 * tack.rider.k:
					sole.append(v)
			sole.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
			var near := INF
			for q in range(1, sole.size()):
				var p := Geometry3D.get_closest_point_to_segment(peg, mi.transform * (sole[q - 1] as Vector3), mi.transform * (sole[q] as Vector3))
				near = minf(near, p.distance_to(peg))
			check(near < 1.2 * tack.rider.k, "%s %s: boot %d stands on its peg (%.1f real cm off)" % [id, pose, i, near / tack.rider.k])
		return
	if tack.rider.stand < 0.99:
		return
	var r := tack.rider
	var u := tack.rig.world_up.normalized()
	for i in 2:
		var mi := r.get_node("foot%d" % i) as MeshInstance3D
		var peg: Vector3 = tack.saddle.pegs[i] * tack.saddle.scale.x
		var low := INF
		var along := []
		var toe := (mi.transform.basis * Vector3.FORWARD).normalized()
		var m := mi.mesh as ArrayMesh
		for sfc in m.get_surface_count():
			for v in (m.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p := mi.transform * v
				var rel := p - peg
				along.append(rel.dot(toe))
				if absf(rel.dot(toe)) < 3.0 * r.k:
					low = minf(low, rel.dot(u))
		along.sort()
		var heel: float = along[0]
		var tip: float = along[along.size() - 1]
		var f := -heel / (tip - heel)
		check(low > -0.8 * r.k and low < 1.0 * r.k, "%s %s: boot %d's sole rests on the bar (%.1f real cm above it)" % [id, pose, i, low / r.k])
		check(f > 0.1 and f < 0.5, "%s %s: the bar is under boot %d's arch (%.0f%% from the heel)" % [id, pose, i, f * 100.0])


## The scarf, flying or hanging, stays out of the rider's coat and the bird's body.
func _scarf(id: String, pose: String, rig: BirdRig, tack: Tack) -> void:
	for t in 30:
		tack.update(1.0 / 30.0)
	var r := tack.rider
	var pts: Array[Vector3] = r._scarf_pts
	var inside := 0
	for i in range(1, pts.size()):
		var p: Vector3 = pts[i]
		if r._clear_of_body(p, 0.3).distance_to(p) > 0.05 * r.k or rig.body.gap(p) < 0.0:
			inside += 1
	eq(inside, 0, "%s %s: the scarf stays out of the coat and the bird" % [id, pose])


## Vertices of the saddle's mesh for material `id`, rig space.
func _verts(tack: Tack, id: String) -> PackedVector3Array:
	var mi := tack.saddle.get_node("Tack_" + id) as MeshInstance3D
	var out := PackedVector3Array()
	var m := mi.mesh as ArrayMesh
	for sfc in m.get_surface_count():
		for v in (m.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(tack.saddle.transform * v)
	return out


func _fit(id: String, rig: BirdRig, tack: Tack) -> void:
	var b := rig.body
	RigPoses.apply(rig, "glide", 0.0)
	tack.update(0.0)
	for part in ["fleece", "saddle"]:
		var vs := _verts(tack, part)
		var lo := INF
		var low_elev := 90.0
		var gaps := []
		for v in vs:
			var g := b.gap(v)
			lo = minf(lo, g)
			gaps.append(g)
			low_elev = minf(low_elev, rad_to_deg(atan2(v.y - b.ring_at(v.z)[0], absf(v.x))))
		gaps.sort()
		check(lo > -0.0003, "%s: the %s is never inside the body (deepest %.2f mm)" % [id, part, lo * 1000.0])
		check(float(gaps[gaps.size() / 20]) < 0.0012 * tack.rider.height / Tack.RIDER_HEIGHT, "%s: the %s sits on it (5th percentile %.2f mm off)" % [id, part, float(gaps[gaps.size() / 20]) * 1000.0])
		check(low_elev > Saddle.FREE_ELEVATION, "%s: the %s stays on the back (lowest at %.0f deg elevation)" % [id, part, low_elev])
	var worst := 0.0
	var inside := 0.0
	for path in tack.saddle.strap_paths:
		for p in (path as PackedVector3Array):
			worst = maxf(worst, b.gap(p))
			inside = minf(inside, b.gap(p))
	check(worst < 0.0012 and inside > -0.0003, "%s: harness straps lie flat on the body (%.2f .. %.2f mm off)" % [id, inside * 1000.0, worst * 1000.0])
	check(tack.saddle.strap_paths.size() == 4, "%s: two loops, each in front of and behind one wing" % id)


## No wing feather comes into the saddle's space: over the back strip (above FREE_ELEVATION) along the
## saddle's length and within 4 cm of the shell -- folded, gliding, and through a wingbeat.
func _wings(id: String, rig: BirdRig, tack: Tack) -> void:
	var b := rig.body
	var zs := []
	for v in _verts(tack, "fleece"):
		zs.append(v.z)
	zs.sort()
	var z0: float = zs[0]
	var z1: float = zs[zs.size() - 1]
	var states := [["folded", 0.0], ["glide", 0.0], ["upstroke", 0.0]]
	for k in 8:
		states.append(["flap", k / 16.0])
	for s in states:
		RigPoses.apply(rig, s[0], s[1])
		var n := 0
		for xf in rig.feather_xforms.slice(0, rig.feather_xforms.size() - BirdRig.TAIL_FEATHERS):
			var t := xf as Transform3D
			for u in [0.0, 0.5, 1.0]:
				for w in [-0.5, 0.5]:
					var q: Vector3 = t.origin + t.basis.z * u + t.basis.x * w
					if q.z < z0 or q.z > z1 or b.gap(q) > 0.04:
						continue
					if rad_to_deg(atan2(q.y - b.ring_at(q.z)[0], absf(q.x))) > Saddle.FREE_ELEVATION:
						n += 1
		eq(n, 0, "%s %s %.2f: no wing feather in the saddle's space" % [id, s[0], s[1]])


func _rider(id: String, pose: String, rig: BirdRig, tack: Tack) -> void:
	var r := tack.rider
	var j := r.joints
	var b := rig.body
	var up := rig.world_up
	var torso: Vector3 = (j.chest as Vector3) - (j.pelvis as Vector3)
	var fwd := -(r.get_node("pelvis") as MeshInstance3D).transform.basis.z
	var standing := r.stand > 0.5
	if pose == "folded":
		var off := rad_to_deg(torso.angle_to(up))
		if standing:
			# (leaning back from the hand loops, away from the bird, no further than a lineman does)
			check(off < 30.0 and torso.dot(tack.saddle.seat_normal) >= (up * torso.length()).dot(tack.saddle.seat_normal) - 1e-6, "%s perched: the rider stands, leaning back from the bird (%.0f deg off upright)" % [id, off])
		else:
			check(off < 15.0, "%s perched: the rider is upright (%.0f deg off)" % [id, off])
		var tilt := rad_to_deg(up.angle_to(tack.saddle.seat_normal))
		if tilt >= Tack.STAND_PITCH.y or tilt <= Tack.STAND_PITCH.x:
			eq(standing, tilt >= Tack.STAND_PITCH.y, "%s perched (back %.0f deg): %s" % [id, tilt, "stands on the footrest (a steep back)" if tilt >= Tack.STAND_PITCH.y else "kneels up (a shallow back)"])
	else:
		var lean := rad_to_deg(torso.angle_to(tack.saddle.seat_normal))
		check(lean > 40.0 and lean < 70.0, "%s flying: the rider tucks down over the launcher (%.0f deg)" % [id, lean])
		check((j.pelvis as Vector3).distance_to(tack.saddle.seat_point * tack.saddle.scale.x) < r.height * 0.15, "%s flying: on the seat" % id)
	for i in 2:
		var side := "left" if i == 0 else "right"
		var hip: Vector3 = j["hip%d" % i]
		var kn: Vector3 = j["knee%d" % i]
		var an: Vector3 = j["ankle%d" % i]
		var flex := 180.0 - rad_to_deg((hip - kn).angle_to(an - kn))
		check(flex >= 0.0 and flex <= 165.0, "%s %s %s knee bends %.0f deg (0..165)" % [id, pose, side, flex])
		check((kn - (hip + an) * 0.5).dot(fwd) > 0.0, "%s %s %s knee points forward (hinges like a knee)" % [id, pose, side])
		var sc := tack.saddle.scale.x   # (the saddle rides the plumage's fluff: compare with it as drawn)
		var support: Vector3 = (tack.saddle.pegs[i] if standing else tack.saddle.heels[i]) * sc
		check(an.distance_to(support) < r.height * 0.15, "%s %s %s foot on its support (%.1f mm)" % [id, pose, side, an.distance_to(support) * 1000.0])
		# The ankle, as drawn: within a man's range -- 20 deg flexed up to 45 down from square to the shin
		# (68..135 deg) -- and not rolled over (its instep faces up the shin, within 20 deg).
		var fb := (r.get_node("foot%d" % i) as MeshInstance3D).transform.basis
		var toe := (fb * Vector3.FORWARD).normalized()
		var shin := (kn - an).normalized()
		var ang := rad_to_deg(toe.angle_to(shin))
		check(ang > 68.0 and ang < 135.0, "%s %s %s ankle: foot %.0f deg to the shin (68..135)" % [id, pose, side, ang])
		var plane_n := toe.cross(shin).normalized()
		var roll := rad_to_deg(asin(clampf(absf((fb * Vector3.UP).normalized().dot(plane_n)), 0.0, 1.0)))
		check(roll < 20.0, "%s %s %s ankle: the foot isn't rolled (%.0f deg)" % [id, pose, side, roll])
		var sh: Vector3 = j["shoulder%d" % i]
		var reach := r._r("upper_arm") + r._r("forearm")
		var hold: Vector3 = (tack.saddle.holds[i] if standing else tack.saddle.grips[i]) * sc
		check(sh.distance_to(hold) < reach * 1.02, "%s %s %s hand reaches its %s (%.1f of %.1f mm)" % [id, pose, side, "hand loop" if standing else "grip", sh.distance_to(hold) * 1000.0, reach * 1000.0])
	# The rider's body clears the launcher (the torso, a capsule from the pelvis to the chest).
	var pel: Vector3 = j.pelvis
	var che: Vector3 = j.chest
	var closest := INF
	for v in _verts(tack, "blued"):
		closest = minf(closest, v.distance_to(Geometry3D.get_closest_point_to_segment(v, pel, che)))
	check(closest > r._r("hip_w") * 0.9, "%s %s: the rider's body clears the launcher (%.1f mm)" % [id, pose, closest * 1000.0])
	# Nothing of the rider inside the bird.
	for key in j:
		check(b.gap(j[key] as Vector3) > 0.0015, "%s %s: rider's %s clear of the body (%.1f mm)" % [id, pose, key, b.gap(j[key] as Vector3) * 1000.0])


func _head(id: String, pose: String, rig: BirdRig, tack: Tack) -> void:
	var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
	var hr := rig.body.head_r * 1.1
	var hits := 0
	var what := {}
	for part in ["blued", "brass"]:
		for v in _verts(tack, part):
			if v.distance_to(hc) < hr:
				hits += 1
				what[part] = true
	for key in tack.rider.joints:
		if (tack.rider.joints[key] as Vector3).distance_to(hc) < hr + tack.rider.height * 0.06:
			hits += 1
			what[key] = true
	eq(hits, 0, "%s %s: the head clears the launcher and the rider %s" % [id, pose, str(what.keys())])


func _launcher(id: String, rig: BirdRig, tack: Tack) -> void:
	var sv := tack.saddle
	var sc := sv.scale.x
	var k := 1.0 / sv.cm
	RigPoses.apply(rig, "glide", 0.0)
	tack.sitting = false
	tack.update(0.0)
	# A mount each side, outboard of the rider's limbs, its pod clear of the bird's body.
	for i in 2:
		var m: Dictionary = sv.mounts[i]
		var piv := (m.pivot as Transform3D).origin * sc
		var s := -1.0 if i == 0 else 1.0
		check(piv.x * s > 0.0, "%s: mount %d on its side" % [id, i])
		var under := sv.at(s * Saddle.MOUNT_X, 0.0, Saddle.MOUNT_Z) * sc
		check((piv - under).y < tack.rider.height * 0.5, "%s: mount %d stands no taller than the rider's hip (%.0f real cm)" % [id, i, (piv - under).y / k / sc])
		var half: float = (10.5 if m.kind == "rockets" else 8.5) * k * sc
		var axis1: Vector3 = ((m.pivot as Transform3D) * Vector3(0.0, 0.0, -60.0 * k)) * sc   # (the pod's axis)
		for key in tack.rider.joints:
			var j: Vector3 = tack.rider.joints[key]
			var q := Geometry3D.get_closest_point_to_segment(j, piv, axis1)
			check(j.distance_to(q) > half + 3.0 * k, "%s: the rider's %s clears mount %d (%.1f real cm)" % [id, key, i, (j.distance_to(q) - half) * sv.cm])
		var low := INF
		for u in 9:
			low = minf(low, rig.body.gap(piv.lerp(axis1, u / 8.0)))
		check(low > half, "%s: mount %d's pod clears the bird's body" % [id, i])
	# The bands round each pod are drawn tight on it: every point of a band's line within a few mm outside the
	# pod's outline, and the outline touching the band all round (no point of it far inside).
	for cl in sv.clamp_loops:
		var pod: Transform3D = cl[1]
		var hull := Saddle._hull(sv._pod_outline(cl[2]))
		var off := 0.0
		for p in (cl[0] as PackedVector3Array):
			var q := pod.affine_inverse() * p * sv.cm
			var d := INF
			for h in hull.size():
				d = minf(d, Vector2(q.x, q.y).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(q.x, q.y), hull[h], hull[(h + 1) % hull.size()])))
			off = maxf(off, d)
		check(off < 0.6, "%s: the %s pod's band is snug (%.1f real cm off it at most)" % [id, cl[2], off])
		# Every round's line of fire passes over the bird's head (as the rig carries it gliding), along the body's
	# axis and along a flight path 4 deg below it.
	var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
	var hr: float = rig.body.head_r
	for kind in Saddle.POD_KINDS:
		for r in (sv.round_order[kind] as Array).size():
			# Rounds leave from their muzzles; only a mount raised as high as it goes (an owl's) may start them
			# further on, past the head.
			var mr: Array = sv.round_order[kind][r]
			if not sv.mounts[mr[0]].capped:
				check(sv.round_launch(kind, r).distance_to(sv.round_muzzle(kind, r)) < 1e-6, "%s: %s round %d leaves from its muzzle" % [id, kind, r])
			var ahead := (sv.round_launch(kind, r) - sv.round_muzzle(kind, r)).length() * sc
			check(ahead < (hc - sv.round_muzzle(kind, r) * sc).length() + 1.5 * hr, "%s: %s round %d starts no further on than just past the head" % [id, kind, r])
			var mz := sv.round_launch(kind, r) * sc
			for down in [0.0, 4.0]:
				var d := Basis(Vector3.RIGHT, -deg_to_rad(down)) * Vector3.FORWARD
				var rel := hc - mz
				var miss := (rel - d * rel.dot(d)).length() - hr
				check(rel.dot(d) <= 0.0 or miss > 0.2 * hr, "%s: %s round %d's line of fire (%.0f deg down) clears the head (%.2f cm)" % [id, kind, r, down, miss * 100.0])
	# The pods show what's left (the default loadout: three rockets left, two seekers right); firing hides the
	# last first, and the one hidden is the round by that muzzle.
	eq(tack.capacity("rockets"), 3, "%s: a rocket pod holds three" % id)
	eq(tack.capacity("seekers"), 2, "%s: a seeker rail holds two" % id)
	tack.set_ammo(2, 1)
	var shown := 0
	for rr in sv.rockets:
		shown += int(rr.visible)
	eq(shown, 2, "%s: rockets left show in their tubes" % id)
	var gone: MeshInstance3D = sv.rockets[2]
	var nearest := -1
	var best := INF
	for r in tack.capacity("rockets"):
		var d := _mesh_centre(gone).distance_to(sv.round_muzzle("rockets", r))
		if d < best:
			best = d
			nearest = r
	check(not gone.visible and nearest == 2, "%s: the round hidden is the one whose muzzle fires next" % id)
	shown = 0
	for q in sv.seekers:
		shown += int(q.visible)
	eq(shown, 1, "%s: seekers left show on the rail" % id)
	tack.set_ammo(3, 2)


## Loadouts (a pod each side: rockets, seekers or a gun) and tilt, on fresh tack: what's carried adds up, each round
## leaves from its own side (a gun's from its barrel's mouth, ahead of its drawn muzzle booster; two guns take turns),
## every round's line of fire clears the head, and the trunnion's tilt is the pod's measured pitch -- 0 and 8 deg,
## both sides.
func _loadouts(id: String, rig: BirdRig) -> void:
	RigPoses.apply(rig, "glide", 0.0)
	var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
	var hr: float = rig.body.head_r
	for lo in [["rockets", "rockets"], ["seekers", "seekers"], ["seekers", "rockets"], ["gun", "rockets"], ["seekers", "gun"], ["gun", "gun"]]:
		var pods: Array[String] = [lo[0], lo[1]]
		var t := Tack.fit(rig, null, pods)
		var n := {"rockets": 0, "seekers": 0, "gun": 0}
		for p in pods:
			n[p] += int(Saddle.POD_ROUNDS[p])
		for kind in Saddle.POD_KINDS:
			eq(t.capacity(kind), int(n[kind]), "%s %s: %s carried" % [id, str(lo), kind])
		var sv := t.saddle
		var sc := sv.scale.x
		for kind in Saddle.POD_KINDS:
			for r in t.capacity(kind):
				var mr: Array = sv._order_at(kind, r)
				var side: float = sv.mounts[mr[0]].side
				check(sv.round_muzzle(kind, r).x * side > 0.0, "%s %s: %s round %d leaves from its own side" % [id, str(lo), kind, r])
				var mz := sv.round_launch(kind, r) * sc
				var rel := hc - mz
				var miss := (rel - Vector3.FORWARD * rel.dot(Vector3.FORWARD)).length() - hr
				check(rel.dot(Vector3.FORWARD) <= 0.0 or miss > 0.2 * hr, "%s %s: %s round %d's line of fire clears the head (%.2f cm)" % [id, str(lo), kind, r, miss * 100.0])
		if pods[0] == "gun" and pods[1] == "gun":
			check(sv.round_muzzle("gun", 0).x * sv.round_muzzle("gun", 1).x < 0.0, "%s: two guns take turns" % id)
		for i in 2:
			if pods[i] == "gun":
				# The gun's muzzle: on its barrel's axis, just ahead of the drawn barrel's foremost point (its booster).
				var pod: Transform3D = sv.mounts[i].pivot
				var front := INF
				for v in _verts(t, "blued"):
					var q := pod.affine_inverse() * (sv.transform.affine_inverse() * v) * sv.cm
					if absf(q.x) < 2.5 and absf(q.y) < 2.5:
						front = minf(front, q.z)
				var m := pod.affine_inverse() * (sv.mounts[i].muzzles[0] as Vector3) * sv.cm
				check(absf(m.x) < 0.5 and absf(m.y) < 0.5 and m.z < front and m.z > front - 6.0, "%s %s: the gun's muzzle is just ahead of its barrel (%.1f real cm on)" % [id, str(lo), front - m.z])
		t.free()
	for tilt in [0.0, 8.0]:
		var t := Tack.fit(rig, null, [], tilt)
		for m in t.saddle.mounts:
			var ax: Vector3 = (m.pivot as Transform3D).basis * Vector3.FORWARD   # (the frame the pod is built in)
			var pitch := rad_to_deg(atan2(ax.y, -ax.z))
			check(absf(pitch - tilt) < 0.5, "%s: tilt %.0f deg sets the pod's pitch (%.1f, side %d)" % [id, tilt, pitch, int(m.side)])
		t.free()


func _mesh_centre(mi: MeshInstance3D) -> Vector3:
	return mi.transform * mi.mesh.get_aabb().get_center()
