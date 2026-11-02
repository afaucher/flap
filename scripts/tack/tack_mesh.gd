class_name TackMesh
extends RefCounted
## Mesh building for the tack (saddle, harness, launcher, rider): grids, sweeps, lathes and tori into one
## SurfaceTool, with the attributes the tack shaders read (scripts/tack/*.gdshader):
##   UV     (along, across) in "real" cm -- the rider's scale: an 8.5 cm pilot is a 1.75 m man at 1:20.6, so
##          leather grain, stitches and weave are sized as on real tack, then the shaders exaggerate them a
##          little, as a miniature painter does;
##   UV2    (distance to the piece's edge, position along that edge), real cm: stitch rows and burnished edges;
##   COLOR  (wear, cavity, seed, unused): rubbed high spots, dark crevices, a per-piece random tone.
## Rows of points join into quads; normals are smoothed within a piece (shared vertices), hard between pieces.

const REAL_H := 1.75   ## m, the man the rider is scaled from

var st := SurfaceTool.new()
var cm := 100.0        ## real cm per model metre
var seed := 0.0
var _n := 0


func _init(rider_height: float) -> void:
	cm = 100.0 * REAL_H / rider_height
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Rows of points (each a PackedVector3Array of the same length) as one smooth piece. `uv`, `uv2` (same shape,
## real cm) and `col` (same shape, or empty: wear 0, cavity 0). `wrap`: each row closes on itself. `flip`
## reverses the faces (a grid seen from its other side).
func grid(rows: Array, uv: Array, uv2: Array, col: Array = [], wrap := false, flip := false) -> void:
	var m := rows.size()
	var n: int = (rows[0] as PackedVector3Array).size()
	var base := _n
	var w := n + 1 if wrap else n   # (wrapped: the first column again, so UVs run on round the ring)
	for i in m:
		for j in w:
			var jj := j % n
			var c: Color = (col[i] as PackedColorArray)[jj] if not col.is_empty() else Color(0.0, 0.0, seed, 0.0)
			c.b = seed
			st.set_color(c)
			var u: Vector2 = (uv[i] as PackedVector2Array)[jj]
			if wrap and j == n:
				u.y = (uv[i] as PackedVector2Array)[n - 1].y + ((rows[i] as PackedVector3Array)[n - 1]).distance_to((rows[i] as PackedVector3Array)[0]) * cm
			st.set_uv(u)
			st.set_uv2((uv2[i] as PackedVector2Array)[jj])
			st.add_vertex((rows[i] as PackedVector3Array)[jj])
			_n += 1
	for i in m - 1:
		for j in w - 1:
			var a := base + i * w + j
			var b := a + 1
			var c := a + w
			var d := c + 1
			if flip:
				_tri(a, b, c)
				_tri(b, d, c)
			else:
				_tri(a, c, b)
				_tri(b, c, d)


func _tri(a: int, b: int, c: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)


## A profile swept along a path. `profile`: 2D points (x across the path's side, y along its normal), in
## order round the section (closed) or across it (open). `ups`: the normal at each path point (or one for
## all). `edge` (real cm, per profile point): distance to the piece's edge there (for stitch rows; 99: none).
## `cav` (per profile point): cavity. `wear`: per path point, or one value. `caps`: close the ends.
func sweep(path: PackedVector3Array, ups: PackedVector3Array, profile: PackedVector2Array, closed := true, edge := PackedFloat32Array(), cav := PackedFloat32Array(), wear := PackedFloat32Array(), caps := true, flip := false) -> void:
	var rows := []
	var uvs := []
	var uv2s := []
	var cols := []
	var along := 0.0
	var np := profile.size()
	var frames := _frames(path, ups)
	for i in path.size():
		if i > 0:
			along += path[i].distance_to(path[i - 1]) * cm
		var f: Basis = frames[i]
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var col := PackedColorArray()
		var across := 0.0
		for j in np:
			if j > 0:
				across += profile[j].distance_to(profile[j - 1]) * cm
			row.append(path[i] + f.x * profile[j].x + f.y * profile[j].y)
			uv.append(Vector2(along, across))
			uv2.append(Vector2(_pick(edge, j, np, 99.0), along))
			col.append(Color(_pick(wear, i, path.size(), 0.0), _pick(cav, j, np, 0.0), seed, 0.0))
		rows.append(row)
		uvs.append(uv)
		uv2s.append(uv2)
		cols.append(col)
	grid(rows, uvs, uv2s, cols, closed, flip)
	if caps and closed:
		for end in [0, path.size() - 1]:
			var f: Basis = frames[end]
			var centre := path[end]
			var ring: PackedVector3Array = rows[end]
			var c0 := _n
			st.set_color(Color(0.0, 0.0, seed, 0.0))
			st.set_uv(Vector2.ZERO)
			st.set_uv2(Vector2(99.0, 0.0))
			st.add_vertex(centre)
			_n += 1
			for j in np:
				st.set_color(Color(0.4, 0.0, seed, 0.0))
				st.set_uv(Vector2(profile[j].x, profile[j].y) * cm)
				st.set_uv2(Vector2(0.0, float(j)))
				st.add_vertex(ring[j])
				_n += 1
			for j in np:
				var a := c0 + 1 + j
				var b := c0 + 1 + (j + 1) % np
				if (end == 0) != flip:
					_tri(c0, a, b)
				else:
					_tri(c0, b, a)
	return


## A per-item value: the array's i-th if it has one per item, its only value if it has one, else `fallback`.
static func _pick(a: PackedFloat32Array, i: int, n: int, fallback: float) -> float:
	if a.size() == n:
		return a[i]
	return a[0] if not a.is_empty() else fallback


## Parallel-transport frames along a path: x the side, y the normal (from `ups`), z the tangent.
static func _frames(path: PackedVector3Array, ups: PackedVector3Array) -> Array:
	var out := []
	var n := path.size()
	for i in n:
		var t := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var up: Vector3 = ups[i] if ups.size() == n else ups[0]
		var y := (up - t * up.dot(t)).normalized()
		if y.length() < 0.5:
			y = t.cross(Vector3.RIGHT).normalized()
		var x := y.cross(t)
		out.append(Basis(x, y, t))
	return out


## A surface of revolution: `profile` (radius, height along the axis) from one end to the other, `segs`
## round, placed by `xf` (the axis is xf's +Y). `edge`, `cav` per profile point as in sweep.
func lathe(profile: PackedVector2Array, segs: int, xf: Transform3D, edge := PackedFloat32Array(), cav := PackedFloat32Array(), wear := 0.0, flip := false) -> void:
	var rows := []
	var uvs := []
	var uv2s := []
	var cols := []
	var along := 0.0
	for i in profile.size():
		if i > 0:
			along += profile[i].distance_to(profile[i - 1]) * cm
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		var col := PackedColorArray()
		var r := profile[i].x
		for j in segs:
			var a := TAU * j / segs
			row.append(xf * Vector3(r * cos(a), profile[i].y, r * sin(a)))
			uv.append(Vector2(along, TAU * r * j / segs * cm))
			uv2.append(Vector2(_pick(edge, i, profile.size(), 99.0), TAU * r * j / segs * cm))
			col.append(Color(wear, _pick(cav, i, profile.size(), 0.0), seed, 0.0))
		rows.append(row)
		uvs.append(uv)
		uv2s.append(uv2)
		cols.append(col)
	grid(rows, uvs, uv2s, cols, true, not flip)


## A ring: major radius `big` round xf's +Y axis, tube radius `small`.
func torus(big: float, small: float, xf: Transform3D, segs := 20, tube := 8, wear := 0.3) -> void:
	var path := PackedVector3Array()
	var ups := PackedVector3Array()
	for i in segs + 1:
		var a := TAU * i / segs
		var p := Vector3(big * cos(a), 0.0, big * sin(a))
		path.append(xf * p)
		ups.append(xf.basis * p.normalized())
	sweep(path, ups, circle(small, tube), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([wear]), false)


## Points round a circle (x, y), counter-clockwise from +x.
static func circle(r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in n:
		var a := TAU * j / n
		out.append(Vector2(r * cos(a), r * sin(a)))
	return out


## A flat strap's section: width `w`, thickness `t`, the edges rounded; points from one edge across the top
## to the other edge and back under. Returns [profile, edge distances (real cm, along the top), cavity].
func strap_section(w: float, t: float, n_top := 6) -> Array:
	var prof := PackedVector2Array()
	var edge := PackedFloat32Array()
	var cav := PackedFloat32Array()
	var r := t * 0.5
	var hw := w * 0.5 - r
	# Right edge, round from the bottom to the top.
	for k in 3:
		var a := -PI * 0.5 + PI * 0.5 * k
		prof.append(Vector2(hw + r * cos(a), r + r * sin(a)))
		edge.append(0.0)
		cav.append(0.0)
	for k in range(1, n_top):
		var x := hw - 2.0 * hw * k / n_top
		prof.append(Vector2(x, t))
		edge.append((hw - absf(x)) * cm)
		cav.append(0.0)
	for k in 3:
		var a := PI * 0.5 + PI * 0.5 * k
		prof.append(Vector2(-hw + r * cos(a), r + r * sin(a)))
		edge.append(0.0)
		cav.append(0.0)
	return [prof, edge, cav]


func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	st.generate_normals()
	st.generate_tangents()
	if mesh != null:
		return st.commit(mesh)
	return st.commit()
