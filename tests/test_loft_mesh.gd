extends TestCase
## The lofted surfaces moved without rebuilding (LoftMesh.update) are drawn exactly as a full rebuild would draw them:
## after a wingbeat's poses on the fast path, every species' arm wing -- both sides -- and, after a glance, its neck have
## the same vertices and the same smoothed normals as the mesh built in full at that pose; and they did take the fast
## path (a full build every pose was most of a flying bird's cost). And built in full, a LoftMesh is tube_mesh's.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		var b0: Array = []
		for lm: LoftMesh in rig._arm_loft:
			b0.append(lm.builds)
		for k in 21:
			RigPoses.apply(rig, "flap", k * 0.025)
			rig.apply_pose()
		var fast: Array = []
		for i in 2:
			var lm: LoftMesh = rig._arm_loft[i]
			check(lm.builds - int(b0[i]) <= 3, "%s side %d: a wingbeat moves the arm wing, not rebuilds it (%d full builds in 21 poses)" % [p.id, i, lm.builds - int(b0[i])])
			fast.append([lm.positions, lm.normals_now])   # (as written: the headless renderer can't read a mesh back)
			rig._arm_built[i] = {}
		rig.apply_pose()   # (the same pose again, built in full)
		for i in 2:
			var lf: LoftMesh = rig._arm_loft[i]
			_compare(p.id, i, fast[i], [lf.positions, lf.normals_now])
		# The neck, the head looking a little round and up (its rings' pairing kept): moved, not rebuilt, and drawn
		# as the full build.
		var nb0 := rig._neck_loft.builds
		for k in 11:
			rig.look_dir = Vector3(0.15 * sin(k * 0.6), 0.1 * cos(k * 0.6), -1.0).normalized()
			rig.apply_pose()
		check(rig._neck_loft.builds - nb0 <= 4, "%s: a glance moves the neck, not rebuilds it (%d full builds in 11 poses)" % [p.id, rig._neck_loft.builds - nb0])
		var neck_fast: Array = [rig._neck_loft.positions, rig._neck_loft.normals_now]
		rig._neck_key = ""
		rig.apply_pose()
		_compare(p.id + " neck", 0, neck_fast, [rig._neck_loft.positions, rig._neck_loft.normals_now])
		rig.queue_free()
	# Built in full, a LoftMesh is BodyShape.tube_mesh's surface (what every lofted surface was before): a bent tube
	# with a closed end, matched vertex by vertex (by position and coordinates), the same smoothed normals.
	var rows: Array = []
	var cols: Array = []
	var uvs: Array = []
	var uv2s: Array = []
	for i in 7:
		var row: Array = []
		var crow: Array = []
		var urow: Array = []
		var u2row: Array = []
		var r := 0.03 * (1.0 - i / 6.0)
		for j in 10:
			var a := TAU * j / 10.0
			row.append(Vector3(cos(a) * r + 0.02 * i * i, sin(a) * r * 0.6, i * 0.04))
			crow.append(Color(0.2 + 0.1 * j, 0.5, 0.3))
		for j in 11:
			urow.append(Vector2(j, i))
			u2row.append(Vector2(10.0, 0.0))
		rows.append(row)
		cols.append(crow)
		uvs.append(urow)
		uv2s.append(u2row)
	var lm := LoftMesh.new()
	lm.build(rows, cols, uvs, uv2s)
	var ref := BodyShape.tube_mesh(rows, null, cols, uvs, uv2s).surface_get_arrays(0)
	var by := {}
	for k in (ref[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		by[_key(ref[Mesh.ARRAY_VERTEX][k], ref[Mesh.ARRAY_TEX_UV][k])] = ref[Mesh.ARRAY_NORMAL][k]
	var mine := lm.mesh.surface_get_arrays(0)
	var worst := 1.0
	var missing := 0
	for k in (mine[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var key := _key(mine[Mesh.ARRAY_VERTEX][k], mine[Mesh.ARRAY_TEX_UV][k])
		if not by.has(key):
			missing += 1
			continue
		worst = minf(worst, (mine[Mesh.ARRAY_NORMAL][k] as Vector3).dot(by[key]))
	check(missing == 0, "LoftMesh's vertices are tube_mesh's (%d not found)" % missing)
	check(worst > 0.999, "LoftMesh's normals are tube_mesh's (worst dot %.5f)" % worst)
	finish()


static func _key(p: Vector3, uv: Vector2) -> String:
	return "%.5f,%.5f,%.5f|%.3f,%.3f" % [p.x, p.y, p.z, uv.x, uv.y]


func _compare(id: String, i: int, fast: Array, full: Array) -> void:
	var fv: PackedVector3Array = fast[0]
	var gv: PackedVector3Array = full[0]
	var fn: PackedVector3Array = fast[1]
	var gn: PackedVector3Array = full[1]
	check(fv.size() == gv.size(), "%s side %d: same vertex count (%d, %d)" % [id, i, fv.size(), gv.size()])
	var worst_p := 0.0
	var worst_n := 1.0
	for k in mini(fv.size(), gv.size()):
		worst_p = maxf(worst_p, fv[k].distance_to(gv[k]))
		worst_n = minf(worst_n, fn[k].dot(gn[k]))
	check(worst_p < 1e-5, "%s side %d: moved, the arm wing's vertices are the full build's (worst %.6f m)" % [id, i, worst_p])
	check(worst_n > 0.999, "%s side %d: and its normals (worst dot %.5f)" % [id, i, worst_n])
