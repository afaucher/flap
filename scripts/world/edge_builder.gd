class_name EdgeBuilder
extends Node3D
## What lies beyond the arena's boundary (docs/design/arena_edge.md; the concept: docs/images/concepts/r5_edge_split.jpg,
## its top left and bottom right): the escarpment along its sector (Escarpment: the rock as one mesh, solid; squared
## blocks set into its faces in courses and fallen into its scree, heather and small pines on its ledges, pines along
## its top), open heath round the rest (grass tufts
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
var block_batches: Array[MultiMeshInstance3D] = []   ## the rock's blocks, one batch per shape (_blocks)
var scree_solid := 0      ## how many of the scree's blocks are solid
var wires: MeshInstance3D
var placed := {}      ## key -> PackedVector3Array: where each batch's instances stand (_batch)
var scree := []       ## the scree's blocks: [centre, size (m, its longest side), how far out to its toe 0..1]
var face_count := 0   ## blocks set into the faces (with their lips)
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
		_blocks()
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


## Heather and small pines on the ledges, pines along the top: placed on points of the rock's own grid (its
## heights and normals as drawn).
func _rock_dressing() -> void:
	var v: PackedVector3Array = _rock_grid[0]
	var nn: PackedVector3Array = _rock_grid[1]
	var px := []
	var pc := []
	var tx_top := []
	var tc_top := []
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
		if s < 1.0 and h < Escarpment.SCREE_H * 1.2:   # (the scree: its blocks, _scree_blocks)
			continue
		elif n.y > 0.93 and h > Escarpment.SCREE_H + 2.0:   # (a ledge or the top)
			var col := _column_near(theta)   # (the top: anywhere past where its last face ends, the plateau too)
			var on_top := not col.is_empty() and s + esc.foot - col[1] > col[col.size() - 2] - 0.3
			if on_top and _rng.randf() < 0.0035:   # (about one every 8 m along it)   # (along the top: pines, taller than the ledges')
				var tall := _rng.randf_range(9.0, 16.0)
				tx_top.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall)), at))
				tc_top.append(Color(1, 1, 1) * _rng.randf_range(0.85, 1.05))
			elif not on_top and _rng.randf() < 0.1:
				var tall := _rng.randf_range(2.0, 5.5)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall) * Vector3(_rng.randf_range(0.8, 1.2), 1.0, _rng.randf_range(0.8, 1.2)))
				px.append(Transform3D(b, at))
				pc.append(Color(1, 1, 1) * _rng.randf_range(0.85, 1.05))
			elif _rng.randf() < 0.7:
				var size := _rng.randf_range(0.5, 1.4)
				hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * 0.45, size)), at))
				hc.append(_heather_colour())
	ledge_pines = _batch("ledge_pines", _rock_pine_mesh(), px, pc)
	_batch("top_pines", _rock_pine_mesh(), tx_top, tc_top)
	_heather_batch(hx, hc, "ledge_heather")


## The rock's blocks (limestone breaks along its bedding and its joints into squared blocks, edges sharp, a few
## corners knocked off): set into the faces in courses, each a little proud of or back from its neighbours, and
## fallen into the scree below, the biggest rolled furthest, out to its toe. Solid where a bird could meet them.
func _blocks() -> void:
	var meshes := []
	for k in BLOCK_SHAPES:
		meshes.append(_block_mesh(k))
	var sets := []   # per shape: [transforms, colours]
	for k in BLOCK_SHAPES:
		sets.append([[], []])
	_face_blocks(sets)
	for k in BLOCK_SHAPES:
		face_count += (sets[k][0] as Array).size()
	_scree_blocks(sets)
	for k in BLOCK_SHAPES:
		var mi := _batch("blocks_%d" % k, meshes[k], sets[k][0], sets[k][1])
		mi.material_override = _rock_mat_instanced()
		block_batches.append(mi)


const BLOCK_SHAPES := 4
const COURSE := Vector2(1.2, 3.6)      ## m: a course's height on the faces
const FACE_BLOCK := Vector2(4.5, 14.0) ## m: a face block's length along the cliff (beds longer than they're high)
const MASS := 1.1                      ## m: how far a mass of blocks (tens of metres along) stands out or back
const PROUD := Vector2(-0.08, 0.16)    ## m: and each block on its own, out of its mass's face (less than 0: set back)
const LIP := Vector3(0.3, 0.35, 0.75)  ## a bedding lip on top of a course, the chance of one, its height, how far it overhangs


