extends TestCase
## Where the neck meets the head (and the trunk), measured on what's drawn, every species, the neck retracted to
## reaching and the head turned and tipped:
## - flush: the neck's last step into the head lies in the head's surface there (its drawn normal), and its first
##   step out of the trunk in the trunk's: no crease at either ring;
## - one light: on both rings the neck's drawn normals are the head's and the trunk's own, so the shading runs on;
## - no curled throat: perched, the front's outline runs down from the chin to the breast without dipping in (else the
##   head looks thrust forward off the neck);
## - no notch: with the neck out (in flight), the back's outline in profile from the crown to where the trunk takes
##   over dips under the line over it by little (a bird's nape feathers fill the neck's waist);
## - no colour cut: the head's colours (and feather-texture strength) carry on down the neck, handed over to the
##   trunk's along it, not stopped at the ring; the feather texture as strong on the head by the ring as on the
##   trunk (the head's own, fainter, only toward the face).

const LOOKS := [Vector3(0.0, 0.0, -1.0), Vector3(0.8, -0.1, -0.6), Vector3(-0.3, 0.45, -0.85)]
const EXTS := [0.0, 0.5, 1.0]
const FLUSH_DEG := 10.0      ## the neck's end steps off their ring's surface by at most this
const SAME_NORMAL_DEG := 1.0
const NOTCH := 0.9           ## the back's outline dips at most this many head radii under its hull (a level head over the
                             ## back dips some: the crown stands above the shoulders)
