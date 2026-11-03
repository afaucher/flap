class_name EdgeBuilder
extends Node3D
## What lies beyond the arena's boundary (docs/design/arena_edge.md; the concept: docs/images/concepts/r5_edge_split.jpg,
## its top left and bottom right): the escarpment along its sector (Escarpment: the rock as one mesh, solid; boulders
## on its scree, heather and small pines on its ledges, pines along its top), open heath round the rest (grass tufts
## and heather thinning with distance, low rolling hills out to the horizon with stands of pines on them), and a
## two-strand wire fence along the edge posts. All outside the boundary; only the rock is solid.

const HILLS_FROM := 130.0    ## m: where the hills mesh takes over from the ground plane and the escarpment's grid
const HILLS_TO := 1100.0
const WIRES := [1.5, 2.7]    ## m: the fence's two strands, up the posts
const WIRE_R := 0.012
const WIRE_SAG := 0.09       ## m at mid span
const ROCK_SHADER := preload("res://scripts/world/rock.gdshader")
const HEATH_SHADER := preload("res://scripts/world/heath.gdshader")

var layout: ArenaLayout
var esc: Escarpment
var rock: MeshInstance3D      ## the escarpment as drawn
var rock_body: StaticBody3D   ## and as solid
var hills: MeshInstance3D
var tufts: MultiMeshInstance3D
var heather: MultiMeshInstance3D
var far_pines: MultiMeshInstance3D
var ledge_pines: MultiMeshInstance3D
var boulders: MultiMeshInstance3D
var wires: MeshInstance3D
var placed := {}      ## key -> PackedVector3Array: where each batch's instances stand (_batch)
var _rock_grid := []   ## the rock's points and normals as drawn ([verts, normals]; _grid_verts)
var _rng := RandomNumberGenerator.new()


func build(l: ArenaLayout) -> void:
	layout = l
	esc = Escarpment.of(l)
	_rng.seed = l.seed * 31 + 17
	var t := Time.get_ticks_usec()
	var times := {}
	if esc != null:
		_rock()
		times.rock = Time.get_ticks_usec() - t
		_rock_dressing()
		times.dressing = Time.get_ticks_usec() - t
	_hills()
	times.hills = Time.get_ticks_usec() - t
	_heath_cover()
	times.heath = Time.get_ticks_usec() - t
	_far_stands()
	_fence()
	times.all = Time.get_ticks_usec() - t
	if OS.get_environment("EDGE_TIMES") != "":
		print("edge build (cumulative us): ", times)


## The ground's height above GROUND_Y anywhere outside the boundary: the escarpment, else the hills (rising from
## HILLS_FROM), else flat.
func ground(x: float, z: float) -> float:
	var h := esc.height(x, z) if esc != null else 0.0
	return maxf(h, hill(x, z))


