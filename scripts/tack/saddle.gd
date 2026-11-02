class_name Saddle
extends Node3D
## The war saddle and launcher, fitted to one bird's back (BackSurface), rig space.
##
## Where it can go (tests/probe_tack_fit.gd): folded or beating, the wings never come higher round the trunk
## than about 35 deg of elevation from its centre, so a strip along the back is always free; the saddle stays
## well inside it, and the neck and head stay ahead of the pommel even with the neck retracted on a perch.
##
## Sizes are a man's, scaled with the rider (TackMesh: an 8.5 cm pilot is 1:20.6): the saddle, the footrest and
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
## struts, a brass bar), the controls on the pommel (a handlebar with firing buttons, a dash), and a mount each side of
## the rider: a pod of three rockets or a rail of two seekers, raised on pylons and tilted in a trunnion. The
## rounds in them show what's left (set_ammo).

const FREE_ELEVATION := 50.0   ## deg: the saddle stays above this elevation round the trunk (wings: <= ~35)
var wide := 1.0                ## the panels' width, 1 or less on a back too narrow for them (build sets it)

var rig_body: BodyShape
var surf: BackSurface
var cm := 100.0               ## real cm per model metre
var seat_z := 0.0             ## rig z of the seat's middle
## Anchor points (rig space, unscaled): where the rider sits, holds and stands.
var seat_point := Vector3.ZERO
var seat_normal := Vector3.UP
var grips: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var holds: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## standing: where the hands hold the grab rail
var grip_dirs: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT]   ## each grip's axis, outward
var grip_ends: Array = [[], []]                            ## each grip's inner and outer end
var hold_dirs: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT]   ## the grab rail's, outward
var buttons: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## the firing buttons' tops
## The grab rail behind the dash: (y, z) in the controls' frame, real cm.
const RAIL := Vector2(9.0, -6.0)
var pegs: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var knees: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## kneeling: where the knees rest (on the flaps)
var ride_pegs: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## riding: the side pegs' tops, under the boots' balls
## Riding, the side pegs and the ankle above and behind them: (y off the back, z aft) real cm.
const PEG := Vector2(13.0, 27.0)
const RIDE_ANKLE := Vector2(24.0, 19.0)
var heels: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## kneeling: where the ankles rest (shins folded back)
var muzzle := Vector3.ZERO
var launcher_xf := Transform3D()
var rockets: Array[MeshInstance3D] = []
var seekers: Array[MeshInstance3D] = []
var outline: Array = []        ## the skirt's outline (rig points), for tests
var strap_paths: Array = []    ## each harness strap's centre line (rig points), for tests
var _tms := {}


## Build for `rig` with a rider `rider_h` m tall.
## `pods`: the left and right mounts' pods ("rockets" / "seekers"; empty: DEFAULT_LOADOUT); `tilt`: deg nose up.
func build(rig: BirdRig, rider_h: float, pods: Array = [], tilt := DEFAULT_TILT) -> void:
	loadout.assign(pods if pods.size() == 2 else DEFAULT_LOADOUT)
	mount_tilt = tilt
	rig_body = rig.body
	surf = BackSurface.new(rig.body)
	cm = 100.0 * TackMesh.REAL_H / rider_h
	# The seat: just behind the shoulders, or further back on a bird whose head sits over them (an owl), so the
	# controls and the rider leaning over them stay behind the head.
	var head_back := -INF
	for hc in _heads():
		head_back = maxf(head_back, (hc as Vector3).z + rig.body.head_r * 1.1)
	seat_z = maxf(rig.body.shoulder.z + 6.0 / cm, head_back + 100.0 / cm)
	# Narrow backs (a sparrow's): the panels narrow so they stay on the strip above the wings.
	wide = 1.0
	for i in 9:
		var z := seat_z + lerpf(-42.5, 38.0, i / 8.0) / cm
		var lo := 0.0
		var hi := surf.half_girth(z)
		for it in 24:
			var mid := (lo + hi) * 0.5
			if surf.elevation(z, mid) > FREE_ELEVATION + 6.0:
				lo = mid
			else:
				hi = mid
		wide = minf(wide, lo * cm / 43.5)
	wide = clampf(wide, 0.5, 1.0)
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
	_panel(tm, -42.5, 38.0, func(f): return _outline(f, 43.5 * wide, 2.8, 0.43), func(_f, _g): return 3.0, func(_f, _g): return 0.15, 3.0, func(_f, _g): return 0.0)


func _skirt() -> void:
	var tm := _tm("saddle")
	tm.seed = 0.55
	# Wider over the knees (the flaps), narrow at the pommel; knee rolls padded up at the front of each flap.
	var hw := func(f: float) -> float:
		return _outline(f, 41.0 * wide, 2.6, 0.42)
	var top := func(f: float, g: float) -> float:
		return 4.6
	_panel(tm, -40.0, 36.0, hw, top, func(_f, _g): return 2.4, 1.6, func(f, g): return 0.35 * smoothstep(0.4, 0.9, absf(g)) * exp(-pow((f - 0.4) / 0.25, 2.0)), 30, 22, true)


