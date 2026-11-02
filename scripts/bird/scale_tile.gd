class_name ScaleTile
extends RefCounted
## The legs' and feet's skin, baked (docs/design/legs_and_feet.md §6): one repeating tile of the podotheca's scales,
## saved as PNGs by tools/bake_feathers.gd and read by leg_skin.gdshader over the leg meshes' own coordinates (UV in
## scales: u round the tube, v along it, toward the foot and the toes' tips). Baked rather than drawn in the shader:
## the domes and slopes are worked out once here, at 64 px a scale, and the GPU's mipmaps average them away smoothly
## with distance, so the pattern neither shimmers nor has to be faded out; and a fetch is cheaper than the ~18
## hashes a pixel the procedural cells took.
##   SCALES (RGBA): R reticulate scales' height (small polygonal domes with grooves between; 1 = DOME high)
##                  G scutes' height (transverse plates down the front, each one's lower lip over the next one's top)
##                  B a random value per reticulate scale (tone variation)
##                  A bristles (the barn owl's "hairy" toes: sparse fine hairs lying along the toe toward its tip)
##   NORMALS (RGBA): RG the reticulate relief's normal (x along u, y along v); B the scutes' normal along v; A unused
## Tile: TILE x TILE scales, wrapping both ways. tools/bake_feathers.gd stamps this file's MD5 beside the PNGs, so
## test_leg_rig can tell a stale bake.

const SCALES_PATH := "res://assets/legs/leg_scales.png"
const NORMALS_PATH := "res://assets/legs/leg_scales_n.png"
const STAMP_PATH := "res://assets/legs/baked_from.md5"
const SOURCE_PATH := "res://scripts/bird/scale_tile.gd"
const SIZE := 512
const TILE := 8.0         ## scales across the tile, both ways (the shader's `tile`)
const CELLS := Vector2i(8, 9)   ## reticulate scales across the tile (u, v): a little shorter than wide
const SCUTES := 6         ## front plates down the tile (each 1.33 scales long)
const DOME := 0.15        ## a reticulate scale's height (scales)
const PLATE := 0.18       ## a scute's lip height (scales)
const BRISTLE_CELLS := Vector2i(14, 5)   ## bristle slots across and along the tile
const BRISTLE_P := 0.5    ## the share of slots that grow a bristle


static func load_scales() -> Texture2D:
	return load(SCALES_PATH) as Texture2D


static func load_normals() -> Texture2D:
	return load(NORMALS_PATH) as Texture2D


static func source_md5() -> String:
	return FileAccess.get_file_as_string(SOURCE_PATH).replace("\r\n", "\n").md5_text()


static func _hash2(x: int, y: int, k: float) -> float:
	var h := sin(float(x) * 127.1 + float(y) * 311.7 + k * 74.7) * 43758.5453
	return h - floorf(h)