func hill(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r < HILLS_FROM:
		return 0.0
	var k := smoothstep(HILLS_FROM, 420.0, r)
	var n := _fbm(Vector2(x, z) * 0.006) * 0.75 + _fbm(Vector2(x, z) * 0.02 + Vector2(5.0, 9.0)) * 0.25
	return k * (4.0 + 70.0 * n * n) + smoothstep(500.0, HILLS_TO, r) * 45.0


# --- The escarpment -------------------------------------------------------------------------

## The rock: a polar grid over the sector (fine across the tiers, coarser over the top), skipping the flat ground
## round it; collision from the same grid (the ledges and the stones are narrow: a coarser one rounds them off).
func _rock() -> void:
	var thetas := _thetas(0.5, esc.foot)
	var radii := PackedFloat32Array()
	var r := esc.foot - Escarpment.SCREE - 1.0
	while r < minf(esc.foot + 40.0, HILLS_FROM + 2.0):
		radii.append(r)
		r += 0.3
	while r < HILLS_FROM + 2.0:
		radii.append(r)
		r += 2.0
	radii.append(HILLS_FROM + 2.0)
	var heights := PackedFloat32Array()
	for t in thetas:
		var col := esc.column(t)
		for rr in radii:
			heights.append(esc.height_in(col, rr))
	_rock_grid = _grid_verts(thetas, radii, heights)
	rock = MeshInstance3D.new()
	rock.name = "Escarpment"
	rock.mesh = _grid_mesh(_rock_grid, thetas.size(), radii.size(), true)
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	rock.material_override = m
	add_child(rock)
	var faces := PackedVector3Array()
	var v: PackedVector3Array = _rock_grid[0]
	var nr := radii.size()
	var cols := range(0, thetas.size(), 1)
	if cols[-1] != thetas.size() - 1:
		cols.append(thetas.size() - 1)
	var rows := range(0, nr, 1)
	if rows[-1] != nr - 1:
		rows.append(nr - 1)
	for ci in cols.size() - 1:
		for rj in rows.size() - 1:
			var pa := v[cols[ci] * nr + rows[rj]]
			var pb := v[cols[ci + 1] * nr + rows[rj]]
			var pc := v[cols[ci + 1] * nr + rows[rj + 1]]
			var pd := v[cols[ci] * nr + rows[rj + 1]]
			if maxf(maxf(pa.y, pb.y), maxf(pc.y, pd.y)) - ArenaLayout.GROUND_Y < 0.02:
				continue
			faces.append_array([pa, pb, pc, pa, pc, pd])   # (wound as the mesh is)
	rock_body = StaticBody3D.new()
	rock_body.name = "EscarpmentBody"
	rock_body.collision_layer = ArenaBuilder.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true   # (solid from any side: a bird that gets round behind a block)
	shape.set_faces(faces)
	cs.shape = shape
	rock_body.add_child(cs)
	add_child(rock_body)


## Angles across the sector, `step` m apart at radius `at_r`.
func _thetas(step: float, at_r: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(ceil(Escarpment.HALF * 2.0 * at_r / step))
	for i in n + 1:
		out.append(esc.at - Escarpment.HALF + Escarpment.HALF * 2.0 * i / n)
	return out


## A polar grid's points from its heights (heights[i * radii + j], by angle then radius), lowered by `drop`, and
## their normals: [verts, normals].
func _grid_verts(thetas: PackedFloat32Array, radii: PackedFloat32Array, heights: PackedFloat32Array, drop := 0.0) -> Array:
	var nt := thetas.size()
	var nr := radii.size()
	var verts := PackedVector3Array()
	verts.resize(nt * nr)
	for i in nt:
		var s := sin(thetas[i])
		var c := cos(thetas[i])
		for j in nr:
			verts[i * nr + j] = Vector3(s * radii[j], ArenaLayout.GROUND_Y + heights[i * nr + j] - drop, c * radii[j])
	var normals := PackedVector3Array()
	normals.resize(nt * nr)
	for i in nt:
		for j in nr:
			var a := verts[mini(i + 1, nt - 1) * nr + j] - verts[maxi(i - 1, 0) * nr + j]
			var b := verts[i * nr + mini(j + 1, nr - 1)] - verts[i * nr + maxi(j - 1, 0)]
			var n := b.cross(a).normalized()
			normals[i * nr + j] = n if n.y >= 0.0 else -n
	return [verts, normals]


## The grid as a mesh, cells left out where all four corners lie on the flat ground (`skip_flat`).
func _grid_mesh(grid: Array, nt: int, nr: int, skip_flat: bool) -> ArrayMesh:
	var verts: PackedVector3Array = grid[0]
	var idx := PackedInt32Array()
	for i in nt - 1:
		for j in nr - 1:
			var q0 := i * nr + j
			var q1 := (i + 1) * nr + j
			var q2 := q1 + 1
			var q3 := q0 + 1
			if skip_flat and maxf(maxf(verts[q0].y, verts[q1].y), maxf(verts[q2].y, verts[q3].y)) - ArenaLayout.GROUND_Y <= 0.02:
				continue
			idx.append_array([q0, q1, q2, q0, q2, q3])
	var surf := []
	surf.resize(Mesh.ARRAY_MAX)
	surf[Mesh.ARRAY_VERTEX] = verts
	surf[Mesh.ARRAY_NORMAL] = grid[1]
	surf[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
	return m


## Boulders on the scree and at the foot, heather and small pines on the ledges, pines along the top: placed on
## points of the rock's own grid (its heights and normals as drawn).
func _rock_dressing() -> void:
	var v: PackedVector3Array = _rock_grid[0]
	var nn: PackedVector3Array = _rock_grid[1]
	var bx := []
	var bc := []
	var px := []
	var pc := []
	var hx := []
	var hc := []
	for k in 16000:
		var i := _rng.randi() % v.size()
		var at := v[i]
		var n := nn[i]
		var h := at.y - ArenaLayout.GROUND_Y
		var theta := atan2(at.x, at.z)
		if esc.taper(theta) < 0.05:
			continue
		var s := Vector2(at.x, at.z).length() - esc.foot
		if s < 1.0 and h < Escarpment.SCREE_H * 1.2:   # (the scree)
			if h < 0.05 or _rng.randf() > 0.55:
				continue
			var size := _rng.randf_range(0.6, 2.6) * (1.0 if _rng.randf() < 0.75 else 2.0)
			var b := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(size, size * _rng.randf_range(0.5, 0.8), size * _rng.randf_range(0.7, 1.1)))
			bx.append(Transform3D(b, at - n * size * 0.2))
			bc.append(Color(0.72, 0.7, 0.66) * _rng.randf_range(0.8, 1.05))
		elif n.y > 0.93 and h > Escarpment.SCREE_H + 2.0:   # (a ledge or the top)
			var on_top := h > esc.top(theta) - 1.5
			if _rng.randf() < (0.045 if on_top else 0.1):
				var tall := _rng.randf_range(8.0, 15.0) if on_top else _rng.randf_range(2.0, 5.5)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall) * Vector3(_rng.randf_range(0.8, 1.2), 1.0, _rng.randf_range(0.8, 1.2)))
				px.append(Transform3D(b, at))
				pc.append(Color(1, 1, 1) * _rng.randf_range(0.85, 1.05))
			elif _rng.randf() < 0.7:
				var size := _rng.randf_range(0.5, 1.4)
				hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * 0.45, size)), at))
				hc.append(_heather_colour())
	boulders = _batch("boulders", _boulder_mesh(), bx, bc)
	boulders.material_override = _rock_mat_instanced()
	ledge_pines = _batch("ledge_pines", _rock_pine_mesh(), px, pc)
	_heather_batch(hx, hc, "ledge_heather")


