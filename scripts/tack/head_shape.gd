class_name HeadShape
extends RefCounted
## The rider's head, as a radial function: the skull a superellipsoid (round behind and above, flatter and
## fuller in the face, the jaw narrower than the cranium, the nape curving in to the neck), with the face's
## landforms added in front -- brow ridge, eye sockets, nose (bridge, tip, wings), cheekbones, lips, chin.
## Real cm, head frame: -Z the way the face looks, +Y up, the origin the head's middle. Rider builds the skin,
## the helmet (the skull's surface pushed out by its padding) and the goggles from it; tests measure them
## against it.

const EYE := Vector2(3.2, 0.6)   ## (x, y) of each eye's centre (x mirrored)
const EYE_R := 1.15
const HELMET_T := 0.9            ## the helmet's padding: its shell this far out from the skull


## The surface's distance from the middle along unit direction `d`.
static func radius(d: Vector3, socket := true) -> float:
	var r := base_radius(d)
	var w := smoothstep(0.15, 0.6, -d.z)
	if w <= 0.0:
		return r
	var p := d * r
	return r + w * relief(p.x, p.y, socket)


static func base_radius(d: Vector3) -> float:
	var a := 7.6 * lerpf(1.0, 0.84, smoothstep(-0.05, -0.85, d.y))   # the jaw narrower than the cranium
	var b := 10.6 if d.y > 0.0 else 11.8
	var c := 9.4
	var n := 2.0
	if d.z > 0.0:
		c = 9.9 * lerpf(1.0, 0.7, smoothstep(-0.2, -0.85, d.y))   # the nape curves in to the neck
	else:
		n = lerpf(2.0, 2.9, smoothstep(0.1, 0.6, -d.z) * smoothstep(0.35, -0.4, d.y))   # a flat, full face
	var s := pow(absf(d.x) / a, n) + pow(absf(d.y) / b, n) + pow(absf(d.z) / c, n)
	return 1.0 / pow(s, 1.0 / n)


static func _g(x: float, y: float, cx: float, cy: float, sx: float, sy: float) -> float:
	return exp(-pow((x - cx) / sx, 2.0) - pow((y - cy) / sy, 2.0))


## The face's landforms (cm out from the skull) at face position (x, y).
static func relief(x: float, y: float, socket := true) -> float:
	var ax := absf(x)
	var h := 0.0
	# Brow ridge, with a little dip between the brows.
	h += 0.75 * exp(-pow((y - 2.1) / 0.8, 2.0)) * (1.0 - smoothstep(4.6, 6.4, ax)) * (1.0 - 0.3 * exp(-pow(x / 0.9, 2.0)))
	if socket:
		h -= 1.05 * _g(ax, y, EYE.x, EYE.y, 1.55, 1.05)
	# Nose: the bridge rising from between the eyes to the tip, the tip's ball, the wings (alae).
	var t := clampf((1.4 - y) / 4.5, 0.0, 1.0)
	var ridge := lerpf(0.55, 2.3, pow(t, 1.3)) * exp(-pow(x / lerpf(0.62, 1.0, t), 2.0))
	ridge *= smoothstep(2.2, 1.0, y) * (1.0 - smoothstep(-3.1, -4.2, y))
	h += ridge
	h += 0.65 * _g(x, y, 0.0, -2.9, 0.85, 0.7)
	h += 0.95 * _g(ax, y, 1.35, -3.35, 0.6, 0.55)
	# Cheekbones; the hollow beneath; the fold from the nose's wing to the mouth's corner.
	h += 0.7 * _g(ax, y, 4.7, -0.6, 1.5, 1.1)
	h -= 0.35 * _g(ax, y, 4.3, -4.6, 1.2, 1.6)
	var fold_t := clampf((-3.3 - y) / 2.4, 0.0, 1.0)
	var fold_x := lerpf(1.95, 2.75, fold_t)
	h -= 0.22 * exp(-pow((ax - fold_x) / 0.32, 2.0)) * smoothstep(-3.0, -3.6, y) * (1.0 - smoothstep(-5.4, -6.2, y))
	# Lips: the upper (with its groove), the line between, the lower; the dip under it; the chin.
	h += 0.5 * _g(x, y, 0.0, -4.85, 2.0, 0.55)
	h -= 0.12 * _g(x, y, 0.0, -4.4, 0.35, 0.45)
	var mouth_y := -5.45 + 0.07 * x * x
	h -= 0.35 * exp(-pow((y - mouth_y) / 0.2, 2.0)) * (1.0 - smoothstep(1.9, 2.5, ax))
	h += 0.42 * _g(x, y, 0.0, -6.05, 1.7, 0.45)
	h -= 0.25 * _g(x, y, 0.0, -7.05, 1.6, 0.5)
	h += 1.0 * _g(x, y, 0.0, -8.7, 1.9, 1.25)
	return h


