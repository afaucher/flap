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

enum Kind { BOARD, ROUND, BEAM, IRON, DARK, BRASS, PAINT, ROPE, CLOTH }
const PAINTED := 1   ## flag: the roundel paint may land here (planks.gdshader's roundel uniforms)
const STENCIL := 2   ## flag: stencilled marks on a painted box's broad faces
const GAPPED := 4    ## flag: a board laid edge to edge with others: its edges are down in the shadowed gaps
## CLOTH's pattern, by its scan board slot: red and white bands (a windsock), a pennant halved orange and white.
enum Cloth { SOCK, PENNANT }

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
	_vert_at(xf * p, p, (xf.basis * n).normalized())


## A vertex at `at` (mesh space) whose piece-frame coordinates are `p` (for shapes that aren't a frame's box).
func _vert_at(at: Vector3, p: Vector3, n: Vector3) -> void:
	_st.set_normal(n)
	_st.set_uv(Vector2(p.x, p.y))
	_st.set_uv2(Vector2(p.z, _seed))
	_st.set_custom(0, Color(_size.x * 0.5, _size.y * 0.5, _size.z * 0.5, float(_kind)))
	_st.set_custom(1, Color(_pith.x, _pith.y, _board, float(_flags)))
	_st.add_vertex(at)
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
func cylinder(name: String, xf: Transform3D, r: float, length: float, kind: int, sd: float, segs := 16, top_r := -1.0, flags := 0, board := -1) -> void:
	if top_r < 0.0:
		top_r = r
	_begin(name, xf, Vector3(r * 2.0, length, r * 2.0), kind, sd, Vector2.ZERO, board, flags)
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


## A domed cap along the frame's y: radius r at its foot (y = 0), `h` high, `rings` bands up to the crown.
func dome(name: String, xf: Transform3D, r: float, h: float, kind: int, sd: float, segs := 10, rings := 3) -> void:
	_begin(name, xf, Vector3(r * 2.0, h * 2.0, r * 2.0), kind, sd, Vector2.ZERO, -1, 0)
	# (a spherical cap: the sphere's radius R and centre below the foot)
	var R := (r * r + h * h) / (2.0 * h)
	var c := Vector3(0.0, h - R, 0.0)
	var a_max := asin(clampf(r / R, 0.0, 1.0))
	var pt := func(i: int, k: int) -> Vector3:
		var a := a_max * (1.0 - float(k) / rings)
		var th := TAU * i / segs
		return c + Vector3(sin(a) * cos(th), cos(a), sin(a) * sin(th)) * R
	for k in rings:
		for i in segs:
			var p00: Vector3 = pt.call(i, k)
			var p10: Vector3 = pt.call(i + 1, k)
			var p01: Vector3 = pt.call(i, k + 1)
			var p11: Vector3 = pt.call(i + 1, k + 1)
			_tri(xf, p00, p10, p11, (p00 + p10 + p11) / 3.0 - c, (p00 - c).normalized(), (p10 - c).normalized(), (p11 - c).normalized())
			if k < rings - 1:
				_tri(xf, p00, p11, p01, (p00 + p11 + p01) / 3.0 - c, (p00 - c).normalized(), (p11 - c).normalized(), (p01 - c).normalized())


## A carriage bolt: a domed head on a washer, standing `n` out from a face at `at`.
func bolt(at: Vector3, n: Vector3, r: float, sd: float) -> void:
	var xf := frame_along(at, at + n, Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
	var w := r * 1.6
	var wt := r * 0.2
	cylinder("washer", Transform3D(xf.basis, at + n * wt * 0.5), w, wt, Kind.IRON, sd, 10)
	dome("bolt", Transform3D(xf.basis, at + n * wt), r, r * 0.55, Kind.IRON, sd)


## A ring of rope (a coil's turn): centre `c`, axis `n`, radius R, the rope's radius r. The rope's own frame (its
## along round the ring, across and through its section) is what the shader's rope pattern reads.
func torus(name: String, c: Vector3, n: Vector3, R: float, r: float, kind: int, sd: float, segs := 20, sides := 6) -> void:
	var y := n.normalized()
	var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	var z := y.cross(x)
	_begin(name, Transform3D(Basis(x, y, z), c), Vector3(r * 2.0, TAU * R, r * 2.0), kind, sd, Vector2.ZERO, -1, 0)
	var at := func(i: int, j: int) -> Array:   # [position, frame coordinates, normal]
		var th := TAU * i / segs
		var ph := TAU * j / sides
		var radial := x * cos(th) + z * sin(th)
		var nn := radial * cos(ph) + y * sin(ph)
		return [c + radial * R + nn * r, Vector3(r * cos(ph), R * th - PI * R, r * sin(ph)), nn]
	for i in segs:
		for j in sides:
			var a: Array = at.call(i, j)
			var b: Array = at.call(i + 1, j)
			var cc: Array = at.call(i + 1, j + 1)
			var d: Array = at.call(i, j + 1)
			for tri in [[a, b, cc], [a, cc, d]]:
				var fn: Vector3 = (tri[0][2] + tri[1][2] + tri[2][2]) / 3.0
				var t3: Array = tri
				if (t3[1][0] - t3[0][0]).cross(t3[2][0] - t3[0][0]).dot(fn) > 0.0:
					t3 = [tri[0], tri[2], tri[1]]
				for v in t3:
					_vert_at(v[0], v[1], v[2])


## A cloth triangle, seen from both sides: hoisted along a..b, its tip at `tip` (pattern `cloth`: Cloth).
func pennant(name: String, a: Vector3, b: Vector3, tip: Vector3, cloth: int, sd: float) -> void:
	var y := (tip - (a + b) * 0.5)
	var ln := y.length()
	y = y / ln
	var x := (b - a - y * (b - a).dot(y)).normalized()
	var z := x.cross(y)
	var mid := (a + b) * 0.5 + y * ln * 0.5
	_begin(name, Transform3D(Basis(x, y, z), mid), Vector3((b - a).length(), ln, 0.002), Kind.CLOTH, sd, Vector2.ZERO, cloth, 0)
	var loc := func(p: Vector3) -> Vector3:
		return Vector3((p - mid).dot(x), (p - mid).dot(y), (p - mid).dot(z))
	for sgn: float in [1.0, -1.0]:
		var pts := [a, b, tip] if sgn > 0.0 else [a, tip, b]
		var nn := z * sgn
		if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(nn) > 0.0:
			pts = [pts[0], pts[2], pts[1]]
		for p in pts:
			_vert_at(p, loc.call(p), nn)


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
