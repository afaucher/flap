extends TestCase
## The outpost deck's planks, as drawn (ArenaBuilder._outpost): ArenaBuilder.PLANKS of them, PLANK_T thick, their tops
## where the deck's collision top is; hand-sawn, not machined -- each plank's edges waver along its length (left
## and right), its ends run a little out of square, and no two are the same width -- but only by millimetres
## (every vertex within PLANK_DEV of the plank's box), laid edge to edge with no overlaps, gaps between that the
## eye sees (at least 5 mm) and none wider than 2.5 cm, the top facing up and the sides out (left and right), the
## same seed the same deck.


func setup() -> void:
	var decks := []
	for run in 2:
		var b := ArenaBuilder.new()
		b.layout = ArenaLayout.new()
		b.layout.seed = 7
		add_child(b)
		var o := ArenaLayout.OutpostData.new()
		o.id = 3
		o.centre = Vector3(0, 10, 0)
		o.out = Vector3.FORWARD
		b._outpost(o)
		decks.append(_planks(b, o))
		b.queue_free()
	var planks: Array = decks[0]
	var o_w := ArenaLayout.OutpostData.new().width
	eq(planks.size(), ArenaBuilder.PLANKS, "%d planks" % ArenaBuilder.PLANKS)
	var narrowest_gap := INF
	var widths := []
	var prev_right := -INF
	var widest_gap := 0.0
	for i in planks.size():
		var mi: MeshInstance3D = planks[i]
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var box := mi.mesh.get_aabb()
		widths.append(box.size.x)
		# Each edge's line along the plank, from the vertices at the edge (the side faces' outermost points).
		for side: float in [-1.0, 1.0]:
			var by_z := {}
			for p in v:
				if absf(p.z) > ArenaLayout.OutpostData.new().depth * 0.45:
					continue   # (the sawn ends)
				var key := snappedf(p.z, 0.001)
				var x := p.x * side
				by_z[key] = maxf(float(by_z.get(key, -INF)), x)
			var xs: Array = by_z.values()
			var spread: float = xs.max() - xs.min()
			check(spread > 0.001 and spread < 2.0 * ArenaBuilder.PLANK_DEV, "plank %d: its %s edge wavers by %.1f mm" % [i, "left" if side < 0 else "right", spread * 1000.0])
		# The box it stays inside: the nominal plank (its middle width, thickness and length) give or take PLANK_DEV.
		var t := ArenaBuilder.PLANK_T
		var L := ArenaLayout.OutpostData.new().depth
		check(box.size.y < t + 2.0 * 0.001 and box.size.y > t - 0.002, "plank %d: %.1f mm thick" % [i, box.size.y * 1000.0])
		check(absf(box.size.z - L) < 2.0 * ArenaBuilder.PLANK_DEV, "plank %d: %.0f mm long (deck %.0f)" % [i, box.size.z * 1000.0, L * 1000.0])
		# The ends a little out of square: the two corners of an end at different z.
		var zl := INF
		var zr := INF
		for p in v:
			if p.z < -L * 0.5 + 0.02 and absf(p.x) > box.size.x * 0.3:
				if p.x < 0.0:
					zl = minf(zl, p.z)
				else:
					zr = minf(zr, p.z)
		check(absf(zl - zr) > 0.0005, "plank %d: its end is out of square by %.1f mm" % [i, absf(zl - zr) * 1000.0])
		# Faces out: the top up, the bottom down, the sides out on their own side.
		var ok := {"top": true, "bottom": true, "left": true, "right": true}
		for q in v.size():
			var p := v[q]
			var n := nrm[q]
			if p.y > box.end.y - 0.0004 and absf(p.z) < L * 0.45 and n.y < 0.8:
				ok.top = false
			if p.y < box.position.y + 0.0001 and absf(p.x) < box.size.x * 0.3 and n.y > -0.8:
				ok.bottom = false
		var side_n := [0.0, 0.0]
		var counts := [0, 0]
		for q in v.size():
			var p := v[q]
			if absf(nrm[q].y) < 0.3 and absf(p.z) < L * 0.4:
				var s := 0 if p.x < 0.0 else 1
				side_n[s] += nrm[q].x
				counts[s] += 1
		ok.left = counts[0] > 0 and side_n[0] / counts[0] < -0.8
		ok.right = counts[1] > 0 and side_n[1] / counts[1] > 0.8
		for f in ok:
			check(ok[f], "plank %d: its %s faces %s" % [i, f, {"top": "up", "bottom": "down", "left": "left", "right": "right"}[f]])
		# Laid edge to edge (deck frame x: the outpost's side; o.out is -Z here, so side is -X... take positions along x).
		var xs_world := []
		for p in v:
			xs_world.append((mi.global_transform * p).x)
		var top_y := -INF
		for p in v:
			top_y = maxf(top_y, (mi.global_transform * p).y)
		check(absf(top_y - 10.0) < 0.0012, "plank %d: its top at the deck's collision top (%.1f mm off)" % [i, (top_y - 10.0) * 1000.0])
		var lo: float = xs_world.min()
		var hi: float = xs_world.max()
		if i > 0:
			check(lo > prev_right, "planks %d and %d don't overlap (%.1f mm apart)" % [i - 1, i, (lo - prev_right) * 1000.0])
			widest_gap = maxf(widest_gap, lo - prev_right)
			narrowest_gap = minf(narrowest_gap, lo - prev_right)
		prev_right = hi
	check(widest_gap < 0.025, "no gap wider than 2.5 cm (widest %.1f mm)" % (widest_gap * 1000.0))
	check(narrowest_gap > 0.005, "gaps between them the eye sees (narrowest %.1f mm)" % (narrowest_gap * 1000.0))
	check(widths.max() - widths.min() > 0.015, "the planks vary in width (%.0f .. %.0f mm)" % [widths.min() * 1000.0, widths.max() * 1000.0])
	check(absf(prev_right - (planks[0] as MeshInstance3D).global_position.x) > o_w * 0.8, "they cover the deck's width")
	# The same seed lays the same deck.
	var same := true
	for i in planks.size():
		if not (planks[i] as MeshInstance3D).mesh.get_aabb().is_equal_approx((decks[1][i] as MeshInstance3D).mesh.get_aabb()):
			same = false
	check(same, "the same seed, the same planks")
	await frames(1)
	finish()


func _planks(b: ArenaBuilder, o: ArenaLayout.OutpostData) -> Array:
	var out := []
	for i in ArenaBuilder.PLANKS + 2:   # (and none beyond)
		var n := b.get_node_or_null("Outpost%d_Plank%d" % [o.id, i])
		if n != null:
			out.append(n)
	return out
