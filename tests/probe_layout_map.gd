extends TestCase
## Diagnostic: the pine wood from above -- where the trees stand, where the open ground is. Writes a PNG
## (pines dark green with their crown reach faint, oaks brown with their limb reach, saplings light green,
## outposts orange, the openings' edges yellow; grey rings every 20 m) and prints the open-ground numbers: the share of the arena more than
## 6 / 9 / 12 m from any trunk, and the biggest open discs.
##   .\test_runner.ps1 -TestName probe_layout_map   (PNG: user://layout_map.png, path printed)

const PX := 6.0   # pixels per metre


func setup() -> void:
	var a := Pinewood.generate(7)
	var n := int(a.boundary * 2.0 * PX) + 20
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.93, 0.91, 0.86))
	var c := n * 0.5
	var at := func(p: Vector2) -> Vector2: return Vector2(c, c) + p * PX
	for r in range(20, int(a.boundary) + 1, 20):
		_ring(img, at.call(Vector2.ZERO), r * PX, Color(0.75, 0.75, 0.75))
	_ring(img, at.call(Vector2.ZERO), a.boundary * PX, Color(0.3, 0.3, 0.3))
	for o in a.openings:
		for k in 180:
			var ang := TAU * k / 180.0
			var q: Vector2 = o.centre + Vector2.from_angle(ang) * Pinewood.edge(o, o.centre + Vector2.from_angle(ang))
			_disc(img, at.call(q), 1.2, Color(0.85, 0.6, 0.2) if o.kind == "gap" else Color(0.9, 0.75, 0.2))
	for t in a.trees:
		match t.kind:
			ArenaLayout.Kind.PINE: _disc(img, at.call(t.base), 2.6 * PX, Color(0.72, 0.8, 0.7))
			ArenaLayout.Kind.BROADLEAF: _disc(img, at.call(t.base), 9.0 * PX, Color(0.85, 0.78, 0.66))
	for t in a.trees:
		match t.kind:
			ArenaLayout.Kind.PINE: _disc(img, at.call(t.base), 3.0, Color(0.1, 0.3, 0.12))
			ArenaLayout.Kind.BROADLEAF: _disc(img, at.call(t.base), 7.0, Color(0.45, 0.28, 0.12))
			_: _disc(img, at.call(t.base), 1.6, Color(0.45, 0.7, 0.3))
	for o in a.outposts:
		_disc(img, at.call(Vector2(o.centre.x, o.centre.z)), 5.0, Color(1.0, 0.5, 0.0))
		var tip: Vector2 = at.call(Vector2(o.centre.x, o.centre.z) + Vector2(o.out.x, o.out.z) * 6.0)
		_line(img, at.call(Vector2(o.centre.x, o.centre.z)), tip, Color(1.0, 0.5, 0.0))
	var kinds := {}
	for t in a.trees:
		kinds[t.kind] = kinds.get(t.kind, 0) + 1
	print("MAP trees by kind (pine %d, oak %d, young %d), %d perches, %d outposts" % [kinds.get(ArenaLayout.Kind.PINE, 0), kinds.get(ArenaLayout.Kind.BROADLEAF, 0), kinds.get(ArenaLayout.Kind.SAPLING, 0), a.perches.size(), a.outposts.size()])
	var path := ProjectSettings.globalize_path("user://layout_map.png")
	img.save_png(path)
	print("MAP ", path)
	# Open ground: distance from each sample to the nearest trunk (pines and oaks; saplings are brush).
	var free := {6.0: 0, 9.0: 0, 12.0: 0}
	var total := 0
	var best := []
	for x in range(-int(a.boundary), int(a.boundary) + 1, 2):
		for z in range(-int(a.boundary), int(a.boundary) + 1, 2):
			var p := Vector2(x, z)
			if p.length() > a.boundary - 6.0:
				continue
			total += 1
			var d := INF
			for t in a.trees:
				if t.kind == ArenaLayout.Kind.PINE or t.kind == ArenaLayout.Kind.BROADLEAF:
					d = minf(d, p.distance_to(t.base) - (9.0 if t.kind == ArenaLayout.Kind.BROADLEAF else 0.0))
			for k in free:
				if d > k:
					free[k] += 1
			best.append([d, p])
	for k in free:
		print("MAP open: %4.1f%% of the arena is more than %.0f m from any trunk" % [free[k] * 100.0 / total, k])
	best.sort_custom(func(u, v): return u[0] > v[0])
	var shown := []
	for b in best:
		var far := true
		for s in shown:
			if (b[1] as Vector2).distance_to(s[1]) < 20.0:
				far = false
		if far:
			shown.append(b)
			print("MAP open disc: %.1f m radius at (%.0f, %.0f), %.0f m from centre" % [b[0], b[1].x, b[1].y, (b[1] as Vector2).length()])
		if shown.size() >= 6:
			break
	finish()


func _disc(img: Image, p: Vector2, r: float, col: Color) -> void:
	for x in range(int(p.x - r), int(p.x + r) + 1):
		for y in range(int(p.y - r), int(p.y + r) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(p) <= r:
				img.set_pixel(x, y, col)


func _ring(img: Image, p: Vector2, r: float, col: Color) -> void:
	for i in int(r * 8.0):
		var q := p + Vector2.from_angle(TAU * i / (r * 8.0)) * r
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixel(int(q.x), int(q.y), col)


func _line(img: Image, p: Vector2, q: Vector2, col: Color, w := 1.5) -> void:
	for i in 40:
		var s := p.lerp(q, i / 39.0)
		_disc(img, s, w, col)
