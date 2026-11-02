class_name Saddle
extends Node3D
## The war saddle and launcher, fitted to one bird's back (BackSurface), rig space.
##
## Where it can go (tests/probe_tack_fit.gd): folded or beating, the wings never come higher round the trunk
## than about 35 deg of elevation from its centre, so a strip along the back is always free; the saddle stays
## well inside it, and the neck and head stay ahead of the pommel even with the neck retracted on a perch.
##
## Sizes are a man's, scaled with the rider (TackMesh: a 7.5 cm pilot is 1:23): the saddle, the footrest and
## the launcher are designed in real cm in a frame laid on the back -- (x across, y off the surface, z aft, all
## real cm) from the seat's middle -- so everything follows the back's curve and sits snugly on it.
##
## It is held on as wildlife biologists hold a backpack on a raptor: two loops, each round one wing's root --
## from the saddle's front corner over the shoulder in front of the wing, down to a ring on the breast, back up
## under the wing behind it to the saddle's rear corner -- so the straps lie flat on the body under the folded
## wing and never cross the wing itself.
##
## Layers: a sheepskin pad, the leather skirt (stitched, with knee rolls), the quilted seat with its pommel and
## cantle, brass fittings (D-rings, buckles, keepers, the breast ring), a canvas kit roll, the footrest (blued
## struts, a brass bar), and the launcher on the pommel: six brass rocket tubes in two banded clusters, a rack of
## three seekers on top, a blued breech with a roundel, spade grips and a ring sight. The rounds in it show
## what's left (set_ammo).

const FREE_ELEVATION := 50.0   ## deg: the saddle stays above this elevation round the trunk (wings: <= ~35)

var rig_body: BodyShape
var surf: BackSurface
var cm := 100.0               ## real cm per model metre
var seat_z := 0.0             ## rig z of the seat's middle
## Anchor points (rig space, unscaled): where the rider sits, holds and stands.
var seat_point := Vector3.ZERO
var seat_normal := Vector3.UP
var grips: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var holds: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## standing: leather hand loops on the back of the rack
var pegs: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var knees: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## kneeling: where the knees rest (on the flaps)
var heels: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## kneeling: where the ankles rest (shins folded back)
var muzzle := Vector3.ZERO
var launcher_xf := Transform3D()
var rockets: Array[MeshInstance3D] = []
var seekers: Array[MeshInstance3D] = []
var outline: Array = []        ## the skirt's outline (rig points), for tests
var strap_paths: Array = []    ## each harness strap's centre line (rig points), for tests
var _tms := {}


## Build for `rig` with a rider `rider_h` m tall.
func build(rig: BirdRig, rider_h: float) -> void:
	rig_body = rig.body
	surf = BackSurface.new(rig.body)
	cm = 100.0 * TackMesh.REAL_H / rider_h
	seat_z = rig.body.shoulder.z + 6.0 / cm
	_pad()
	_skirt()
	_seat()
	_footrest()
	_kit_roll()
	_harness()
	_launcher()
	for id in _tms:
		var mi := MeshInstance3D.new()
		mi.name = "Tack_" + id
		mi.mesh = (_tms[id] as TackMesh).commit()
		mi.material_override = TackMaterials.get_mat(id)
		add_child(mi)


func _tm(id: String) -> TackMesh:
	if not _tms.has(id):
		_tms[id] = TackMesh.new(TackMesh.REAL_H / cm * 100.0)
	return _tms[id]


## A point in the saddle frame (real cm: x across, y off the surface, z aft of the seat's middle).
func at(x: float, y: float, z: float) -> Vector3:
	return surf.point(seat_z + z / cm, x / cm, y / cm)


func normal_at(x: float, z: float) -> Vector3:
	return surf.normal(seat_z + z / cm, x / cm)


# --- Panels -----------------------------------------------------------------------------------------------