# --- The heath ------------------------------------------------------------------------------

## The hills: a ring of height field from HILLS_FROM out to the horizon, the escarpment's top running into them.
func _hills() -> void:
	var thetas := PackedFloat32Array()
	for i in 721:
		thetas.append(TAU * i / 720.0)
	var radii := PackedFloat32Array()
	var r := HILLS_FROM
	while r < HILLS_TO:
		radii.append(r)
		r *= 1.06
	radii.append(HILLS_TO)
	hills = MeshInstance3D.new()
	hills.name = "Hills"
	var heights := PackedFloat32Array()
	for t in thetas:
		var col := esc.column(t) if esc != null else PackedFloat32Array()
		for rr in radii:
			heights.append(maxf(esc.height_in(col, rr) if esc != null else 0.0, hill(sin(t) * rr, cos(t) * rr)))
	hills.mesh = _grid_mesh(_grid_verts(thetas, radii, heights, 0.3), thetas.size(), radii.size(), false)
	var m := ShaderMaterial.new()
	m.shader = HEATH_SHADER
	hills.material_override = m
	add_child(hills)


## Grass tufts and heather on the flat heath outside the posts, thick near the edge, thinning out to HILLS_FROM.
func _heath_cover() -> void:
	var tx := []
	var tc := []
	var hx := []
	var hc := []
	for k in 60000:
		var theta := _rng.randf() * TAU
		var r := layout.boundary + 0.5 + pow(_rng.randf(), 1.7) * (HILLS_FROM + 20.0 - layout.boundary)
		var x := sin(theta) * r
		var z := cos(theta) * r
		if esc != null and esc.height_in(_column_near(theta), r) > 0.05:   # (on the rock)
			continue
		var h := hill(x, z)
		var at := Vector3(x, ArenaLayout.GROUND_Y + h, z)
		if _rng.randf() < 0.82:
			var size := _rng.randf_range(0.6, 1.3)
			tx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * _rng.randf_range(0.8, 1.3), size)), at))
			tc.append(Color(0.34, 0.3, 0.13).lerp(Color(0.16, 0.21, 0.07), _rng.randf()) * _rng.randf_range(0.8, 1.1))
		else:
			var size := _rng.randf_range(0.5, 1.3)
			hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * 0.45, size)), at))
			hc.append(_heather_colour())
	tufts = _batch("tufts", _tuft_mesh(), tx, tc)
	(tufts.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	heather = _heather_batch(hx, hc, "heather")


## Stands of pines out on the hills (and along the escarpment's top, behind it).
func _far_stands() -> void:
	var xs := []
	var cs := []
	for k in 70:
		var theta := _rng.randf() * TAU
		var r := _rng.randf_range(160.0, 720.0)
		var c := Vector2(sin(theta), cos(theta)) * r
		var n := _rng.randi_range(4, 22)
		var spread := _rng.randf_range(8.0, 26.0) * (0.6 + r / 700.0)
		for i in n:
			var p := c + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * spread
			var tall := _rng.randf_range(13.0, 24.0)
			xs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall)), Vector3(p.x, ArenaLayout.GROUND_Y + ground(p.x, p.y) - 0.2, p.y)))
			cs.append(Color(1, 1, 1) * _rng.randf_range(0.8, 1.05))
	far_pines = _batch("far_pines", _pine_mesh(), xs, cs)