## Courses of blocks up every face of every tier: each column of blocks FACE_BLOCK long along the cliff, each block
## COURSE high, set at the face where it stands at that height, PROUD of it or back.
func _face_blocks(sets: Array) -> void:
	var arc := -Escarpment.HALF * esc.foot
	while arc < Escarpment.HALF * esc.foot:
		var len := _rng.randf_range(FACE_BLOCK.x, FACE_BLOCK.y)
		var theta := esc.at + (arc + len * 0.5) / esc.foot
		arc += len
		var col := esc.column(theta)
		if col.is_empty() or col[0] < 0.08:
			continue
		var out := Vector3(sin(theta), 0.0, cos(theta))   # (away from the wood, into the rock)
		var along := Vector3.UP.cross(out).normalized()
		for i in Escarpment.TIERS.size():
			var b := 3 + i * 6
			var e: float = col[b]
			var face: float = col[b + 1]
			var face_h: float = col[b + 2]
			var h0: float = col[b + 4]
			if face_h < 1.0 or esc.gully(arc - len * 0.5) > 0.2:   # (none in a cleft: it stays dark and deep)
				continue
			var y := 0.0
			while y < face_h - 0.4:
				var ch := minf(_rng.randf_range(COURSE.x, COURSE.y), face_h - y)
				var t := (y + ch * 0.5) / face_h   # (where the face stands at this height)
				var r := col[1] + e + face * t
				var proud := MASS * (_mass(arc, i) - 0.5) * 2.0 + _rng.randf_range(PROUD.x, PROUD.y)
				var depth := 2.2 + MASS * 2.0
				var top_gap := 0.04 if y + ch >= face_h - 0.01 else 0.0   # (the top course: just under the ledge)
				var centre := out * (r - proud + depth * 0.5) + Vector3.UP * (ArenaLayout.GROUND_Y + h0 + y + (ch - top_gap) * 0.5)
				var basis := Basis(along * (len - _rng.randf_range(0.02, 0.12)), Vector3.UP * (ch - top_gap - _rng.randf_range(0.01, 0.04)), out * depth)
				basis = Basis(Vector3.UP, _rng.randf_range(-0.03, 0.03)) * Basis(along, _rng.randf_range(-0.02, 0.02)) * basis
				var k := _rng.randi() % BLOCK_SHAPES
				sets[k][0].append(Transform3D(basis, centre))
				sets[k][1].append(_stone_colour())
				if top_gap == 0.0 and ch > 2.0 and _rng.randf() < LIP.x:   # (a harder bed: it juts, a shadow under it)
					var lip_out := proud + LIP.z * _rng.randf_range(0.6, 1.3)
					var lip_c := out * (r - lip_out + depth * 0.5) + Vector3.UP * (ArenaLayout.GROUND_Y + h0 + y + ch - LIP.y * 0.5)
					var lip_b := Basis(along * (len * _rng.randf_range(0.5, 1.0)), Vector3.UP * LIP.y, out * depth)
					sets[k][0].append(Transform3D(lip_b, lip_c))
					sets[k][1].append(_stone_colour())
				y += ch


## The scree: blocks fallen from the faces, lying on its slope, sizes sorted down it (small against the foot, the
## biggest out at the toe), a few big ones out on the heath's edge; none on the perch stones or across the way in
## to them from the wood. The bigger ones solid.
func _scree_blocks(sets: Array) -> void:
	var stones := esc.stones()
	var solid := []
	for n in 5200:
		var theta := esc.at + _rng.randf_range(-1.0, 1.0) * Escarpment.HALF
		var w := esc.taper(theta)
		if w < 0.05 or _rng.randf() > w:
			continue
		var col := _column_near(theta)
		if col.is_empty():
			continue
		var s := _rng.randf_range(-Escarpment.SCREE - 1.2, 0.4)
		var r: float = col[1] + s
		var p := Vector2(sin(theta), cos(theta)) * r
		var clear := true
		for st in stones:
			var c: Vector2 = st[0]
			var to_wood := -c.normalized()
			var rel := p - c
			var along := rel.dot(to_wood)
			if rel.length() < float(st[1]) + 2.2 or (along > 0.0 and along < 8.0 and absf(rel.dot(Vector2(-to_wood.y, to_wood.x))) < 2.0):
				clear = false
		if not clear or r < layout.boundary + 1.5:
			continue
		var toe := clampf(-s / Escarpment.SCREE, 0.0, 1.2)   # (0 at the foot, 1 at the toe)
		var size := lerpf(0.5, 2.6, toe) * _rng.randf_range(0.6, 1.35) * (1.8 if _rng.randf() < 0.08 else 1.0) * lerpf(0.6, 1.0, w)
		var dims := Vector3(size, size * _rng.randf_range(0.4, 0.75), size * _rng.randf_range(0.55, 1.0))
		var h := esc.height_in(col, r)
		var at := Vector3(p.x, ArenaLayout.GROUND_Y + h, p.y)
		var nrm := esc.normal(p.x, p.y, 0.4)
		var up := (nrm + Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.25).normalized()
		var fwd := Vector3(sin(theta), 0.0, cos(theta)).rotated(Vector3.UP, _rng.randf_range(-0.9, 0.9))
		var x := up.cross(fwd).normalized()
		var z := x.cross(up).normalized()
		var basis := Basis(x * dims.x, up * dims.y, z * dims.z)
		var centre := at + up * dims.y * _rng.randf_range(0.15, 0.4)   # (bedded into the scree, some sitting high: a heap)
		var k := _rng.randi() % BLOCK_SHAPES
		sets[k][0].append(Transform3D(basis, centre))
		sets[k][1].append(_stone_colour())
		scree.append([centre, maxf(dims.x, dims.z), toe])
		if size > 1.3:   # (a bird skimming the scree meets these; the small ones only scuff)
			solid.append([Transform3D(Basis(x, up, z), centre), dims])
	for b in solid:   # (boxes a little inside the drawn block: its chamfers and knocked-off corners)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (b[1] as Vector3) * 0.92
		cs.shape = box
		cs.transform = b[0]
		rock_body.add_child(cs)
	scree_solid = solid.size()