## A panel lying on the back: from z0 to z1 (real cm, saddle frame), half width hw(f) (f 0 front .. 1 back;
## real cm), its top at top(f, g) and bottom at bot(f, g) (g -1 left .. 1 right; real cm off the surface). The
## edge rolls down from top to bottom over `roll` cm, so the shell closes. Wear from wear(f, g); quilting
## (COLOR.a) where quilt(f, g) says. The top's texture runs along its real length (a pommel's rise isn't
## stretched).
func _panel(tm: TackMesh, z0: float, z1: float, hw: Callable, top: Callable, bot: Callable, roll: float, wear: Callable, nz := 30, ns := 22, keep_outline := false, quilt := Callable()) -> void:
	var rows_t := []
	var rows_b := []
	var uv := []
	var uv2 := []
	var cols := []
	# The outline as a closed polygon in (z, x), real cm, with its perimeter length at each corner: each point's
	# distance to the edge (and where along it) is measured to the nearest segment, so stitch rows follow the
	# outline round the ends too.
	var poly := PackedVector2Array()
	for i in nz + 1:
		poly.append(Vector2(lerpf(z0, z1, float(i) / nz), float(hw.call(float(i) / nz))))
	for i in range(nz, -1, -1):
		poly.append(Vector2(lerpf(z0, z1, float(i) / nz), -float(hw.call(float(i) / nz))))
	var per := PackedFloat32Array([0.0])
	for i in range(1, poly.size()):
		per.append(per[i - 1] + poly[i].distance_to(poly[i - 1]))
	var run := PackedFloat32Array()   # (per column: the top's length so far, real cm)
	run.resize(ns + 1)
	var prev_row := PackedVector3Array()
	for i in nz + 1:
		var f := float(i) / nz
		var z := lerpf(z0, z1, f)
		var w: float = hw.call(f)
		var rt := PackedVector3Array()
		var rb := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		var rc := PackedColorArray()
		for j in ns + 1:
			var g := -1.0 + 2.0 * j / ns
			var x := g * w
			var near := _to_outline(poly, per, Vector2(z, x))
			var e: float = near.x
			var r := sqrt(maxf(1.0 - pow(1.0 - clampf(e / roll, 0.0, 1.0), 2.0), 0.0))
			var b: float = bot.call(f, g)
			var t: float = lerpf(b, top.call(f, g), r)
			var pt := at(x, t, z)
			if i > 0:
				run[j] += pt.distance_to(prev_row[j]) * cm
			rt.append(pt)
			rb.append(at(x, b, z))
			ru.append(Vector2(z0 + run[j], x))
			ru2.append(Vector2(e, near.y))
			rc.append(Color(wear.call(f, g), 0.25 * (1.0 - r), 0.0, float(quilt.call(f, g)) if quilt.is_valid() else 0.0))
		prev_row = rt
		rows_t.append(rt)
		rows_b.append(rb)
		uv.append(ru)
		uv2.append(ru2)
		cols.append(rc)
		if keep_outline:
			outline.append(rt[0])
			outline.append(rt[ns])
	tm.grid(rows_t, uv, uv2, cols, false, true)
	tm.grid(rows_b, uv, uv2, cols)


