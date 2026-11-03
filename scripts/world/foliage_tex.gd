class_name FoliageTex
extends RefCounted
## Foliage card textures, painted here (no downloads): each an RGBA image of a spray seen flat, its alpha the
## silhouette, made once and shared (alpha-tested cards in ArenaBuilder's crowns and floor).
##   needles   a Scots pine spray: a shoot forking twice, needles in pairs all along it pointing forward,
##             blue-green, densest toward the tips (a card is ~0.7 m across)
##   oak       a twig with clusters of lobed oak leaves (~0.8 m)
##   grass     a tussock of heath grass: blades from a tight root fanning up and out, curving over, olive at the
##             root, straw at the tips (~0.8 m; v runs base 1 -> tip 0)
##   fern      a bracken frond: a stem up the middle, pinnae left and right shortening to the tip, each lobed
##             (~0.9 m long; the card's v runs base 1 -> tip 0)
## Pixels are painted as anti-aliased strokes into float buffers (coverage, then colour over), then mipmapped.

static var _cache := {}


static func get_tex(kind: String) -> ImageTexture:
	if not _cache.has(kind):
		match kind:
			"needles": _cache[kind] = _needles(1024, 11)
			"oak": _cache[kind] = _oak(512, 23)
			"fern": _cache[kind] = _fern(512, 37)
			"grass": _cache[kind] = _grass(512, 53)
	return _cache[kind]


class Canvas:
	var n := 0           ## width
	var m := 0           ## height
	var a := PackedFloat32Array()
	var rgb := PackedFloat32Array()

	func _init(size: int, height := 0) -> void:
		n = size
		m = height if height > 0 else size
		a.resize(n * m)
		rgb.resize(n * m * 3)

	## A stroke from p to q (pixels), `w` wide, colour c, alpha coverage blended over what's there.
	func stroke(p: Vector2, q: Vector2, w: float, c: Color, taper := 1.0) -> void:
		var d := q - p
		var length := d.length()
		var steps := maxi(1, int(length * 1.5))
		for i in steps + 1:
			var f := float(i) / steps
			var pt := p + d * f
			var ww := w * lerpf(1.0, taper, f)
			var r := maxf(ww * 0.5, 0.5)
			var x0 := int(floor(pt.x - r - 1.0))
			var y0 := int(floor(pt.y - r - 1.0))
			for yy in range(y0, y0 + int(r * 2.0) + 3):
				if yy < 0 or yy >= m:
					continue
				for xx in range(x0, x0 + int(r * 2.0) + 3):
					if xx < 0 or xx >= n:
						continue
					var dist := Vector2(xx + 0.5, yy + 0.5).distance_to(pt)
					var cov := clampf(r + 0.5 - dist, 0.0, 1.0)
					if cov <= 0.0:
						continue
					var k := yy * n + xx
					var old := a[k]
					var na := old + cov * (1.0 - old)
					var t := cov / maxf(na, 1e-4)
					rgb[k * 3] = lerpf(rgb[k * 3], c.r, t)
					rgb[k * 3 + 1] = lerpf(rgb[k * 3 + 1], c.g, t)
					rgb[k * 3 + 2] = lerpf(rgb[k * 3 + 2], c.b, t)
					a[k] = na

	## A filled leaf: an ellipse-ish blade from base p toward dir, `length` long, `width` wide, lobed.
	func leaf(p: Vector2, dir: Vector2, length: float, width: float, lobes: int, c: Color) -> void:
		var side := Vector2(-dir.y, dir.x)
		var steps := int(length)
		for i in steps:
			var f := (i + 0.5) / steps
			var env := sin(PI * pow(f, 0.8)) * width * 0.5
			if lobes > 0:
				env *= 0.72 + 0.28 * absf(sin(PI * f * lobes))
			var mid := p + dir * f * length
			stroke(mid - side * env, mid + side * env, 1.6, c)
		stroke(p, p + dir * length * 0.95, 0.9, c.darkened(0.25))

	func image() -> Image:
		var data := PackedByteArray()
		data.resize(n * m * 4)
		for k in n * m:
			# (unpremultiplied colour; where nothing was painted, the nearest painted colour would be better for
			# mip bleeding -- a dark green fill does well enough)
			var aa := a[k]
			data[k * 4] = int(clampf(rgb[k * 3] if aa > 0.0 else 0.12, 0.0, 1.0) * 255.0)
			data[k * 4 + 1] = int(clampf(rgb[k * 3 + 1] if aa > 0.0 else 0.17, 0.0, 1.0) * 255.0)
			data[k * 4 + 2] = int(clampf(rgb[k * 3 + 2] if aa > 0.0 else 0.1, 0.0, 1.0) * 255.0)
			data[k * 4 + 3] = int(clampf(aa, 0.0, 1.0) * 255.0)
		var img := Image.create_from_data(n, m, false, Image.FORMAT_RGBA8, data)
		img.generate_mipmaps()
		FoliageTex._keep_coverage(img, 0.4)
		return img


