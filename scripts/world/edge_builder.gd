class_name EdgeBuilder
extends Node3D
## What lies beyond the arena's boundary (docs/design/arena_edge.md; the concept: docs/images/concepts/r5_edge_split.jpg,
## its top left and bottom right): the escarpment along its sector (Escarpment: the rock as one mesh, solid; squared
## blocks set into its faces in courses and fallen into its scree, heather and small pines on its ledges, pines along
## its top), open heath round the rest (grass tufts
## and heather thinning with distance, low rolling hills out to the horizon with stands of pines on them), and a
## two-strand wire fence along the edge posts. All outside the boundary; only the rock is solid.

const GRASS_IN := 15.0      ## m inside the posts the heath's grass reaches, thinning in among the last trees (drawn only)
const GRASS_FULL := 3.0     ## m past the posts it's at its thickest
const GRASS_TO := 300.0     ## m: as far out as it's sown; it ends where the ground rises into the hills (GRASS_RISE)
const GRASS_RISE := Vector2(1.0, 7.0)   ## m above the valley floor: where it starts thinning, and where it's gone
const HILLS_FROM := 150.0
const HILLS_TO := 2600.0
const WIRES := [0.6, 1.15]   ## m: the fence's two strands, up the posts
const WIRE_R := 0.012
const FENCE_EVERY := 2.8     ## m between fence posts (drawn only; every fourth or so an edge post, a perch)
const FENCE_POST := Vector2(0.07, 1.3)   ## m: their radius and height
const WIRE_SAG := 0.07       ## m at mid span
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
var slab_count := 0       ## block tops laid on the ledges and the pavement (_slabs)
var wires: MeshInstance3D
static var draw_always := false   ## build what's drawn only even with no screen (test_arena_edge)
var placed := {}      ## key -> PackedVector3Array: where each batch's instances stand (_batch)
var scree := []       ## the scree's blocks: [centre, size (m, its longest side), how far out to its toe 0..1]
var wall: MeshInstance3D   ## the cliff's faces: the sheet of its beds and joints (Escarpment.column's rows)
var _rock_grid := []   ## the rock's points and normals as drawn ([verts, normals]; _grid_verts)
var _rng := RandomNumberGenerator.new()


func build(l: ArenaLayout) -> void:
	layout = l
	esc = Escarpment.of(l)
	_rng.seed = l.seed * 31 + 17
	var t := Time.get_ticks_usec()
	var times := {}
	# (with no screen -- the headless tests' matches -- only what's solid: the rock and the scree's big blocks; what's
	# drawn only would cost every match seconds for nothing. draw_always: build it all anyway, for tests of it.)
	var drawn := draw_always or DisplayServer.get_name() != "headless"
	if esc != null:
		_rock()
		if drawn:
			_wall()
		times.rock = Time.get_ticks_usec() - t
		if drawn:
			_rock_dressing()
		_blocks()
		times.dressing = Time.get_ticks_usec() - t
	if not drawn:
		return
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
	# (layered, as the heath concept's: open heath rolling gently away from the fence; a low ridge out about half a
	# kilometre whose height swings round the ring, so its crest runs across the view on a slant; and far hills one
	# to two kilometres off, low on the horizon and blue with distance; a little roughness over all)
	var dir := Vector2(x, z) / r   # (noise round the ring from the direction, not the angle: no seam where it wraps)
	var k := smoothstep(HILLS_FROM, 260.0, r)
	var swell := 12.0 * _fbm(Vector2(x, z) * 0.004 + Vector2(1.0, 3.0))   # (the heath's own long, low swells)
	var mid_h := 8.0 + 40.0 * _fbm(dir * 1.3 + Vector2(2.0, 0.0)) * _fbm(dir * 0.55 + Vector2(4.0, 7.0)) * 1.6
	var mid := mid_h * exp(-pow((r - 520.0) / 140.0, 2.0))
	var far := (90.0 + 150.0 * _fbm(dir * 0.9 + Vector2(9.0, 1.0))) * smoothstep(950.0, 1700.0, r)
	var rough := 6.0 * (_fbm(Vector2(x, z) * 0.012 + Vector2(5.0, 9.0)) - 0.4) * smoothstep(150.0, 400.0, r)
	return k * maxf(0.0, swell + mid + far + rough + 1.5)



# --- The escarpment -------------------------------------------------------------------------

