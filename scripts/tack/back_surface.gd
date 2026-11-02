class_name BackSurface
extends RefCounted
## The trunk's shell (BodyShape) as a surface the tack is fitted to: a point by (z along the trunk, s the arc
## from the spine round the ring, + to the right), and how far off it. Saddle panels and harness straps are
## laid out in (z, s), so they follow the shell exactly and fit snugly whatever the species. Rig space.

const STEPS := 180   ## ring samples from the spine (t = 90 deg) round the right side to the keel (-90 deg)

var body: BodyShape
var _tables := {}    ## z key -> PackedFloat32Array: arc length at each ring sample


func _init(b: BodyShape) -> void:
	body = b


func _t_at(i: int) -> float:
	return PI * 0.5 - PI * float(i) / STEPS


func _ring_point(r: PackedFloat32Array, t: float, z: float) -> Vector3:
	var p := BodyShape.section(t, r[1], r[2], r[3])
	return Vector3(p.x, r[0] + p.y, z)


func _table(z: float) -> PackedFloat32Array:
	var key := int(roundf(z * 4000.0))
	if _tables.has(key):
		return _tables[key]
	var zq := key / 4000.0
	var r := body.ring_at(zq)
	var arc := PackedFloat32Array([0.0])
	var prev := _ring_point(r, _t_at(0), zq)
	for i in range(1, STEPS + 1):
		var p := _ring_point(r, _t_at(i), zq)
		arc.append(arc[i - 1] + p.distance_to(prev))
		prev = p
	_tables[key] = arc
	return arc


## Half the ring's girth at z (spine to keel).
func half_girth(z: float) -> float:
	var a := _table(z)
	return a[STEPS]


## The ring angle t at arc s from the spine (|s| clamped to the half girth); s < 0 on the left.
func t_of(z: float, s: float) -> float:
	var a := _table(z)
	var target := minf(absf(s), a[STEPS])
	var lo := 0
	var hi := STEPS
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if a[mid] < target:
			lo = mid
		else:
			hi = mid
	var f := (target - a[lo]) / maxf(a[hi] - a[lo], 1e-9)
	return lerpf(_t_at(lo), _t_at(hi), f)


## The arc from the spine at ring angle t (0..90 deg on the flank, 90 the spine, -90 the keel).
func s_of(z: float, t: float) -> float:
	var a := _table(z)
	var fi := clampf((PI * 0.5 - t) / PI * STEPS, 0.0, STEPS)
	var i := mini(int(fi), STEPS - 1)
	return lerpf(a[i], a[i + 1], fi - i)


## The shell point at (z, s), `h` off it along the outward normal.
func point(z: float, s: float, h := 0.0) -> Vector3:
	var r := body.ring_at(z)
	var p := _ring_point(r, t_of(z, s), z)
	if s < 0.0:
		p.x = -p.x
	if h != 0.0:
		p += normal(z, s) * h
	return p


func normal(z: float, s: float) -> Vector3:
	var e := 0.0015
	var pz := _raw(z + e, s) - _raw(z - e, s)
	var ps := _raw(z, s + e) - _raw(z, s - e)
	var n := ps.cross(pz).normalized()
	var c := Vector3(0.0, body.ring_at(z)[0], z)
	if n.dot(_raw(z, s) - c) < 0.0:
		n = -n
	return n


func _raw(z: float, s: float) -> Vector3:
	var r := body.ring_at(z)
	var p := _ring_point(r, t_of(z, s), z)
	if s < 0.0:
		p.x = -p.x
	return p


## Height of the spine (top of the ring) at z.
func spine_y(z: float) -> float:
	var r := body.ring_at(z)
	return r[0] + r[2]


## Elevation of the shell point (z, s) seen from the ring's centre: 90 deg over the spine, 0 at the widest.
func elevation(z: float, s: float) -> float:
	var p := _raw(z, s)
	return rad_to_deg(atan2(p.y - body.ring_at(z)[0], absf(p.x)))
