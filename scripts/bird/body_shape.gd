class_name BodyShape
extends RefCounted
## The body's skeleton landmarks and the feather shell fitted around them (docs/design/body_rig_plan.html).
##
## The trunk is rigid (a bird's thoracic vertebrae, pelvis and sacrum are fused), so its shell is lofted once
## through a few elliptical rings, each placed from a landmark: the shoulder ring passes through the shoulder
## joints, the hip ring round the hips plus thigh padding, the breast ring at the keel's deepest point. The
## neck is a three-bone chain from the front of the trunk to the head; its shell is a tube re-lofted every
## frame. Rig space as in BirdRig: -Z is the nose, +X the right wing, +Y up; lengths in metres.
##
## Ring: [z, centre y, half width, height above centre, depth below centre]. The cross-section is two
## superellipse halves: a broad, flattish back with squarer shoulders above (exponent N_TOP), a deeper,
## narrower breast below running down toward the keel (N_BOT) -- a bird's trunk is not an oval, though the
## feathers round it off.

## Per species, as fractions of body length L (starting values to tune in the bird lab): neck length from
## the trunk to the head retracted / reaching; trunk depth at the breast; head radius (about 1.2x life; the owl's at
## life size -- docs/research/eyes_and_beaks.md 4.1, option A, so real-proportioned beaks fit); tibiotarsus and
## tarsometatarsus (the measured bones, docs/research/legs_and_feet.md 1.3: the tibiotarsus 1.3 to 1.9 times the
## tarsus, so a perched bird's ankle hangs below its belly; the owl is a barn owl's long legs); neck extension in flight (0 retracted .. 1 reaching); head yaw range (deg); owl-style
## reversible outer toe; plumage fluff when perched; the skull's shape (head sphere scale x, y, z) and brow ridge
## (docs/research/eyes_and_beaks.md 4.2: the crow's long head, the hawk's flat crown and frown, the owl's flat face).
const DATA := {
	"crow": {"neck": [0.14, 0.26], "depth": 0.32, "head": 0.06, "legs": [0.19, 0.13], "neck_flight": 0.75, "head_yaw": 110.0, "zygo": false, "fluff": 1.0, "skull": [0.88, 0.9, 1.15], "brow": 0.0},
	"owl": {"neck": [0.1, 0.18], "depth": 0.34, "head": 0.15, "legs": [0.29, 0.21], "neck_flight": 0.3, "head_yaw": 135.0, "zygo": true, "fluff": 1.1, "skull": [1.0, 1.05, 0.7], "brow": 0.0},
	"hawk": {"neck": [0.12, 0.22], "depth": 0.3, "head": 0.065, "legs": [0.2, 0.15], "neck_flight": 0.75, "head_yaw": 110.0, "zygo": false, "fluff": 1.0, "skull": [1.0, 0.88, 1.08], "brow": 1.0},
	"falcon": {"neck": [0.1, 0.18], "depth": 0.32, "head": 0.07, "legs": [0.19, 0.12], "neck_flight": 0.8, "head_yaw": 110.0, "zygo": false, "fluff": 1.0, "skull": [1.0, 0.95, 1.02], "brow": 0.7},
	"sparrow": {"neck": [0.09, 0.15], "depth": 0.33, "head": 0.08, "legs": [0.18, 0.12], "neck_flight": 0.5, "head_yaw": 110.0, "zygo": false, "fluff": 1.05, "skull": [0.95, 0.95, 1.0], "brow": 0.0},
}
const N_TOP := 2.6   ## back: flatter than an ellipse (2), squarer at the shoulders
const N_BOT := 1.8   ## breast: deeper and narrower toward the keel
const FEMUR := 0.09   ## femur length / L: short, near horizontal, hidden in the belly feathers

var L := 0.45
var shoulder := Vector3.ZERO     ## right shoulder joint
var hip := Vector3.ZERO          ## right hip joint (acetabulum)
var tail_base := Vector3.ZERO    ## pygostyle
var neck_base := Vector3.ZERO    ## where the neck's bones leave the trunk
var collar_z := 0.0               ## where the body's surface hands over to the neck's: near the breast's widest,
                                 ## where the trunk runs nearly straight, so the neck carries on smoothly