## The rock: a polar grid over the sector (fine across the tiers, coarser over the top), skipping the flat ground
## round it; collision from the same grid (the ledges and the stones are narrow: a coarser one rounds them off).
func _rock() -> void:
	var thetas := _thetas(0.5, esc.foot)
	var radii := PackedFloat32Array()
	var r := layout.boundary + 1.0   # (the talus reaches out almost to the boundary)
	while r < esc.foot + 40.0:
		radii.append(r)
		r += 0.3
	var far := esc.foot + Escarpment.BEND + 50.0   # (out to where the curving ends run)
	while r < far:
		radii.append(r)
		r += 1.5 if r < esc.foot + 90.0 else 3.0
	radii.append(far)
	var heights := PackedFloat32Array()
	for t in thetas:
		var col := esc.column(t)
		for rr in radii:
			heights.append(esc.height_in(col, rr))
	_rock_grid = _grid_verts(thetas, radii, heights)
	rock = MeshInstance3D.new()
	rock.name = "Escarpment"
	rock.mesh = _grid_mesh(_rock_grid, thetas.size(), radii.size(), true)
	rock.material_override = _rock_mat("marble_cliff_05", 7.0, Color(0.9, 0.92, 0.97), 1.0, true)
	(rock.material_override as ShaderMaterial).set_shader_parameter("cut_steep", true)   # (the wall draws those)
	# (not out at the sector's ends, where the wall is low and its sheet thin: there the height field draws its steps)
	(rock.material_override as ShaderMaterial).set_shader_parameter("cut_sector", Vector2(esc.at, Escarpment.HALF))
	(rock.material_override as ShaderMaterial).set_shader_parameter("fracture", 0.4)
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
	var reach_at := PackedFloat32Array()
	for ci in cols.size():
		reach_at.append(esc.reach(thetas[cols[ci]], layout.boundary))
	for ci in cols.size() - 1:
		for rj in rows.size() - 1:
			var pa := v[cols[ci] * nr + rows[rj]]
			var pb := v[cols[ci + 1] * nr + rows[rj]]
			var pc := v[cols[ci + 1] * nr + rows[rj + 1]]
			var pd := v[cols[ci] * nr + rows[rj + 1]]
			if maxf(maxf(pa.y, pb.y), maxf(pc.y, pd.y)) - ArenaLayout.GROUND_Y < 0.02:
				continue
			if Vector2(pa.x, pa.z).length() > reach_at[ci] + 6.0:   # (solid only where a bird can get to)
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


## The wall: Escarpment.column's rows up every bed (its panels set back and forward by their beds and joints, hard
## beds jutting over soft ones as overhanging lips), joined column to column into one sheet facing the wood. The height
## field under it (_rock) draws only its gentle parts -- the scree, the ledges, the top -- so where the wall
## overhangs, the sheet is what's seen. Its rows above the top close up on the top's edge.
func _wall() -> void:
	var thetas := _thetas(0.33, esc.foot)   # (fine enough to draw the faces' fracture facets)
	var nt := thetas.size()
	var cols := []
	for t in thetas:
		cols.append(esc.column(t))
	var nr := 0
	for c in cols:
		if not (c as PackedFloat32Array).is_empty():
			nr = int(c[4])
			break
	var verts := PackedVector3Array()
	verts.resize(nt * nr)
	for i in nt:
		var c: PackedFloat32Array = cols[i]
		var sn := sin(thetas[i])
		var cs := cos(thetas[i])
		for j in nr:
			var z := 0.0
			var r := esc.foot
			if not c.is_empty():
				z = c[5 + j * 2]
				r = c[6 + j * 2]
			verts[i * nr + j] = Vector3(sn * r, ArenaLayout.GROUND_Y + z, cs * r)
	var normals := PackedVector3Array()
	normals.resize(nt * nr)
	for i in nt:
		var inward := -Vector3(sin(thetas[i]), 0.0, cos(thetas[i]))
		for j in nr:
			var up := verts[i * nr + mini(j + 1, nr - 1)] - verts[i * nr + maxi(j - 1, 0)]
			var side := verts[mini(i + 1, nt - 1) * nr + j] - verts[maxi(i - 1, 0) * nr + j]
			var n := up.cross(side)
			if n.length_squared() < 1e-8:   # (a closed-up row: no slope of its own)
				n = inward
			n = n.normalized()
			normals[i * nr + j] = n if n.dot(inward) >= -0.2 else -n
	var idx := PackedInt32Array()
	for i in nt - 1:
		if (cols[i] as PackedFloat32Array).is_empty() or (cols[i + 1] as PackedFloat32Array).is_empty():
			continue
		for j in nr - 1:
			var q0 := i * nr + j
			var q1 := (i + 1) * nr + j
			var q2 := q1 + 1
			var q3 := q0 + 1
			if verts[q0].distance_squared_to(verts[q3]) + verts[q1].distance_squared_to(verts[q2]) < 1e-6:
				continue   # (closed up above the top, or squeezed out under the ground)
			var dr := Vector2(verts[q3].x, verts[q3].z).length() - Vector2(verts[q0].x, verts[q0].z).length()
			if dr > 0.8 and verts[q3].y - verts[q0].y < dr * 0.35:
				continue   # (a ledge between tiers: near level, set back; the height field draws it, as ground)
			idx.append_array(PackedInt32Array([q0, q1, q2, q0, q2, q3]))   # (facing the wood)
	var surf := []
	surf.resize(Mesh.ARRAY_MAX)
	surf[Mesh.ARRAY_VERTEX] = verts
	surf[Mesh.ARRAY_NORMAL] = normals
	surf[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
	wall = MeshInstance3D.new()
	wall.name = "Wall"
	wall.mesh = m
	var mat := _rock_mat("marble_cliff_05", 7.0, Color(0.9, 0.92, 0.97), 1.0, false)
	mat.set_shader_parameter("fracture", 0.7)
	wall.material_override = mat
	add_child(wall)


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
		var tal := esc.talus(_column_near(theta)).y
		if h < tal + 0.6:   # (the talus: its blocks, _scree_blocks)
			continue
		elif n.y > 0.93 and h > tal + 2.0:   # (a ledge or the top)
			var col := _column_near(theta)   # (the top: anywhere past where its last face ends, the plateau too)
			var on_top := not col.is_empty() and s + esc.foot > esc.top_start(col) - 0.3
			if on_top and _rng.randf() < 0.0035:   # (about one every 8 m along it)   # (along the top: pines, taller than the ledges')
				var tall := _rng.randf_range(9.0, 16.0)
				tx_top.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall)), at))
				tc_top.append(Color(1, 1, 1) * _rng.randf_range(0.85, 1.05))
			elif not on_top and Vector2(at.x, at.z).length() > layout.boundary + 8.0 and _rng.randf() < 0.1 * smoothstep(0.5, 0.72, _vnoise(Vector2(at.x, at.z) * 0.08)):   # (a few, in clumps; none leaning over the fence)
				var tall := _rng.randf_range(2.0, 5.5)
				var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(tall, tall, tall) * Vector3(_rng.randf_range(0.8, 1.2), 1.0, _rng.randf_range(0.8, 1.2)))
				px.append(Transform3D(b, at))
				pc.append(Color(1, 1, 1) * _rng.randf_range(0.85, 1.05))
			elif _rng.randf() < 0.25:
				var size := _rng.randf_range(0.5, 1.4)
				hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * 0.45, size)), at))
				hc.append(_heather_colour())
	_ledge_growth(hx, hc)
	ledge_pines = _batch("ledge_pines", _rock_pine_mesh(), px, pc)
	_batch("top_pines", _rock_pine_mesh(), tx_top, tc_top)
	_heather_batch(hx, hc, "ledge_heather")