## (distance to the outline polygon, perimeter position of the nearest point), both real cm.
static func _to_outline(poly: PackedVector2Array, per: PackedFloat32Array, q: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	for i in poly.size() - 1:
		var a := poly[i]
		var d := poly[i + 1] - a
		var t := clampf((q - a).dot(d) / maxf(d.length_squared(), 1e-9), 0.0, 1.0)
		var dist := q.distance_to(a + d * t)
		if dist < best.x:
			best = Vector2(dist, per[i] + d.length() * t)
	return best


## A superellipse outline: half width `w` at its widest, `n` its squareness, widest at `mid` (0..1).
static func _outline(f: float, w: float, n: float, mid := 0.5) -> float:
	var u := (f - mid) / (mid if f < mid else 1.0 - mid)
	return w * pow(maxf(1.0 - pow(absf(u), n), 0.0), 1.0 / n)


func _pad() -> void:
	var tm := _tm("fleece")
	tm.seed = 0.3
	_panel(tm, -42.5, 38.0, func(f): return _outline(f, 43.5, 2.8, 0.43), func(_f, _g): return 3.0, func(_f, _g): return 0.15, 3.0, func(_f, _g): return 0.0)


func _skirt() -> void:
	var tm := _tm("saddle")
	tm.seed = 0.55
	# Wider over the knees (the flaps), narrow at the pommel; knee rolls padded up at the front of each flap.
	var hw := func(f: float) -> float:
		return _outline(f, 41.0, 2.6, 0.42)
	var top := func(f: float, g: float) -> float:
		return 4.6
	_panel(tm, -40.0, 36.0, hw, top, func(_f, _g): return 2.4, 1.6, func(f, g): return 0.35 * smoothstep(0.4, 0.9, absf(g)) * exp(-pow((f - 0.4) / 0.25, 2.0)), 30, 22, true)


func _seat() -> void:
	# Laid out like a motorcycle's: a high "tank" in front that the rider hugs, knees pressed into its sides on
	# knee pads; a narrower, lower seat behind it, quilted; a low cantle. The launcher is mounted ahead of the
	# tank like a fairing, its spade grips the handlebars; brass footpegs stand out from the seat's sides.
	var tm := _tm("seat")
	tm.seed = 0.7
	var hw := func(f: float) -> float:
		return lerpf(19.0, 14.0, smoothstep(0.35, 0.6, f)) * sqrt(_outline(f, 1.0, 2.4, 0.45))
	var top := func(f: float, g: float) -> float:
		var tank := 24.0 * smoothstep(0.0, 0.16, f) * (1.0 - smoothstep(0.38, 0.55, f))
		var seat := 16.0 * smoothstep(0.3, 0.5, f) * (1.0 - smoothstep(0.86, 1.0, f))
		var cantle := 6.0 * pow(smoothstep(0.76, 0.97, f), 1.6)
		var knee := 3.0 * exp(-pow((f - 0.3) / 0.08, 2.0)) * smoothstep(0.55, 0.85, absf(g))
		return 5.0 + maxf(tank, seat) * pow(maxf(1.0 - g * g, 0.0), 0.35) + cantle - 1.2 * (1.0 - g * g) * exp(-pow((f - 0.66) / 0.12, 2.0)) + knee
	var quilt := func(f: float, g: float) -> float:
		return smoothstep(0.52, 0.6, f) * (1.0 - smoothstep(0.78, 0.86, f)) * (1.0 - smoothstep(0.45, 0.7, absf(g)))
	_panel(tm, -36.0, 28.0, hw, top, func(_f, _g): return 4.2, 2.0, func(f, g): return 0.8 * (1.0 - absf(g)) * exp(-pow((f - 0.68) / 0.12, 2.0)) + 0.8 * smoothstep(0.55, 0.85, absf(g)) * exp(-pow((f - 0.3) / 0.1, 2.0)), 40, 24, false, quilt)
	seat_point = at(0.0, 20.0, 6.0)
	seat_normal = normal_at(0.0, 6.0)
	var brass := _tm("brass")
	var blued := _tm("blued")
	for s in [-1.0, 1.0]:
		knees[int(s > 0)] = at(s * 21.0, 18.0, -12.0)
		# A footpeg: a blued bracket from the seat's base, a brass peg with a knurled rubber-less grip.
		var root := at(s * 13.5, 6.5, 13.0)
		var tip := at(s * 23.0, 7.5, 13.0)
		blued.sweep(PackedVector3Array([at(s * 12.0, 4.0, 9.0), root, at(s * 12.0, 4.0, 17.0)]), PackedVector3Array([normal_at(s * 12.0, 13.0)]), TackMesh.circle(1.3 / cm, 8), true)
		brass.sweep(PackedVector3Array([root, root.lerp(tip, 0.5), tip]), PackedVector3Array([normal_at(s * 18.0, 13.0)]), TackMesh.circle(1.5 / cm, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.8]))
		heels[int(s > 0)] = at(s * 20.0, 10.5, 15.0)
	# Brass pommel plate and cantle binding: a rod along the top edge of each rise.
	for ends in [[-35.0, -32.0, 15.0, 11.0], [26.5, 27.5, 11.0, 9.0]]:
		var path := PackedVector3Array()
		var ups := PackedVector3Array()
		for k in 13:
			var g := -1.0 + 2.0 * k / 12.0
			var z: float = lerpf(ends[0], ends[1], 1.0 - g * g)
			var y: float = lerpf(ends[3], ends[2], 1.0 - g * g)
			path.append(at(g * 14.0, y, z))
			ups.append(normal_at(g * 14.0, z))
		brass.sweep(path, ups, TackMesh.circle(1.3 / cm, 8), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.7]))


# --- Footrest and kit roll ----------------------------------------------------------------------------------