## How far the mass of blocks at `arc` m along tier `i` stands out, 0..1: masses tens of metres long.
func _mass(arc: float, i: int) -> float:
	return esc._n1(arc / 23.0 + i * 3.7) * 0.7 + esc._n1(arc / 9.0 + i * 1.9 + 4.0) * 0.3


func _stone_colour() -> Color:
	return Color(1, 1, 1).lerp(Color(1.06, 1.02, 0.94), _rng.randf()) * _rng.randf_range(0.78, 1.12)


## A squared block, unit size: its edges chamfered narrow, each corner pulled in a little by its own amount and one
## or two knocked right off, so no two shapes are quite the same (`variant`). Flat faces, sharp edges.
func _block_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + variant * 17
	var bevel := 0.035
	var corners := []
	var pull := []
	for i in 8:
		var c := Vector3(0.5 if i & 1 else -0.5, 0.5 if i & 2 else -0.5, 0.5 if i & 4 else -0.5)
		corners.append(c)
		var knock := 0.18 if rng.randf() < 0.22 else rng.randf_range(0.0, 0.06)
		pull.append(Vector3(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0)) * knock)
	# P(c, a): corner c's point on the face across axis a (the other two coordinates drawn in by the chamfer and the
	# corner's own pull).
	var pt := func(i: int, a: int) -> Vector3:
		var c: Vector3 = corners[i]
		var q := c
		for ax in 3:
			var inward := -signf(c[ax])
			var d: float = (pull[i] as Vector3)[ax]
			q[ax] += inward * (d if ax == a else bevel + d)
		return q
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var g := (b - a).cross(c - a)
		if g.length_squared() < 1e-10:
			return
		if g.dot((a + b + c) / 3.0) > 0.0:   # (front faces wind clockwise seen from outside: the cross points in)
			var t := b
			b = c
			c = t
		var n := -(b - a).cross(c - a).normalized()
		for v in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		tri.call(a, b, c)
		tri.call(a, c, d)
	for a in 3:   # the six faces
		for sgn in [-1, 1]:
			var ids := []
			for i in 8:
				if signf((corners[i] as Vector3)[a]) == float(sgn):
					ids.append(i)
			var b1 := (a + 1) % 3
			var b2 := (a + 2) % 3
			ids.sort_custom(func(p, q): return atan2((corners[p] as Vector3)[b2], (corners[p] as Vector3)[b1]) < atan2((corners[q] as Vector3)[b2], (corners[q] as Vector3)[b1]))
			quad.call(pt.call(ids[0], a), pt.call(ids[1], a), pt.call(ids[2], a), pt.call(ids[3], a))
	for i in 8:   # the edges' chamfers and the corners
		for a in 3:
			var j := i ^ (1 << a)
			if j < i:
				continue
			var b1 := (a + 1) % 3
			var b2 := (a + 2) % 3
			quad.call(pt.call(i, b1), pt.call(j, b1), pt.call(j, b2), pt.call(i, b2))
		tri.call(pt.call(i, 0), pt.call(i, 1), pt.call(i, 2))
	return st.commit()


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