var femur := 0.0
var tib := 0.0
var tars := 0.0
var head_r := 0.0
var neck_rest := 0.0             ## neck base -> head, retracted
var neck_reach := 0.0            ## ... reaching
var neck_bone := 0.0             ## each of the three neck bones
var neck_flight := 0.5
var head_yaw := 110.0
var zygo := false
var fluff_perched := 1.0
var skull := Vector3.ONE             ## head sphere scale per axis (docs/research/eyes_and_beaks.md 4.2)
var brow := 0.0                      ## raptor brow ridge (0 none .. 1 a hawk's)
var rings: Array = []            ## front to back


static func for_profile(p: BirdProfile, wing: WingShape) -> BodyShape:
	var b := BodyShape.new()
	var d: Dictionary = DATA.get(p.id, DATA["crow"])
	var l := p.body_length
	b.L = l
	b.shoulder = Vector3(wing.shoulder.x, l * 0.06, wing.shoulder.y)
	b.hip = Vector3(l * 0.05, -l * 0.02, l * 0.03)
	b.tail_base = Vector3(0.0, l * 0.02, l * 0.24)
	b.neck_base = Vector3(0.0, l * 0.03, -l * 0.25)   # (y set from the rings below)
	b.femur = l * FEMUR
	b.tib = l * float(d.legs[0])
	b.tars = l * float(d.legs[1])
	b.head_r = l * float(d.head)
	b.neck_rest = l * float(d.neck[0])
	b.neck_reach = l * float(d.neck[1])
	b.neck_bone = b.neck_reach / 2.7   # never quite straight
	b.neck_flight = d.neck_flight
	b.head_yaw = Face.spec(p.id).head_yaw   # (Face holds the head's range of motion)
	b.zygo = d.zygo
	b.fluff_perched = d.fluff
	b.skull = Vector3(d.skull[0], d.skull[1], d.skull[2])
	b.brow = d.brow
	b._build_rings(float(d.depth))
	b.neck_base.y = b.ring_at(b.neck_base.z)[0]
	b.collar_z = -l * 0.19
	return b


func _build_rings(depth: float) -> void:
	var k := depth / 0.32       # deeper-bodied species: every ring's underside scales
	var breast_bot := depth - 0.15
	# The shoulder ring passes through the shoulder joints.
	var sh_top := 0.15
	var sh_w := shoulder.x / L / pow(maxf(1.0 - pow(absf(shoulder.y / L / sh_top), N_TOP), 0.1), 1.0 / N_TOP)
	var r := [
		[-0.33, 0.05, 0.0, 0.0, 0.0],
		[-0.3, 0.05, 0.07, 0.06, 0.07 * k],                    # throat
		[-0.25, 0.03, 0.13, 0.11, 0.14 * k],
		[-0.19, 0.01, 0.16, 0.13, 0.16 * k],                   # front of the breast
		[shoulder.z / L, 0.0, sh_w, sh_top, 0.17 * k],         # shoulders
		[-0.04, 0.0, 0.175, 0.155, breast_bot],                  # keel, deepest
		[hip.z / L + 0.01, 0.0, hip.x / L + 0.115, 0.145, 0.155 * k],   # hips + thigh padding
		[0.16, 0.0, 0.125, 0.12, 0.105 * k],                     # vent
		[tail_base.z / L + 0.02, tail_base.y / L, 0.05, 0.04, 0.04],   # tail base (pygostyle)
		[0.31, tail_base.y / L, 0.0, 0.0, 0.0],
	]
	rings.clear()
	for ring in r:
		rings.append(PackedFloat32Array([ring[0] * L, ring[1] * L, ring[2] * L, ring[3] * L, ring[4] * L]))


## A superellipse coordinate: `c` (a cos or sin) raised to 2/n, keeping its sign; the exponent by half (`s`: the sin).
static func _se(c: float, s: float) -> float:
	var nexp := N_TOP if s >= 0.0 else N_BOT
	return signf(c) * pow(absf(c), 2.0 / nexp)


## Position along the trunk, 0 front .. 1 back (colour zones use it).
func u_at(z: float) -> float:
	return clampf((z - front_z()) / (back_z() - front_z()), 0.0, 1.0)