func _footrest() -> void:
	# Behind the cantle, low: kneeling in flight the rider's boots rest on it; perched (the bird pitched up)
	# it's the step the rider stands on, far enough aft that standing clears the launcher.
	var blued := _tm("blued")
	var brass := _tm("brass")
	var grip := _tm("strap")
	var pz := 58.0
	var py := 13.0
	for s in [-1.0, 1.0]:
		# A strut from the skirt's rear corner, back and up to the bar.
		var a := at(s * 20.0, 4.0, 30.0)
		var b := at(s * 21.0, py - 1.0, pz)
		blued.sweep(PackedVector3Array([a, a.lerp(b, 0.5) + normal_at(s * 20.0, 44.0) * 2.0 / cm, b]), PackedVector3Array([normal_at(s * 20.0, 44.0)]), TackMesh.circle(1.5 / cm, 8), true, PackedFloat32Array(), PackedFloat32Array([0.2]))
		# Rivet plate where it meets the skirt.
		var n := normal_at(s * 20.0, 30.0)
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(3.0 / cm, 0.0), Vector2(3.0 / cm, 0.8 / cm), Vector2(1.2 / cm, 1.4 / cm), Vector2(0.0, 1.5 / cm)]), 12, Transform3D(_basis_y(n), a - n * 0.5 / cm))
		pegs[int(s > 0)] = at(s * 15.0, py + 1.5, pz)
	# The bar, brass, with leather grips wound round where the boots go.
	var bar := PackedVector3Array()
	for k in 9:
		var x := -24.0 + 48.0 * k / 8.0
		bar.append(at(x, py, pz))
	brass.sweep(bar, PackedVector3Array([normal_at(0.0, pz)]), TackMesh.circle(1.4 / cm, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.8]))
	for s in [-1.0, 1.0]:
		var wrap := PackedVector3Array()
		for k in 5:
			wrap.append(at(s * (9.0 + 12.0 * k / 4.0), py, pz))
		grip.sweep(wrap, PackedVector3Array([normal_at(0.0, pz)]), TackMesh.circle(1.75 / cm, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))


func _kit_roll() -> void:
	var tm := _tm("canvas")
	tm.seed = 0.2
	var path := PackedVector3Array()
	for k in 11:
		var x := -30.0 + 60.0 * k / 10.0
		path.append(at(x, 9.5, 72.0))
	tm.sweep(path, PackedVector3Array([normal_at(0.0, 72.0)]), TackMesh.circle(9.0 / cm, 14), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.3]))
	var st := _tm("strap")
	for s in [-1.0, 1.0]:
		var loop := PackedVector3Array()
		var ups := PackedVector3Array()
		for k in 17:
			var a := TAU * k / 16.0
			var c := at(s * 20.0, 9.5, 72.0)
			var n := normal_at(s * 20.0, 72.0)
			var aft := (at(s * 20.0, 0.0, 73.0) - at(s * 20.0, 0.0, 71.0)).normalized()
			var dir := n * sin(a) + aft * cos(a)
			loop.append(c + dir * 9.6 / cm)
			ups.append(dir)
		var sec: Array = st.strap_section(4.0 / cm, 0.5 / cm)
		st.sweep(loop, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.2]))


# --- Harness --------------------------------------------------------------------------------------------------

