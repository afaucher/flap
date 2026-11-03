extends TestCase
## An outpost's framing as drawn (ArenaBuilder._outpost_frame: one TimberMesh in the deck's frame), read from its mesh:
##  - every piece of wood carries a true frame (its across / along / through coordinates are metres on the drawn
##    mesh) with its grain along its length: a brace's, a bearer's, a hangar board's along its longest side;
##  - the drawn rail is the perch's collision: round, the rail's radius about the capsule's axis, the deck's width;
##    the deck's and the hangar's collision boxes are the ones the AI and the landing know;
##  - the planks' nails are where the planks cross the drawn bearers;
##  - ironwork: bolts on the bearers' faces, brass corners on every ammo box;
##  - the outpost is a handful of draw calls (its planks and one frame mesh), the same mesh for every outpost.


func setup() -> void:
	var b := ArenaBuilder.new()
	b.layout = ArenaLayout.new()
	b.layout.style = "pinewood"
	b.layout.seed = 7
	add_child(b)
	var o := ArenaLayout.OutpostData.new()
	o.id = 2
	o.centre = Vector3(3, 10, -2)
	o.out = Vector3(1, 0, 1).normalized()
	b._outpost(o)
	var fm: MeshInstance3D = b.get_node("Outpost2_Frame")
	var arr := fm.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var pieces: Array = fm.get_meta("pieces")
	check(pieces.size() > 100, "the frame holds the outpost's pieces (%d)" % pieces.size())
	var by_name := {}
	for k in pieces.size():
		var p: Dictionary = pieces[k]
		p["last"] = pieces[k + 1].first if k + 1 < pieces.size() else pos.size()
		if not by_name.has(p.name):
			by_name[p.name] = []
		by_name[p.name].append(p)
	var wood := [TimberMesh.Kind.BOARD, TimberMesh.Kind.BEAM, TimberMesh.Kind.ROUND]
	var bad_frame := 0
	var bad_grain := []
	var checked := 0
	for p in pieces:
		var kind := int(c0[p.first * 4 + 3] + 0.5)
		if not wood.has(kind):
			continue
		checked += 1
		# The local frame is metres on the mesh: distances between vertices match in both.
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for v in range(p.first, p.last):
			var l := Vector3(uv[v].x, uv[v].y, uv2[v].x)
			lo = lo.min(l)
			hi = hi.max(l)
			var w: int = p.first + (v - p.first + 7) % (p.last - p.first)
			var lw := Vector3(uv[w].x, uv[w].y, uv2[w].x)
			if absf(pos[v].distance_to(pos[w]) - l.distance_to(lw)) > 1e-4:
				bad_frame += 1
		# The grain (along) runs the piece's longest way.
		var ext := hi - lo
		if ext.y < ext.x - 1e-4 or ext.y < ext.z - 1e-4:
			bad_grain.append("%s (along %.3f, across %.3f, through %.3f)" % [p.name, ext.y, ext.x, ext.z])
	check(checked > 30, "wood pieces checked (%d)" % checked)
	eq(bad_frame, 0, "every wood piece's frame is metres on the drawn mesh")
	check(bad_grain.is_empty(), "every piece's grain runs its longest way%s" % ("" if bad_grain.is_empty() else ": not " + ", ".join(bad_grain.slice(0, 4))))
	for name in ["brace_l", "brace_r", "bearer_out", "bearer_in", "rail", "hangar_board_px_0"]:
		check(by_name.has(name), "the outpost has its %s" % name)

	# The drawn rail is the perch's collision capsule: round about its axis at the rail's radius, the deck's width.
	var body: StaticBody3D = b.get_node("Outpost2")
	var cap: CollisionShape3D = null
	var boxes := []
	for c in body.get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			cap = c
		elif c is CollisionShape3D and c.shape is BoxShape3D:
			boxes.append(c)
	check(cap != null and is_equal_approx((cap.shape as CapsuleShape3D).radius, o.rail_radius), "the rail's collision is a capsule of the rail's radius")
	var rail: Dictionary = by_name["rail"][0]
	var axis_a := cap.global_transform * Vector3(0, -1, 0)
	var axis_b := cap.global_transform * Vector3(0, 1, 0)
	var ad := (axis_b - axis_a).normalized()
	var worst := 0.0
	var span_lo := INF
	var span_hi := -INF
	for v in range(rail.first, rail.last):
		var w: Vector3 = fm.global_transform * pos[v]
		var t := (w - axis_a).dot(ad)
		var r := ((w - axis_a) - ad * t).length()
		if Vector2(uv[v].x, uv2[v].x).length() > o.rail_radius * 0.5:   # (the round, not the end caps' middles)
			worst = maxf(worst, absf(r - o.rail_radius))
		span_lo = minf(span_lo, t)
		span_hi = maxf(span_hi, t)
	check(worst < 0.0015, "the drawn rail is round at the rail's radius about the perch's axis (off by %.1f mm at most)" % (worst * 1000.0))
	near(span_hi - span_lo, o.width, 0.002, "the drawn rail runs the deck's width")
	var sizes := []
	for c in boxes:
		sizes.append((c.shape as BoxShape3D).size)
	check(sizes.has(Vector3(o.width, o.thickness, o.depth)), "the deck's collision box")
	check(sizes.has(ArenaBuilder.HANGAR_SIZE), "the hangar's collision box")
	# ... and the AI's clearance queries see all of it: every corner of the hangar's box lies in the deck's capsules.
	for c in boxes:
		if (c.shape as BoxShape3D).size != ArenaBuilder.HANGAR_SIZE:
			continue
		var outside := 0
		for k in 8:
			var corner: Vector3 = c.global_transform * (Vector3(float(k & 1) - 0.5, float((k >> 1) & 1) - 0.5, float((k >> 2) & 1) - 0.5) * ArenaBuilder.HANGAR_SIZE)
			var inside := false
			for seg in b.layout.deck_lines(o):
				if corner.distance_to(Geometry3D.get_closest_point_to_segment(corner, seg[0], seg[1])) <= float(seg[2]) + 1e-3:
					inside = true
			if not inside:
				outside += 1
		eq(outside, 0, "the AI's clearance queries hold the hangar (corners outside them)")

	# The planks' nails: where each plank crosses a drawn bearer.
	var plank: MeshInstance3D = b.get_node("Outpost2_Plank4")
	var nail_at: Vector2 = (plank.material_override as ShaderMaterial).get_shader_parameter("nail_at")
	for name in ["bearer_out", "bearer_in"]:
		var bp: Dictionary = by_name[name][0]
		var mid := Vector3.ZERO
		for v in range(bp.first, bp.last):
			mid += fm.global_transform * pos[v]
		mid /= bp.last - bp.first
		var z := (plank.global_transform.affine_inverse() * mid).z
		check(absf(z - nail_at.x) < 0.005 or absf(z - nail_at.y) < 0.005, "nails where the planks cross the %s (it is at %.3f, nails at %.3f, %.3f)" % [name, z, nail_at.x, nail_at.y])

	# Ironwork: bolt heads on the bearers' faces; brass corners on every ammo box.
	var bolts := 0
	var outer: Dictionary = by_name["bearer_out"][0]
	var obx: Transform3D = outer.xform
	for p in by_name.get("bolt", []):
		var lp := obx.affine_inverse() * (p.xform as Transform3D).origin
		if absf(lp.y) < (outer.size as Vector3).y * 0.5 and absf(lp.z) > (outer.size as Vector3).z * 0.5 and absf(lp.z) < (outer.size as Vector3).z * 0.5 + 0.02:
			bolts += 1
	check(bolts >= 4, "bolts on the outer bearer's face (%d)" % bolts)
	var crates: Array = by_name.get("crate", [])
	check(crates.size() >= 3, "ammo boxes (%d)" % crates.size())
	for i in crates.size():
		var cx: Transform3D = crates[i].xform
		var cs: Vector3 = crates[i].size
		var corners := 0
		var own := []   # (its own fittings: the pieces built after it, up to the next box)
		for k in range(pieces.find(crates[i]) + 1, pieces.size()):
			if pieces[k].name == "crate":
				break
			if pieces[k].name == "crate_corner":
				own.append(pieces[k])
		for p in own:
			var lp := cx.affine_inverse() * (p.xform as Transform3D).origin
			if absf(absf(lp.x) - cs.x * 0.5) < 0.008 and absf(absf(lp.y) - cs.y * 0.5) < 0.008 and absf(absf(lp.z) - cs.z * 0.5) < 0.008:
				corners += 1
		eq(corners, 8, "ammo box %d: brass at its eight corners" % i)

	# Draw calls: nine planks and the frame; a second outpost of the same size shares the frame's mesh.
	var meshes := 0
	for c in b.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Outpost2_"):
			meshes += 1
	eq(meshes, 10, "an outpost is nine planks and one frame mesh")
	var o2 := ArenaLayout.OutpostData.new()
	o2.id = 5
	o2.centre = Vector3(-8, 12, 4)
	b._outpost(o2)
	check((b.get_node("Outpost5_Frame") as MeshInstance3D).mesh == fm.mesh, "outposts of a size share one frame mesh")
	await frames(1)
	finish()
