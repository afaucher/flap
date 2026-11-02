class_name FeatherAtlas
extends RefCounted
## Baked feather textures for plumage level 6 (docs/research/feather_texture_study.md). Two images, generated
## here and saved as PNGs by tools/bake_feathers.gd (they take a few seconds to bake, so the game loads the
## PNGs, imported with mipmaps):
## - the ATLAS: one cell per feather type (primary, slotted primary, secondary, tail, greater covert, lesser
##   covert), two variants of each, laid out to match the feather card's UVs (BirdRig._feather_mesh: UV.x -1..1
##   across the vane, UV.y 0..1 base to tip). The image's x runs from the trailing (inner-vane) edge to the
##   leading (outer-vane) edge, and its y from the tip (top) to the base (bottom).
## - the BODY tile: small overlapping contour feathers, tip toward +y (the tail), repeating.
## Neither carries colour. Each texel is four masks the shader colours per species and strip row:
##   R  shade: soft barb striations, vane splits, mottling, the shadow where the row above covers the base,
##        a darker rim (1 = unshaded; typical 0.85)
##   G  rachis: the shaft
##   B  spot field: soft blobs (dark spots near the tip of coverts and body feathers, paired spots along the
##        flight feathers) that the shader thresholds, so a species picks how big they are
##   A  edge distance: 0 at the feather's outline (and outside it: the card's tip is rounded off to a half disc,
##        cut away by the shader's alpha scissor) .. 1 half a vane-width in (pale fringes, dark centres)
## Units: feather geometry is in half-widths of the vane at its widest (`hw`), so spots, barbs and fringes keep
## their size from a long narrow primary to a short broad covert.

const ATLAS_PATH := "res://assets/feathers/feather_atlas.png"
const BODY_PATH := "res://assets/feathers/body_scales.png"
const ATLAS_SIZE := Vector2i(1024, 768)
const BODY_SIZE := 512

enum Type { PRIMARY, SLOTTED, SECONDARY, TAIL, GREATER, LESSER }
## Per type: its cell (pixels, variant 0; variant 1 sits one cell width to the right), the outline (BirdRig's
## PLAIN or EMARG profile), the vane's width / length (WingShape's W_* ratios), where the shaft sits (`asym`,
## toward the leading edge, in UV.x units: the outer vane is the narrow one), how far up the row in front
## covers it (`overlap`, share of the length), the barbs' angle off the shaft on the outer and inner vane
## (deg), and the spot layout.
const TYPES := [
	{"rect": [0, 0, 128, 512], "profile": "plain", "aspect": 0.16, "asym": 0.4, "overlap": 0.34, "barb": [24.0, 40.0], "spots": "flight"},
	{"rect": [256, 0, 128, 512], "profile": "emarg", "aspect": 0.13, "asym": 0.4, "overlap": 0.34, "barb": [24.0, 40.0], "spots": "flight"},
	{"rect": [512, 0, 128, 512], "profile": "plain", "aspect": 0.27, "asym": 0.22, "overlap": 0.44, "barb": [30.0, 45.0], "spots": "flight"},
	{"rect": [768, 0, 128, 512], "profile": "plain", "aspect": 0.2, "asym": 0.12, "overlap": 0.3, "barb": [28.0, 40.0], "spots": "flight"},
	{"rect": [0, 512, 128, 256], "profile": "plain", "aspect": 0.55, "asym": 0.08, "overlap": 0.42, "barb": [45.0, 55.0], "spots": "pair"},
	{"rect": [256, 512, 128, 256], "profile": "plain", "aspect": 0.6, "asym": 0.0, "overlap": 0.4, "barb": [50.0, 55.0], "spots": "drop"},
]
const VARIANTS := 2
## Chevron: how far the colour strip's bands sweep toward the tip at the vane's edge (UV.y per UV.x off the
## shaft), so bars follow the barbs (a V pointing to the base) instead of crossing the feather square.
const CHEVRON := [0.025, 0.025, 0.035, 0.03, 0.06, 0.06]