## The two loops, each as (z / L, ring angle t deg) control points on the right side; the left mirrors.
func _harness() -> void:
	var L := rig_body.L
	var st := _tm("strap")
	st.seed = 0.4
	var brass := _tm("brass")
	var w := 12.0 / cm
	var th := 1.0 / cm
	var sec: Array = st.strap_section(w, th)
	# Corners of the skirt, real cm in the saddle frame: front (-34, x 26) and rear (30, x 30).
	var front := [-34.0, 27.0]
	var rear := [29.0, 30.0]
	var ring_z := -0.11 * L
	for side in [-1.0, 1.0]:
		var corner_f := Vector2(seat_z + front[0] / cm, side * front[1] / cm)
		var corner_r := Vector2(seat_z + rear[0] / cm, side * rear[1] / cm)
		var fwd := [corner_f, _zt(-0.165 * L, 48.0, side), _zt(-0.178 * L, 12.0, side), _zt(-0.172 * L, -28.0, side), _zt(-0.145 * L, -64.0, side), _zt(ring_z, -86.0, side)]
		var aft := [_zt(ring_z, -86.0, side), _zt(-0.08 * L, -62.0, side), _zt(-0.045 * L, -32.0, side), _zt(-0.02 * L, -4.0, side), _zt(-0.0 * L, 30.0, side), corner_r]
		for ctrl in [fwd, aft]:
			var pts := _spline(ctrl, 48)
			var path := PackedVector3Array()
			var ups := PackedVector3Array()
			for p in pts:
				path.append(surf.point(p.x, p.y, 0.35 / cm))
				ups.append(surf.normal(p.x, p.y))
			st.sweep(path, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.15]))
			strap_paths.append(path)
			# A buckle a fifth of the way from the saddle, with a keeper just past it.
			var k := 0.2 if ctrl == fwd else 0.8
			var i := int(k * (path.size() - 1))
			var keep := i + (3 if ctrl == fwd else -3)
			_buckle(brass, path[i], (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized(), ups[i], w)
			_keeper(st, path[keep], (path[mini(keep + 1, path.size() - 1)] - path[maxi(keep - 1, 0)]).normalized(), ups[keep], w)
		# D-rings on the skirt's corners, the straps hooked through them.
		for c in [[front[0], front[1]], [rear[0], rear[1]]]:
			var p := at(side * c[1], 3.4, c[0])
			var n := normal_at(side * c[1], c[0])
			var out := (at(side * (c[1] + 2.0), 3.4, c[0]) - p).normalized()
			brass.torus(3.2 / cm, 0.7 / cm, Transform3D(_basis_y(n), p + out * 2.0 / cm), 16, 6, 0.5)
	# The breast ring where the loops meet, over a leather rosette.
	var rp := surf.point(ring_z, surf.half_girth(ring_z), 0.6 / cm)
	var rn := surf.normal(ring_z, surf.half_girth(ring_z) - 0.001)
	brass.torus(5.0 / cm, 1.2 / cm, Transform3D(_basis_y(rn), rp + rn * 0.6 / cm), 22, 8, 0.6)
	var ros := _tm("strap")
	ros.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(9.0 / cm, 0.0), Vector2(9.5 / cm, 0.5 / cm), Vector2(8.8 / cm, 1.1 / cm), Vector2(0.0, 1.2 / cm)]), 20, Transform3D(_basis_y(rn), rp - rn * 0.4 / cm))


func _zt(z: float, t_deg: float, side: float) -> Vector2:
	return Vector2(z, side * surf.s_of(z, deg_to_rad(t_deg)))


## Catmull-Rom through (z, s) control points, `n` samples.
static func _spline(ctrl: Array, n: int) -> Array:
	var out := []
	var m := ctrl.size()
	for k in n + 1:
		var u := float(k) / n * (m - 1)
		var i := mini(int(u), m - 2)
		var f := u - i
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, m - 1)]
		out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f))
	return out


## A buckle: a rounded rectangular brass frame across the strap, a centre bar and a tongue.
func _buckle(tm: TackMesh, p: Vector3, t: Vector3, n: Vector3, w: float) -> void:
	var x := n.cross(t).normalized()
	var hw := w * 0.5 + 1.2 / cm
	var hl := 5.0 / cm
	var lift := 1.6 / cm
	var loop := PackedVector3Array()
	var ups := PackedVector3Array()
	for k in 25:
		var a := TAU * k / 24.0
		var c := cos(a)
		var s := sin(a)
		var q := Vector2(hw * signf(c) * pow(absf(c), 0.4), hl * signf(s) * pow(absf(s), 0.4))
		loop.append(p + x * q.x + t * q.y + n * lift)
		ups.append(n)
	tm.sweep(loop, ups, TackMesh.circle(0.75 / cm, 6), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.6]), false)
	tm.sweep(PackedVector3Array([p - x * hw + n * lift, p + x * hw + n * lift]), PackedVector3Array([n]), TackMesh.circle(0.6 / cm, 6), true)
	tm.sweep(PackedVector3Array([p + n * (lift + 0.4 / cm), p + t * hl + n * (lift + 0.2 / cm)]), PackedVector3Array([n]), TackMesh.circle(0.45 / cm, 6), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))


## A keeper: a short band of leather round the strap.
func _keeper(tm: TackMesh, p: Vector3, t: Vector3, n: Vector3, w: float) -> void:
	var x := n.cross(t).normalized()
	var path := PackedVector3Array([p - t * 2.0 / cm, p + t * 2.0 / cm])
	var hw := w * 0.5 + 0.6 / cm
	var prof := PackedVector2Array()
	for k in 12:
		var a := TAU * k / 12.0
		prof.append(Vector2(hw * signf(cos(a)) * pow(absf(cos(a)), 0.3), (1.6 / cm) * signf(sin(a)) * pow(absf(sin(a)), 0.3) + 0.6 / cm))
	tm.sweep(path, PackedVector3Array([n]), prof, true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.3]))
	return


static func _basis_y(n: Vector3) -> Basis:
	var y := n.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


# --- Launcher ------------------------------------------------------------------------------------------------