func _seat() -> void:
	# Laid out like a motorcycle's: a high "tank" in front that the rider hugs, knees pressed into its sides on
	# knee pads; a narrower, lower seat behind it, quilted; a low cantle. The launcher is mounted ahead of the
	# tank like a fairing, a handlebar ahead of the tank; brass footpegs stand out from the seat's sides.
	var tm := _tm("seat")
	tm.seed = 0.7
	var hw := func(f: float) -> float:
		return lerpf(19.0, 14.0, smoothstep(0.35, 0.6, f)) * minf(1.0, wide * 1.15) * sqrt(_outline(f, 1.0, 2.4, 0.45))
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
		knees[int(s > 0)] = at(s * 21.0 * minf(1.0, wide * 1.15), 18.0, -12.0)
		# A rear-set footpeg, as a racer's: a blued hanger from the seat's side, back and up, a brass peg under
		# the ball of the boot; the ankle rides up behind it, heel raised (RIDE_ANKLE).
		var root := at(s * 14.0, PEG.x, PEG.y)
		var tip := at(s * 23.0, PEG.x + 0.5, PEG.y)
		blued.sweep(PackedVector3Array([at(s * 12.5, 4.0, PEG.y - 9.0), root, at(s * 12.5, 4.0, PEG.y + 5.0)]), PackedVector3Array([normal_at(s * 12.0, PEG.y)]), TackMesh.circle(1.3 / cm, 8), true)
		brass.sweep(PackedVector3Array([root, root.lerp(tip, 0.5), tip]), PackedVector3Array([normal_at(s * 18.0, PEG.y)]), TackMesh.circle(1.5 / cm, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.8]))
		ride_pegs[int(s > 0)] = at(s * 19.0, PEG.x + 1.5, PEG.y)
		heels[int(s > 0)] = at(s * 19.5, RIDE_ANKLE.x, RIDE_ANKLE.y)
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


# --- Weapons --------------------------------------------------------------------------------------------------

## The weapons ride on two mounts, one each side of the rider, raised on pylons so the line of fire passes over
## the bird's head; each mount carries a pod -- "rockets" (three tubes) or "seekers" (two on a rail) -- in a
## trunnion that tilts it (mount_tilt, deg nose up; a brass quadrant and locking pin show the setting). Ahead of
## the rider, on the pommel: the controls -- a handlebar, a firing button on each grip, a dash of gauges -- and
## the hand loops for standing. Each round knows where it leaves from (round_muzzle).
const POD_KINDS := ["rockets", "seekers"]
const POD_ROUNDS := {"rockets": 3, "seekers": 2}
const DEFAULT_LOADOUT: Array[String] = ["rockets", "seekers"]   ## left, right
const DEFAULT_TILT := 3.0       ## deg
const MOUNT_X := 44.0           ## real cm out from the spine: clear of the rider's elbows and knees
const MOUNT_Z := -38.0          ## real cm, the trunnion: beside the rider's shoulders in the tuck
const CLEAR_AOA := 5.0          ## deg: the line of fire is checked along a path this far below the body's axis
const MOUNT_RAISE := 30.0       ## real cm: the highest a mount stands over the controls (no stilts)
const CLEAR_HEAD := 0.35        ## of the head's radius, margin over the head (carried in flight or reaching)

var loadout: Array[String] = DEFAULT_LOADOUT.duplicate()
var mount_tilt := DEFAULT_TILT
var mounts: Array = []          ## per side (0 left, 1 right): {kind, side, pivot: Transform3D (tilted), rounds, muzzles}
var clamp_loops: Array = []    ## each pod band's centre line (saddle space) with [.., pod frame, kind, z], for tests
var round_order := {"rockets": [], "seekers": []}   ## [mount index, round index] in firing order


## Where round `i` (0-based, in firing order: set_ammo hides from the end) of `kind` leaves from, saddle space.
func round_muzzle(kind: String, i: int) -> Vector3:
	var o: Array = round_order[kind]
	if o.is_empty():
		return muzzle
	var mr: Array = o[clampi(i, 0, o.size() - 1)]
	return (mounts[mr[0]].muzzles as Array)[mr[1]]


## Where round `i` of `kind` starts its flight, saddle space: its muzzle, unless the bird's head is in the way
## of a mount at its highest (an owl's), then just past the head along the line of fire.
func round_launch(kind: String, i: int) -> Vector3:
	var o: Array = round_order[kind]
	if o.is_empty():
		return muzzle
	var mr: Array = o[clampi(i, 0, o.size() - 1)]
	return (mounts[mr[0]].launch as Array)[mr[1]]


func capacity(kind: String) -> int:
	return (round_order[kind] as Array).size()