## The rock's blocks (limestone breaks along its bedding and its joints, then at odd angles: flat faces, sharp
## edges, no two alike; _block_mesh): set into the faces in courses, each a little proud of or back from its neighbours, and
## fallen into the scree below, the biggest rolled furthest, out to its toe. Solid where a bird could meet them.
func _blocks() -> void:
	var meshes := []
	for k in BLOCK_SHAPES:
		meshes.append(_block_mesh(k))
	var sets := []   # per shape: [transforms, colours]
	for k in BLOCK_SHAPES:
		sets.append([[], []])
	_scree_blocks(sets)
	var slab_set := [[], []]
	_slabs(slab_set)
	var bm := BoxMesh.new()   # (flat-topped: stretched thin, a chamfered block's uneven corners shade as broken halves)
	var slabs := _batch("slabs", bm, slab_set[0], slab_set[1])
	slabs.material_override = _rock_mat_instanced()
	for k in BLOCK_SHAPES:
		var mi := _batch("blocks_%d" % k, meshes[k], sets[k][0], sets[k][1])
		mi.material_override = _rock_mat_instanced()
		block_batches.append(mi)


const BLOCK_SHAPES := 8


## The scree: blocks fallen from the faces, lying on its slope, sizes sorted down it (small against the foot, the
## biggest out at the toe), a few big ones out on the heath's edge; none on the perch stones or across the way in
## to them from the wood. The bigger ones solid.
func _scree_blocks(sets: Array) -> void:
	var stones := esc.stones()
	var solid := []
	for n in 7000:
		var theta := esc.at + _rng.randf_range(-1.0, 1.0) * Escarpment.HALF
		var w := esc.taper(theta)
		if w < 0.05 or _rng.randf() > w:
			continue
		var col := _column_near(theta)
		if col.is_empty():
			continue
		var tw := esc.talus(col).x
		var s := _rng.randf_range(-tw - 1.2, 0.4)
		var r: float = col[6] + s
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
		var toe := clampf(-s / tw, 0.0, 1.2)   # (0 at the foot, 1 at the toe)
		if _rng.randf() < 0.95 * smoothstep(0.35, 0.55, _soil(p)):   # (bare earth in patches: few blocks there)
			continue
		var size := lerpf(0.5, 2.6, toe) * _rng.randf_range(0.6, 1.35) * (1.8 if _rng.randf() < 0.08 else 1.0) * lerpf(0.6, 1.0, w)
		if r - size * 0.8 < layout.boundary + 1.5:   # (its whole width clear of the fence)
			continue
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
	for b in solid:   # (boxes a little inside the drawn block: its cut-off corners and faces)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (b[1] as Vector3) * 0.8
		cs.shape = box
		cs.transform = b[0]
		rock_body.add_child(cs)
	scree_solid = solid.size()
	# Heather and grass come up among the scree in patches, thickest out at its toe (more soil, less rock).
	var hx := []
	var hc := []
	for n in 7000:
		var theta := esc.at + _rng.randf_range(-1.0, 1.0) * Escarpment.HALF
		if esc.taper(theta) < 0.1:
			continue
		var col := _column_near(theta)
		if col.is_empty():
			continue
		var tw := esc.talus(col).x
		var s := _rng.randf_range(-tw - 1.0, 0.0)
		var r: float = col[6] + s
		var p := Vector2(sin(theta), cos(theta)) * r
		var toe := clampf(-s / tw, 0.0, 1.0)
		if r < layout.boundary + 1.0 or _rng.randf() > toe * smoothstep(0.4, 0.7, _vnoise(p * 0.11 + Vector2(2.0, 5.0))):
			continue
		var at := Vector3(p.x, ArenaLayout.GROUND_Y + esc.height(p.x, p.y), p.y)
		var size := _rng.randf_range(0.5, 1.2)
		hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size * 1.3, size * 0.55, size * 1.3)), at))
		hc.append(Color(0.62, 0.36, 0.5).lerp(Color(0.5, 0.55, 0.3), _rng.randf()) * _rng.randf_range(0.6, 0.95))
	var mi := _batch("scree_growth", _tuft_cards(), hx, hc)
	mi.material_override = _grass_mat()