## The launcher sits on the pommel, fixed along the body's axis (it's aimed by flying): its own frame has -Z
## forward; real cm from the rear of the breech.
func _launcher() -> void:
	var base := at(0.0, 33.0, -36.0)
	launcher_xf = Transform3D(Basis.IDENTITY, base)
	var k := 1.0 / cm
	var blued := _tm("blued")
	var brass := _tm("brass")
	var lx := func(x: float, y: float, z: float) -> Vector3:
		return launcher_xf * Vector3(x * k, y * k, z * k)
	# Breech: a rounded block.
	_rbox(blued, lx.call(0.0, 0.0, -30.0), Vector3(18.0, 15.0, 62.0) * k, 3.0 * k, Basis.IDENTITY)
	# Roundels on its sides.
	for s in [-1.0, 1.0]:
		var rd := _tm("roundel")
		var c: Vector3 = lx.call(s * 9.2, 0.5, -10.0)
		_disc(rd, c, Vector3(s, 0.0, 0.0), 4.5 * k, 0.4 * k)
	# Two racks of three tubes, one each side of the breech, in banded frames; the rockets' noses stand out of
	# the tubes' mouths and their fins out of the backs, so you can count what's left.
	for s in [-1.0, 1.0]:
		for i in 3:
			var c := Vector2(s * (15.5 + 8.8 * i), -2.0)
			var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), lx.call(c.x, c.y, -15.0))   # (lathe axis +Y -> -Z)
			var ro := 4.2 * k
			var ri := 3.4 * k
			var lt := 70.0 * k
			brass.lathe(PackedVector2Array([Vector2(ri, 2.0 * k), Vector2(ri, 0.0), Vector2(ro * 1.1, 0.0), Vector2(ro * 1.1, 1.0 * k), Vector2(ro, 1.6 * k), Vector2(ro, lt - 1.6 * k), Vector2(ro * 1.1, lt - 1.0 * k), Vector2(ro * 1.1, lt), Vector2(ri, lt), Vector2(ri, lt - 4.0 * k)]), 16, xf, PackedFloat32Array([0.4, 0.0, 0.0, 0.3, 99, 99, 0.3, 0.0, 0.0, 0.4]), PackedFloat32Array([0.8, 0.4, 0, 0, 0, 0, 0, 0, 0.5, 0.9]))
			rockets.append(_round(lt, k, xf))
		var xc: float = s * (15.5 + 8.8)
		for zb in [-20.0, -50.0, -81.0]:
			var loop := PackedVector3Array()
			var ups := PackedVector3Array()
			for j in 41:
				var a := TAU * j / 40.0
				var q := Vector2(xc + 13.8 * signf(cos(a)) * pow(absf(cos(a)), 0.25), -2.0 + 5.0 * signf(sin(a)) * pow(absf(sin(a)), 0.25))
				loop.append(lx.call(q.x, q.y, zb))
				ups.append(Vector3(signf(cos(a)) * pow(absf(cos(a)), 0.25), signf(sin(a)) * pow(absf(sin(a)), 0.25), 0.0).normalized())
			var sec: Array = brass.strap_section(4.0 * k, 0.9 * k)
			brass.sweep(loop, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.35]), false)
			# A rivet each end of the band.
			for e in [-1.0, 1.0]:
				brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0 * k, 0.0), Vector2(0.9 * k, 0.5 * k), Vector2(0.0, 0.8 * k)]), 8, Transform3D(Basis(Vector3.BACK, -e * PI * 0.5), lx.call(xc + e * 14.7, -2.0, zb)))
		# A blued rail along the top of the rack, and two cross tubes to the breech.
		blued.sweep(PackedVector3Array([lx.call(xc, 3.6, -16.0), lx.call(xc, 3.6, -84.0)]), PackedVector3Array([Vector3.UP]), PackedVector2Array([Vector2(6.0, 0.0) * k, Vector2(-6.0, 0.0) * k, Vector2(-6.0, 1.2) * k, Vector2(6.0, 1.2) * k]), true)
		for zb in [-28.0, -60.0]:
			blued.sweep(PackedVector3Array([lx.call(s * 9.0, -2.0, zb), lx.call(s * 12.0, -2.0, zb)]), PackedVector3Array([Vector3.UP]), TackMesh.circle(1.6 * k, 8), true)
		# The yoke: a cheek plate from the pommel up to the breech.
		_rbox(brass, lx.call(s * 8.0, -15.0, -8.0), Vector3(2.0, 28.0, 22.0) * k, 1.0 * k, Basis.IDENTITY)
	# A rack of three seekers on top.
	_rbox(blued, lx.call(0.0, 10.5, -30.0), Vector3(20.0, 2.5, 46.0) * k, 1.0 * k, Basis.IDENTITY)
	for i in 3:
		seekers.append(_seeker(lx.call(-6.5 + 6.5 * i, 14.5, -8.0), k))
	# Spade grips behind the breech, with a thumb trigger bar between them.
	for s in [-1.0, 1.0]:
		var g0: Vector3 = lx.call(s * 9.0, -2.0, 1.0)
		var g1: Vector3 = lx.call(s * 9.0, -5.0, 9.0)
		blued.sweep(PackedVector3Array([lx.call(s * 9.0, 2.0, -1.0), g0]), PackedVector3Array([Vector3.UP]), TackMesh.circle(1.4 * k, 8), true)
		_tm("glove").sweep(PackedVector3Array([g0, g0.lerp(g1, 0.5), g1]), PackedVector3Array([Vector3.UP]), TackMesh.circle(2.2 * k, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))
		grips[int(s > 0)] = g0.lerp(g1, 0.5)
	# Hand loops for a rider standing on the footrest: leather, hanging from the back of the seeker rack.
	for s in [-1.0, 1.0]:
		var loop := PackedVector3Array()
		var ups := PackedVector3Array()
		for j in 13:
			var a := PI * j / 12.0
			loop.append(lx.call(s * 6.0 + 3.0 * cos(a), 11.0 + 7.0 * sin(a), -7.0 + 4.0 * sin(a)))
			ups.append(Vector3(cos(a), sin(a), 0.0))
		var lsec: Array = _tm("strap").strap_section(2.2 * k, 0.5 * k)
		_tm("strap").sweep(loop, ups, lsec[0], true, lsec[1], lsec[2], PackedFloat32Array([0.6]))
		holds[int(s > 0)] = lx.call(s * 6.0, 18.0, -3.0)
	brass.sweep(PackedVector3Array([lx.call(-8.0, -1.0, 2.0), lx.call(8.0, -1.0, 2.0)]), PackedVector3Array([Vector3.UP]), TackMesh.circle(0.8 * k, 8), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))
	# Ring sight at the rear, bead at the front.
	brass.sweep(PackedVector3Array([lx.call(0.0, 8.5, -4.0), lx.call(0.0, 17.0, -4.0)]), PackedVector3Array([Vector3.BACK]), TackMesh.circle(0.6 * k, 6), true)
	brass.torus(4.5 * k, 0.45 * k, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), lx.call(0.0, 21.5, -4.0)), 20, 6, 0.6)
	brass.sweep(PackedVector3Array([lx.call(0.0, 8.5, -72.0), lx.call(0.0, 16.5, -72.0)]), PackedVector3Array([Vector3.BACK]), TackMesh.circle(0.6 * k, 6), true)
	brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.1 * k, 0.4 * k), Vector2(1.0 * k, 1.4 * k), Vector2(0.0, 1.8 * k)]), 10, Transform3D(Basis.IDENTITY, lx.call(0.0, 16.5, -72.0)))
	muzzle = lx.call(0.0, 0.0, -95.0)