## Skin colour masks at face position (x, y), weight `w` (1 in the face): r flush (cheeks, nose, lips), g
## cavity, a stubble.
static func masks(x: float, y: float, w: float) -> Color:
	var ax := absf(x)
	var lips := maxf(_g(x, y, 0.0, -4.95, 1.9, 0.38), _g(x, y, 0.0, -5.95, 1.6, 0.36))
	var flush := 0.45 * _g(ax, y, 4.0, -2.0, 1.6, 1.4) + 0.4 * _g(x, y, 0.0, -2.9, 1.0, 1.0) + lips
	var cav := 0.55 * _g(ax, y, EYE.x - 1.6, EYE.y - 0.2, 0.5, 0.6) + 0.35 * _g(ax, y, 1.3, -3.95, 0.7, 0.3)
	var mouth_y := -5.45 + 0.07 * x * x
	cav += 0.5 * exp(-pow((y - mouth_y) / 0.14, 2.0)) * (1.0 - smoothstep(1.9, 2.4, ax))
	var stubble := smoothstep(-2.6, -5.5, y) * (1.0 - 0.8 * lips) * (1.0 - smoothstep(-10.0, -11.5, y))
	stubble = maxf(stubble - 0.7 * _g(ax, y, 4.0, -2.6, 1.6, 1.3), 0.0)
	return Color(clampf(flush * w, 0.0, 1.0), clampf(cav * w, 0.0, 1.0), 0.0, clampf(stubble * lerpf(0.5, 1.0, w), 0.0, 1.0))


## The unit direction at polar angle `th` from +Y and azimuth `ph` (0 the way the face looks, + to the right).
static func dir(th: float, ph: float) -> Vector3:
	return Vector3(sin(th) * sin(ph), cos(th), -sin(th) * cos(ph))


static func point(d: Vector3, socket := true) -> Vector3:
	return d * radius(d, socket)


## The outward surface normal along `d` (finite differences on the sphere of directions).
static func normal(d: Vector3) -> Vector3:
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1)
	var e := 0.01
	var a := point((d + t1 * e).normalized()) - point((d - t1 * e).normalized())
	var b := point((d + t2 * e).normalized()) - point((d - t2 * e).normalized())
	var n := a.cross(b).normalized()
	return n if n.dot(d) > 0.0 else -n


## The eye's centre (x sign `side`): set back behind the face so the brow ridge stands over it.
static func eye_centre(side: float) -> Vector3:
	var d := Vector3(side * EYE.x, EYE.y, -8.5).normalized()
	var p := Vector3.ZERO
	for i in 6:
		p = point(d, false)
		d = Vector3(side * EYE.x, EYE.y, p.z).normalized()
	return Vector3(side * EYE.x, EYE.y, p.z + 0.25 + EYE_R)


## The helmet's outer surface along `d`: the skull pushed out along its normal by the padding.
static func helmet_point(d: Vector3) -> Vector3:
	return point(d) + normal(d) * HELMET_T


## How far `p` lies outside the helmet's outer surface (measured along the ray from the middle).
static func helmet_gap(p: Vector3) -> float:
	var l := p.length()
	return l - helmet_point(p / l).length() if l > 1e-4 else -INF


## The helmet's lower edge, as the polar angle at azimuth `ph`: across the forehead above the brows, down the
## cheek flaps' front edges behind the eyes to the jaw, round the nape behind.
static func helmet_edge(ph: float) -> float:
	var a := absf(wrapf(ph, -PI, PI))
	var e := lerpf(1.2 - 0.03 * smoothstep(0.0, 0.7, a), 2.6, smoothstep(0.74, 1.2, a))
	return lerpf(e, 2.3, smoothstep(2.1, 2.6, a))


## How far point `p` (head frame) lies outside the skin (negative: inside).
static func gap(p: Vector3) -> float:
	var l := p.length()
	return l - radius(p / l) if l > 1e-4 else -INF
