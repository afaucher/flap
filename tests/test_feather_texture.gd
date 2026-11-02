extends TestCase
## Plumage level 6, the feather-texture experiment (docs/research/feather_texture_study.md): the committed
## PNGs are what FeatherAtlas bakes today (not stale) and import with mipmaps; a level-6 rig draws its feathers
## and body with the texture shaders; every feather carries a valid atlas cell, signed so the shaft's narrow
## outer vane is on its leading side -- toward the front / the tip on both wings (they mirror), toward the
## outside of the tail fan on both halves.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	# The PNGs match the baker, texel for texel (a sample), and have mipmaps (small cards must not shimmer).
	var pairs := [[FeatherAtlas.load_atlas(), FeatherAtlas.bake_atlas(), "atlas"], [FeatherAtlas.load_body(), FeatherAtlas.bake_body(), "body tile"]]
	for pair in pairs:
		var tex: Texture2D = pair[0]
		var baked: Image = pair[1]
		check(tex != null, "%s loads" % pair[2])
		if tex == null:
			continue
		var img := tex.get_image()
		check(img.has_mipmaps(), "%s imported with mipmaps" % pair[2])
		eq(img.get_size(), baked.get_size(), "%s size" % pair[2])
		var worst := 0.0
		for k in 400:
			var x := (k * 7919) % baked.get_width()
			var y := (k * 104729) % baked.get_height()
			var a := img.get_pixel(x, y)
			var b := baked.get_pixel(x, y)
			worst = maxf(worst, maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a))))
		check(worst <= 1.5 / 255.0, "%s PNG matches FeatherAtlas (re-run tools/bake_feathers.gd): worst %.4f" % [pair[2], worst])

	Plumage.level = 6
	var rig := BirdRig.new()
	add_child(rig)
	rig.build(BirdProfile.by_id("hawk"))
	check(rig.marks_material != null and rig.marks_material.shader == BirdRig.TEXTURE_SHADER, "level 6 feathers use the texture shader")
	var trunk_m := rig._trunk.material_override as ShaderMaterial
	check(trunk_m != null and trunk_m.shader == BirdRig.BODY_TEXTURE_SHADER, "level 6 trunk uses the body-feather shader")
	check(rig._arm_tex.size() == 2, "both arm lofts textured")
	rig.flap = 0.0
	rig.fold = 0.0
	rig.apply_pose()
	var names := {WingShape.Kind.PRIMARY: "primary", WingShape.Kind.SECONDARY: "secondary", 6: "tail"}
	var seen := {"primary": [0, 0], "secondary": [0, 0], "tail": [0, 0]}
	var cells := 2 * FeatherAtlas.TYPES.size()
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
	finish()
