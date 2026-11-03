extends TestCase
## Trunks and limbs as drawn (ArenaBuilder._trunk, _tube) are closed at their far ends: every edge of the mesh is
## shared by two triangles except round the trunk's foot (below the ground) and a limb's root (inside its trunk),
## and the cap faces outward, so a treetop seen from above, or a limb's tip seen end on, is wood, not a hole.


func setup() -> void:
	var b := ArenaBuilder.new()
	b.layout = ArenaLayout.new()
	add_child(b)
	for kind in [ArenaLayout.Kind.PINE, ArenaLayout.Kind.BROADLEAF, ArenaLayout.Kind.SAPLING]:
		var t := ArenaLayout.TreeData.new()
		t.kind = kind
		t.base = Vector2(3.0, -2.0)
		t.height = 24.0 if kind != ArenaLayout.Kind.SAPLING else 4.0
		t.radius = 0.5 if kind != ArenaLayout.Kind.SAPLING else 0.08
		var arr := b._cell({}, Vector2i.ZERO, "pine_trunk")
		b._trunk(arr, t, 0.3)
		_closed(arr, "%s trunk" % ArenaLayout.Kind.keys()[kind], ArenaLayout.GROUND_Y - 0.15, Vector3.UP)
	# A limb: out and up from a trunk, tapering to its tip.
	var pts := PackedVector3Array([Vector3(0, 10, 0), Vector3(1.0, 10.3, 0.2), Vector3(2.2, 10.5, 0.3), Vector3(3.0, 10.6, 0.5)])
	var radii := PackedFloat32Array([0.12, 0.09, 0.06, 0.03])
	var arr := b._cell({}, Vector2i.ZERO, "limb")
	b._tube(arr, pts, radii, 9, 0.6, 0.5)
	_closed(arr, "limb", NAN, (pts[3] - pts[2]).normalized(), pts[0])
	b.queue_free()
	finish()


## Every open edge of `arr`'s triangles lies on the tube's first ring (at height `foot_y`, or round `root`); the
## triangles at the far end face along `out`.
func _closed(arr: Array, what: String, foot_y: float, out: Vector3, root := Vector3.INF) -> void:
	var v: PackedVector3Array = arr[0]
	var idx: PackedInt32Array = arr[5]
	var edges := {}
	for i in range(0, idx.size(), 3):
		for e in 3:
			var a: Vector3 = v[idx[i + e]].snappedf(1e-4)
			var c: Vector3 = v[idx[i + (e + 1) % 3]].snappedf(1e-4)
			var k := [a, c] if str(a) < str(c) else [c, a]
			edges[k] = int(edges.get(k, 0)) + 1
	var open := 0
	var stray := 0
	for k in edges:
		if edges[k] == 1:
			open += 1
			for p in k:
				var on_foot: bool = absf((p as Vector3).y - foot_y) < 0.05 if not is_nan(foot_y) else (p as Vector3).distance_to(root) < 0.2
				if not on_foot:
					stray += 1
	check(open > 0, "%s: the foot ring is open (it's under the ground or in the trunk)" % what)
	eq(stray, 0, "%s: no open edge anywhere else (the far end capped)" % what)
	# The cap winds the way the wall does: the wall's first triangle faces out from the axis at the foot, the
	# cap's last one along `out` -- both the same side of their triangles, so both are drawn from outside.
	var axis0: Vector3 = root if root != Vector3.INF else Vector3(v[idx[0]].x, foot_y, v[idx[0]].z)
	if root == Vector3.INF:   # (the trunk's axis: the foot ring's middle)
		var c := Vector3.ZERO
		var m := 0
		for p in v:
			if absf(p.y - foot_y) < 0.05:
				c += p
				m += 1
		axis0 = c / maxi(m, 1)
	var nw := (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]])
	var wall_out := nw.dot((v[idx[0]] + v[idx[1]] + v[idx[2]]) / 3.0 - axis0)
	var i := idx.size() - 3
	var nc := (v[idx[i + 1]] - v[idx[i]]).cross(v[idx[i + 2]] - v[idx[i]])
	check(nc.length() > 1e-8 and signf(nc.dot(out)) == signf(wall_out), "%s: the cap faces out, as the wall does" % what)