## Heather and grass along every ledge, thick, as in the concept's green and purple bands: along each tier's ledge
## every half metre or so, a mound or a tuft somewhere across it.
func _ledge_growth(hx: Array, hc: Array) -> void:
	var tx := []
	var tc := []
	var arc := -Escarpment.HALF * esc.foot
	while arc < Escarpment.HALF * esc.foot:
		arc += _rng.randf_range(0.35, 0.8)
		var theta := esc.at + arc / esc.foot
		var col := _column_near(theta)
		if col.is_empty() or col[0] < 0.15:
			continue
		for l in esc.ledges(col, 0.8):
			var depth: float = float(l[1]) - float(l[0])
			# (in patches along the ledge, not a hedge: thick where a slow noise is high, bare elsewhere)
			if _rng.randf() > smoothstep(0.35, 0.65, _vnoise(Vector2(arc * 0.09, float(l[2]) * 0.3))):
				continue
			var r: float = float(l[0]) + _rng.randf_range(0.2, depth - 0.1)
			var at := Vector3(sin(theta) * r, ArenaLayout.GROUND_Y + esc.height_in(col, r), cos(theta) * r)
			if _rng.randf() < 0.55:
				var size := _rng.randf_range(0.6, 1.7)
				hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * 0.5, size)), at))
				hc.append(_heather_colour())
			else:
				var size := _rng.randf_range(0.5, 1.0)
				tx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size, size)), at))
				tc.append(Color(0.3, 0.3, 0.13).lerp(Color(0.15, 0.2, 0.07), _rng.randf()))
	var mi := _batch("ledge_tufts", _tuft_cards(), tx, tc)
	mi.material_override = _grass_mat()


## The talus's earthy patches (the shader's soil, the same noise): 0..1.
func _soil(p: Vector2) -> float:
	return _vnoise(p * 0.09 + Vector2(13.0, 13.0)) * 0.7 + _vnoise(p * 0.2 + Vector2(3.0, 9.0)) * 0.3