## The bird's head in flight, as it carries it and reaching: centres, rig space (level flight).
func _heads() -> Array:
	var b := rig_body
	var out := []
	for e in [b.neck_flight, 1.0]:
		var dir := (Vector3.UP + Vector3.FORWARD * 0.7).normalized().slerp((Vector3.UP * 0.15 + Vector3.FORWARD).normalized(), e)
		out.append(b.neck_base + dir * lerpf(b.neck_rest, b.neck_reach, e))
	return out


func _launcher() -> void:
	var base := at(0.0, 33.0, -36.0)
	launcher_xf = Transform3D(Basis.IDENTITY, base)
	var k := 1.0 / cm
	var blued := _tm("blued")
	var brass := _tm("brass")
	var lx := func(x: float, y: float, z: float) -> Vector3:
		return launcher_xf * Vector3(x * k, y * k, z * k)
	# The controls, on a blued column from the pommel's front: a handlebar swept back to a leather grip each
	# side, a thumb button on each (red where that side's pod holds rockets, nickel for seekers); a small dash
	# between them -- each side's rounds on a gauge, a compass in the middle; a roundel badge on the column.
	var foot := at(0.0, 21.0, -33.0)
	var head: Vector3 = lx.call(0.0, -1.0, -15.0)
	blued.sweep(PackedVector3Array([foot, foot.lerp(head, 0.5), head]), PackedVector3Array([Vector3.BACK]), TackMesh.circle(1.9 * k, 10), true, PackedFloat32Array(), PackedFloat32Array([0.2]), PackedFloat32Array([0.3]))
	brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(3.4 * k, 0.0), Vector2(3.4 * k, 0.8 * k), Vector2(2.2 * k, 1.4 * k), Vector2(0.0, 1.5 * k)]), 14, Transform3D(_basis_y(normal_at(0.0, -33.0)), foot - normal_at(0.0, -33.0) * 0.4 * k))
	brass.lathe(PackedVector2Array([Vector2(2.4 * k, -1.2 * k), Vector2(2.6 * k, -0.6 * k), Vector2(2.6 * k, 0.6 * k), Vector2(2.4 * k, 1.2 * k)]), 14, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), head))
	_disc(_tm("roundel"), lx.call(0.0, -6.0, -17.2), Vector3(0.0, 0.25, -1.0).normalized(), 3.2 * k, 0.3 * k)
	for s in [-1.0, 1.0]:
		var i := int(s > 0)
		var bar := PackedVector3Array([head, lx.call(s * 2.0, -0.7, -12.5), lx.call(s * 3.0, -1.3, -8.5)])
		brass.sweep(bar, PackedVector3Array([Vector3.UP]), TackMesh.circle(1.0 * k, 10), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.5]))
		# The grip runs the width of a gloved fist and out past it each side; the hand closes round its middle.
		var g0: Vector3 = lx.call(s * 3.0, -1.3, -8.5)
		var g1: Vector3 = lx.call(s * 17.5, -2.6, -2.6)
		var grip := PackedVector3Array()
		for q in 7:
			grip.append(g0.lerp(g1, q / 6.0))
		_tm("strap").sweep(grip, PackedVector3Array([Vector3.UP]), PackedVector2Array(_grip_section(1.7 * k)), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.9 * k, 0.0), Vector2(1.9 * k, 0.6 * k), Vector2(0.0, 0.7 * k)]), 12, Transform3D(_basis_y((g1 - g0).normalized()), g1))
		grips[i] = g0.lerp(g1, 0.53)
		grip_dirs[i] = (g1 - g0).normalized()
		grip_ends[i] = [g0, g1]
		# The thumb button, on a brass bezel on top of the grip right above the fist, under the thumb.
		var up_g := (Vector3.UP - grip_dirs[i] * Vector3.UP.dot(grip_dirs[i])).normalized()
		var bp: Vector3 = grips[i] - grip_dirs[i] * 2.5 * k + up_g * 1.6 * k
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.1 * k, 0.0), Vector2(1.1 * k, 0.5 * k), Vector2(0.0, 0.5 * k)]), 12, Transform3D(_basis_y(up_g), bp))
		var kind: String = loadout[i] if i < loadout.size() else DEFAULT_LOADOUT[i]
		_tm("red" if kind == "rockets" else "nickel").lathe(_ball(0.75 * k), 10, Transform3D(_basis_y(up_g).scaled(Vector3(1.0, 0.6, 1.0)), bp + up_g * 0.4 * k))
		buttons[i] = bp + up_g * 0.9 * k
	# The dash: a blued plate on the column's head, tilted to the rider, three brass-rimmed dials.
	var dash := Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	var dc: Vector3 = lx.call(0.0, 2.2, -14.0)
	_rbox(blued, dc, Vector3(15.0, 1.2, 6.0) * k, 0.5 * k, dash)
	for d in [[-4.6, 2.0, "gauge"], [0.0, 2.4, "compass"], [4.6, 2.0, "gauge"]]:
		var c: Vector3 = dc + dash * (Vector3(float(d[0]), 0.6, 0.0) * k)
		var r: float = float(d[1]) * k
		var xf := Transform3D(dash, c)
		brass.lathe(PackedVector2Array([Vector2(r * 0.8, 0.0), Vector2(r, 0.0), Vector2(r * 1.05, 0.4 * k), Vector2(r, 0.7 * k), Vector2(r * 0.85, 0.6 * k)]), 16, xf)
		_tm("nickel").lathe(PackedVector2Array([Vector2(0.0, 0.3 * k), Vector2(r * 0.85, 0.3 * k)]), 16, xf)
		_tm("glass").lathe(PackedVector2Array([Vector2(r * 0.85, 0.55 * k), Vector2(r * 0.5, 0.7 * k), Vector2(0.0, 0.75 * k)]), 16, xf)
		# (a needle on each gauge; the compass a card with a lubber line)
		var needle := dash * Vector3(0.6 if d[2] == "gauge" else 0.0, 0.0, -1.0).normalized()
		_tm("dark").sweep(PackedVector3Array([c + dash * Vector3(0, 0.38, 0) * k, c + dash * Vector3(0, 0.38, 0) * k + needle * r * 0.7]), PackedVector3Array([dash * Vector3.UP]), PackedVector2Array([Vector2(0.12, 0.0) * k, Vector2(-0.12, 0.0) * k, Vector2(-0.12, 0.08) * k, Vector2(0.12, 0.08) * k]), true)
	# A grab rail behind the dash, low, on two posts: what the standing rider holds (wrapped in leather where the
	# hands go).
	for s in [-1.0, 1.0]:
		brass.sweep(PackedVector3Array([lx.call(s * 8.0, 1.0, -10.0), lx.call(s * 8.0, RAIL.x, RAIL.y)]), PackedVector3Array([Vector3.BACK]), TackMesh.circle(0.7 * k, 6), true)
	brass.sweep(PackedVector3Array([lx.call(-11.0, RAIL.x, RAIL.y), lx.call(11.0, RAIL.x, RAIL.y)]), PackedVector3Array([Vector3.UP]), TackMesh.circle(0.9 * k, 8), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.7]))
	for s in [-1.0, 1.0]:
		var wrap := PackedVector3Array()
		for q in 4:
			wrap.append(lx.call(s * (2.0 + 2.8 * q), RAIL.x, RAIL.y))
		_tm("strap").sweep(wrap, PackedVector3Array([Vector3.UP]), PackedVector2Array(_grip_section(1.25 * k)), true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.9]))
		holds[int(s > 0)] = lx.call(s * 6.0, RAIL.x, RAIL.y)
		hold_dirs[int(s > 0)] = Vector3(s, 0.0, 0.0)
	muzzle = lx.call(0.0, 0.0, -40.0)
	# The mounts, left and right.
	mounts.clear()
	clamp_loops.clear()
	round_order = {"rockets": [], "seekers": []}
	for i in 2:
		var kind: String = loadout[i] if i < loadout.size() and POD_KINDS.has(loadout[i]) else DEFAULT_LOADOUT[i]
		mounts.append(_mount(-1.0 if i == 0 else 1.0, kind, lx))
	# Firing order: alternate sides round by round.
	for kind in POD_KINDS:
		for r in 3:
			for i in 2:
				if mounts[i].kind == kind and r < (mounts[i].rounds as Array).size():
					round_order[kind].append([i, r])
	rockets.clear()
	seekers.clear()
	for mr in round_order.rockets:
		rockets.append(mounts[mr[0]].rounds[mr[1]])
	for mr in round_order.seekers:
		seekers.append(mounts[mr[0]].rounds[mr[1]])