## The atlas cell for a feather group ("primary", "tail", ... as Plumage.group names them; `slotted`: the
## emarginated primary mesh) and variant.
static func cell(g: String, slotted: bool, variant: int) -> int:
	var t := Type.PRIMARY
	match g:
		"primary", "alula": t = Type.SLOTTED if slotted else Type.PRIMARY
		"secondary", "tertial": t = Type.SECONDARY
		"tail": t = Type.TAIL
		"greater", "under_covert": t = Type.GREATER
		"lesser", "lesser_bar": t = Type.LESSER
	return t * VARIANTS + (variant % VARIANTS)


## Cell rectangles in atlas UV (x0, y0, w, h), indexed by cell().
static func cell_rects() -> PackedVector4Array:
	var out := PackedVector4Array()
	for t in TYPES.size():
		var r: Array = TYPES[t].rect
		for v in VARIANTS:
			out.append(Vector4(float(r[0] + v * r[2]) / ATLAS_SIZE.x, float(r[1]) / ATLAS_SIZE.y, float(r[2]) / ATLAS_SIZE.x, float(r[3]) / ATLAS_SIZE.y))
	return out


## Per cell: (shaft position in UV.x, chevron, 0, 0), indexed by cell().
static func cell_shapes() -> PackedVector4Array:
	var out := PackedVector4Array()
	for t in TYPES.size():
		for v in VARIANTS:
			out.append(Vector4(float(TYPES[t].asym), float(CHEVRON[t]), 0.0, 0.0))
	return out


static func load_atlas() -> Texture2D:
	return load(ATLAS_PATH) as Texture2D


static func load_body() -> Texture2D:
	return load(BODY_PATH) as Texture2D


# --- Baking ---------------------------------------------------------------------------------------------

## Half-width of the outline at v (0 base .. 1 tip), as a share of the widest.
static func _prof(pts: Array, v: float) -> float:
	for k in pts.size() - 1:
		var a: Array = pts[k]
		var b: Array = pts[k + 1]
		if v <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (v - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6))
	return float(pts[pts.size() - 1][1])


