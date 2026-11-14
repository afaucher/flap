extends TestCase
## The arm wing's feather chart (BirdRig.arm_chart_even; docs/design/wing_rig.md, "The arm wing's chart"), measured
## on the drawn loft triangle by triangle against the trunk's own chart beside the shoulder. Each band of the loft
## (its connector rows from the body's loop, then its stations out to the wrist), every bird, both wings, gliding and
## mid-upstroke:
## - stretch (the tile's scale along its most stretched direction over its least, by area): the trunk's own is about
##   1.5 (row_spacing); the arm's was 2.5-6x across the chord (a rest chord shorter than the wing's, no thickness);
## - density (tiles per metre over the trunk's): rising from the trunk's to the arm's (ARM_FEATHER: its coverts
##   smaller), not dipping at the join (the connector rows squeezed into 0.04 L of chart: feathers drawn twice the size);
## - the chart's chord: as long as the drawn chord it covers.
## The old chart is measured too and must fail, so the checks see the fix both ways.

const ROW_SPACING := 1.45   ## body_feathers.gdshader's default: the shader draws v / row_spacing
const STRETCH_MAX := 3.0    ## a station's median stretch (even: 1.7-2.8, the right wing's root stations the most; old: to 6.4)
const JOIN_DENSITY := 0.95  ## the connector rows' median density, at least (x the trunk's)
const CHORD_TOL := 0.25     ## the chart's chord within this share of the drawn one (the stations short of the wrist)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	Plumage.level = 6
	var keep := BirdRig.arm_chart_even
	var old_fails := 0
	var old_cases := 0
	for even: bool in [true, false]:
		BirdRig.arm_chart_even = even
		for p in BirdProfile.all():
			var rig := BirdRig.new()
			add_child(rig)
			rig.build(p)
			for pose: String in ["glide", "upstroke"]:
				RigPoses.apply(rig, pose, 0.0)
				rig.apply_pose()
				for side in 2:
					var bad := _judge(measure(rig, side), "%s %s wing %d" % [p.id, pose, side], even)
					if not even:
						old_cases += 1
						old_fails += 1 if bad != "" else 0
			rig.queue_free()
	BirdRig.arm_chart_even = keep
	check(old_fails == old_cases, "the old chart fails the checks: %d of %d wings" % [old_fails, old_cases])
	finish()


## Checks one wing's bands; the even chart's failures are reported, the old chart's returned ("" = it passed).
func _judge(bands: Array, what: String, report: bool) -> String:
	var why := ""
	var dens := []
	for b: Dictionary in bands:
		dens.append(b.density)
		if b.station and b.stretch > STRETCH_MAX:
			why += " %s stretch %.2f;" % [b.label, b.stretch]
		if not b.station and b.density < JOIN_DENSITY:
			why += " %s density %.2f;" % [b.label, b.density]
		if b.station and b.index < BirdRig.ARM_STATIONS - 1 and absf(b.chart / b.chord - 1.0) > CHORD_TOL:
			why += " %s chart %.0f mm on %.0f mm;" % [b.label, b.chart * 1000.0, b.chord * 1000.0]
	# (and no jump: from one band to the next the density changes by a third at most)
	for i in range(1, dens.size()):
		if dens[i] > dens[i - 1] * 1.34 or dens[i] < dens[i - 1] / 1.34:
			why += " density jumps %.2f -> %.2f at %s;" % [dens[i - 1], dens[i], bands[i].label]
	if report:
		check(why == "", "%s: the chart lies evenly%s" % [what, why])
	return why


## Per band of wing `side`'s loft, root to wrist: {label, station (else a connector row), index (within its kind),
## stretch (by area, median), stretch90, density (median, over the trunk's), along_v (the tile mostly stretched
## across the chord), chord (drawn, m), chart (the chord the chart gives it, m)}.
static func measure(rig: BirdRig, side: int) -> Array:
	var sh: Vector3 = rig._trunk.transform.affine_inverse() * (rig.wing_joints[side][0] as Vector3)
	var trunk := trunk_stats(rig, sh)
	var lm: LoftMesh = rig._arm_loft[side]
	var arr := (lm.mesh as ArrayMesh).surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var w := lm.around + 1
	var half := lm.around / 2
	var unit := rig._tile * BirdRig.ARM_FEATHER
	var out := []
	for i in lm.rows_n - 1:
		var st: Array = []   # [stretch, area] (by area: a long thin quad's sliver triangle mostly measures its own shape)
		var dn: Array = []
		var along_v := 0
		for j in lm.around:
			var a := i * w + j
			var b := i * w + j + 1
			var c := (i + 1) * w + j
			var d := (i + 1) * w + j + 1
			for tri: Array in [[a, c, b], [b, c, d]]:
				var r := jacobian(pos[tri[0]], pos[tri[1]], pos[tri[2]], uv[tri[0]], uv[tri[1]], uv[tri[2]])
				if r.is_empty():
					continue
				var area := (pos[tri[1]] - pos[tri[0]]).cross(pos[tri[2]] - pos[tri[0]]).length() * 0.5
				st.append([r[1] / maxf(r[2], 1e-6), area])
				dn.append([sqrt(r[1] * r[2]) / trunk.x, area])
				along_v += 1 if r[3] else 0
		if st.is_empty():
			continue
		var station := i >= BirdRig.ROOT_ROWS
		var k := i - BirdRig.ROOT_ROWS if station else i
		if station and k >= BirdRig.ARM_STATIONS:
			continue   # (the band closing the wrist's end, inside the hand's piece: no surface to chart)
		out.append({"label": ("station %d" if station else "connector %d") % k, "station": station, "index": k,
			"stretch": quantile(st, 0.5), "stretch90": quantile(st, 0.9), "density": quantile(dn, 0.5),
			"along_v": along_v * 2 > st.size(), "chord": pos[i * w].distance_to(pos[i * w + half]),
			"chart": absf(uv[i * w + half].y - uv[i * w].y) * unit})
	return out