# --- The fence ------------------------------------------------------------------------------

## Two strands of wire between each edge post and the next round the ring, sagging a little (none across a gap
## where more than one post is missing).
func _fence() -> void:
	var posts := []
	for t in layout.trees:
		if t.kind == ArenaLayout.Kind.POST:
			posts.append(t)
	if posts.size() < 2:
		return
	posts.sort_custom(func(a, b): return atan2(a.base.x, a.base.y) < atan2(b.base.x, b.base.y))
	var spacing := TAU / ArenaLayout.POST_COUNT
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in posts.size():
		var a: ArenaLayout.TreeData = posts[i]
		var b: ArenaLayout.TreeData = posts[(i + 1) % posts.size()]
		var gap := absf(wrapf(atan2(b.base.x, b.base.y) - atan2(a.base.x, a.base.y), -PI, PI))
		if gap > spacing * 2.5:
			continue
		for y in WIRES:
			var pa := Vector3(a.base.x, ArenaLayout.GROUND_Y + y, a.base.y)
			var pb := Vector3(b.base.x, ArenaLayout.GROUND_Y + y, b.base.y)
			_wire(verts, normals, pa, pb)
	var surf := []
	surf.resize(Mesh.ARRAY_MAX)
	surf[Mesh.ARRAY_VERTEX] = verts
	surf[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
	wires = MeshInstance3D.new()
	wires.name = "FenceWires"
	wires.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.3, 0.28)
	mat.metallic = 0.6
	mat.roughness = 0.55
	wires.material_override = mat
	add_child(wires)


## One span of wire from `a` to `b` (a thin square tube along a shallow catenary).
func _wire(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3) -> void:
	const SEGS := 10
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	var ring := [up, side, -up, -side]
	for k in SEGS:
		var t0 := float(k) / SEGS
		var t1 := float(k + 1) / SEGS
		var c0 := a.lerp(b, t0) - Vector3.UP * WIRE_SAG * 4.0 * t0 * (1.0 - t0)
		var c1 := a.lerp(b, t1) - Vector3.UP * WIRE_SAG * 4.0 * t1 * (1.0 - t1)
		for e in 4:
			var n0: Vector3 = ring[e]
			var n1: Vector3 = ring[(e + 1) % 4]
			var q := [c0 + n0 * WIRE_R, c1 + n0 * WIRE_R, c1 + n1 * WIRE_R, c0 + n1 * WIRE_R]
			var nn := (n0 + n1).normalized()
			for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				verts.append(v)
				normals.append(nn)