## A point of the cross-section at angle `t` (0 = +X, 90 deg = up) for half width `w`, height `top` above and
## `bot` below centre, with the superellipse exponents `nt` / `nb` (2: an ellipse): [x, y].
static func section(t: float, w: float, top: float, bot: float, nt := N_TOP, nb := N_BOT) -> Vector2:
	var c := cos(t)
	var s := sin(t)
	var n := nt if s >= 0.0 else nb
	return Vector2(w * signf(c) * pow(absf(c), 2.0 / n), (top if s >= 0.0 else bot) * signf(s) * pow(absf(s), 2.0 / n))


func front_z() -> float:
	return rings[0][0]


func back_z() -> float:
	return rings[rings.size() - 1][0]


## The ring at `z` (Hermite through the rings; sizes 0 past the ends): [centre y, half width, top, bottom].
func ring_at(z: float) -> PackedFloat32Array:
	var n := rings.size()
	if z <= front_z() or z >= back_z():
		var e: PackedFloat32Array = rings[0] if z <= front_z() else rings[n - 1]
		return PackedFloat32Array([e[1], 0.0, 0.0, 0.0])
	var i := 0
	while i < n - 2 and z > rings[i + 1][0]:
		i += 1
	var a: PackedFloat32Array = rings[i]
	var b: PackedFloat32Array = rings[i + 1]
	var h := b[0] - a[0]
	var u := (z - a[0]) / h
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	for c in 4:
		var ma := _slope(i, c + 1) * h
		var mb := _slope(i + 1, c + 1) * h
		var u2 := u * u
		var u3 := u2 * u
		out[c] = (2.0 * u3 - 3.0 * u2 + 1.0) * a[c + 1] + (u3 - 2.0 * u2 + u) * ma + (-2.0 * u3 + 3.0 * u2) * b[c + 1] + (u3 - u2) * mb
	for c in range(1, 4):
		out[c] = maxf(out[c], 0.0)
	return out


## Catmull-Rom slope of ring parameter `c` at ring `i` (0 at the closed ends, so they round off).
func _slope(i: int, c: int) -> float:
	if i == 0 or i == rings.size() - 1:
		return 0.0 if c > 1 else 0.0
	var p: PackedFloat32Array = rings[i - 1]
	var q: PackedFloat32Array = rings[i + 1]
	return (q[c] - p[c]) / (q[0] - p[0])


## How far `pt` is outside the trunk shell (m, along the ring's radius; negative = inside).
func gap(pt: Vector3) -> float:
	var r := ring_at(pt.z)
	var dy := pt.y - r[0]
	var h := r[2] if dy >= 0.0 else r[3]
	if r[1] < 1e-4 or h < 1e-4:
		var ez := front_z() if pt.z < 0.0 else back_z()
		return pt.distance_to(Vector3(0.0, r[0], ez))
	var radial := Vector2(pt.x, dy)
	var nexp := N_TOP if dy >= 0.0 else N_BOT
	var e := pow(pow(absf(pt.x) / r[1], nexp) + pow(absf(dy) / h, nexp), 1.0 / nexp)
	if e < 1e-5:
		return -minf(r[1], h)
	return radial.length() * (1.0 - 1.0 / e)


## The shell's half width at (`z`, height `y`): where a point at that height on the flank meets the surface.
func half_width_at(z: float, y: float) -> float:
	var r := ring_at(z)
	var dy := y - r[0]
	var h := r[2] if dy >= 0.0 else r[3]
	if h < 1e-4:
		return 0.0
	var nexp := N_TOP if dy >= 0.0 else N_BOT
	return r[1] * pow(maxf(1.0 - pow(minf(absf(dy / h), 1.0), nexp), 0.0), 1.0 / nexp)


## Move `pt` onto the flank at its height (x set to the surface, plus `pad`), on side `s`.
func onto_flank(pt: Vector3, s: float, pad := 0.0) -> Vector3:
	return Vector3(s * (half_width_at(pt.z, pt.y) + pad), pt.y, pt.z)