## The value below which `q` of the area lies ([value, area] pairs).
static func quantile(vals: Array, q: float) -> float:
	vals.sort_custom(func(x, y): return x[0] < y[0])
	var total := 0.0
	for v: Array in vals:
		total += v[1]
	var acc := 0.0
	for v: Array in vals:
		acc += v[1]
		if acc >= q * total:
			return v[0]
	return vals[vals.size() - 1][0]


## The trunk's own density (tiles per metre, the geometric mean of the two directions) and stretch, median over its
## triangles within 0.25 L of the shoulder `sh` (trunk space).
static func trunk_stats(rig: BirdRig, sh: Vector3) -> Vector2:
	var arr := (rig._trunk.mesh as ArrayMesh).surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var dn := PackedFloat32Array()
	var st := PackedFloat32Array()
	for t in range(0, idx.size(), 3):
		var c := (pos[idx[t]] + pos[idx[t + 1]] + pos[idx[t + 2]]) / 3.0
		if c.distance_to(sh) > rig._L * 0.25:
			continue
		var r := jacobian(pos[idx[t]], pos[idx[t + 1]], pos[idx[t + 2]], uv[idx[t]], uv[idx[t + 1]], uv[idx[t + 2]])
		if r.is_empty():
			continue
		dn.append(sqrt(r[1] * r[2]))
		st.append(r[1] / maxf(r[2], 1e-6))
	dn.sort()
	st.sort()
	return Vector2(dn[dn.size() / 2], st[st.size() / 2]) if not dn.is_empty() else Vector2(1.0, 1.0)


## The chart's map on one triangle (tiles per metre, v over ROW_SPACING as drawn): [ok, largest and smallest singular
## values, whether the tile is stretched along v (the least dense direction, in the chart, is mostly v)], or [] for a
## degenerate triangle.
static func jacobian(p0: Vector3, p1: Vector3, p2: Vector3, t0: Vector2, t1: Vector2, t2: Vector2) -> Array:
	var e1 := p1 - p0
	var e2 := p2 - p0
	var n := e1.cross(e2)
	if n.length() < 1e-12 or e1.length() < 1e-7:
		return []
	var tx := e1.normalized()
	var ty := n.normalized().cross(tx)
	var q1 := Vector2(e1.length(), 0.0)
	var q2 := Vector2(e2.dot(tx), e2.dot(ty))
	var s := Vector2(1.0, 1.0 / ROW_SPACING)
	var d1 := (t1 - t0) * s
	var d2 := (t2 - t0) * s
	var det := q1.x * q2.y - q2.x * q1.y
	if absf(det) < 1e-14:
		return []
	# J = [d1 d2] * inverse([q1 q2]) (2x2: chart per surface metre)
	var ia := Vector2(q2.y, -q1.y) / det   # inverse's first row
	var ib := Vector2(-q2.x, q1.x) / det   # second row
	var j00 := d1.x * ia.x + d2.x * ib.x
	var j01 := d1.x * ia.y + d2.x * ib.y
	var j10 := d1.y * ia.x + d2.y * ib.x
	var j11 := d1.y * ia.y + d2.y * ib.y
	# singular values of [[j00, j01], [j10, j11]]
	var a := j00 * j00 + j01 * j01   # J J^T
	var b := j00 * j10 + j01 * j11
	var c := j10 * j10 + j11 * j11
	var tr := a + c
	var disc := sqrt(maxf(tr * tr * 0.25 - (a * c - b * b), 0.0))
	var l1 := tr * 0.5 + disc
	var l2 := maxf(tr * 0.5 - disc, 0.0)
	# the least dense direction in the chart: J J^T's eigenvector for l2
	var ev := Vector2(b, l2 - a) if absf(b) > 1e-12 else (Vector2(1, 0) if a < c else Vector2(0, 1))
	return [true, sqrt(l1), sqrt(l2), absf(ev.normalized().y) > 0.7071]