## Block tops (as the concept's plan: the ledges and the cliff's top are bare blocks, soil and thin grass in the joints
## between them, not lawns): flat blocks tiled across every ledge and over a strip of limestone pavement along the top's
## edge, SLAB.x..SLAB.y m along the cliff, in rows across, a little proud, turned with the cliff, gaps between (the
## grikes); none on a perch. Drawn only (a bird skims them; they stand under half a metre proud).
const SLAB := Vector3(2.5, 7.0, 12.0)   ## m: least and most along the cliff, and how deep the pavement runs past the top
func _slabs(set: Array) -> void:
	var perches := []
	for p in layout.perches:
		if p.tree_id == layout.rock_tree:
			perches.append(Vector2(p.position.x, p.position.z))
	var arc := -Escarpment.HALF * esc.foot
	var lim := Escarpment.HALF * esc.foot * Escarpment.BEND_FROM * 1.4   # (where the cliff is near: not out round its arms)
	arc = -lim
	while arc < lim:
		var len := _rng.randf_range(SLAB.x, SLAB.y)
		var theta := esc.at + (arc + len * 0.5) / esc.foot
		arc += len + _rng.randf_range(0.1, 0.6)
		var col := esc.column(theta)
		if col.is_empty() or col[0] < 0.4:
			continue
		var bands := []   # [from, to, height]: each ledge, and the pavement past the top
		for l in esc.ledges(col, 1.6):
			bands.append([float(l[0]) + 0.3, float(l[1]) - 0.3, float(l[2])])
		var ts := esc.top_start(col)
		bands.append([ts + 0.6, ts + SLAB.z, esc.height_in(col, ts + 2.0)])
		var out := Vector3(sin(theta), 0.0, cos(theta))
		var along := Vector3.UP.cross(out).normalized()
		for band in bands:
			var r: float = float(band[0]) + _rng.randf_range(0.0, 0.8)
			while r < float(band[1]) - 0.8:
				var depth := minf(_rng.randf_range(1.5, 5.0), float(band[1]) - r)
				var c := r + depth * 0.5
				r += depth + _rng.randf_range(0.1, 0.5)
				var along_off := _rng.randf_range(-0.25, 0.25) * len   # (rows not lined up)
				var len_here := len * _rng.randf_range(0.55, 1.0)
				var p := Vector2(sin(theta), cos(theta)) * c + Vector2(along.x, along.z) * along_off
				var near := false
				for q in perches:
					if (q as Vector2).distance_to(p) < 2.2:
						near = true
				if near or _rng.randf() < 0.22:   # (gaps: soil, a lost slab)
					continue
				var h := esc.height_in(col, c)
				var thick := _rng.randf_range(0.35, 0.8)
				var proud := _rng.randf_range(0.12, 0.4)
				var basis := Basis(along * len_here, Vector3.UP * thick, out * (depth - _rng.randf_range(0.1, 0.4)))
				basis = Basis(Vector3.UP, _rng.randf_range(-0.14, 0.14)) * Basis(along, _rng.randf_range(-0.04, 0.04)) * Basis(out, _rng.randf_range(-0.04, 0.04)) * basis
				set[0].append(Transform3D(basis, Vector3(p.x, ArenaLayout.GROUND_Y + h + proud - thick * 0.5, p.y)))
				set[1].append(_stone_colour())
				slab_count += 1


func _stone_colour() -> Color:
	return Color(1, 1, 1).lerp(Color(1.06, 1.02, 0.94), _rng.randf()) * _rng.randf_range(0.78, 1.12)


## A broken block, unit size: a cube cut by BLOCK_CUTS planes of its own (`variant`) -- limestone breaks along its
## joints and bedding and then at odd angles, so every face is flat and every edge sharp, but no two blocks are
## square: some corners sliced off small, some faces cut back far enough to turn the block wedge- or slab-shaped.
const BLOCK_CUTS := Vector2i(5, 9)   ## the least and most cuts a block takes
func _block_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911 + variant * 17
	var faces := []   # (each a PackedVector3Array, wound anticlockwise seen from outside)
	for a in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[a] = sgn
			var u := Vector3.ZERO
			u[(a + 1) % 3] = 0.5
			var v := Vector3.ZERO
			v[(a + 2) % 3] = 0.5
			var c := n * 0.5
			var quad := PackedVector3Array([c - u - v, c + u - v, c + u + v, c - u + v])
			if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(n) < 0.0:
				quad.reverse()
			faces.append(quad)
	for k in rng.randi_range(BLOCK_CUTS.x, BLOCK_CUTS.y):
		# (a plane at a random angle, most of them toward a corner or an edge; how deep it cuts: a sliver to a third)
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var reach := absf(n.x) * 0.5 + absf(n.y) * 0.5 + absf(n.z) * 0.5   # (the cube's farthest point along n)
		faces = _cut(faces, n, reach - rng.randf_range(0.06, 0.32) * (1.0 if rng.randf() < 0.75 else 1.6))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var poly: PackedVector3Array = f
		var n := (poly[1] - poly[0]).cross(poly[2] - poly[0]).normalized()
		for i in range(1, poly.size() - 1):   # (front faces wind clockwise seen from outside, in Godot)
			for q in [poly[0], poly[i + 1], poly[i]]:
				st.set_normal(n)
				st.add_vertex(q)
	return st.commit()


