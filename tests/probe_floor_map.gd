extends TestCase
## The floor's map, for a picture: the mound heights over the whole field, how the fine mesh draws each of its cells
## (plain, joined in an 8 x 8 or 4 x 4 fan, or left to the ring), the tiles, the ring's hole and the big plane, and
## the trees and outposts for bearings. Writes JSON for tools to draw; headless:
##   .\probe.ps1 -Headless probe_floor_map --out <file.json> [--seed n]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var sd := Boot.arg_value(args, "--seed")
	var layout := Pinewood.generate(int(sd) if sd != "" else 7)
	var ff := layout.floor_field
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	var ground: Node = arena.get_node("Ground")
	var fine := ground.get_node("FloorMounds") as Node3D
	var plane: MeshInstance3D = null
	for c in ground.get_children():
		if c is MeshInstance3D:
			plane = c
	# The ring: its hole's nearest edge and its outer half size.
	var rv: PackedVector3Array = plane.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var hole := INF
	var outer := 0.0
	for p in rv:
		var q := Vector2(p.x, p.z)
		hole = minf(hole, q.length())
		outer = maxf(outer, maxf(absf(q.x), absf(q.y)))
	# The fine mesh's cells, each by the triangle over its middle: 0 none (the ring's), 1 plain, 4 / 8 a fan of that.
	var centre := Vector2(fine.position.x, fine.position.z)
	var step := ArenaBuilder.FLOOR_STEP
	var half := ff.size * 0.5
	var segs := int(round(ff.size / step))
	var state := PackedByteArray()
	state.resize(segs * segs)
	var tiles := []
	for t in fine.get_children():
		if not t is MeshInstance3D:
			continue
		var arr := (t as MeshInstance3D).mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var lo := Vector2(INF, INF)
		var hi := -lo
		for i in range(0, idx.size(), 3):
			var a := Vector2(v[idx[i]].x, v[idx[i]].z)
			var b := Vector2(v[idx[i + 1]].x, v[idx[i + 1]].z)
			var c := Vector2(v[idx[i + 2]].x, v[idx[i + 2]].z)
			lo = lo.min(a).min(b).min(c)
			hi = hi.max(a).max(b).max(c)
			var area := absf((b - a).cross(c - a)) * 0.5 / (step * step)   # (0.5 plain, bk / 4 in a fan of bk)
			var kind := 1 if area < 0.75 else (4 if area < 1.5 else 8)
			var tlo := a.min(b).min(c)
			var thi := a.max(b).max(c)
			for cj in range(maxi(0, int(floor((tlo.y + half) / step))), mini(segs - 1, int(floor((thi.y + half) / step))) + 1):
				for ci in range(maxi(0, int(floor((tlo.x + half) / step))), mini(segs - 1, int(floor((thi.x + half) / step))) + 1):
					var m := Vector2(-half + (ci + 0.5) * step, -half + (cj + 0.5) * step)
					if Geometry2D.point_is_inside_triangle(m, a, b, c) or Geometry2D.point_is_inside_triangle(m + Vector2(0.013, 0.007), a, b, c):
						state[cj * segs + ci] = maxi(state[cj * segs + ci], kind)
		tiles.append([lo.x + centre.x, lo.y + centre.y, hi.x + centre.x, hi.y + centre.y])
	var trees := []
	for t: ArenaLayout.TreeData in layout.trees:
		trees.append([t.base.x, t.base.y, t.radius, t.kind])
	var posts := []
	for o: ArenaLayout.OutpostData in layout.outposts:
		posts.append([o.centre.x, o.centre.z])
	var opens := []
	for o in layout.openings:
		opens.append([o.centre.x, o.centre.y, o.r, o.kind])
	var data := {
		"n": ff.n, "origin": [ff.origin.x, ff.origin.y], "res": FloorField.RES, "mound_h": FloorField.MOUND_H,
		"heights": Array(ff.heights()), "flat_beyond": ff.flat_beyond(),
		"segs": segs, "step": step, "fine_centre": [centre.x, centre.y], "fine_size": ff.size,
		"cells": Array(state), "tiles": tiles, "hole": hole, "outer": outer, "half_extent": layout.half_extent,
		"trees": trees, "outposts": posts, "openings": opens,
	}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	for s in state:
		counts[s] += 1
	print("MAP %d x %d cells: ring %d, plain %d, 4x4 %d, 8x8 %d; hole %.1f m, outer %.1f m; -> %s" % [segs, segs, counts[0], counts[1], counts[4], counts[8], hole, outer, out])
	check(true, "written")
	finish()