# --- Meshes and materials -------------------------------------------------------------------

func _batch(key: String, mesh: Mesh, xfs: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	var buf := PackedFloat32Array()   # (all at once: 12 floats of transform, rows of the basis and the origin, then colour)
	buf.resize(xfs.size() * 16)
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		var c: Color = colors[i]
		var o := i * 16
		buf[o] = t.basis.x.x; buf[o + 1] = t.basis.y.x; buf[o + 2] = t.basis.z.x; buf[o + 3] = t.origin.x
		buf[o + 4] = t.basis.x.y; buf[o + 5] = t.basis.y.y; buf[o + 6] = t.basis.z.y; buf[o + 7] = t.origin.y
		buf[o + 8] = t.basis.x.z; buf[o + 9] = t.basis.y.z; buf[o + 10] = t.basis.z.z; buf[o + 11] = t.origin.z
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
	mm.buffer = buf
	var at := PackedVector3Array()
	for t in xfs:
		at.append((t as Transform3D).origin)
	placed[key] = at
	var mi := MultiMeshInstance3D.new()
	mi.name = "Edge_" + key
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	return mi


## The escarpment's column (Escarpment.column) nearest angle `theta`, cached in steps of a milli-radian (10 cm at
## its foot): for placing things round it, not for its own heights.
var _columns := {}
func _column_near(theta: float) -> PackedFloat32Array:
	var k := roundi(esc.off(theta) * 1000.0)
	if not _columns.has(k):
		_columns[k] = esc.column(esc.at + k / 1000.0)
	return _columns[k]


func _heather_batch(xfs: Array, colors: Array, key: String) -> MultiMeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	s.is_hemisphere = true
	return _batch(key, s, xfs, colors)


func _heather_colour() -> Color:
	return Color(0.17, 0.09, 0.13).lerp(Color(0.1, 0.13, 0.06), _rng.randf()) * _rng.randf_range(0.8, 1.1)


func _rock_mat_instanced() -> Material:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter("strata", 0.0)
	return m


## A boulder: a low sphere with its vertices pushed in and out (unit size).
func _boulder_mesh() -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 9
	s.rings = 5
	var arr := s.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var p := v[i]
		var k := 0.8 + 0.4 * fposmod(sin(floorf(p.x * 9.0) * 12.9 + floorf(p.y * 9.0) * 78.2 + floorf(p.z * 9.0) * 37.7) * 43758.5, 1.0)
		v[i] = p * k
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	return st.commit()


## A grass tuft: blades fanning up and out from a point (unit size, vertex colour darker at the root).
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var az := TAU * i / 9.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(sin(az), 0.0, cos(az))
		var tip := out * rng.randf_range(0.2, 0.45) + Vector3.UP * rng.randf_range(0.6, 1.0)
		var side := out.cross(Vector3.UP).normalized() * 0.04
		var n := (out * 0.3 + Vector3.UP).normalized()
		for p in [-side, side, tip]:
			st.set_normal(n)
			st.set_color(Color(0.7, 0.72, 0.6) if p != tip else Color(1.0, 1.0, 0.92))
			st.add_vertex(p)
	return st.commit()


## A pine for far off and for the rock (unit height): a bare trunk, a flat-topped crown of a few dark lobes up
## the top third, as the wood's pines stand.
func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.3, 0.17, 0.1)
	var crown := Color(0.06, 0.1, 0.05)
	_cone(st, Vector3.ZERO, 0.018, 0.008, 0.9, 6, trunk)
	var lobes := [[Vector3(0.0, 0.84, 0.0), Vector3(0.2, 0.09, 0.2)], [Vector3(0.07, 0.74, 0.03), Vector3(0.15, 0.08, 0.14)],
			[Vector3(-0.06, 0.68, -0.05), Vector3(0.14, 0.07, 0.13)], [Vector3(0.02, 0.93, 0.05), Vector3(0.12, 0.06, 0.12)]]
	for l in lobes:
		_blob(st, l[0], l[1], crown)
	st.generate_normals()
	return st.commit()