## One rocket in its tube (its own MeshInstance, hidden when fired): a steel case standing a little out of the
## tube's mouth, a red ogive nose, four fins out of the tube's back. `xf`: the tube's frame (axis +Y forward).
func _round(lt: float, k: float, xf: Transform3D) -> MeshInstance3D:
	var r := 3.0 * k
	var nose0 := lt + 4.0 * k
	var prof := PackedVector2Array()
	for j in 9:
		var u := float(j) / 8.0
		prof.append(Vector2(r * sqrt(maxf(1.0 - u * u, 0.0)) * (1.0 - 0.1 * u), nose0 + 9.0 * k * u))
	var tm := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	tm.lathe(PackedVector2Array([Vector2(0.0, -2.0 * k), Vector2(r * 0.7, -2.0 * k), Vector2(r, -1.0 * k), Vector2(r, nose0)]), 12, xf)
	for f in 4:
		var a := TAU * f / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		tm.sweep(PackedVector3Array([xf * (d * r * 0.8 + Vector3(0, -2.0 * k, 0)), xf * (d * (r + 3.0 * k) + Vector3(0, -3.5 * k, 0))]), PackedVector3Array([xf.basis * side]), PackedVector2Array([Vector2(-0.25 * k, -3.0 * k), Vector2(0.25 * k, -3.0 * k), Vector2(0.25 * k, 3.0 * k), Vector2(-0.25 * k, 3.0 * k)]), true)
	var tm2 := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	tm2.lathe(prof, 12, xf)
	var m := tm.commit()
	m = tm2.commit(m)
	m.surface_set_material(0, TackMaterials.get_mat("nickel"))
	m.surface_set_material(1, TackMaterials.get_mat("red"))
	var mi := MeshInstance3D.new()
	mi.name = "Round"
	mi.mesh = m
	add_child(mi)
	return mi