## A grip's section: round, with eight shallow flutes for the fingers.
func _grip_section(r: float) -> Array:
	var out := []
	for j in 16:
		var a := TAU * j / 16.0
		out.append(Vector2(cos(a), sin(a)) * r * (1.0 - 0.06 * float(j % 2)))
	return out


func _ball(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in 7:
		var a := -PI * 0.5 + PI * j / 6.0
		out.append(Vector2(r * cos(a), r * (sin(a) + 1.0)))
	return out


## One side's mount: pylons from the skirt up to a fork, the trunnion, the elevation quadrant, the pod. Returns
## {kind, side, pivot, rounds, muzzles}. The pivot's height is the lowest that keeps every round's line of fire
## (CLEAR_AOA below the body's axis) over the head, carried or reaching, by CLEAR_HEAD of its radius.
func _mount(s: float, kind: String, lx: Callable) -> Dictionary:
	var k := 1.0 / cm
	var blued := _tm("blued")
	var brass := _tm("brass")
	var foot := at(s * MOUNT_X, 0.0, MOUNT_Z)
	var y0: float = (lx.call(0.0, 0.0, 0.0) as Vector3).y
	var tilt := deg_to_rad(mount_tilt)
	var muzzles_local := _pod_muzzles(kind)
	var heads := _heads()
	var hr := rig_body.head_r * (1.0 + CLEAR_HEAD)
	var down := Basis(Vector3.RIGHT, -deg_to_rad(CLEAR_AOA)) * Vector3.FORWARD
	var pivot := Vector3(foot.x, maxf(foot.y + 15.0 * k, y0), foot.z)   # (no lower than the controls: above the rider's knees and elbows)
	var top := y0 + MOUNT_RAISE * k
	for it in 240:
		var xf := Transform3D(Basis(Vector3.RIGHT, tilt), pivot)
		var ok := true
		for m in muzzles_local:
			var mp: Vector3 = xf * ((m as Vector3) * k)
			for hc in heads:
				var rel: Vector3 = hc - mp
				if rel.dot(down) > 0.0 and (rel - down * rel.dot(down)).length() < hr:
					ok = false
		if ok or pivot.y >= top:
			break
		pivot.y = minf(pivot.y + 0.5 * k, top)
	var fork := Transform3D(Basis.IDENTITY, pivot)
	var pod := Transform3D(Basis(Vector3.RIGHT, tilt), pivot)
	var fx := func(x: float, y: float, z: float) -> Vector3:
		return fork * (Vector3(x, y, z) * k)
	var half := _pod_half(kind) + 0.9   # the pod's half width at the clamp, the band on it
	# Pylons: front and rear legs from riveted plates on the skirt to the fork's base, and a brace in to the tank.
	var fb: Vector3 = fx.call(0.0, -9.0, 0.0)
	for z in [MOUNT_Z - 16.0, MOUNT_Z + 14.0]:
		var a := at(s * 22.0, 4.6, z)
		var n := normal_at(s * 22.0, z)
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(3.2 * k, 0.0), Vector2(3.2 * k, 0.8 * k), Vector2(1.4 * k, 1.4 * k), Vector2(0.0, 1.5 * k)]), 14, Transform3D(_basis_y(n), a - n * 0.4 * k))
		for q in 3:
			var aq := TAU * q / 3.0
			var b := _basis_y(n)
			brass.lathe(_ball(0.5 * k), 6, Transform3D(b, a + (b.x * cos(aq) + b.z * sin(aq)) * 2.3 * k + n * 0.6 * k))
		blued.sweep(PackedVector3Array([a, a.lerp(fb, 0.5) + Vector3(s, 0, 0) * 1.0 * k, fb]), PackedVector3Array([Vector3(s, 0.0, 0.0)]), TackMesh.circle(1.5 * k, 10), true, PackedFloat32Array(), PackedFloat32Array([0.2]), PackedFloat32Array([0.2]))
	blued.sweep(PackedVector3Array([at(s * 14.0, 20.0, MOUNT_Z), fb]), PackedVector3Array([Vector3.UP]), TackMesh.circle(1.1 * k, 8), true)
	# The fork: a saddle block at the pylons' head and two cheeks rising either side of the pod's clamp.
	_rbox(blued, fx.call(0.0, -9.5, 0.0), Vector3(2.0 * half + 8.0, 3.0, 9.0) * k, 1.0 * k, Basis.IDENTITY)
	for e in [-1.0, 1.0]:
		_rbox(blued, fx.call(e * (half + 2.2), -4.0, 0.0), Vector3(2.2, 12.0, 8.0) * k, 1.0 * k, Basis.IDENTITY)
		# Trunnion pins: brass caps through each cheek.
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.8 * k, 0.0), Vector2(1.8 * k, 1.2 * k), Vector2(1.2 * k, 1.8 * k), Vector2(0.0, 1.9 * k)]), 14, Transform3D(Basis(Vector3.BACK, -e * PI * 0.5), fx.call(e * (half + 3.2), 0.0, 0.0)))
	# The elevation quadrant on the outer cheek: a brass arc with a stud every 5 deg from -5 to +20, the pod's
	# index arm, and a locking pin through the arc at the setting.
	var qx := s * (half + 3.6)
	var arc := PackedVector3Array()
	var arc_up := PackedVector3Array()
	for j in 13:
		var a := deg_to_rad(lerpf(-8.0, 23.0, j / 12.0))
		arc.append(fx.call(qx, 8.5 * sin(a), -8.5 * cos(a)))
		arc_up.append(Vector3(s, 0.0, 0.0))
	var asec: Array = brass.strap_section(2.0 * k, 0.5 * k)
	brass.sweep(arc, arc_up, asec[0], true, asec[1], asec[2], PackedFloat32Array([0.4]))
	brass.sweep(PackedVector3Array([fx.call(qx, -3.0, 0.0), fx.call(qx, 8.5 * sin(deg_to_rad(-8.0)), -8.5 * cos(deg_to_rad(-8.0)))]), PackedVector3Array([Vector3(s, 0, 0)]), TackMesh.circle(0.5 * k, 6), true)
	for j in 6:
		var a := deg_to_rad(-5.0 + 5.0 * j)
		brass.lathe(_ball(0.35 * k), 6, Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), fx.call(qx + s * 0.25, 8.5 * sin(a), -8.5 * cos(a))))
	var pin: Vector3 = pod * (Vector3(qx + s * 0.6, 0.0, -8.5) * k)
	brass.sweep(PackedVector3Array([pin - Vector3(s, 0, 0) * 1.2 * k, pin + Vector3(s, 0, 0) * 1.4 * k]), PackedVector3Array([Vector3.UP]), TackMesh.circle(0.45 * k, 6), true)
	brass.lathe(_ball(0.9 * k), 8, Transform3D(Basis(Vector3.BACK, -s * PI * 0.5), pin + Vector3(s, 0, 0) * 1.4 * k))
	blued.sweep(PackedVector3Array([pod * (Vector3(s * (half + 3.3), 0.0, -1.0) * k), pod * (Vector3(s * (half + 3.3), 0.0, -9.5) * k)]), PackedVector3Array([pod.basis * Vector3.UP]), PackedVector2Array([Vector2(0.4, -0.9) * k, Vector2(-0.4, -0.9) * k, Vector2(-0.4, 0.9) * k, Vector2(0.4, 0.9) * k]), true)
	# The pod, in its clamp.
	var rounds: Array = []
	if kind == "rockets":
		rounds = _rocket_pod(pod)
	else:
		rounds = _seeker_pod(pod)
	_clamp(pod, kind, 0.0)
	_clamp(pod, kind, -30.0 if kind == "rockets" else -22.0)
	# The firing cable from the box's side, drooping, to the pod's breech.
	var c0: Vector3 = lx.call(s * 1.5, -2.0, -15.0)
	var c1: Vector3 = pod * (Vector3(-s * 3.0, -3.0, 14.0) * k)
	var cable := PackedVector3Array()
	for j in 9:
		var u := j / 8.0
		cable.append(c0.lerp(c1, u) + Vector3.DOWN * 4.0 * k * sin(PI * u))
	_tm("dark").sweep(cable, PackedVector3Array([Vector3.UP]), TackMesh.circle(0.55 * k, 6), true)
	var mz := []
	var launch := []
	for m in muzzles_local:
		var mp: Vector3 = pod * ((m as Vector3) * k)
		mz.append(mp)
		# Where the round starts: its muzzle, or -- if the head is still in its way with the mount at its
		# highest (an owl's) -- just past the head along the line of fire.
		var lp := mp
		for hc in heads:
			var rel: Vector3 = hc - lp
			if rel.dot(down) > 0.0 and (rel - down * rel.dot(down)).length() < hr:
				lp = mp + down * (rel.dot(down) + hr)
		launch.append(lp)
	return {"kind": kind, "side": s, "pivot": pod, "rounds": rounds, "muzzles": mz, "launch": launch, "capped": pivot.y >= top - 1e-6}


