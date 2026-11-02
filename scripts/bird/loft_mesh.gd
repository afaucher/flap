class_name LoftMesh
extends RefCounted
## A tube mesh lofted every pose (the arm wing, the neck) without rebuilding it every pose. Built in full --
## positions, colours, feather coordinates, indices, smoothed normals, as BodyShape.tube_mesh builds them through
## SurfaceTool, which was most of a lofted surface's cost -- Between those full builds only the positions move: `update` writes the new
## positions and their normals straight into the mesh's vertex buffer (one call), leaving the colours, coordinates and
## indices as they are. The caller does a full `build` whenever what those carry would change.
##
## The normals are SurfaceTool.generate_normals' own: each triangle's unit normal summed at every vertex sharing its
## position (a tube's seam column, a ring collapsed to a point), normalised. Godot 4 keeps a mesh's vertex stream as
## all positions (float x 3), then per vertex its normal (octahedral, two u16) and tangent (two u16). The materials
## these lofts use don't read tangents.

var mesh := ArrayMesh.new()
var rows_n := 0          ## rings
var around := 0          ## points per ring
var has_uv := false      ## built with feather coordinates: each ring carries its first point again (a seam column)
var builds := 0         ## full builds so far (tests: they mustn't be every pose)
var positions := PackedVector3Array()   ## what the mesh draws now (written to it; the GPU's copy can't be read back)
var normals_now := PackedVector3Array()
var _vd := PackedByteArray()
var _noff := 0
var _flip := false       ## the triangles' winding as SurfaceTool's normals see it


## Build in full -- the same vertices, colours, coordinates and triangles as BodyShape.tube_mesh, in ring order (which
## `update` relies on; SurfaceTool re-indexes, so it can't be updated in place) -- and remember the vertex buffer.
func build(rows: Array, colors: Array, uvs: Array, uv2s: Array) -> void:
	builds += 1
	rows_n = rows.size()
	around = (rows[0] as Array).size()
	has_uv = not uvs.is_empty()
	var n := around
	var w := n + 1 if has_uv else n
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for i in rows_n:
		for j in w:
			pos.append(rows[i][j % n])
			if not colors.is_empty():
				col.append(colors[i][j % n])
			if has_uv:
				uv.append(uvs[i][j])
				uv2.append(uv2s[i][j])
	var idx := PackedInt32Array()
	for i in rows_n - 1:
		for j in n:
			var a := i * w + j
			var b := i * w + (j + 1) % w
			var c := (i + 1) * w + j
			var d := (i + 1) * w + (j + 1) % w
			idx.append_array([a, c, b, b, c, d])
	# The normals face out of the tube (its faces are wound outward, as SurfaceTool's normals then point).
	_flip = false
	var nrm := normals(rows)
	var ring: Array = rows[rows_n / 2]
	var centre := Vector3.ZERO
	for q in ring:
		centre += q / float(n)
	var probe := (rows_n / 2) * w
	if nrm[probe].dot(pos[probe] - centre) < 0.0:
		_flip = true
		nrm = normals(rows)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	if not colors.is_empty():
		arr[Mesh.ARRAY_COLOR] = col
	if has_uv:
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	positions = pos
	normals_now = nrm
	# The vertex buffer as built, written here rather than read back (a read back from the GPU stalls the frame).
	_noff = RenderingServer.mesh_surface_get_format_offset(mesh.surface_get_format(0), pos.size(), Mesh.ARRAY_NORMAL)
	_vd = pos.to_byte_array()
	_vd.resize(_noff + pos.size() * 8)
	_encode_normals(nrm)


## Whether a loft of `rings` rings of `points` each has the shape this mesh was built with (else build).
func fits(rings: int, points: int) -> bool:
	return not _vd.is_empty() and rings == rows_n and points == around


## Move the built mesh to `rows` (same rings, same points per ring): positions and normals only.
func update(rows: Array) -> void:
	var w := around + 1 if has_uv else around
	var pos := PackedVector3Array()
	pos.resize(rows_n * w)
	for i in rows_n:
		var row: Array = rows[i]
		for j in w:
			pos[i * w + j] = row[j % around]
	var nrm := normals(rows)
	var vd := pos.to_byte_array()   # (the positions block: all of them, before the normals)
	vd.append_array(_vd.slice(_noff))
	_vd = vd
	_encode_normals(nrm)
	RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(), 0, 0, _vd)
	positions = pos
	normals_now = nrm


## Each vertex's normal into the buffer (octahedral, two u16), and its tangent slot: these lofts' materials don't
## read tangents, so it gets the normal's code too.
func _encode_normals(nrm: PackedVector3Array) -> void:
	for k in nrm.size():
		var oc := nrm[k].octahedron_encode()
		var x := clampi(int(oc.x * 65535.0), 0, 65535)
		var y := clampi(int(oc.y * 65535.0), 0, 65535)
		_vd.encode_u16(_noff + k * 8, x)
		_vd.encode_u16(_noff + k * 8 + 2, y)
		_vd.encode_u16(_noff + k * 8 + 4, x)
		_vd.encode_u16(_noff + k * 8 + 6, y)


## The smoothed normals of `rows` as the mesh lays them out (w = around + 1 per ring with a seam column).
func normals(rows: Array) -> PackedVector3Array:
	var n := around
	var acc := PackedVector3Array()
	acc.resize(rows_n * n)
	acc.fill(Vector3.ZERO)
	for i in rows_n - 1:
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		for j in n:
			var jb := (j + 1) % n
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[jb]
			var c: Vector3 = r1[j]
			var d: Vector3 = r1[jb]
			# (tube_mesh's triangles a, c, b and b, c, d)
			var f1 := (c - a).cross(b - a)
			var f2 := (c - b).cross(d - b)
			if f1.length_squared() > 1e-24:
				f1 = f1.normalized()
				acc[i * n + j] += f1
				acc[(i + 1) * n + j] += f1
				acc[i * n + jb] += f1
			if f2.length_squared() > 1e-24:
				f2 = f2.normalized()
				acc[i * n + jb] += f2
				acc[(i + 1) * n + j] += f2
				acc[(i + 1) * n + jb] += f2
	# A ring collapsed to a point (a closed end) is one vertex to SurfaceTool: its normals summed.
	for i in rows_n:
		var row: Array = rows[i]
		if (row[0] as Vector3).distance_squared_to(row[n / 2]) < 1e-14:
			var all := Vector3.ZERO
			for j in n:
				all += acc[i * n + j]
			for j in n:
				acc[i * n + j] = all
	var w := n + 1 if has_uv else n
	var out := PackedVector3Array()
	out.resize(rows_n * w)
	var sg := -1.0 if _flip else 1.0
	for i in rows_n:
		for j in w:
			var v := acc[i * n + (j % n)]
			out[i * w + j] = (v * sg).normalized() if v.length_squared() > 1e-30 else Vector3.UP
	return out
