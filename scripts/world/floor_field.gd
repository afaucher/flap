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

const RES := 0.5            ## m between the grid's points
const MOUND_H := 0.22       ## m: the mounds at their highest
const MOSS_SHARE := 0.2     ## of the floor
const DIRT_SHARE := 0.08
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
			f.data[k * 4] = MOUND_H * hh * lit * fade
			f.data[k * 4 + 1] = ms
			f.data[k * 4 + 2] = ds
			f.data[k * 4 + 3] = op
	return f


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
