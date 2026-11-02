extends TestCase
## Plumage level 6, the feather-texture experiment (docs/research/feather_texture_study.md): the committed
## PNGs are what FeatherAtlas bakes today (not stale) and import with mipmaps; a level-6 rig draws its feathers
## and body with the texture shaders; every feather carries a valid atlas cell, signed so the shaft's narrow
## outer vane is on its leading side -- toward the front / the tip on both wings (they mirror), toward the
## outside of the tail fan on both halves.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	# The PNGs were baked from today's FeatherAtlas (its MD5, stamped by the baker: re-baking takes a minute),
	# are its size, and have mipmaps (small cards must not shimmer).
	var stamp := FileAccess.get_file_as_string(FeatherAtlas.STAMP_PATH).strip_edges()
	eq(stamp, FeatherAtlas.source_md5(), "the feather PNGs are baked from today's FeatherAtlas (re-run tools/bake_feathers.gd)")
	var texs := [[FeatherAtlas.load_atlas(), FeatherAtlas.ATLAS_SIZE, "atlas"], [FeatherAtlas.load_atlas_normal(), FeatherAtlas.ATLAS_SIZE, "atlas relief"],
		[FeatherAtlas.load_body(), Vector2i(FeatherAtlas.BODY_SIZE, FeatherAtlas.BODY_SIZE), "body tile"], [FeatherAtlas.load_body_normal(), Vector2i(FeatherAtlas.BODY_SIZE, FeatherAtlas.BODY_SIZE), "body relief"]]
	for tx in texs:
		var tex: Texture2D = tx[0]
		check(tex != null, "%s loads" % tx[2])
		if tex == null:
			continue
		var img := tex.get_image()
		check(img.has_mipmaps(), "%s imported with mipmaps" % tx[2])
		eq(img.get_size(), tx[1], "%s size" % tx[2])
	# Neighbouring feathers in a row never share an atlas variant (coverts have four).
	for side in 2:
		for fi in 30:
			check(FeatherAtlas.cell("greater", false, fi, side) != FeatherAtlas.cell("greater", false, fi + 1, side), "covert %d / %d differ (side %d)" % [fi, fi + 1, side])
	Plumage.level = 6
	var rig := BirdRig.new()
	add_child(rig)
	rig.build(BirdProfile.by_id("hawk"))
	check(rig.marks_material != null and rig.marks_material.shader == BirdRig.TEXTURE_SHADER, "level 6 feathers use the texture shader")
	# Silhouette cards: rooted on the trunk's shell, mirrored left and right (centre tracts aside), riding on the
	# trunk (its fluff scales them), drawn with the feather material in the body's own colour.
	var nc := rig.card_xforms.size()
	check(nc > 40 and rig.get_node_or_null("Trunk/SilhouetteCards") != null, "silhouette cards on the trunk (%d)" % nc)
	var worst_root := 0.0
	var unmirrored := 0
	for ci in nc:
		var o: Vector3 = rig.card_xforms[ci].origin
		worst_root = maxf(worst_root, absf(rig.body.gap(o)))
		if rig.CARD_TRACTS[rig.card_tracts[ci]].get("centre", false):
			continue
		var found := false
		for cj in nc:
			found = found or rig.card_xforms[cj].origin.distance_to(o * Vector3(-1, 1, 1)) < 1e-4
		unmirrored += 0 if found else 1
	check(worst_root < rig._L * 0.02, "cards rooted on the shell (worst %.4f m)" % worst_root)
	check(unmirrored == 0, "cards mirrored left and right (%d unmatched)" % unmirrored)
	for tract in ["scapular", "flank", "rump", "vent"]:
		check(rig.card_tracts.has(tract), "a %s tract" % tract)
	# The brow ridge is feathered: the head's feather material and chart over it, not a smooth blob of colour.
	check(not rig._brows.is_empty(), "the hawk has brow ridges")
	for b in rig._brows:
		var arr := (b.mesh as ArrayMesh).surface_get_arrays(0)
		check(b.material_override == rig.body_texture_material and arr[Mesh.ARRAY_COLOR] != null and (arr[Mesh.ARRAY_COLOR] as PackedColorArray)[0].a > 0.5, "the brow ridge wears the head's feathers")
	# The outline frays on the body's own surface: nothing is drawn off it (no shells beside the bird).
	check(float(rig.body_texture_material.get_shader_parameter("fray")) > 0.0, "the body's outline frays")
	check(rig.body_texture_material.next_pass == null, "no shells drawn off the body")
	BirdRig.silhouette_cards = false
	BirdRig.outline_down = false
	var bare := BirdRig.new()
	add_child(bare)
	bare.build(BirdProfile.by_id("hawk"))
	BirdRig.silhouette_cards = true
	BirdRig.outline_down = true
	check(bare.card_xforms.is_empty() and bare.get_node_or_null("Trunk/SilhouetteCards") == null, "cards switch off")
	check(float(bare.body_texture_material.get_shader_parameter("fray")) == 0.0, "the fraying switches off")
	bare.queue_free()
	# Light: flight feathers smoother and more translucent than the coverts (per row of the material), and the
	# crow's glossier than the owl's velvety ones.
	var gl: PackedVector4Array = rig.marks_material.get_shader_parameter("gloss")
	var prim := gl[Plumage.row_index("primary", false)]
	var cov := gl[Plumage.row_index("lesser", false)]
	check(gl.size() == Plumage.GROUPS.size() * 2 and prim.x < cov.x and prim.z > cov.z, "flight feathers smoother and more translucent than coverts (%s vs %s)" % [prim, cov])
	check(float(Plumage.gloss("crow", "primary")[0]) < float(Plumage.gloss("hawk", "primary")[0]) and float(Plumage.gloss("owl", "primary")[0]) > float(Plumage.gloss("hawk", "primary")[0]), "crow glossy, owl matte")
	# The game's light at a bird's scale: the sun's first shadow cascade holds the bird the chase camera follows,
	# and ambient occlusion has a radius of centimetres, not metres.
	var scene := Node3D.new()
	add_child(scene)
	Game.add_environment(scene)
	var sun: DirectionalLight3D = scene.find_children("*", "DirectionalLight3D", false, false)[0]
	var env: Environment = (scene.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	var first := sun.directional_shadow_max_distance * sun.directional_shadow_split_1
	var cam := ChaseCamera.new()
	var follow := cam.distance
	cam.free()
	check(sun.shadow_enabled and first > follow * 1.2 and first < 10.0, "first shadow cascade holds the followed bird (%.1f m)" % first)
	check(env.ssao_enabled and env.ssao_radius < 0.5, "bird-scale ambient occlusion")
	scene.queue_free()
	var trunk_m := rig._trunk.material_override as ShaderMaterial
	check(trunk_m != null and trunk_m.shader == BirdRig.BODY_TEXTURE_SHADER, "level 6 trunk uses the body-feather shader")
	for i in 2:
		for k in 4:
			check((rig._fairings[i][k] as MeshInstance3D).material_override == rig.body_texture_material, "wing %d piece %d (the joint to the body too) textured" % [i, k])
	check(rig._neck_mi.material_override == rig.body_texture_material and (rig._head.get_node("HeadSurface") as MeshInstance3D).material_override == rig.body_texture_material, "neck and head textured")
	rig.flap = 0.0
	rig.fold = 0.0
	rig.apply_pose()
	var names := {WingShape.Kind.PRIMARY: "primary", WingShape.Kind.SECONDARY: "secondary", 6: "tail"}
	var seen := {"primary": [0, 0], "secondary": [0, 0], "tail": [0, 0]}
	var cells := FeatherAtlas.CELLS
	eq(rig.feather_codes.size(), rig.feather_xforms.size(), "a code per feather")
	for i in rig.feather_xforms.size():
		var code: float = rig.feather_codes[i]
		var cell := int(absf(code) + 0.5) - 1
		check(cell >= 0 and cell < cells, "feather %d has an atlas cell (%f)" % [i, code])
		var g: String = names.get(rig.feather_kinds[i] % 100, "")
		if g == "":
			continue
		var xf: Transform3D = rig.feather_xforms[i]
		var lead := xf.basis.x.normalized() * signf(code)   # the leading (outer-vane) side, in rig space
		var side := signf(xf.origin.x)
		var want := Vector3(side, 0.0, 0.0) if g == "tail" else Vector3(side, 0.0, -1.0).normalized()
		check(lead.dot(want) > 0.2, "%s at x %.3f: outer vane on the leading side (%s)" % [g, xf.origin.x, lead])
		seen[g][0 if side < 0.0 else 1] += 1
	for g in seen:
		check(seen[g][0] > 0 and seen[g][0] == seen[g][1], "%s: checked on both sides (%s)" % [g, seen[g]])
	Plumage.level = 5
	rig.queue_free()
	# One feather chart across the joins (every species): where the neck meets the trunk and the head, and where
	# the wing's surface meets the body, both sides carry the same coordinates (u up to its period), so the
	# contour feathers run on with no seam.
	for p in BirdProfile.all():
		var b := BirdRig.new()
		add_child(b)
		b.build(p)
		b.look_dir = Vector3(0.3, -0.1, -1.0).normalized()
		b.fold = 0.0
		b.apply_pose()
		var sc := b._trunk.scale.x
		var tm := (b._trunk.mesh as ArrayMesh).surface_get_arrays(0)
		var nm := b.drawn_arrays(b._neck_mi)
		var hm := ((b._head.get_node("HeadSurface") as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var am := b.drawn_arrays(b._fairings[1][0])
		var trunk_pts: Array = []
		for k in (tm[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			trunk_pts.append([(tm[Mesh.ARRAY_VERTEX][k] as Vector3) * sc, tm[Mesh.ARRAY_TEX_UV][k], tm[Mesh.ARRAY_TEX_UV2][k]])
		var head_pts: Array = []
		for k in (hm[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			head_pts.append([b._head.transform * (hm[Mesh.ARRAY_VERTEX][k] as Vector3), hm[Mesh.ARRAY_TEX_UV][k], hm[Mesh.ARRAY_TEX_UV2][k]])
		var worst_t := 0.0
		var worst_h := 0.0
		var n_t := 0
		var n_h := 0
		var nv: PackedVector3Array = nm[Mesh.ARRAY_VERTEX]
		for k in nv.size():
			var q := nv[k]
			var quv: Vector2 = nm[Mesh.ARRAY_TEX_UV][k]
			for pair in [[trunk_pts, 0], [head_pts, 1]]:
				for e in pair[0]:
					if (e[0] as Vector3).distance_to(q) < 1e-5:
						var per: float = (e[2] as Vector2).x
						var du := absf(wrapf(quv.x - (e[1] as Vector2).x, -0.5 * per, 0.5 * per))
						var d := maxf(du, absf(quv.y - (e[1] as Vector2).y))
						if pair[1] == 0:
							worst_t = maxf(worst_t, d)
							n_t += 1
						else:
							worst_h = maxf(worst_h, d)
							n_h += 1
		check(n_t >= BirdRig.TRUNK_AROUND and worst_t < 1e-3, "%s neck and trunk share their coordinates where they meet (%d points, worst %.4f tiles)" % [p.id, n_t, worst_t])
		check(n_h >= BirdRig.TRUNK_AROUND and worst_h < 1e-3, "%s neck and head share their coordinates where they meet (%d points, worst %.4f tiles)" % [p.id, n_h, worst_h])
		# The wing's surface: its points on the body carry the trunk's own coordinates there.
		var worst_a := 0.0
		var n_a := 0
		var av: PackedVector3Array = am[Mesh.ARRAY_VERTEX]
		for k in av.size():
			var q := av[k] / sc
			if absf(b.body.gap(q)) < b.body.L * 0.002:
				var want: Array = b.body.uv_at(q)
				var auv: Vector2 = am[Mesh.ARRAY_TEX_UV][k]
				var per: float = (want[1] as Vector2).x
				worst_a = maxf(worst_a, maxf(absf(wrapf(auv.x - (want[0] as Vector2).x, -0.5 * per, 0.5 * per)), absf(auv.y - (want[0] as Vector2).y)))
				n_a += 1
		check(n_a >= BirdRig.ARM_AROUND and worst_a < 0.02, "%s wing surface starts on the trunk's coordinates (%d points, worst %.4f tiles)" % [p.id, n_a, worst_a])
		b.queue_free()
	finish()