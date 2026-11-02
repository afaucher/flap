extends TestCase
## The detailed legs and feet (LegRig; docs/design/legs_and_feet.md), every species, both legs, perched, flaring and
## gliding. Measured on the drawn meshes:
## - trunk -> trousers: the trousers' first ring lies on the drawn trunk, with the trunk's colour, feather
##   coordinates and normal where it touches;
## - trousers -> bare tarsus: the trousers' last ring IS the tarsus's first (the same points), and the feathers
##   overlap the skin there (the skirt hangs below and outside the hem); the owl's feathered tube ends on the pad;
## - tarsus -> pad and each toe -> pad: the tube's first (or last) ring lies on the drawn pad, with the pad's colour
##   and scale coordinates there; neighbouring toes' bases don't overlap on the pad;
## - toe -> claw: one tube, the claw's rings running on from the toe's last ring, horn-coloured, tapering to a
##   point, curved by the species' arc, sized by its talon ratios; pads bulge under the toes;
## - the left leg mirrors the right point for point; normals face out; the tarsus's front plates face forward.
## - the toes wrap the branch they grip (the folded pose's, 2.5 x as thick, and an arena branch's 8 cm): the pad on
##   its top, every claw tip down on the bark, no toe in it.
## And a perched Bird with the detailed legs on: feet on the perch.


func _init() -> void:
	timeout_sec = 150.0


func setup() -> void:
	var stamp := FileAccess.get_file_as_string(ScaleTile.STAMP_PATH).strip_edges()
	eq(stamp, ScaleTile.source_md5(), "the leg scale PNGs are baked from today's ScaleTile (re-run tools/bake_feathers.gd -- --scales)")
	var was := LegRig.enabled
	LegRig.enabled = true
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		check(rig.legs != null and rig._leg_meshes[0].is_empty(), p.id + " detailed legs replace the capsules")
		check(rig.legs.skin_mat.get_shader_parameter("scales") != null and rig.legs.skin_mat.get_shader_parameter("scales_n") != null, p.id + " the skin reads the baked scale tile")
		# The measured proportions (docs/research/legs_and_feet.md 1.3): the drawn tibiotarsus 1.3 to 1.9 times the
		# tarsus, and the perched ankle below the belly (the trousers show).
		RigPoses.apply(rig, "folded", 0.0)
		var lj: Array = rig.leg_joints[1]
		var ratio := (lj[1] as Vector3).distance_to(lj[2]) / (lj[2] as Vector3).distance_to(lj[3])
		check(ratio > 1.3 and ratio < 1.95, "%s tibiotarsus / tarsus %.2f, as measured" % [p.id, ratio])
		check(rig.legs.exit_on[1] == "tibia", "%s perched: the tibia leaves the belly (exit on %s)" % [p.id, rig.legs.exit_on[1]])
		var seen := {}
		for pose in ["folded", "flare", "glide"]:
			RigPoses.apply(rig, pose, 0.0)
			rig.breath = 0.0
			for i in 2:
				_joins(rig, i, pose, seen)
			if pose != "glide":
				_mirror(rig, pose)
		# The toes wrap the branch they grip, thin or thick: every claw tip comes down onto the bark, no toe sinks
		# into it, and the pad sits on top of it.
		for k in [1.0, 2.5, 0.08 / (RigPoses.BRANCH_R * p.body_length)]:   # (0.08 m: an arena branch)
			RigPoses.apply(rig, "folded", 0.0)
			rig.grip_radius *= k
			rig.breath = 0.0
			rig.apply_pose()
			_grip_fit(rig, "%s branch x%.1f" % [p.id, k])
		check(seen.has("shell"), p.id + " the trunk -> trousers join was checked")
		check(seen.has("toes"), p.id + " the toe joins were checked")
		check(seen.has("hem") or p.id == "owl", p.id + " the trousers -> tarsus join was checked")
		check(seen.has("owl_pad") == (p.id == "owl"), p.id + " feathered to the toes only on the owl")
		rig.queue_free()
	# The game's path: a perched bird with the detailed legs, feet on the perch.
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var perch := layout.start_perch()
	for id in ["hawk", "owl"]:
		var pr := BirdProfile.by_id(id)
		var b := Bird.new()
		add_child(b)
		b.setup(pr, layout, ScriptedInput.new())
		b.perch_at(perch)
		await frames(60)
		for i in 2:
			var foot_world: Vector3 = b.rig.global_transform * (b.rig.leg_joints[i][3] as Vector3)
			check(foot_world.distance_to(perch.position) < pr.body_length * 0.1, "%s perched foot %d on the perch (%.3f m)" % [id, i, foot_world.distance_to(perch.position)])
			check(b.rig.legs.skin_mi[i].visible and (b.rig.legs.skin_mi[i].mesh as ArrayMesh).get_surface_count() == 1, "%s foot %d drawn" % [id, i])
		var toe_back: float = (b.rig.legs.toe_heading[1][2] as Vector3).dot(-b.rig._world_frame()[1])
		check((toe_back > 0.0) == (id == "owl"), id + " outer toe back only on the owl")
		b.queue_free()
		await frames(1)
	LegRig.enabled = was
	finish()