## Each round's muzzle in its pod's frame (real cm, -Z forward): just ahead of its nose.
func _pod_muzzles(kind: String) -> Array:
	var out := []
	if kind == "rockets":
		for c in _rocket_tubes():
			out.append(Vector3(c.x, c.y, -73.0))
	else:
		for x in [-3.6, 3.6]:
			out.append(Vector3(x, -3.0, -50.0))
	return out


func _rocket_tubes() -> Array:
	return [Vector2(-4.7, -2.8), Vector2(4.7, -2.8), Vector2(0.0, 5.3)]


## The pod's cross-section (pod frame, real cm), as points round its parts: the tubes (rockets), or the
## seekers and the rail over them.
func _pod_outline(kind: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var circ := func(c: Vector2, r: float) -> void:
		for j in 16:
			pts.append(c + Vector2(cos(TAU * j / 16.0), sin(TAU * j / 16.0)) * r)
	if kind == "rockets":
		for c in _rocket_tubes():
			circ.call(c, 4.2)
	else:
		for x in [-3.6, 3.6]:
			circ.call(Vector2(x, -3.0), 2.6)
		for q in [Vector2(-7.0, 2.4), Vector2(7.0, 2.4), Vector2(-7.0, 4.8), Vector2(7.0, 4.8), Vector2(-4.0, 6.2), Vector2(4.0, 6.2)]:
			pts.append(q)
	return pts


## Convex hull of 2D points, counter-clockwise (monotone chain).
static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var p := Array(pts)
	p.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var cross := func(o: Vector2, a: Vector2, b: Vector2) -> float: return (a - o).cross(b - o)
	var lower: Array = []
	for q in p:
		while lower.size() >= 2 and float(cross.call(lower[-2], lower[-1], q)) <= 0.0:
			lower.pop_back()
		lower.append(q)
	var upper: Array = []
	for i in range(p.size() - 1, -1, -1):
		var q: Vector2 = p[i]
		while upper.size() >= 2 and float(cross.call(upper[-2], upper[-1], q)) <= 0.0:
			upper.pop_back()
		upper.append(q)
	lower.pop_back()
	upper.pop_back()
	return PackedVector2Array(lower + upper)


## The pod's widest half width (real cm), from its outline.
func _pod_half(kind: String) -> float:
	var h := 0.0
	for q in _pod_outline(kind):
		h = maxf(h, absf(q.x))
	return h


## A band round the pod at `z` (pod frame, real cm), drawn tight round its outline: blued, with a clamp bolt on
## top.
func _clamp(pod: Transform3D, kind: String, z: float) -> void:
	var k := 1.0 / cm
	var hull := _hull(_pod_outline(kind))
	var n := hull.size()
	var loop := PackedVector3Array()
	var ups := PackedVector3Array()
	var top := -INF
	for i in n + 1:
		var a: Vector2 = hull[(i - 1 + n) % n]
		var b: Vector2 = hull[i % n]
		var c: Vector2 = hull[(i + 1) % n]
		var out := ((b - a).orthogonal().normalized() + (c - b).orthogonal().normalized()).normalized()   # (outward: the hull runs counter-clockwise)
		var q := b + out * 0.05
		top = maxf(top, q.y)
		loop.append(pod * (Vector3(q.x, q.y, z) * k))
		ups.append(pod.basis * Vector3(out.x, out.y, 0.0))
	var sec: Array = _tm("blued").strap_section(3.0 * k, 0.8 * k)
	_tm("blued").sweep(loop, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.4]), false)
	clamp_loops.append([loop, pod, kind, z])
	var bolt := pod * (Vector3(0.0, top + 1.3, z) * k)
	_tm("brass").sweep(PackedVector3Array([bolt + pod.basis.x * 2.2 * k, bolt - pod.basis.x * 2.2 * k]), PackedVector3Array([pod.basis.y]), TackMesh.circle(0.6 * k, 6), true)
	_tm("brass").lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.1 * k, 0.0), Vector2(1.1 * k, 0.9 * k), Vector2(0.0, 0.9 * k)]), 6, Transform3D(Basis(Vector3.BACK, PI * 0.5) * pod.basis, bolt + pod.basis.x * 2.2 * k))