## A pine grown on rock (unit height): low on its trunk, a tapering crown of a few tiers of drooping skirts, as
## the ledge and cliff-top pines stand in the concept.
func _rock_pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.3, 0.17, 0.1)
	_cone(st, Vector3.ZERO, 0.025, 0.006, 0.95, 6, trunk)
	var tiers := 5
	for i in tiers:
		var k := float(i) / tiers
		var y := 0.18 + k * 0.72
		var r := 0.26 * (1.0 - k) + 0.05
		var c := Color(0.06, 0.1, 0.05).lerp(Color(0.09, 0.13, 0.06), k)
		_skirt(st, Vector3(0.0, y, 0.0), r, 0.24 - k * 0.1, 9, c, float(i) * 0.7)
	st.generate_normals()
	return st.commit()


## A drooping skirt of foliage: a shallow cone, open below, its rim ragged.
func _skirt(st: SurfaceTool, top: Vector3, r: float, h: float, segs: int, c: Color, phase: float) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var r0 := r * (0.75 + 0.25 * sin(a0 * 3.0 + phase) * sin(a0 * 5.0 + phase * 2.0))
		var r1 := r * (0.75 + 0.25 * sin(a1 * 3.0 + phase) * sin(a1 * 5.0 + phase * 2.0))
		var p0 := top + Vector3(sin(a0) * r0, -h, cos(a0) * r0)
		var p1 := top + Vector3(sin(a1) * r1, -h, cos(a1) * r1)
		for p in [top + Vector3.UP * h * 0.3, p1, p0, p0, p1, top - Vector3.UP * h * 0.7]:
			st.set_color(c)
			st.add_vertex(p)


func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, segs: int, c: Color) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := base + Vector3(sin(a0) * r0, 0.0, cos(a0) * r0)
		var p1 := base + Vector3(sin(a1) * r0, 0.0, cos(a1) * r0)
		var q0 := base + Vector3(sin(a0) * r1, h, cos(a0) * r1)
		var q1 := base + Vector3(sin(a1) * r1, h, cos(a1) * r1)
		for p in [p0, p1, q1, p0, q1, q0]:
			st.set_color(c)
			st.add_vertex(p)


func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color) -> void:
	const RINGS := 4
	const SEGS := 8
	for i in RINGS:
		var t0 := PI * i / RINGS
		var t1 := PI * (i + 1) / RINGS
		for j in SEGS:
			var a0 := TAU * j / SEGS
			var a1 := TAU * (j + 1) / SEGS
			var pts := []
			for tp in [[t0, a0], [t0, a1], [t1, a1], [t1, a0]]:
				var lump := 1.0 + 0.18 * sin(tp[1] * 3.0 + tp[0] * 2.0)
				pts.append(c + Vector3(sin(tp[0]) * sin(tp[1]) * r.x * lump, cos(tp[0]) * r.y, sin(tp[0]) * cos(tp[1]) * r.z * lump))
			for p in [pts[0], pts[2], pts[1], pts[0], pts[3], pts[2]]:
				st.set_color(col)
				st.add_vertex(p)


func _fbm(p: Vector2) -> float:
	var s := 0.0
	var a := 0.5
	for i in 4:
		s += a * _vnoise(p)
		p = Vector2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8) * 2.03 + Vector2(1.7, 1.7)
		a *= 0.5
	return s / 0.9375


func _vnoise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var sd := float(layout.seed) * 17.3
	var h00 := fposmod(sin(i.x * 127.1 + i.y * 311.7 + sd) * 43758.5453, 1.0)
	var h10 := fposmod(sin((i.x + 1.0) * 127.1 + i.y * 311.7 + sd) * 43758.5453, 1.0)
	var h01 := fposmod(sin(i.x * 127.1 + (i.y + 1.0) * 311.7 + sd) * 43758.5453, 1.0)
	var h11 := fposmod(sin((i.x + 1.0) * 127.1 + (i.y + 1.0) * 311.7 + sd) * 43758.5453, 1.0)
	return lerpf(lerpf(h00, h10, f.x), lerpf(h01, h11, f.x), f.y)