## Measured on the drawn toes against the branch the folded pose grips: its top is the grip point (the foot target),
## its axis runs across the bird (the bird faces across the branch).
func _grip_fit(rig: BirdRig, tag: String) -> void:
	var r := rig.grip_radius
	var up: Vector3 = rig._world_frame()[0]
	var right: Vector3 = (rig._world_frame()[1] as Vector3).cross(up).normalized()
	var lr := rig.legs
	var r0 := float(lr.spec.toe_r) * lr.L
	for i in 2:
		var axis: Vector3 = rig.foot_targets[i] - up * r
		var from_axis := func(q: Vector3) -> float:
			var d := q - axis
			return (d - right * d.dot(right)).length()
		var a := _arrays(lr.skin_mi[i])
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pad: Vector3 = lr.pad_centre[i]
		near(from_axis.call(pad), r + lr.sole_height(), r0 * 0.1, "%s leg %d: the pad sits on the bark" % [tag, i])
		var worst_in := INF
		for k in 4:
			var rows := _rows(lr.parts_s[i]["toe%d" % k])
			var nclaw: int = lr.claw_rows[i][k]
			var tip := v[(rows[rows.size() - 1] as PackedInt32Array)[0]]
			var dt: float = from_axis.call(tip)
			check(dt > r - r0 * 0.2 and dt < r + r0 * 0.6, "%s leg %d toe %d: the claw tip on the bark (%.4f from the axis, bark %.4f)" % [tag, i, k, dt, r])
			for j in range(2, rows.size() - nclaw):
				worst_in = minf(worst_in, from_axis.call(_centroid(v, rows[j])) - r)
		check(worst_in > r0 * 0.5, "%s leg %d: no toe sinks into the bark (closest centreline %.4f over it, toe radius %.4f)" % [tag, i, worst_in, r0])


func _arrays(mi: MeshInstance3D) -> Array:
	var m := mi.mesh as ArrayMesh
	return m.surface_get_arrays(0) if m != null and m.get_surface_count() > 0 else []


## Rows of a tube part as drawn: [vertex indices per row (n + 1 each, the last the seam copy)].
static func _rows(pt: Vector3i) -> Array:
	var out := []
	for r in pt.y:
		var row := PackedInt32Array()
		for j in pt.z:
			row.append(pt.x + r * pt.z + j)
		out.append(row)
	return out


## A ring's centre: midway between its two side points (j = 0 and n/2; LegRig's rings are lopsided front to back).
static func _centre(v: PackedVector3Array, row: PackedInt32Array) -> Vector3:
	return (v[row[0]] + v[row[(row.size() - 1) / 2]]) * 0.5


static func _centroid(v: PackedVector3Array, row: PackedInt32Array) -> Vector3:
	var c := Vector3.ZERO
	for j in row.size() - 1:
		c += v[row[j]]
	return c / float(row.size() - 1)