func volume(steps := 200) -> float:
	var v := 0.0
	var dz := (back_z() - front_z()) / steps
	for k in steps:
		var r := ring_at(front_z() + (k + 0.5) * dz)
		v += r[1] * (1.7078 * r[2] + 1.5022 * r[3]) * dz   # superellipse half-areas (2 a b G(1+1/n)^2 / G(1+2/n), n = 2.6 / 1.8)
	return v


## The trunk shell as a mesh (built once; the trunk never bends). `color` (optional) colours each vertex from
## (u along the trunk 0 front .. 1 back, v up its side -1 keel .. 1 spine, side 0 midline .. 1 widest).
## Feather coordinates (`unit` > 0, m per coordinate unit; `size` (z) the feathers' size there, a share of the
## unit): u round each ring from the spine (signed, periodic in the girth), v along each lengthwise line from
## `v0` at the front ring (one per point round it), tips toward +v (the tail). Kept in trunk_uv / trunk_uv2 / trunk_z for lookups.
var trunk_uv: Array = []
var trunk_uv2: Array = []
var trunk_z := PackedFloat32Array()


func trunk_mesh(slices := 30, around := 20, color := Callable(), z_from := -INF, unit := 0.0, size := Callable(), v0 := PackedFloat32Array()) -> ArrayMesh:
	var pts: Array = []
	var cols: Array = []
	var z0 := maxf(z_from, front_z())   # (from `z_from` the front is left open: the neck carries on from it)
	trunk_uv.clear()
	trunk_uv2.clear()
	trunk_z.clear()
	for i in slices + 1:
		var z := lerpf(z0, back_z(), float(i) / slices)
		var r := ring_at(z)
		var row: Array = []
		var crow: Array = []
		for j in around:
			var t := TAU * j / around
			var h := r[2] if sin(t) >= 0.0 else r[3]
			row.append(Vector3(r[1] * _se(cos(t), sin(t)), r[0] + h * _se(sin(t), sin(t)), z))
			if color.is_valid():
				crow.append(color.call(u_at(z), sin(t), absf(cos(t))))
		pts.append(row)
		cols.append(crow)
		if unit > 0.0:
			var s: float = size.call(z)
			var arcs: Array = ring_arcs(row, around / 4, unit * s)   # (j = around / 4: the spine)
			var uv := PackedVector2Array()
			var uv2 := PackedVector2Array()
			for j in around + 1:
				var v: float = v0[j % around] if not v0.is_empty() else 0.0
				if i > 0:   # (along each lengthwise line, in the feathers' size between the rings)
					var pz := trunk_z[i - 1]
					v = (trunk_uv[i - 1] as PackedVector2Array)[j].y + (row[j % around] as Vector3).distance_to(pts[i - 1][j % around]) / (unit * 0.5 * (s + float(size.call(pz))))
				uv.append(Vector2(arcs[0][j], v))
				uv2.append(Vector2(arcs[1], sin(TAU * j / around)))
			trunk_uv.append(uv)
			trunk_uv2.append(uv2)
			trunk_z.append(z)
	return tube_mesh(pts, null, cols if color.is_valid() else [], trunk_uv, trunk_uv2)


## The trunk's feather coordinates at a point on (or by) its surface (trunk space): [uv, uv2], read from the
## mesh's grid (trunk_mesh with a unit).
func uv_at(p: Vector3) -> Array:
	var n := trunk_z.size()
	if n < 2:
		return [Vector2.ZERO, Vector2(1000.0, 0.0)]
	var fi := clampf((p.z - trunk_z[0]) / (trunk_z[n - 1] - trunk_z[0]) * (n - 1), 0.0, n - 1.001)
	var i := int(fi)
	var r := ring_at(clampf(p.z, trunk_z[0], trunk_z[n - 1]))
	var dy := p.y - r[0]
	var h := r[2] if dy >= 0.0 else r[3]
	var nexp := N_TOP if dy >= 0.0 else N_BOT
	# The ring angle: invert the superellipse (x = w cos^(2/n), y = h sin^(2/n)).
	var cx := signf(p.x) * pow(clampf(absf(p.x) / maxf(r[1], 1e-5), 0.0, 1.0), nexp / 2.0)
	var sy := signf(dy) * pow(clampf(absf(dy) / maxf(h, 1e-5), 0.0, 1.0), nexp / 2.0)
	var around: int = (trunk_uv[0] as PackedVector2Array).size() - 1
	var fj := fposmod(atan2(sy, cx), TAU) / TAU * around
	var j := mini(int(fj), around - 1)
	var out := []
	for grid in [trunk_uv, trunk_uv2]:
		var a: PackedVector2Array = grid[i]
		var b: PackedVector2Array = grid[i + 1]
		var lo := a[j].lerp(a[j + 1], fj - j)
		var hi := b[j].lerp(b[j + 1], fj - j)
		out.append(lo.lerp(hi, fi - i))
	return out