## Three brass tubes in a cluster (two under, one over), banded, a blued spine along the top; a rocket in each
## (noses out of the mouths, fins out of the backs, so you count what's left).
func _rocket_pod(pod: Transform3D) -> Array:
	var k := 1.0 / cm
	var brass := _tm("brass")
	var blued := _tm("blued")
	var rounds := []
	var lt := 70.0 * k
	for c in _rocket_tubes():
		var xf := Transform3D(pod.basis * Basis(Vector3.RIGHT, -PI * 0.5), pod * (Vector3(c.x, c.y, 14.0) * k))   # (lathe +Y -> pod -Z)
		var ro := 4.2 * k
		var ri := 3.4 * k
		brass.lathe(PackedVector2Array([Vector2(ri, 2.0 * k), Vector2(ri, 0.0), Vector2(ro * 1.1, 0.0), Vector2(ro * 1.1, 1.0 * k), Vector2(ro, 1.6 * k), Vector2(ro, lt - 1.6 * k), Vector2(ro * 1.1, lt - 1.0 * k), Vector2(ro * 1.1, lt), Vector2(ri, lt), Vector2(ri, lt - 4.0 * k)]), 16, xf, PackedFloat32Array([0.4, 0.0, 0.0, 0.3, 99, 99, 0.3, 0.0, 0.0, 0.4]), PackedFloat32Array([0.8, 0.4, 0, 0, 0, 0, 0, 0, 0.5, 0.9]))
		rounds.append(_round(lt, k, xf))
	# Bands round the cluster, riveted.
	for zb in [8.0, -48.0]:
		var loop := PackedVector3Array()
		var ups := PackedVector3Array()
		for j in 41:
			var a := TAU * j / 40.0
			var d := Vector2(cos(a), sin(a))
			var h := -INF
			for c in _rocket_tubes():
				h = maxf(h, (c as Vector2).dot(d) + 4.7)
			loop.append(pod * (Vector3(d.x * h, d.y * h, zb) * k))
			ups.append(pod.basis * Vector3(d.x, d.y, 0.0))
		var sec: Array = brass.strap_section(3.2 * k, 0.8 * k)
		brass.sweep(loop, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.35]), false)
		for c in _rocket_tubes():
			var d3 := Vector3(c.x, c.y, 0.0).normalized()
			brass.lathe(_ball(0.6 * k), 6, Transform3D(pod.basis * _basis_y(d3), pod * ((Vector3(c.x, c.y, 0.0) + d3 * 4.9 + Vector3(0, 0, zb)) * k)))
	# The spine: a blued bar along the top tube, tying the bands; a breech plate across the backs (the fins
	# stand behind it).
	blued.sweep(PackedVector3Array([pod * (Vector3(0.0, 10.1, 12.0) * k), pod * (Vector3(0.0, 10.1, -52.0) * k)]), PackedVector3Array([pod.basis.y]), PackedVector2Array([Vector2(1.8, 0.0) * k, Vector2(-1.8, 0.0) * k, Vector2(-1.8, 1.0) * k, Vector2(1.8, 1.0) * k]), true)
	return rounds


