class_name FloorField
extends RefCounted
## The pine wood's floor as data, the one source for what's drawn, what's solid and what the code asks of the ground
## (ArenaLayout.ground): a grid RES m apart over the wood holding, at each point, the needle litter's mound height (m),
## and the moss, dirt and opening signals the floor shader draws its patches from. Pure: built with the layout
## (Pinewood.generate; on the loading screen's worker thread), from Godot's own noise (fast, native).
##   height  low broad mounds on the litter (none on the moss, the dirt or in the openings), up to MOUND_H, gone by the
##           wood's edge
##   moss    in the hollows: -1..1 about its edge (the shader adds a ragged fine edge and thresholds at 0), MOSS_SHARE
##           of the floor
##   dirt    the same for bare dirt, DIRT_SHARE of what isn't moss
##   open    1 well inside an opening (the clearing, the glade, the gaps), 0 outside, over its edge
## Round each pine and oak, its foot (`feet`): the root plate a low dome, and the roots running out from the trunk's
## flare lobes (ArenaBuilder._trunk's four, where its mesh swells) and a couple of smaller ones between, ridges
## that taper off a few metres out; moss in the hollows between them on the shady side.

const RES := 0.5            ## m between the grid's points
const MOUND_H := 0.22       ## m: the mounds at their highest
const MOSS_SHARE := 0.2     ## of the floor
const DIRT_SHARE := 0.08
const FOOT := {"dome": Vector2(0.1, 1.6), "ridge": Vector3(0.2, 0.3, 2.6), "oak": 1.7, "veteran": 1.45, "pole": 0.5}   ## dome: height m, its reach
	## past the trunk m; ridge: height at the trunk m, half width m, length m; an oak's foot that much bigger
static var feet := true      ## the trunks' feet in the floor (off: the floor runs flat up to the trunks, for A/B)
const BAND := 0.05          ## the signals' half width about their edges (noise units: the shader's ragged edge works in it)

var n := 0                  ## points a side
var origin := Vector2.ZERO  ## the grid's (0, 0) in the world (x, z)
var size := 0.0             ## m a side
var fade_r := 0.0           ## m from the middle where the mounds are gone
var data := PackedFloat32Array()   ## n*n*4: height, moss, dirt, open