func _joins(rig: BirdRig, i: int, pose: String, seen: Dictionary) -> void:
	var lr := rig.legs
	var L := rig.profile.body_length
	var tag := "%s %s leg %d" % [rig.profile.id, pose, i]
	var sp: Dictionary = lr.spec
	var fa := _arrays(lr.feather_mi[i])
	var sa := _arrays(lr.skin_mi[i])
	check(not sa.is_empty(), tag + ": the foot is drawn")
	if sa.is_empty():
		return
	var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = sa[Mesh.ARRAY_NORMAL]
	var sc: PackedColorArray = sa[Mesh.ARRAY_COLOR]
	var sidx: PackedInt32Array = sa[Mesh.ARRAY_INDEX]
	var ps: Dictionary = lr.parts_s[i]
	var pad_tris := _tris_in(sidx, ps.pad)
	var pr: float = float(sp.pad_r) * L
	# --- Trunk -> trousers ---
	if not fa.is_empty() and (lr.parts_f[i] as Dictionary).has("trouser"):
		seen["shell"] = true
		var fv: PackedVector3Array = fa[Mesh.ARRAY_VERTEX]
		var fn: PackedVector3Array = fa[Mesh.ARRAY_NORMAL]
		var fc: PackedColorArray = fa[Mesh.ARRAY_COLOR]
		var fuv: PackedVector2Array = fa[Mesh.ARRAY_TEX_UV]
		var tr_rows := _rows(lr.parts_f[i].trouser)
		var ta := _arrays(rig._trunk)
		var st := rig._trunk.scale.x
		var tv := PackedVector3Array()
		for q in (ta[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			tv.append(q * st)
		var t_tris := _tris_in(ta[Mesh.ARRAY_INDEX], Vector3i(0, 1, tv.size()))
		var worst := [0.0, 0.0, 0.0, 1.0]   # distance, colour, uv, normal agreement
		for vi in (tr_rows[0] as PackedInt32Array):
			var hit := _closest(fv[vi], tv, ta[Mesh.ARRAY_INDEX], t_tris)
			worst[0] = maxf(worst[0], hit[0])
			var at: Array = _interp(hit, ta)
			var dc := maxf(maxf(absf(fc[vi].r - at[0].r), absf(fc[vi].g - at[0].g)), absf(fc[vi].b - at[0].b))
			worst[1] = maxf(worst[1], dc)
			worst[2] = maxf(worst[2], _uv_diff(fuv[vi], at[1], at[2]))
			worst[3] = minf(worst[3], fn[vi].dot(at[3]))
		check(worst[0] < L * 0.004, "%s: the trousers start on the drawn trunk (worst %.2f mm)" % [tag, worst[0] * 1000.0])
		check(worst[1] < 0.05, "%s: with the trunk's colour there (worst %.3f)" % [tag, worst[1]])
		check(worst[2] < 0.06, "%s: and its feather coordinates (worst %.3f tiles)" % [tag, worst[2]])
		check(worst[3] > 0.95, "%s: and its shading normal (worst dot %.3f)" % [tag, worst[3]])
		var last: PackedInt32Array = tr_rows[tr_rows.size() - 1]
		if sp.feathered == "foot":
			# The owl: the feathered tube ends on the pad.
			seen["owl_pad"] = true
			var wd := 0.0
			for j in last.size():
				wd = maxf(wd, _closest(fv[last[j]], sv, sidx, pad_tris)[0])
			check(wd < pr * 0.04, "%s: the feathered tarsus ends on the foot pad (worst %.2f mm)" % [tag, wd * 1000.0])
		elif ps.has("tarsus"):
			# Trousers -> tarsus: the hem ring is the tarsus's first ring; the skirt's edge hangs below and outside it.
			seen["hem"] = true
			var first: PackedInt32Array = _rows(ps.tarsus)[0]
			var wd := 0.0
			for j in last.size():
				wd = maxf(wd, fv[last[j]].distance_to(sv[first[j]]))
			check(wd < 1e-6, "%s: the trousers' hem is the tarsus's first ring (worst %.6f m)" % [tag, wd])
			var edge: PackedInt32Array = tr_rows[tr_rows.size() - 2]
			var ankle: Vector3 = rig.leg_joints[i][2]
			var t2 := ((rig.leg_joints[i][3] as Vector3) - ankle).normalized()
			var over := true
			for j in last.size() - 1:
				var e := fv[edge[j]] - ankle
				var h := fv[last[j]] - ankle
				over = over and e.dot(t2) > h.dot(t2) and (e - t2 * e.dot(t2)).length() > (h - t2 * h.dot(t2)).length() * 1.2
			check(over, "%s: the feathers overlap the skin at the hem (the skirt below and outside it)" % tag)
		_outward(fv, fn, tr_rows.slice(LegRig.FILLET_W.size(), tr_rows.size() - 2), tag + " trousers")   # (along the leg)
	# --- Tarsus -> pad ---
	if ps.has("tarsus"):
		var rows := _rows(ps.tarsus)
		_on_pad(rows[rows.size() - 1], sa, pad_tris, pr, tag + ": the tarsus's foot")
		_outward(sv, sn, rows.slice(0, rows.size() - 1), tag + " tarsus")
		# The front plates (u = 0, j = 3n/4) face the way the toes point.
		var mid: PackedInt32Array = rows[rows.size() / 2]
		var c := _centre(sv, mid)
		var front := sv[mid[(mid.size() - 1) * 3 / 4]] - c
		if pose == "folded":   # (sitting: the tarsus's front faces forward; trailing in flight it faces down)
			check(front.dot(rig._world_frame()[1]) > 0.0, tag + ": the tarsus's front plates face forward")
	# --- Toes -> pad, toe -> claw ---
	seen["toes"] = true
	var loops: Array = []
	var foot: Vector3 = lr.pad_centre[i]
	for k in 4:
		var rows := _rows(ps["toe%d" % k])
		var root: PackedInt32Array = rows[0]
		_on_pad(root, sa, pad_tris, pr, "%s: toe %d's base" % [tag, k])
		var lp := PackedVector3Array()
		for j in root.size() - 1:
			lp.append(sv[root[j]] - foot)
		loops.append(lp)
		var nc: int = lr.claw_rows[i][k]
		var toe_rows := rows.slice(2, rows.size() - nc)
		var claw := rows.slice(rows.size() - nc - 1)   # (the toe's last ring, then the claw's)
		_outward(sv, sn, toe_rows, "%s toe %d" % [tag, k])
		# The claw: runs on from the toe's last ring, horn-coloured, to a point.
		var base: PackedInt32Array = claw[0]
		var c1: PackedInt32Array = claw[1]
		var tip: PackedInt32Array = claw[claw.size() - 1]
		var r_last := sv[base[0]].distance_to(_centroid(sv, base))
		check(_centre(sv, c1).distance_to(_centre(sv, base)) < r_last * 1.5, "%s toe %d: the claw runs on from the toe" % [tag, k])
		check(sc[base[0]].a < 0.01 and sc[c1[0]].a > 0.99 and sc[tip[0]].a > 0.99, "%s toe %d: skin, then horn" % [tag, k])
		check(sv[tip[0]].distance_to(sv[tip[3]]) < 1e-6, "%s toe %d: the claw tapers to a point" % [tag, k])
		var cl := PackedVector3Array()
		for row in claw:
			cl.append(_centre(sv, row))
		var t0 := (cl[1] - cl[0]).normalized()
		var t1 := (cl[cl.size() - 1] - cl[cl.size() - 2]).normalized()
		var arc := rad_to_deg(t0.angle_to(t1))
		check(absf(arc - float(sp.arc) * 0.85) < 30.0, "%s toe %d: the claw curves %.0f deg (species %.0f)" % [tag, k, arc, sp.arc])
		# Pads: the sole bulges (under the joints on raptors, under the bones on perchers).
		if pose == "folded":
			var lo := INF
			var hi := 0.0
			for row: PackedInt32Array in toe_rows:
				var cc := _centre(sv, row)
				var n := row.size() - 1
				var ratio := sv[row[n / 4]].distance_to(cc) / maxf(sv[row[n / 2]].distance_to(cc), 1e-9)
				lo = minf(lo, ratio)
				hi = maxf(hi, ratio)
			check(hi > lo * (1.0 + 0.6 * float(sp.bulge)), "%s toe %d: pads bulge under the toe (%.2f .. %.2f)" % [tag, k, lo, hi])
	# Neighbouring toes' bases don't overlap on the pad: their loops, seen from the pad's centre (a gnomonic view,
	# in which the pad's surface between them maps one to one), share no area.
	for pair in [[0, 1], [1, 2], [0, 3], [2, 3]]:
		var a: PackedVector3Array = loops[pair[0]]
		var b: PackedVector3Array = loops[pair[1]]
		var m := Vector3.ZERO
		for q in a:
			m += q.normalized()
		for q in b:
			m += q.normalized()
		m = m.normalized()
		var e1 := m.cross(Vector3.UP if absf(m.y) < 0.9 else Vector3.RIGHT).normalized()
		var e2 := m.cross(e1)
		var polys := []
		for lp in [a, b]:
			var poly := PackedVector2Array()
			for q: Vector3 in lp:
				poly.append(Vector2(q.dot(e1), q.dot(e2)) / maxf(q.dot(m), 1e-6))
			polys.append(poly)
		var both := Geometry2D.intersect_polygons(polys[0], polys[1])
		check(both.is_empty(), "%s: toes %d and %d meet the pad apart" % [tag, pair[0], pair[1]])
	# Claw sizes: the hallux's against the outer toe's, as the species' talons (measured along the drawn claws).
	if pose == "folded":
		var lens := []
		for k in 4:
			var rows := _rows(ps["toe%d" % k])
			var nc: int = lr.claw_rows[i][k]
			var s := 0.0
			var prev := _centre(sv, rows[rows.size() - nc - 1])
			for r in range(rows.size() - nc, rows.size()):
				var c := _centre(sv, rows[r])
				s += c.distance_to(prev)
				prev = c
			lens.append(s)
		var want := float(sp.claws[0]) / float(sp.claws[3])
		near(float(lens[3]) / float(lens[2]), want, want * 0.12, "%s: hallux / outer claw %.2f (species %.2f)" % [tag, float(lens[3]) / float(lens[2]), want])


## Triangles of `idx` whose corners are all in part `pt` (first vertex, rows, columns).
static func _tris_in(idx: PackedInt32Array, pt: Vector3i) -> PackedInt32Array:
	var lo := pt.x
	var hi := pt.x + pt.y * pt.z
	var out := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if idx[t] >= lo and idx[t] < hi and idx[t + 1] >= lo and idx[t + 1] < hi and idx[t + 2] >= lo and idx[t + 2] < hi:
			out.append(t)
	return out


## The closest point on the triangles `tris` (offsets into idx) to p: [distance, triangle offset, barycentrics].
static func _closest(p: Vector3, v: PackedVector3Array, idx: PackedInt32Array, tris: PackedInt32Array) -> Array:
	var best := [INF, -1, Vector3.ZERO]
	for t in tris:
		var a := v[idx[t]]
		if a.distance_squared_to(p) > 0.04 * 0.04 * 16.0:   # (far away: skip)
			continue
		var bc := _closest_on_tri(p, a, v[idx[t + 1]], v[idx[t + 2]])
		var q: Vector3 = a * bc.x + v[idx[t + 1]] * bc.y + v[idx[t + 2]] * bc.z
		var d := q.distance_to(p)
		if d < best[0]:
			best = [d, t, bc]
	return best


## Barycentrics of the point of triangle abc closest to p (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest_on_tri(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return Vector3(1, 0, 0)
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return Vector3(0, 1, 0)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var w := d1 / (d1 - d3)
		return Vector3(1.0 - w, w, 0)
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return Vector3(0, 0, 1)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var w := d2 / (d2 - d6)
		return Vector3(1.0 - w, 0, w)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return Vector3(0, 1.0 - w, w)
	var denom := 1.0 / (va + vb + vc)
	var vv := vb * denom
	var ww := vc * denom
	return Vector3(1.0 - vv - ww, vv, ww)


## What the mesh draws at a closest-point hit: [colour, uv, uv2, face normal].
static func _interp(hit: Array, arr: Array) -> Array:
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var t: int = hit[1]
	var bc: Vector3 = hit[2]
	var ids := [idx[t], idx[t + 1], idx[t + 2]]
	var col := Color(0, 0, 0, 0)
	var uv := Vector2.ZERO
	var uv2 := Vector2.ZERO
	var nrm := Vector3.ZERO
	for k in 3:
		col += (arr[Mesh.ARRAY_COLOR] as PackedColorArray)[ids[k]] * bc[k]
		uv += (arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[ids[k]] * bc[k]
		uv2 += (arr[Mesh.ARRAY_TEX_UV2] as PackedVector2Array)[ids[k]] * bc[k]
		nrm += (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array)[ids[k]] * bc[k]
	return [col, uv, uv2, nrm.normalized()]


## How far apart two chart points are, u compared modulo the period there.
static func _uv_diff(a: Vector2, b: Vector2, b2: Vector2) -> float:
	var per := b2.x
	var du := absf(a.x - b.x)
	if per < 500.0:
		du = absf(wrapf(a.x - b.x, -0.5 * per, 0.5 * per))
	return maxf(du, absf(a.y - b.y))


## A ring of the skin mesh lies on its drawn foot pad, with the pad's colour and scale coordinates there.
func _on_pad(row: PackedInt32Array, sa: Array, pad_tris: PackedInt32Array, pr: float, tag: String) -> void:
	var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
	var sc: PackedColorArray = sa[Mesh.ARRAY_COLOR]
	var suv: PackedVector2Array = sa[Mesh.ARRAY_TEX_UV]
	var worst := [0.0, 0.0, 0.0]
	for j in row.size():
		var hit := _closest(sv[row[j]], sv, sa[Mesh.ARRAY_INDEX], pad_tris)
		worst[0] = maxf(worst[0], hit[0])
		var at := _interp(hit, sa)
		worst[1] = maxf(worst[1], absf(sc[row[j]].r - (at[0] as Color).r) + absf(sc[row[j]].g - (at[0] as Color).g) + absf(sc[row[j]].b - (at[0] as Color).b))
		worst[2] = maxf(worst[2], _uv_diff(suv[row[j]], at[1], at[2]))
	check(worst[0] < pr * 0.04, "%s on the drawn pad (worst %.2f mm)" % [tag, worst[0] * 1000.0])
	check(worst[1] < 0.02, "%s with the pad's colour (worst %.3f)" % [tag, worst[1]])
	check(worst[2] < 0.25, "%s with the pad's scale coordinates (worst %.3f scales)" % [tag, worst[2]])


## Every vertex normal of these rows faces out of its ring.
func _outward(v: PackedVector3Array, nrm: PackedVector3Array, rows: Array, tag: String) -> void:
	var bad := 0
	var all := 0
	var where := []
	for k in rows.size():
		var row: PackedInt32Array = rows[k]
		var c := _centroid(v, row)
		for vi in row:
			var r := v[vi] - c
			if r.length() < 1e-6:
				continue
			all += 1
			if nrm[vi].dot(r) <= 0.0:
				bad += 1
				if not where.has(k):
					where.append(k)
	check(all > 0 and bad == 0, "%s: normals face out (%d of %d inward, rows %s)" % [tag, bad, all, where])


## The left leg mirrors the right, point for point (x flipped), feathers and skin.
func _mirror(rig: BirdRig, pose: String) -> void:
	var L := rig.profile.body_length
	for pair in [[rig.legs.feather_mi, "feathers"], [rig.legs.skin_mi, "skin"]]:
		var a := _arrays(pair[0][0])
		var b := _arrays(pair[0][1])
		if a.is_empty() and b.is_empty():
			continue
		var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX] if not a.is_empty() else PackedVector3Array()
		var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX] if not b.is_empty() else PackedVector3Array()
		var ok := va.size() == vb.size() and va.size() > 0
		var worst := 0.0
		if ok:
			for k in va.size():
				worst = maxf(worst, va[k].distance_to(vb[k] * Vector3(-1, 1, 1)))
		# (3e-4 L: the trunk mesh's own normals mirror only to ~0.005, and the trousers' fillet leaves the trunk along
		# them -- about 0.1 mm on the owl)
		check(ok and worst < L * 3e-4, "%s %s: left %s mirror the right (%d / %d points, worst %.6f m)" % [rig.profile.id, pose, pair[1], va.size(), vb.size(), worst])