## A rail with two seekers slung under it side by side on launch shoes; a cover plate over the rail.
func _seeker_pod(pod: Transform3D) -> Array:
	var k := 1.0 / cm
	var blued := _tm("blued")
	var brass := _tm("brass")
	var rounds := []
	# The rail: a blued beam, wide enough for both seekers.
	_rbox(blued, pod * (Vector3(0.0, 3.6, -14.0) * k), Vector3(14.0, 2.4, 60.0) * k, 0.8 * k, pod.basis)
	_rbox(blued, pod * (Vector3(0.0, 5.4, -14.0) * k), Vector3(8.0, 1.6, 50.0) * k, 0.6 * k, pod.basis)
	for x in [-3.6, 3.6]:
		for z in [8.0, -26.0]:
			_rbox(blued, pod * (Vector3(x, 1.4, z) * k), Vector3(2.4, 2.2, 4.0) * k, 0.4 * k, pod.basis)
		rounds.append(_seeker(pod * (Vector3(x, -3.0, 18.0) * k), pod.basis, k))
	# Rail end caps, brass.
	for z in [16.0, -44.0]:
		_rbox(brass, pod * (Vector3(0.0, 3.6, z) * k), Vector3(14.6, 3.0, 1.2) * k, 0.4 * k, pod.basis)
	return rounds


