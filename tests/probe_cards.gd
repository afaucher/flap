extends TestCase
## Diagnostic: which texture each foliage card batch in the pine wood is drawn with.

func setup() -> void:
	var a := Pinewood.generate(7)
	var b := ArenaBuilder.new()
	add_child(b)
	b.build(a)
	for k in ["needles", "sapling", "leaves"]:
		var mi := b.get_node("Batch_cards_" + k) as MultiMeshInstance3D
		var m := mi.material_override as ShaderMaterial
		var t := m.get_shader_parameter("tex") as Texture2D
		print("CARDS %s: %d instances, tex %s (%dx%d), same as oak: %s, same as needles: %s" % [k, mi.multimesh.instance_count, str(t), t.get_width(), t.get_height(), str(t == FoliageTex.get_tex("oak")), str(t == FoliageTex.get_tex("needles"))])
	finish()