## [scales, normals].
static func bake() -> Array[Image]:
	var n := SIZE
	var px := TILE / n   # (a pixel, in scales)
	# Reticulate scales: a jittered grid's Voronoi cells, wrapping. Feature points per cell, in cell units.
	var feat := PackedVector2Array()
	for cy in CELLS.y:
		for cx in CELLS.x:
			feat.append(Vector2(0.15 + 0.7 * _hash2(cx, cy, 1.0), 0.15 + 0.7 * _hash2(cx, cy, 2.0)))
	var cell_w := Vector2(TILE / CELLS.x, TILE / CELLS.y)   # (a cell, in scales)
	var h_ret := PackedFloat32Array()
	h_ret.resize(n * n)
	var h_scu := PackedFloat32Array()
	h_scu.resize(n * n)
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for y in n:
		for x in n:
			# --- Reticulate: distance to the nearest cell edge (scales) and the distance to its centre.
			var p := Vector2((x + 0.5) * px / cell_w.x, (y + 0.5) * px / cell_w.y)
			var ic := Vector2i(floori(p.x), floori(p.y))
			var best := 1e9
			var best_o := Vector2.ZERO
			var best_id := Vector2i.ZERO
			var offs: Array[Vector2] = []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := Vector2i(ic.x + dx, ic.y + dy)
					var w := Vector2i(posmod(c.x, CELLS.x), posmod(c.y, CELLS.y))
					var o := (Vector2(c) + feat[w.y * CELLS.x + w.x] - p) * cell_w   # (in scales)
					offs.append(o)
					var d := o.length_squared()
					if d < best:
						best = d
						best_o = o
						best_id = w
			var edge := 1e9
			for o in offs:
				var dd := o - best_o
				if dd.length_squared() > 1e-8:
					edge = minf(edge, (best_o + o).dot(dd.normalized()) * 0.5)
			var rnd := _hash2(best_id.x, best_id.y, 3.0)
			# A dome: steep out of the groove, rounded on top; bigger scales a touch higher.
			var e := clampf(edge / 0.34, 0.0, 1.0)
			var dome := (1.0 - pow(1.0 - e, 2.2)) * (0.88 + 0.12 * rnd)
			h_ret[y * n + x] = DOME * dome
			# --- Scutes: down each plate (f 0 its top, tucked under the plate above .. 1 its lower lip).
			var v := (y + 0.5) * px
			var f := fposmod(v / (TILE / SCUTES), 1.0)
			var lip := 1.0 - FeatherAtlas._smooth(0.93, 1.0, f) * 0.6   # (the lip's rounded edge)
			h_scu[y * n + x] = PLATE * FeatherAtlas._smooth(0.0, 0.07, f) * (0.45 + 0.55 * f) * lip
			# --- Bristles: in slots across and along the tile, a fine hair from a root in its slot, leaning a little,
			# tapering to its tip, lying toward +v (the toe's tip).
			var bristle := 0.0
			var bs := Vector2(TILE / BRISTLE_CELLS.x, TILE / BRISTLE_CELLS.y)
			var q := Vector2((x + 0.5) * px, v)
			var bi := Vector2i(floori(q.x / bs.x), floori(q.y / bs.y))
			for dy in range(-2, 1):
				for dx in range(-1, 2):
					var c := Vector2i(bi.x + dx, bi.y + dy)
					var w := Vector2i(posmod(c.x, BRISTLE_CELLS.x), posmod(c.y, BRISTLE_CELLS.y))
					if _hash2(w.x, w.y, 5.0) > BRISTLE_P:
						continue
					var root := (Vector2(c) + Vector2(_hash2(w.x, w.y, 6.0), _hash2(w.x, w.y, 7.0))) * bs
					var length := bs.y * (1.1 + 0.9 * _hash2(w.x, w.y, 8.0))
					var dir := Vector2((_hash2(w.x, w.y, 9.0) - 0.5) * 0.5, 1.0).normalized()
					var r := q - root
					var t := r.dot(dir)
					if t < 0.0 or t > length:
						continue
					var across := absf(r.x * dir.y - r.y * dir.x)
					var width := 0.055 * (1.0 - 0.8 * t / length)   # (scales)
					bristle = maxf(bristle, 1.0 - FeatherAtlas._smooth(width * 0.5, width, across))
			var i := (y * n + x) * 4
			data[i] = int(clampf(h_ret[y * n + x] / DOME, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 1] = int(clampf(h_scu[y * n + x] / PLATE, 0.0, 1.0) * 255.0 + 0.5)
			data[i + 2] = int(rnd * 255.0 + 0.5)
			data[i + 3] = int(bristle * 255.0 + 0.5)
	# Normals by central differences (wrapping), slopes in scales per scale.
	var nrm := PackedByteArray()
	nrm.resize(n * n * 4)
	for y in n:
		var ya := posmod(y - 1, n)
		var yb := posmod(y + 1, n)
		for x in n:
			var xa := posmod(x - 1, n)
			var xb := posmod(x + 1, n)
			var hx := (h_ret[y * n + xb] - h_ret[y * n + xa]) / (2.0 * px)
			var hy := (h_ret[yb * n + x] - h_ret[ya * n + x]) / (2.0 * px)
			var nr := Vector3(-hx, -hy, 1.0).normalized()
			var sy := (h_scu[yb * n + x] - h_scu[ya * n + x]) / (2.0 * px)
			var ns := Vector2(-sy, 1.0).normalized()
			var i := (y * n + x) * 4
			nrm[i] = int(clampf(nr.x * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5)
			nrm[i + 1] = int(clampf(nr.y * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5)
			nrm[i + 2] = int(clampf(ns.x * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5)
			nrm[i + 3] = 255
	return [Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data), Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, nrm)]