## One seeker, tail at `p`, pointing along basis -Z (its own MeshInstance, hidden when fired): a nickel body
## with a brass band at the warhead's joint, a red nose with the seeker's glass eye at its tip, four canards
## and four tail fins (in an X).
func _seeker(p: Vector3, b: Basis, k: float) -> MeshInstance3D:
	var xf := Transform3D(b * Basis(Vector3.RIGHT, -PI * 0.5), p)   # (lathe +Y -> forward)
	var r := 2.6 * k
	var body := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	body.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 0.7, 0.0), Vector2(r * 0.85, 1.2 * k), Vector2(r, 3.0 * k), Vector2(r, 52.0 * k)]), 14, xf)
	var fins := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	for f in 4:
		var a := TAU * f / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-sin(a), 0.0, cos(a))
		# Tail fin: a swept trapezoid from the body out, 12 cm long at the root.
		fins.sweep(PackedVector3Array([xf * (d * r * 0.95 + Vector3(0, 7.0 * k, 0)), xf * (d * (r + 4.2 * k) + Vector3(0, 3.0 * k, 0))]), PackedVector3Array([xf.basis * side]), PackedVector2Array([Vector2(-0.22 * k, -7.0 * k), Vector2(0.22 * k, -7.0 * k), Vector2(0.22 * k, 5.0 * k), Vector2(-0.22 * k, 5.0 * k)]), true)
		# Canard: small, ahead of the band.
		fins.sweep(PackedVector3Array([xf * (d * r * 0.95 + Vector3(0, 46.0 * k, 0)), xf * (d * (r + 1.8 * k) + Vector3(0, 45.0 * k, 0))]), PackedVector3Array([xf.basis * side]), PackedVector2Array([Vector2(-0.18 * k, -2.0 * k), Vector2(0.18 * k, -2.0 * k), Vector2(0.18 * k, 1.5 * k), Vector2(-0.18 * k, 1.5 * k)]), true)
	var band := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	band.lathe(PackedVector2Array([Vector2(r, 38.0 * k), Vector2(r * 1.08, 38.5 * k), Vector2(r * 1.08, 41.0 * k), Vector2(r, 41.5 * k)]), 14, xf)
	var nose := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	var np := PackedVector2Array()
	for j in 8:
		var u := j / 7.0
		np.append(Vector2(r * (1.0 - 0.62 * pow(u, 1.4)), (52.0 + 11.0 * u) * k))
	nose.lathe(np, 14, xf)
	var eye := TackMesh.new(TackMesh.REAL_H * 100.0 / cm)
	var ep := PackedVector2Array()
	for j in 6:
		var a := PI * 0.5 * j / 5.0
		ep.append(Vector2(r * 0.4 * cos(a), (63.0 + 2.2 * sin(a)) * k))
	eye.lathe(ep, 12, xf)
	var m := body.commit()
	m = fins.commit(m)
	m = band.commit(m)
	m = nose.commit(m)
	m = eye.commit(m)
	for i in 5:
		m.surface_set_material(i, TackMaterials.get_mat(["nickel", "blued", "brass", "red", "glass"][i]))
	var mi := MeshInstance3D.new()
	mi.name = "Seeker"
	mi.mesh = m
	add_child(mi)
	return mi


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