## The convex solid `faces` cut by the plane n . x = d (n unit), keeping what lies below it, the cut closed by a new
## face: each face clipped (Sutherland-Hodgman), the points on the plane gathered and ordered round it.
static func _cut(faces: Array, n: Vector3, d: float) -> Array:
	var out := []
	var cap := PackedVector3Array()
	for f in faces:
		var poly: PackedVector3Array = f
		var kept := PackedVector3Array()
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var da := n.dot(a) - d
			var db := n.dot(b) - d
			if da <= 0.0:
				kept.append(a)
			if (da < 0.0) != (db < 0.0) and absf(da - db) > 1e-9:
				var x := a.lerp(b, da / (da - db))
				kept.append(x)
				cap.append(x)
		if kept.size() >= 3:
			out.append(kept)
	if cap.size() >= 3:
		var c := Vector3.ZERO
		for q in cap:
			c += q
		c /= cap.size()
		var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := n.cross(u)
		var pts := Array(cap)
		pts.sort_custom(func(p, q): return atan2((p - c).dot(v), (p - c).dot(u)) < atan2((q - c).dot(v), (q - c).dot(u)))
		var poly := PackedVector3Array()
		for q in pts:   # (the clipped edges meet at shared points: drop the doubles)
			if poly.is_empty() or (q as Vector3).distance_to(poly[poly.size() - 1]) > 1e-5:
				poly.append(q)
		if poly.size() > 3 and poly[0].distance_to(poly[poly.size() - 1]) < 1e-5:
			poly.resize(poly.size() - 1)
		if poly.size() >= 3:
			if (poly[1] - poly[0]).cross(poly[2] - poly[0]).dot(n) < 0.0:
				poly.reverse()
			out.append(poly)
	return out


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
	for k in 320000:
		var theta := _rng.randf() * TAU
		var r := layout.boundary - GRASS_IN + pow(_rng.randf(), 2.1) * (GRASS_TO - layout.boundary + GRASS_IN)
		var x := sin(theta) * r
		var z := cos(theta) * r
		# (the forest floor gives way to grass gradually: thin in among the last trees, thinner in their shade, along
		# a ragged line, thickening to the sward past the posts)
		var fade := smoothstep(layout.boundary - GRASS_IN, layout.boundary + GRASS_FULL, r + (_vnoise(Vector2(x, z) * 0.06) - 0.5) * 12.0)
		if _rng.randf() > fade:
			continue
		if r < layout.boundary and _rng.randf() > lerpf(0.3, 1.0, Pinewood.light(layout, Vector2(x, z))):
			continue
		if esc != null and esc.height(x, z) > 0.05:   # (on the rock)
			continue
		var h := hill(x, z)
		# (out at the hills: thinning as the ground rises from the valley floor, along a ragged line, so the sward
		# ends at the foot of the slopes and the hills above are heath)
		if h > GRASS_RISE.x:
			var rise := smoothstep(GRASS_RISE.x, GRASS_RISE.y, h + (_vnoise(Vector2(x, z) * 0.03 + Vector2(7.0, 2.0)) - 0.5) * 4.0)
			if _rng.randf() < rise:
				continue
			fade *= 1.0 - rise * 0.5
		var at := Vector3(x, ArenaLayout.GROUND_Y + h, z)
		# (heather grows in patches: where a slow noise is high, low purple-brown tussocks instead of grass)
		var patch := _vnoise(Vector2(x, z) * 0.07 + Vector2(3.0, 1.0)) * 0.7 + _vnoise(Vector2(x, z) * 0.21 + Vector2(9.0, 4.0)) * 0.3
		# (the sward as the heath concept's: one cover, not plants in rows -- wide low tufts that overlap, of mixed
		# heights, golden straw to olive in drifts; heather in bigger, darker patches)
		if patch < 0.55 or _rng.randf() < 0.12:
			var size := _rng.randf_range(0.3, 0.75) * lerpf(0.6, 1.0, fade)   # (knee high and under, below the fence wire)
			tx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size * 1.9, size * _rng.randf_range(0.6, 1.2), size * 1.9)), at))
			var drift := _vnoise(Vector2(x, z) * 0.11 + Vector2(5.0, 8.0))
			tc.append(Color(1.05, 0.95, 0.7).lerp(Color(0.78, 0.82, 0.55), clampf(drift * 1.3 - 0.15 + _rng.randf_range(-0.2, 0.2), 0.0, 1.0)) * _rng.randf_range(0.55, 0.88))
		else:
			var size := _rng.randf_range(0.45, 0.95)
			hx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size * 1.6, size * 0.55, size * 1.6)), at))
			hc.append(Color(0.62, 0.38, 0.48).lerp(Color(0.5, 0.42, 0.36), _rng.randf()) * _rng.randf_range(0.75, 1.0))
	tufts = _batch("tufts", _tuft_cards(), tx, tc)
	tufts.material_override = _grass_mat("sward", true)
	heather = _batch("heather", _tuft_cards(), hx, hc)
	heather.material_override = _grass_mat("grass", true)
	for mi in [tufts, heather]:   # (as games do grass: its self-shadowing faked in the shader, not cast)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Stands of pines out on the hills (and along the escarpment's top, behind it).