static func build(a: ArenaLayout, extent: float) -> FloorField:
	var f := FloorField.new()
	f.n = int(ceil(extent * 2.0 / RES)) + 1
	f.size = (f.n - 1) * RES
	f.origin = -Vector2.ONE * f.size * 0.5
	f.fade_r = a.boundary + 4.0
	var n := f.n
	var moss := _noise_img(a.seed * 3 + 1, 0.055, 4, f)       # (the hollows: broad)
	var dirt := _noise_img(a.seed * 3 + 2, 0.12, 3, f)
	var mound := _noise_img(a.seed * 3 + 3, 0.35, 3, f)
	var moss_thr := _quantile(moss, 1.0 - MOSS_SHARE)
	var dirt_thr := _quantile(dirt, 1.0 - DIRT_SHARE)
	var opens := PackedFloat32Array()
	opens.resize(n * n)
	for o in a.openings:   # (each opening's own patch of the grid: how far in from its ragged edge, over 3 m)
		var c: Vector2 = o.centre
		var reach := float(o.r) * 1.3 + 4.0
		var i0 := maxi(0, int((c.x - reach - f.origin.x) / RES))
		var i1 := mini(n - 1, int((c.x + reach - f.origin.x) / RES) + 1)
		var j0 := maxi(0, int((c.y - reach - f.origin.y) / RES))
		var j1 := mini(n - 1, int((c.y + reach - f.origin.y) / RES) + 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := f.origin + Vector2(i, j) * RES
				var e := Pinewood.edge(o, p)
				var v := clampf((e + 1.0 - p.distance_to(c)) / 3.0, 0.0, 1.0)
				opens[j * n + i] = maxf(opens[j * n + i], v)
	var foot_h := PackedFloat32Array()
	foot_h.resize(n * n)
	var foot_moss := PackedFloat32Array()
	foot_moss.resize(n * n)
	foot_moss.fill(-1.0)   # (no moss of their own outside the feet)
	if feet:
		_feet(a, f, foot_h, foot_moss)
	f.data.resize(n * n * 4)
	for j in n:
		for i in n:
			var k := j * n + i
			var p := f.origin + Vector2(i, j) * RES
			var ms := clampf((moss[k] - moss_thr) / BAND, -1.0, 1.0)
			var ds := clampf((dirt[k] - dirt_thr) / BAND, -1.0, 1.0)
			var op := opens[k]
			# (the mounds slope down to nothing where the moss and the dirt begin: on the litter's side of their edges)
			var lit := (1.0 - smoothstep(-1.0, 0.0, ms)) * (1.0 - smoothstep(-1.0, 0.0, ds) * 0.8) * (1.0 - op)
			var hh := smoothstep(0.3, 0.75, mound[k])
			var fade := 1.0 - smoothstep(f.fade_r - 12.0, f.fade_r, p.length())
			f.data[k * 4] = maxf(MOUND_H * hh * lit * fade, foot_h[k])
			f.data[k * 4 + 1] = maxf(ms, foot_moss[k])
			f.data[k * 4 + 2] = ds
			f.data[k * 4 + 3] = op
	return f


## Each pine's and oak's foot into `h` (height, m) and `moss` (the moss signal) over the grid round it.
static func _feet(a: ArenaLayout, f: FloorField, h: PackedFloat32Array, moss: PackedFloat32Array) -> void:
	var n := f.n
	var to_sun := Basis.from_euler(Vector3(0.0, deg_to_rad(ForestLight.SUN_AZIMUTH), 0.0)) * Vector3.BACK
	var shade_dir := -Vector2(to_sun.x, to_sun.z).normalized()   # (the side of a trunk away from the sun)
	for t in a.trees:
		if t.kind != ArenaLayout.Kind.PINE and t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		var k := foot_k(t)
		var c: Vector2 = t.base
		var roots := roots_of(t)
		var reach: float = t.radius + float(FOOT.ridge.z) * k * 1.3
		var i0 := maxi(0, int((c.x - reach - f.origin.x) / RES))
		var i1 := mini(n - 1, int((c.x + reach - f.origin.x) / RES) + 1)
		var j0 := maxi(0, int((c.y - reach - f.origin.y) / RES))
		var j1 := mini(n - 1, int((c.y + reach - f.origin.y) / RES) + 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := f.origin + Vector2(i, j) * RES
				var d := p - c
				var r := d.length()
				var out := maxf(r - t.radius, 0.0)   # (m out from the bark)
				var dome: float = float(FOOT.dome.x) * k * (1.0 - smoothstep(0.0, float(FOOT.dome.y) * k, out))
				var ridge := 0.0
				for rt in roots:
					var dir: Vector2 = rt[0]
					var along: float = d.dot(dir) - t.radius
					if along < -t.radius * 0.5:
						continue
					var across := absf(d.dot(Vector2(-dir.y, dir.x)))
					var w: float = float(rt[3]) * (1.0 - 0.5 * clampf(along / float(rt[2]), 0.0, 1.0))   # (narrowing out)
					ridge = maxf(ridge, ridge_at(along, float(rt[1]), float(rt[2])) * exp(-(across * across) / (w * w)))
				var kk := j * n + i
				h[kk] = maxf(h[kk], dome + ridge)
				# Moss in the hollows between the roots, near the trunk, on its shady side.
				if r > 0.01 and out < 2.0 * k:
					var shady := smoothstep(-0.2, 0.6, (d / r).dot(shade_dir))
					var hollow := 1.0 - smoothstep(0.03, 0.09, ridge)
					var near := 1.0 - smoothstep(1.0 * k, 2.0 * k, out)
					moss[kk] = maxf(moss[kk], (shady * hollow * near) * 1.6 - 0.6)


## Tree `t`'s roots running out from its foot: [direction (Vector2), height at the trunk m, length m, half width m]:
## one from each of the trunk's four flare lobes (ArenaBuilder._trunk's, where its mesh swells) and two smaller between.
## The floor's ridges over them (here) and the bark-covered roots drawn along them (ArenaBuilder._roots) both read these.
static func roots_of(t: ArenaLayout.TreeData) -> Array:
	var k := foot_k(t)
	var seed := fmod(t.id * 0.6180339, 1.0)   # (as ArenaBuilder._pinewood gives the trunk its lobes)
	var out := []
	for q in 4:   # (where the trunk's mesh swells: sin(4a + seed * 7) = 1; its ring at angle a points (-sin a, -cos a))
		var ang := (PI * 0.5 - seed * 7.0) / 4.0 + q * PI * 0.5 + (_hash(t.id * 3.3 + q) - 0.5) * 0.25
		out.append([Vector2(-sin(ang), -cos(ang)), FOOT.ridge.x * k * (0.75 + 0.5 * _hash(t.id * 4.1 + q)), FOOT.ridge.z * k * (0.7 + 0.6 * _hash(t.id * 2.3 + q)), FOOT.ridge.y * k])
	for q in 2:
		var ang := (PI * 0.5 - seed * 7.0) / 4.0 + (q * 2 + 1) * PI * 0.25 + (_hash(t.id * 7.7 + q) - 0.5) * 0.4
		out.append([Vector2(-sin(ang), -cos(ang)), FOOT.ridge.x * k * 0.55, FOOT.ridge.z * k * 0.6, FOOT.ridge.y * k * 0.7])
	return out


## How big tree `t`'s foot is, against a mature pine's: an oak's broad, a veteran pine's bigger, a pole's slight.
static func foot_k(t: ArenaLayout.TreeData) -> float:
	if t.kind == ArenaLayout.Kind.BROADLEAF:
		return float(FOOT.oak)
	return float(FOOT.get(t.form, 1.0))


## A root ridge's height `along` m out from the bark (of `height` at the trunk, `length` long).
static func ridge_at(along: float, height: float, length: float) -> float:
	return height * pow(1.0 - clampf(along / length, 0.0, 1.0), 1.5)


static func _hash(x: float) -> float:
	return fposmod(sin(x * 127.1) * 43758.5453, 1.0)


## Godot's noise sampled over the grid (`freq` per metre, `octaves`), 0..1, as a flat array.
static func _noise_img(s: int, freq: float, octaves: int, f: FloorField) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = s
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.frequency = freq * RES   # (the image samples a point a pixel)
	noise.offset = Vector3(f.origin.x / RES, f.origin.y / RES, 0.0)
	var img := noise.get_image(f.n, f.n, false, false, false)
	img.convert(Image.FORMAT_RF)
	var raw := img.get_data().to_float32_array()
	var out := PackedFloat32Array()
	out.resize(raw.size())
	for i in raw.size():
		out[i] = raw[i] * 0.5 + 0.5
	return out


## The value below which `share` of `v` lies (sampled: every 7th).
static func _quantile(v: PackedFloat32Array, share: float) -> float:
	var s := PackedFloat32Array()
	for i in range(0, v.size(), 7):
		s.append(v[i])
	s.sort()
	return s[clampi(int(share * (s.size() - 1)), 0, s.size() - 1)]


## The mound height (m above GROUND_Y) at world (x, z), bilinear between the grid's points; 0 off the grid.
func height(x: float, z: float) -> float:
	var u := (x - origin.x) / RES
	var v := (z - origin.y) / RES
	if u < 0.0 or v < 0.0 or u >= n - 1 or v >= n - 1:
		return 0.0
	var i := int(u)
	var j := int(v)
	var fu := u - i
	var fv := v - j
	var k := j * n + i
	return lerpf(lerpf(data[k * 4], data[(k + 1) * 4], fu), lerpf(data[(k + n) * 4], data[(k + n + 1) * 4], fu), fv)


## The heights alone, for a HeightMapShape3D (row by row along x).
func heights() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n * n)
	for k in n * n:
		out[k] = data[k * 4]
	return out


## The whole field as an image for the shader (RGBA float: height, moss, dirt, open).
func image() -> Image:
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBAF, data.to_byte_array())