## A closed tube through rows of points (each row one ring, rows in order): quads between rows, the end rows
## pinched to their centre. Clockwise front faces seen from outside (Godot's convention). `colors`, if given,
## is one colour per point, in the same rows.
## Feather coordinates (plumage level 6, body_feathers.gdshader): `uvs` one per point PLUS one more per row (the
## ring's first point again, closing it: a feather coordinate runs on round the ring, so it can't wrap on a
## shared vertex); `uv2s` the same shape, (period, up) -- `period` is the ring's girth in the same units, the
## shader treats u as periodic in it. With `per_triangle`, uvs has one per point and each triangle unwraps its
## own corners' u to within half a period of its first (for a coordinate whose seam crosses the rows).
static func tube_mesh(rows: Array, mesh: ArrayMesh = null, colors: Array = [], uvs: Array = [], uv2s: Array = [], per_triangle := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = rows[0].size()
	var m := rows.size()
	if per_triangle and not uvs.is_empty():
		var tri := func(ids: Array) -> void:
			var u0: float = (uvs[ids[0].x][ids[0].y] as Vector2).x
			for q in ids:
				var uv: Vector2 = uvs[q.x][q.y]
				var uv2: Vector2 = uv2s[q.x][q.y]
				if uv2.x > 1e-6:
					uv.x -= uv2.x * roundf((uv.x - u0) / uv2.x)
				if not colors.is_empty():
					st.set_color(colors[q.x][q.y])
				st.set_uv(uv)
				st.set_uv2(uv2)
				st.add_vertex(rows[q.x][q.y])
		for i in m - 1:
			for j in n:
				var jb := (j + 1) % n
				tri.call([Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, jb)])
				tri.call([Vector2i(i, jb), Vector2i(i + 1, j), Vector2i(i + 1, jb)])
		st.generate_normals()
		st.index()
	else:
		var w := n + 1 if not uvs.is_empty() else n   # (with feather coordinates the ring's first column again)
		for i in m:
			for j in w:
				if not colors.is_empty():
					st.set_color(colors[i][j % n])
				if not uvs.is_empty():
					st.set_uv(uvs[i][j])
					st.set_uv2(uv2s[i][j])
				st.add_vertex(rows[i][j % n])
		for i in m - 1:
			for j in n:
				var a := i * w + j
				var b := i * w + (j + 1) % w
				var c := (i + 1) * w + j
				var d := (i + 1) * w + (j + 1) % w
				st.add_index(a)
				st.add_index(c)
				st.add_index(b)
				st.add_index(b)
				st.add_index(c)
				st.add_index(d)
		st.generate_normals()
	if mesh == null:
		return st.commit()
	mesh.clear_surfaces()
	return st.commit(mesh)


## Feather coordinates round one ring of points (rig units): each point's arc length from the ring's dorsal
## point `dorsal` (an index, the ring's top), signed, running on round the ring in its own order (n + 1 values,
## the last closing it), and the ring's girth; both divided by `unit` (m per coordinate unit).
static func ring_arcs(row: Array, dorsal: int, unit: float) -> Array:
	var n := row.size()
	var acc := PackedFloat32Array([0.0])
	for j in n:
		acc.append(acc[j] + (row[j] as Vector3).distance_to(row[(j + 1) % n]))
	var out := PackedFloat32Array()
	for j in n + 1:
		out.append((acc[j] - acc[dorsal]) / unit)
	return [out, acc[n] / unit]