static func _hash(a: float, b: float) -> float:
	var h := sin(a * 127.1 + b * 311.7) * 43758.5453
	return h - floorf(h)


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func bake_atlas() -> Image:
	var w := ATLAS_SIZE.x
	var h := ATLAS_SIZE.y
	var data := PackedByteArray()
	data.resize(w * h * 4)
	data.fill(0)
	# (empty texels: a flat mid shade with no marks, so mip bleed from an unused corner is harmless)
	for i in w * h:
		data[i * 4] = 220
		data[i * 4 + 3] = 255
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	for t in TYPES.size():
		var spec: Dictionary = TYPES[t]
		var r: Array = spec.rect
		for variant in VARIANTS:
			noise.seed = 17 + t * 13 + variant * 101
			_bake_cell(data, w, int(r[0]) + variant * int(r[2]), int(r[1]), int(r[2]), int(r[3]), spec, variant, noise)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _bake_cell(data: PackedByteArray, img_w: int, x0: int, y0: int, cw: int, ch: int, spec: Dictionary, variant: int, noise: FastNoiseLite) -> void:
	var pts: Array = BirdRig.EMARG_PROFILE if spec.profile == "emarg" else BirdRig.PLAIN_PROFILE
	var length := 2.0 / float(spec.aspect)   # the feather's length in half-widths
	var asym := float(spec.asym)
	var overlap := float(spec.overlap)
	var tan_o := tan(deg_to_rad(float(spec.barb[0])))
	var tan_i := tan(deg_to_rad(float(spec.barb[1])))
	var spots := String(spec.spots)
	var vs := float(variant)
	for py in ch:
		var v := 1.0 - (py + 0.5) / ch
		var pw := _prof(pts, v)
		var y := v * length
		for px in cw:
			var u := (px + 0.5) / cw * 2.0 - 1.0   # -1 trailing .. 1 leading edge
			var x := u * pw
			var xr := asym * pw
			var dx := x - xr
			var outer := dx > 0.0
			var vane := pw * ((1.0 - asym) if outer else (1.0 + asym))
			var q := clampf(absf(dx) / maxf(vane, 1e-4), 0.0, 1.0)   # 0 at the shaft .. 1 at the vane's edge
			var tn := tan_o if outer else tan_i
			# Along a barb, y - |dx| / tan(angle) is constant: the barb's "phase".
			var phase := y - absf(dx) / tn
			var side := 1.0 if outer else 0.0
			# --- shade ---
			var shade := 1.0
			shade -= 0.06 * (0.5 + 0.5 * cos(TAU * phase * 7.0))                       # barb striations
			shade -= 0.06 * noise.get_noise_2d(phase * 2.2, side * 9.0 + vs * 3.0)      # barbs clumping
			shade -= 0.04 * noise.get_noise_2d(x * 1.3 + 40.0, y * 1.3)                 # mottling
			# Vane splits: here and there the barbs part along a line, more open toward the edge.
			var sf := 0.9
			var j := floorf(phase * sf + side * 0.37 + vs * 0.61)
			if _hash(j, side + vs * 7.0) < 0.42:
				var centre := (j + 0.5 + 0.3 * (_hash(j + 5.0, side) - 0.5) - side * 0.37 - vs * 0.61) / sf
				var dist := absf(phase - centre) * sin(atan(tn))
				shade -= 0.3 * exp(-pow(dist / 0.03, 2.0)) * _smooth(0.25, 0.85, q)
			# The row in front covers the base: shadow just past where it ends, so rows read as layers.
			shade *= lerpf(0.7, 1.0, _smooth(overlap - 0.1, overlap + 0.14, v))
			# To the outline, half-widths. The outline is the card's, with its tip rounded off to a half disc as wide
			# as the vane (soft round tips; the shader cuts away what lies outside, A = 0).
			var cap_y := y - (length - 1.0)
			var allowed := pw if cap_y <= 0.0 else minf(pw, sqrt(maxf(1.0 - cap_y * cap_y, 0.0)))
			var edge := maxf(minf(allowed - absf(x), (1.0 - v) * length), 0.0)
			shade *= lerpf(0.86, 1.0, _smooth(0.0, 0.08, edge))                         # a darker rim
			# --- shaft ---
			var rw := 0.07 * (1.0 - 0.75 * v)
			var rachis := (1.0 - _smooth(rw * 0.5, rw * 1.3, absf(dx))) * _smooth(0.0, 0.03, v) * (1.0 - _smooth(0.94, 0.99, v))
			# --- spots ---
			var spot := 0.0
			var wob := 0.18 * noise.get_noise_2d(x * 3.0 + 90.0, y * 3.0)
			match spots:
				"flight":   # a spot on each vane at 5 stations toward the tip: broken bars
					for k in 5:
						var vk := 0.42 + 0.11 * k + 0.02 * (_hash(float(k), vs) - 0.5)
						var yc := vk * length - absf(dx) / tn * 0.35
						var xc := xr + (0.55 if outer else -0.5) * vane
						var d := pow((x - xc) / (0.32 * vane + 0.05), 2.0) + pow((y - yc) / 0.42, 2.0)
						spot = maxf(spot, exp(-d * (1.0 + wob)))
				"pair":   # a dark spot on each vane, near the tip
					var yc := (0.68 + 0.04 * vs) * length
					var xc := xr + (0.48 if outer else -0.48) * vane
					var d := pow((x - xc) / ((0.34 - 0.06 * vs) * vane), 2.0) + pow((y - yc) / (0.42 - 0.06 * vs), 2.0)
					spot = exp(-d * (1.0 + wob))
				"drop":   # one arrowhead across the shaft, near the tip
					var yc := (0.66 + 0.04 * vs) * length + 0.35 * absf(dx)
					var d := pow(dx / 0.5, 2.0) + pow((y - yc) / 0.38, 2.0)
					spot = exp(-d * (1.0 + wob))
			var i := ((y0 + py) * img_w + x0 + px) * 4
			data[i] = int(clampf(shade, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 1] = int(clampf(rachis, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 2] = int(clampf(spot, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 3] = int(clampf(edge / 0.5, 0.0, 1.0) * 255.0 + 0.5)


## Body tile: rows of small rounded feathers, each row staggered half a feather and overlapping the next
## like roof tiles (the row toward the head on top), tips toward +y. 4 feathers across, 8 rows per tile, each
## nudged and sized a little at random so the repeat doesn't read as a grid.
const BODY_COLS := 4
const BODY_ROWS := 8


static func bake_body() -> Image:
	var n := BODY_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.seed = 5
	var cw := 1.0 / BODY_COLS
	var rh := 1.0 / BODY_ROWS
	var rad0 := 0.72 * cw   # feather radius: 1.4x the half-spacing, so each row hides the last one's base
	for py in n:
		for px in n:
			var p := Vector2((px + 0.5) / n, (py + 0.5) / n)
			var row0 := int(floorf(p.y / rh))
			var hit := Vector2.INF
			var hit_id := Vector2.ZERO
			var rad := rad0
			var shadow_d := INF
			# Rows from the head end (on top) toward the tail; the first feather covering p is the one seen.
			for k in range(row0 - 3, row0 + 2):
				var off := 0.5 * cw * float(posmod(k, 2))
				var c0 := int(floorf((p.x - off) / cw))
				var found := false
				for c in range(c0 - 1, c0 + 2):
					var id := Vector2(posmod(c, BODY_COLS), posmod(k, BODY_ROWS))
					var centre := Vector2(off + (c + 0.5) * cw, (k + 0.5) * rh)
					centre += Vector2(_hash(id.x, id.y) - 0.5, _hash(id.y + 11.0, id.x) - 0.5) * Vector2(0.18 * cw, 0.3 * rh)
					var rk := rad0 * (0.94 + 0.12 * _hash(id.x + 21.0, id.y + 4.0))
					var dist := p.distance_to(centre)
					if dist < rk:
						hit = (p - centre) / rk
						hit_id = id
						rad = rk
						found = true
						break
					shadow_d = minf(shadow_d, dist - rk)
				if found:
					break
			var l := hit if hit.x != INF else Vector2.ZERO
			var r := l.length()
			# Shade: the overlying feather's shadow just past its edge, a gentle fall-off toward the tip, soft barbs.
			var shade := 1.0 - 0.28 * exp(-maxf(shadow_d, 0.0) / (0.1 * rad0))
			shade *= lerpf(1.0, 0.92, _smooth(0.6, 1.0, r))
			var phase := l.y - absf(l.x) * 0.8
			shade -= 0.04 * (0.5 + 0.5 * cos(TAU * phase * 5.0))
			shade -= 0.05 * noise.get_noise_2d(p.x * 18.0, p.y * 18.0)
			shade *= 0.94 + 0.12 * _hash(hit_id.x, hit_id.y)   # each feather a touch lighter or darker
			var rachis := (1.0 - _smooth(0.02, 0.06, absf(l.x))) * _smooth(-0.4, 0.1, l.y) * (1.0 - _smooth(0.45, 0.7, l.y))
			# A spot near the tip (on the back a dark subterminal mark, on the breast a drop): some feathers
			# strongly marked, some faintly.
			var wob := 0.25 * noise.get_noise_2d(p.x * 40.0 + 50.0, p.y * 40.0)
			var amp := 0.4 + 0.6 * _hash(hit_id.x + 3.0, hit_id.y + 7.0)
			var spot := amp * exp(-(pow(l.x / 0.2, 2.0) + pow((l.y - 0.62) / 0.24, 2.0)) * (1.0 + wob))
			var edge := clampf(2.0 * (1.0 - r), 0.0, 1.0)
			var i := (py * n + px) * 4
			data[i] = int(clampf(shade, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 1] = int(clampf(rachis * 0.6, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 2] = int(clampf(spot, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 3] = int(edge * 255.0 + 0.5)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