const THROAT := 0.23         ## perched, the front's outline dips in under the chin at most this many head radii
const CUT := 0.5             ## a quarter of the way down from the head ring, at most this far over to the trunk's colours


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		rig.visible = false
		var hr := rig.body.head_r
		var w := BirdRig.TRUNK_AROUND + 1
		var head_mi := rig._head.get_node("HeadSurface") as MeshInstance3D
		var ha := (head_mi.mesh as ArrayMesh).surface_get_arrays(0)
		var hv := ha[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var hn := ha[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var ta := (rig._trunk.mesh as ArrayMesh).surface_get_arrays(0)
		var tv := ta[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var tn := ta[Mesh.ARRAY_NORMAL] as PackedVector3Array
		# The texture's strength (COLOR.a) on the head's ring and the trunk's front ring.
		var ring_a := 1.0
		var hc := ha[Mesh.ARRAY_COLOR] as PackedColorArray
		for q in rig._hp60:
			ring_a = minf(ring_a, hc[_nearest(hv, q)].a)
		var trunk_a := (ta[Mesh.ARRAY_COLOR] as PackedColorArray)[_nearest(tv, rig._trunk_at(rig.body.collar_z, PI * 0.5))].a
		check(absf(ring_a - trunk_a) < 0.05, "%s feather texture as strong by the head ring as on the trunk (%.2f, %.2f)" % [p.id, ring_a, trunk_a])
		var worst := {"head_flush": 0.0, "trunk_flush": 0.0, "head_normal": 0.0, "trunk_normal": 0.0, "notch": 0.0, "throat": 0.0, "cut": 0.0}
		for ext in EXTS:
			for look in LOOKS:
				rig.neck_ext = ext
				rig.look_dir = (look as Vector3).normalized()
				rig.head_offset = Vector3.ZERO
				rig.apply_pose()
				var na := rig.drawn_arrays(rig._neck_mi)
				var nv := na[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var nn := na[Mesh.ARRAY_NORMAL] as PackedVector3Array
				var ht := rig._head.transform
				var tsc := rig._trunk.scale.x
				for j in BirdRig.TRUNK_AROUND:
					# The head end (row 0): the head's drawn normal at the ring point the neck ends on.
					var p0 := nv[j]
					var k := _nearest(hv, ht.affine_inverse() * p0)
					var n_head := (ht.basis * hn[k]).normalized()
					var into := (p0 - nv[w + j]).normalized()   # (row 1 -> row 0: into the head)
					worst.head_flush = maxf(worst.head_flush, rad_to_deg(asin(clampf(absf(into.dot(n_head)), 0.0, 1.0))))
					worst.head_normal = maxf(worst.head_normal, rad_to_deg(nn[j].angle_to(n_head)))
					# The trunk end (the last row).
					var last := (BirdRig.NECK_ROWS - 1) * w
					var pa := nv[last + j]
					var kt := _nearest(tv, pa / tsc)
					var n_trunk := tn[kt].normalized()
					var out := (nv[last - w + j] - pa).normalized()
					worst.trunk_flush = maxf(worst.trunk_flush, rad_to_deg(asin(clampf(absf(out.dot(n_trunk)), 0.0, 1.0))))
					worst.trunk_normal = maxf(worst.trunk_normal, rad_to_deg(nn[last + j].angle_to(n_trunk)))
				if look == LOOKS[0] and ext >= 0.5:
					worst.notch = maxf(worst.notch, _notch(rig, ha, na, ta, tsc) / hr)
				if look == LOOKS[0] and ext == 0.0:
					worst.throat = _throat(rig, ha, na, ta, tsc) / hr
		worst.cut = _cut(p)
		for key in ["head_flush", "trunk_flush"]:
			check(worst[key] < FLUSH_DEG, "%s neck flush with the %s (%.1f deg off its surface)" % [p.id, key.split("_")[0], worst[key]])
		for key in ["head_normal", "trunk_normal"]:
			check(worst[key] < SAME_NORMAL_DEG, "%s neck lit as the %s on their ring (normals %.2f deg apart)" % [p.id, key.split("_")[0], worst[key]])
		check(worst.notch < NOTCH, "%s no notch at the nape (the back's outline dips %.2f head radii)" % [p.id, worst.notch])
		check(worst.throat < THROAT, "%s perched, the throat runs down from the chin (the front's outline dips %.2f head radii)" % [p.id, worst.throat])
		check(worst.cut < CUT, "%s the head's colours carry on down the neck (a quarter of the way down, %.2f of the way over to the trunk's)" % [p.id, worst.cut])
		print("  %s: flush head %.1f trunk %.1f deg, normals %.2f / %.2f deg, notch %.2f hr, throat %.2f hr, cut %.2f" % [p.id,
			worst.head_flush, worst.trunk_flush, worst.head_normal, worst.trunk_normal, worst.notch, worst.throat, worst.cut])
		rig.queue_free()
	finish()


static func _nearest(pts: PackedVector3Array, q: Vector3) -> int:
	var best := INF
	var k := 0
	for i in pts.size():
		var d := pts[i].distance_squared_to(q)
		if d < best:
			best = d
			k = i
	return k


## How deep the back's outline in profile (the rig's side view: z along, y up) dips under its upper hull, from the
## head's crown back to the top of the trunk's front ring.
func _notch(rig: BirdRig, ha: Array, na: Array, ta: Array, tsc: float) -> float:
	var side := func(v: Vector3) -> Vector2: return Vector2(v.z, v.y)
	var crown: Vector2 = _extreme(ha[Mesh.ARRAY_VERTEX], rig._head.transform, side)
	var back: Vector2 = _extreme((na[Mesh.ARRAY_VERTEX] as PackedVector3Array).slice((BirdRig.NECK_ROWS - 1) * (BirdRig.TRUNK_AROUND + 1)), Transform3D.IDENTITY, side)
	return _dip(_outline(rig, ha, na, ta, tsc, side), crown.x, back.x)


## How deep the front's outline in profile (y along, forward out) dips in, from the face's front-most point down to
## where the neck leaves the trunk: the head's surface above the neck's ring (its cap under the ring is hidden in the
## neck), the neck, the trunk. A throat curled in under the head reads as the head thrust forward off the neck.
func _throat(rig: BirdRig, ha: Array, na: Array, ta: Array, tsc: float) -> float:
	var front := func(v: Vector3) -> Vector2: return Vector2(v.y, -v.z)
	var shown := _shown_head(rig, ha)
	var face: Vector2 = _extreme(shown[Mesh.ARRAY_VERTEX], rig._head.transform, front)
	var nv := na[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var breast: Vector2 = _extreme(nv.slice((BirdRig.NECK_ROWS - 1) * (BirdRig.TRUNK_AROUND + 1)), Transform3D.IDENTITY, front)
	return _dip(_outline(rig, shown, na, ta, tsc, front), breast.x, face.x)


## The head mesh's triangles that lie on or above the neck's ring (round its axis: the rest is the cap inside the neck).
static func _shown_head(rig: BirdRig, ha: Array) -> Array:
	var vv := ha[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var ii := ha[Mesh.ARRAY_INDEX] as PackedInt32Array
	var ax := BirdRig._neck_axis()
	var x2 := ax.cross(Vector3.RIGHT)
	var up := PackedByteArray()
	up.resize(vv.size())
	for i in vv.size():
		var d := Vector3(vv[i].x / rig.body.skull.x, vv[i].y / rig.body.skull.y, vv[i].z / rig.body.skull.z).normalized()
		var th := acos(clampf(d.dot(ax), -1.0, 1.0))
		up[i] = 1 if th >= rig._ring_th(atan2(d.dot(x2), d.x)) - 1e-3 else 0
	var keep := PackedInt32Array()
	for t in range(0, ii.size(), 3):
		if up[ii[t]] == 1 and up[ii[t + 1]] == 1 and up[ii[t + 2]] == 1:
			keep.append_array([ii[t], ii[t + 1], ii[t + 2]])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vv
	out[Mesh.ARRAY_INDEX] = keep
	return out


## The head's (unless `ha` is empty), neck's and trunk's surfaces mapped to a profile by `map` (point -> (along, out)): their triangles sampled
## finely, their vertices alone too sparse along the neck.
func _outline(rig: BirdRig, ha: Array, na: Array, ta: Array, tsc: float, map: Callable) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for m in [[ha, rig._head.transform], [na, Transform3D.IDENTITY], [ta, Transform3D.IDENTITY.scaled(Vector3.ONE * tsc)]]:
		var arr: Array = m[0]
		if arr.is_empty():
			continue
		var xf: Transform3D = m[1]
		var vv := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var ii := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
		for t in range(0, ii.size(), 3):
			var a := xf * vv[ii[t]]
			var b := xf * vv[ii[t + 1]]
			var c := xf * vv[ii[t + 2]]
			for x in 6:
				for y in 6 - x:
					pts.append(map.call(a + (b - a) * (x / 5.0) + (c - a) * (y / 5.0)))
	return pts


## The point of `vv` (through `xf`) furthest out in the profile `map` makes (or, `vertex`, that vertex itself).
static func _extreme(vv: PackedVector3Array, xf: Transform3D, map: Callable, vertex := false) -> Variant:
	var best := Vector2(0.0, -INF)
	var at := Vector3.ZERO
	for v in vv:
		var q: Vector2 = map.call(xf * v)
		if q.y > best.y:
			best = q
			at = v
	return at if vertex else best


## How deep an outline (`pts`: (along, out)) dips under its outer hull between `x0` and `x1` along.
static func _dip(pts: Array[Vector2], x0: float, x1: float) -> float:
	const BINS := 40
	var top := PackedFloat32Array()
	top.resize(BINS + 1)
	top.fill(-INF)
	var z0 := minf(x0, x1)
	var z1 := maxf(x0, x1)
	for q in pts:
		if q.x < z0 or q.x > z1:
			continue
		var b := roundi((q.x - z0) / (z1 - z0) * BINS)
		top[b] = maxf(top[b], q.y)
	var hull := []
	for b in BINS + 1:
		if top[b] == -INF:
			continue
		var q := Vector2(b, top[b])
		while hull.size() >= 2 and (hull[-1] - hull[-2]).cross(q - hull[-2]) >= 0.0:
			hull.pop_back()
		hull.append(q)
	var deep := 0.0
	for i in hull.size() - 1:
		var a: Vector2 = hull[i]
		var c: Vector2 = hull[i + 1]
		for b in range(int(a.x) + 1, int(c.x)):
			if top[b] == -INF:
				continue
			deep = maxf(deep, lerpf(a.y, c.y, (b - a.x) / (c.x - a.x)) - top[b])
	return deep


## How far the colour has gone over to the trunk's a quarter of the way down the neck from the head ring (along each
## lengthwise line), on a rig of `p` coloured in two tones -- the head all one colour, the body all another -- so only
## the hand-over shows: 0 still the head's, 1 the trunk's already. The worst over the columns, the neck half out.
func _cut(p: BirdProfile) -> float:
	var rig := TwoTone.new()
	add_child(rig)
	rig.build(p)
	rig.visible = false
	rig.neck_ext = 0.5
	rig.apply_pose()
	var cols := rig._neck_loft.colors_built
	var nv := rig._neck_loft.positions
	var w := BirdRig.TRUNK_AROUND + 1
	var n := BirdRig.NECK_ROWS
	var worst := 0.0
	for j in BirdRig.TRUNK_AROUND:
		var c0 := _c4(cols[j])
		var dir := _c4(cols[(n - 1) * w + j]) - c0
		var run := PackedFloat32Array([0.0])
		for i in n - 1:
			run.append(run[i] + nv[i * w + j].distance_to(nv[(i + 1) * w + j]))
		var at := run[n - 1] * 0.25
		for i in n - 1:
			if run[i + 1] >= at:
				var c := _c4(cols[i * w + j].lerp(cols[(i + 1) * w + j], (at - run[i]) / (run[i + 1] - run[i])))
				worst = maxf(worst, (c - c0).dot(dir) / dir.length_squared())
				break
	rig.queue_free()
	return worst


class TwoTone extends BirdRig:
	func _head_color_d(_d: Vector3, _marks := 1.0) -> Color:
		return Color(0.9, 0.2, 0.1)

	func _body_color_at(_u: float, _v: float, _side: float) -> Color:
		return Color(0.1, 0.3, 0.9)


static func _c4(c: Color) -> Vector4:
	return Vector4(c.r, c.g, c.b, c.a)


static func _cdist(a: Color, b: Color) -> float:
	return Vector4(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a).length()