## One seeker on the rack: a slim body, a red nose, four fins.
func _seeker(p: Vector3, k: float) -> MeshInstance3D:
	var tm := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), p)
	var r := 2.2 * k
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.8, 0.0), Vector2(r, 1.0 * k), Vector2(r, 22.0 * k)])
	tm.lathe(prof, 12, xf)
	var nose := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	var np := PackedVector2Array([Vector2(r, 22.0 * k), Vector2(r * 0.9, 25.0 * k), Vector2(r * 0.6, 28.0 * k), Vector2(r * 0.25, 30.0 * k), Vector2(0.0, 30.6 * k)])
	nose.lathe(np, 12, xf)
	for f in 3:
		var a := TAU * f / 3.0 + PI * 0.5
		var d := Vector3(cos(a), sin(a), 0.0)
		var fin := PackedVector3Array([p + d * r * 0.9 + Vector3(0, 0, -1.0 * k), p + d * (r + 1.8 * k) + Vector3(0, 0, 0.5 * k)])
		tm.sweep(fin, PackedVector3Array([Vector3(-sin(a), cos(a), 0.0)]), PackedVector2Array([Vector2(-0.2 * k, -2.5 * k), Vector2(0.2 * k, -2.5 * k), Vector2(0.2 * k, 1.0 * k), Vector2(-0.2 * k, 1.0 * k)]), true)
	var m := tm.commit()
	m = nose.commit(m)
	m.surface_set_material(0, TackMaterials.get_mat("nickel"))
	m.surface_set_material(1, TackMaterials.get_mat("red"))
	var mi := MeshInstance3D.new()
	mi.name = "Seeker"
	mi.mesh = m
	add_child(mi)
	return mi


## A rounded box: centre, full size, corner radius, orientation.
func _rbox(tm: TackMesh, c: Vector3, size: Vector3, r: float, b: Basis) -> void:
	var prof := PackedVector2Array()
	var hx := size.x * 0.5 - r
	var hy := size.y * 0.5 - r
	for q in 4:
		var cx := hx if q == 0 or q == 3 else -hx
		var cy := hy if q < 2 else -hy
		for j in 4:
			var a := PI * 0.5 * q + PI * 0.5 * j / 3.0
			prof.append(Vector2(cx + r * cos(a), cy + r * sin(a)))
	var hz := size.z * 0.5
	var path := PackedVector3Array()
	var ups := PackedVector3Array()
	for z in [-hz, -hz + r * 0.3, hz - r * 0.3, hz]:
		path.append(c + b * Vector3(0.0, 0.0, z))
		ups.append(b * Vector3.UP)
	tm.sweep(path, ups, prof, true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.1]))


## A thin disc facing `n` (UV centred on it, real cm, for the roundel pattern).
func _disc(tm: TackMesh, c: Vector3, n: Vector3, r: float, t: float) -> void:
	var xf := Transform3D(_basis_y(n), c)
	var rows := []
	var uv := []
	var uv2 := []
	for i in 7:
		var rr := r * i / 6.0
		var row := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		for j in 24:
			var a := TAU * j / 24.0
			var lp := Vector3(rr * cos(a), t, rr * sin(a))
			row.append(xf * lp)
			ru.append(Vector2(lp.x, lp.z) * cm)
			ru2.append(Vector2((r - rr) * cm, a))
		rows.append(row)
		uv.append(ru)
		uv2.append(ru2)
	tm.grid(rows, uv, uv2, [], true, true)


## Show the rounds left.
func set_ammo(n_rockets: int, n_seekers: int) -> void:
	for i in rockets.size():
		rockets[i].visible = i < n_rockets
	for i in seekers.size():
		seekers[i].visible = i < n_seekers
