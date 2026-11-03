class_name TimberMesh
extends RefCounted
## Builds timber (and its ironwork) as one ArrayMesh for planks.gdshader, each vertex carrying its own piece's
## frame so one draw call can hold a whole outpost's framing, every piece with its grain running its own way:
##   UV       (across, along)    m from the piece's middle: along is the grain
##   UV2      (through, seed)    the third local axis; the piece's seed (0 .. 1)
##   CUSTOM0  (half across, half along, half through, kind)
##   CUSTOM1  (pith across, pith through, scan board (-1: by seed), flags)
## A piece's frame (`xf`) is orthonormal: basis.x across, basis.y along the grain, basis.z through the board.
## The shader finds each face's own normal in that frame, so an end face (normal along the grain) draws end grain,
## a board's edge maps the scan by the through-board coordinate, and a face wider than a scan board is laid as
## several boards. `pieces` records what was built (name, frame, size, kind, its first vertex) for tests and probes.

enum Kind { BOARD, ROUND, BEAM, IRON, DARK, BRASS, PAINT, ROPE }
const PAINTED := 1   ## flag: the roundel paint may land here (planks.gdshader's roundel uniforms)

var pieces := []
var _st := SurfaceTool.new()
var _n := 0


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)


## A frame for a piece running from a to b (its grain), `across` as near to `hint` as the run allows.
static func frame_along(a: Vector3, b: Vector3, hint: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var x := (hint - y * hint.dot(y))
	if x.length() < 1e-4:
		x = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.RIGHT
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)


## Per-vertex attributes for the piece being written.
var _size := Vector3.ONE
var _kind := 0
var _seed := 0.0
var _pith := Vector2.ZERO
var _board := -1.0
var _flags := 0


func _begin(name: String, xf: Transform3D, size: Vector3, kind: int, sd: float, pith: Vector2, board: int, flags: int) -> void:
	_size = size
	_kind = kind
	_seed = sd
	_pith = pith
	_board = float(board)
	_flags = flags
	pieces.append({"name": name, "xform": xf, "size": size, "kind": kind, "first": _n})


func _vert(xf: Transform3D, p: Vector3, n: Vector3) -> void:
	_st.set_normal((xf.basis * n).normalized())
	_st.set_uv(Vector2(p.x, p.y))
	_st.set_uv2(Vector2(p.z, _seed))
	_st.set_custom(0, Color(_size.x * 0.5, _size.y * 0.5, _size.z * 0.5, float(_kind)))
	_st.set_custom(1, Color(_pith.x, _pith.y, _board, float(_flags)))
	_st.add_vertex(xf * p)
	_n += 1


## A triangle facing `n` (local): wound front-facing for Godot (clockwise seen from the front).
func _tri(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, n: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	if (b - a).cross(c - a).dot(n) > 0.0:
		_vert(xf, a, na)
		_vert(xf, c, nc)
		_vert(xf, b, nb)
	else:
		_vert(xf, a, na)
		_vert(xf, b, nb)
		_vert(xf, c, nc)


func _quad(xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(xf, a, b, c, n)
	_tri(xf, a, c, d, n)


## A square-sawn piece: `size` (across, along, through) about the frame's origin.
func box(name: String, xf: Transform3D, size: Vector3, kind: int, sd: float, pith := Vector2.ZERO, board := -1, flags := 0) -> void:
	_begin(name, xf, size, kind, sd, pith, board, flags)
	var h := size * 0.5
	for ax in 3:
		for sg: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = sg
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = h[(ax + 1) % 3]
			var v := Vector3.ZERO
			v[(ax + 2) % 3] = h[(ax + 2) % 3]
			var c := n * h[ax]
			_quad(xf, c - u - v, c + u - v, c + u + v, c - u + v, n)


## A round piece along the frame's y: radius r (top_r at +y, for a domed bolt head), `segs` round, capped.
func cylinder(name: String, xf: Transform3D, r: float, length: float, kind: int, sd: float, segs := 16, top_r := -1.0, flags := 0) -> void:
	if top_r < 0.0:
		top_r = r
	_begin(name, xf, Vector3(r * 2.0, length, r * 2.0), kind, sd, Vector2.ZERO, -1, flags)
	var hl := length * 0.5
	var slope := (r - top_r) / length
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n0 := (d0 + Vector3(0.0, slope, 0.0)).normalized()
		var n1 := (d1 + Vector3(0.0, slope, 0.0)).normalized()
		var p00 := d0 * r - Vector3(0.0, hl, 0.0)
		var p10 := d1 * r - Vector3(0.0, hl, 0.0)
		var p01 := d0 * top_r + Vector3(0.0, hl, 0.0)
		var p11 := d1 * top_r + Vector3(0.0, hl, 0.0)
		var nm := (n0 + n1).normalized()
		_tri(xf, p00, p10, p11, nm, n0, n1, n1)
		_tri(xf, p00, p11, p01, nm, n0, n1, n0)
		_tri(xf, Vector3(0.0, hl, 0.0), p01, p11, Vector3.UP)
		_tri(xf, Vector3(0.0, -hl, 0.0), p00, p10, Vector3.DOWN)


## A hex nut / bolt head on a washer, standing `n` out from a face at `at` (the head's axis along n).
func bolt(at: Vector3, n: Vector3, r: float, sd: float) -> void:
	var xf := frame_along(at, at + n, Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
	var w := r * 1.7
	var wt := r * 0.22
	cylinder("washer", Transform3D(xf.basis, at + n * wt * 0.5), w, wt, Kind.IRON, sd, 10)
	cylinder("bolt", Transform3D(xf.basis, at + n * (wt + r * 0.35)), r, r * 0.7, Kind.IRON, sd, 6, r * 0.8)


## A flat iron plate on a face: centre `at`, its normal `n`, `u` along its length; (length, width, thick).
func plate(at: Vector3, n: Vector3, u: Vector3, size: Vector3, sd: float) -> void:
	var y := u.normalized()
	var z := n.normalized()
	var x := y.cross(z).normalized()
	box("plate", Transform3D(Basis(x, y, z), at + z * size.z * 0.5), Vector3(size.y, size.x, size.z), Kind.IRON, sd)


func vertex_count() -> int:
	return _n


func commit() -> ArrayMesh:
	return _st.commit()