## Mipmaps that keep the alpha test's coverage: plain averaging thins needles to a soft blob that the test then
## cuts into a smooth, leaf-like outline; here each level's alpha is scaled so as much of it passes `cut` as
## passes at full size, so a distant spray stays a spiky fringe of needles. (Castano's coverage-preserving mips.)
static func _keep_coverage(img: Image, cut: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var levels := img.get_mipmap_count() + 1
	var c0 := -1.0
	for lv in levels:
		var off := img.get_mipmap_offset(lv)
		var lw := maxi(1, w >> lv)
		var lh := maxi(1, h >> lv)
		var n := lw * lh
		var hist := PackedInt32Array()
		hist.resize(256)
		for k in n:
			hist[data[off + k * 4 + 3]] += 1
		var cover := func(sc: float) -> float:
			var above := 0
			for b in 256:
				if b * sc > cut * 255.0:
					above += hist[b]
			return float(above) / n
		if lv == 0:
			c0 = cover.call(1.0)
			continue
		var lo := 1.0
		var hi := 8.0
		for it in 14:
			var mid := (lo + hi) * 0.5
			if cover.call(mid) < c0:
				lo = mid
			else:
				hi = mid
		var sc := (lo + hi) * 0.5
		for k in n:
			var i := off + k * 4 + 3
			data[i] = mini(255, int(data[i] * sc))
	img.set_data(w, h, true, Image.FORMAT_RGBA8, data)


static func _needle_col(rng: RandomNumberGenerator) -> Color:
	return Color(0.2, 0.31, 0.2).lerp(Color(0.33, 0.42, 0.24), rng.randf()) * rng.randf_range(0.85, 1.1)


## A shoot from p along dir, `length` px, needles in pairs along it; forks into side shoots.
static func _shoot(cv: Canvas, rng: RandomNumberGenerator, p: Vector2, dir: Vector2, length: float, depth: int, px_per_cm: float) -> void:
	var twig := Color(0.3, 0.32, 0.18)   # (a shoot's stem: green-brown, and mostly hidden in its needles)
	var bend := rng.randf_range(-0.25, 0.25)
	var pts: Array[Vector2] = [p]
	var dd := dir
	var seg := 8
	for i in seg:
		dd = dd.rotated(bend / seg).normalized()
		pts.append(pts[-1] + dd * length / seg)
	for i in seg:
		cv.stroke(pts[i], pts[i + 1], lerpf(1.8, 0.9, float(i) / seg) * (1.0 if depth == 0 else 0.7), twig)
	# Needles: pairs every few mm, 4-6 cm, angled forward ~45 deg, longer and denser toward the tip.
	var total := int(length / (0.25 * px_per_cm))
	for i in total:
		var f := float(i) / total
		if f < 0.12:
			continue
		var k := int(f * seg)
		var base := pts[k].lerp(pts[mini(k + 1, seg)], f * seg - k)
		var along := (pts[mini(k + 1, seg)] - pts[k]).normalized()
		var nl := rng.randf_range(4.5, 6.0) * px_per_cm   # (all about the same length: a brush's outline is blunt)
		# (seen from above, a pine shoot is a bottle brush: needles stand out all round it, so in the flat some
		# lie to the sides at full length and others, pointing up or down, foreshortened over the shoot)
		for q in 3:
			var s := -1.0 if q == 0 else (1.0 if q == 1 else (1.0 if rng.randf() < 0.5 else -1.0))
			var fore := 1.0 if q < 2 else rng.randf_range(0.25, 0.6)
			var ang: float = s * rng.randf_range(0.75, 1.3) * (1.0 if q < 2 else 0.6)   # (standing well out from the shoot)
			var nd := along.rotated(ang)
			var tip := base + nd * nl * fore + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * px_per_cm * 0.4
			cv.stroke(base, tip, 2.2, _needle_col(rng) * (0.85 if q == 2 else 1.0), 0.35)
	# The bud's tuft at the tip: needles fanning forward, so the brush ends round, not in a point.
	var end := pts[seg]
	var fwd := (pts[seg] - pts[seg - 1]).normalized()
	for i in 14:
		var nd := fwd.rotated(rng.randf_range(-1.1, 1.1))
		cv.stroke(end, end + nd * rng.randf_range(3.5, 5.5) * px_per_cm, 2.2, _needle_col(rng), 0.35)
	if depth < 2:
		for fk in rng.randi_range(1, 2):
			var f := rng.randf_range(0.35, 0.75)
			var k := int(f * seg)
			var sdir := (pts[mini(k + 1, seg)] - pts[k]).normalized().rotated((1.0 if fk == 0 else -1.0) * rng.randf_range(0.45, 0.8))
			_shoot(cv, rng, pts[k], sdir, length * rng.randf_range(0.45, 0.6), depth + 1, px_per_cm)


## One shoot, a bottle brush of needles, along the card (+u) from its left edge: long and narrow (3:8). A crown
## builds its tufts in 3D from many of these radiating from the limb ends, rather than one flat fan of them,
## which at a distance merges into the outline of a lobed leaf.
const NEEDLE_ASPECT := 0.375


static func _needles(size: int, s: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var h := int(size * NEEDLE_ASPECT)
	var cv := Canvas.new(size, h)
	var px_per_cm := size / 45.0
	_shoot(cv, rng, Vector2(size * 0.02, h * 0.52), Vector2(1.0, rng.randf_range(-0.05, 0.05)).normalized(), size * 0.8, 2, px_per_cm)   # (depth 2: no side shoots off the card)
	return ImageTexture.create_from_image(cv.image())


static func _oak(size: int, s: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var cv := Canvas.new(size)
	var px_per_cm := size / 80.0
	var twig := Color(0.36, 0.3, 0.22)
	for b in 4:
		var p := Vector2(size * 0.08, size * rng.randf_range(0.3, 0.7))
		var dir := Vector2(1.0, rng.randf_range(-0.5, 0.5)).normalized()
		var length := size * rng.randf_range(0.55, 0.8)
		var q := p + dir * length
		cv.stroke(p, q, 2.4, twig, 0.5)
		for i in 7:
			var f := lerpf(0.25, 1.0, i / 6.0)
			var at := p.lerp(q, f)
			for l in rng.randi_range(2, 4):
				var ld := dir.rotated(rng.randf_range(-1.6, 1.6))
				var lc := Color(0.24, 0.36, 0.13).lerp(Color(0.38, 0.47, 0.18), rng.randf()) * rng.randf_range(0.85, 1.1)
				cv.leaf(at, ld, rng.randf_range(8.0, 12.0) * px_per_cm, rng.randf_range(4.0, 6.0) * px_per_cm, 4, lc)
	return ImageTexture.create_from_image(cv.image())


static func _fern(size: int, s: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var cv := Canvas.new(size)
	var stem := Color(0.42, 0.42, 0.2)
	var base := Vector2(size * 0.5, size * 0.98)
	var tip := Vector2(size * 0.5 + rng.randf_range(-12, 12), size * 0.03)
	cv.stroke(base, tip, 3.0, stem, 0.3)
	var n := 16
	for i in n:
		var f := lerpf(0.12, 0.97, float(i) / (n - 1))
		var at := base.lerp(tip, f)
		var reach := size * 0.46 * sin(PI * lerpf(0.15, 1.0, f) * 0.62 + 0.3) * (1.0 - f * 0.85)
		for s2 in [-1.0, 1.0]:
			var d := Vector2(s2, -0.35 - 0.3 * f).normalized()
			var end := at + d * reach
			cv.stroke(at, end, 1.6, stem, 0.5)
			var m := int(reach / 11.0)
			for j in m:
				var g := (j + 0.5) / m
				var pp := at.lerp(end, g)
				var w := lerpf(17.0, 6.0, g) * lerpf(1.0, 0.6, f)
				var lc := Color(0.3, 0.44, 0.15).lerp(Color(0.42, 0.52, 0.2), rng.randf())
				for s3 in [-1.0, 1.0]:
					cv.leaf(pp, d.rotated(s3 * 1.2 - s2 * 0.15), w, w * 0.62, 0, lc)
	return ImageTexture.create_from_image(cv.image())


static func _grass(size: int, s: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var cv := Canvas.new(size)
	var root := Vector2(size * 0.5, size * 0.99)
	for i in 70:
		var lean := rng.randf_range(-1.0, 1.0)
		var tall := size * rng.randf_range(0.45, 0.97) * (1.0 - absf(lean) * 0.3)
		var p := root + Vector2(rng.randf_range(-size * 0.06, size * 0.06), 0.0)
		var dir := Vector2(lean * 0.55, -1.0).normalized()
		var segs := 7
		var w := rng.randf_range(4.0, 7.5)
		var col := Color(0.36, 0.38, 0.18).lerp(Color(0.5, 0.48, 0.24), rng.randf())
		var tip_col := Color(0.78, 0.7, 0.42).lerp(Color(0.6, 0.62, 0.32), rng.randf())
		for k in segs:
			var f := float(k + 1) / segs
			var q := p + dir * tall / segs
			dir = dir.rotated(lean * 0.09 * f).normalized()   # (curving over, more toward the tip)
			cv.stroke(p, q, w * lerpf(1.0, 0.25, f), col.lerp(tip_col, f), 0.85)
			p = q
	return ImageTexture.create_from_image(cv.image())