func _far_stands() -> void:
	var xs := []
	var cs := []
	for k in 70:
		var theta := _rng.randf() * TAU
		var r := 260.0 + pow(_rng.randf(), 1.4) * 1300.0   # (few near, more far off: small in the view, as the concept's)
		var c := Vector2(sin(theta), cos(theta)) * r
		var n := _rng.randi_range(3, 12)
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
	var fx := []
	var fc := []
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in posts.size():
		var a: ArenaLayout.TreeData = posts[i]
		var b: ArenaLayout.TreeData = posts[(i + 1) % posts.size()]
		var gap := absf(wrapf(atan2(b.base.x, b.base.y) - atan2(a.base.x, a.base.y), -PI, PI))
		if gap > spacing * 2.5:
			continue
		# (between each pair of edge posts, thinner fence posts every FENCE_EVERY m or so, the wire stapled to each:
		# the line of posts the heath concept's fence draws to the vanishing point)
		var pa2 := Vector2(a.base)
		var pb2 := Vector2(b.base)
		var n := maxi(1, roundi(pa2.distance_to(pb2) / FENCE_EVERY))
		var stops := [pa2]
		for k in range(1, n):
			var q := pa2.lerp(pb2, (k + _rng.randf_range(-0.15, 0.15)) / n)
			stops.append(q)
			var lean := Basis(Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.05))
			fx.append(Transform3D(lean * Basis().scaled(Vector3(1.0, _rng.randf_range(0.92, 1.05), 1.0)), Vector3(q.x, ArenaLayout.GROUND_Y, q.y)))
			fc.append(Color(1, 1, 1) * _rng.randf_range(0.8, 1.1))
		stops.append(pb2)
		for y in WIRES:
			for k in stops.size() - 1:
				var s0: Vector2 = stops[k]
				var s1: Vector2 = stops[k + 1]
				_wire(verts, normals, Vector3(s0.x, ArenaLayout.GROUND_Y + y, s0.y), Vector3(s1.x, ArenaLayout.GROUND_Y + y, s1.y))
	var surf := []
	surf.resize(Mesh.ARRAY_MAX)
	surf[Mesh.ARRAY_VERTEX] = verts
	surf[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
	var post := CylinderMesh.new()
	post.top_radius = FENCE_POST.x * 0.85
	post.bottom_radius = FENCE_POST.x
	post.height = FENCE_POST.y
	post.radial_segments = 7
	post.rings = 1
	var pm := ArrayMesh.new()   # (its foot at the origin)
	var arr := post.get_mesh_arrays()
	var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in pv.size():
		pv[i].y += FENCE_POST.y * 0.5
	arr[Mesh.ARRAY_VERTEX] = pv
	pm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var fp := _batch("fence_posts", pm, fx, fc)
	(fp.material_override as StandardMaterial3D).albedo_color = ArenaBuilder.FENCE_POST_COLOR
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
	var m := _rock_mat("rock_boulder_dry", 2.4, Color(0.8, 0.83, 0.9), 0.0, false)
	m.set_shader_parameter("veg_amount", 0.15)   # (a little moss on the blocks' tops, not a lawn)
	m.set_shader_parameter("fracture", 0.5)
	m.set_shader_parameter("fracture_size", 0.5)
	return m


## The rock's material: rock.gdshader on the photoscan `scan` (assets/textures/rock; assets/LICENSES.md) repeating
## every `tile` m, toned by `tint`; with `scree`, the talus's stony dirt (rocky_trail) on the gentle ground low down,
## gray_rocks' rubble in patches over it.
static func _rock_mat(scan: String, tile: float, tint: Color, strata: float, scree: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	var p := "res://assets/textures/rock/%s/%s" % [scan, scan]
	m.set_shader_parameter("use_scan", true)
	m.set_shader_parameter("scan_albedo", load(p + "_diff_2k.jpg"))
	m.set_shader_parameter("scan_normal", load(p + "_nor_gl_2k.jpg"))
	m.set_shader_parameter("scan_arm", load(p + "_arm_2k.jpg"))
	m.set_shader_parameter("scan_tile", tile)
	m.set_shader_parameter("scan_tint", tint)
	m.set_shader_parameter("strata", strata)
	if scree:
		var g := "res://assets/textures/ground/rocky_trail/rocky_trail"
		var rb := "res://assets/textures/rock/gray_rocks/gray_rocks"
		m.set_shader_parameter("use_ground", true)
		m.set_shader_parameter("ground_albedo", load(g + "_diff_2k.jpg"))
		m.set_shader_parameter("ground_normal", load(g + "_nor_gl_2k.jpg"))
		m.set_shader_parameter("ground_tile", 2.0)
		m.set_shader_parameter("ground_tint", Color(0.5, 0.49, 0.52))   # (cooler and darker than the scan: grey-brown, as the concept)
		m.set_shader_parameter("rubble_albedo", load(rb + "_diff_2k.jpg"))
		m.set_shader_parameter("rubble_normal", load(rb + "_nor_gl_2k.jpg"))
		m.set_shader_parameter("rubble_tile", 1.8)
		m.set_shader_parameter("ground_y", ArenaLayout.GROUND_Y)
		m.set_shader_parameter("scree_top", (Escarpment.SKYLINE.y + Escarpment.SKYLINE.z) * 0.5 * Escarpment.TALUS.y + 1.0)
	return m


## A grass tussock as drawn: three cards of FoliageTex's grass crossed at 60 deg, standing on the origin (unit
## size), lit as the sward (normals mostly up).
func _tuft_cards() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := PI * i / 3.0
		var side := Vector3(cos(a), 0.0, sin(a)) * 0.5
		var face := Vector3(-sin(a), 0.0, cos(a))
		var n := (face * 0.3 + Vector3.UP).normalized()
		var q := [[-side, Vector2(0, 1)], [side, Vector2(1, 1)], [side + Vector3.UP, Vector2(1, 0)], [-side + Vector3.UP, Vector2(0, 0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(q[k][1])
			st.add_vertex(q[k][0])
	return st.commit()


## The grass cards' material: the foliage shader on FoliageTex's `tex` (grass: a tussock, for the heather; sward:
## meadow grass, for the sward) (the arena builder's, as the bracken's).
## With `heath`, lit as grass (foliage.gdshader's `grass`: normals up, root darkening faked, not cast).
func _grass_mat(tex := "grass", heath := false) -> Material:
	var extra := {"bend": 0.15, "clump_normal": 0.8, "sway": 0.02, "flutter": 0.01, "backlight": 0.6}
	if heath:
		extra.merge({"grass": 1.0, "root_ao": 0.35}, true)
	return ArenaBuilder._foliage_mat(tex, {"tex": tex, "tint": Color(1, 1, 1)}, extra)


## A grass tuft as geometry: blades fanning up and out from a point (unit size, vertex colour darker at the root).
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 18:   # (blades: each a tapering strip in two pieces, bending out, darker and greener at the root)
		var az := TAU * i / 18.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(sin(az), 0.0, cos(az))
		var tall := rng.randf_range(0.55, 1.1)
		var lean := rng.randf_range(0.12, 0.45)
		var base := out * rng.randf_range(0.0, 0.12)
		var mid := base + out * lean * 0.35 + Vector3.UP * tall * 0.55
		var tip := base + out * lean + Vector3.UP * tall
		var side := out.cross(Vector3.UP).normalized()
		var w0 := side * rng.randf_range(0.035, 0.06)
		var w1 := w0 * 0.6
		var n := (out * 0.25 + Vector3.UP).normalized()   # (lit as the sward, not blade by blade)
		var root := Color(0.45, 0.5, 0.35)
		var mc := Color(0.8, 0.8, 0.62)
		var tc := Color(1.05, 0.98, 0.78)
		for q in [[base - w0, root], [base + w0, root], [mid + w1, mc], [base - w0, root], [mid + w1, mc], [mid - w1, mc],
				[mid - w1, mc], [mid + w1, mc], [tip, tc]]:
			st.set_normal(n)
			st.set_color(q[1])
			st.add_vertex(q[0])
	return st.commit()


## A pine for far off and for the rock (unit height): a bare trunk, a flat-topped crown of a few dark lobes up
## the top third, as the wood's pines stand.
func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.3, 0.17, 0.1)
	var crown := Color(0.06, 0.1, 0.05)
	_cone(st, Vector3.ZERO, 0.02, 0.008, 0.85, 6, trunk)
	# (a Scots pine's crown seen from far off: rounded masses over the top half, wider than they're tall, one a
	# little off to the side)
	var lobes := [[Vector3(0.0, 0.86, 0.0), Vector3(0.2, 0.12, 0.2)], [Vector3(0.08, 0.76, 0.04), Vector3(0.17, 0.11, 0.16)],
			[Vector3(-0.07, 0.68, -0.05), Vector3(0.16, 0.1, 0.15)], [Vector3(0.03, 0.95, 0.04), Vector3(0.14, 0.08, 0.14)],
			[Vector3(-0.1, 0.84, 0.08), Vector3(0.13, 0.1, 0.13)], [Vector3(0.05, 0.6, -0.08), Vector3(0.12, 0.08, 0.11)]]
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
