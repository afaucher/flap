extends TestCase
## The pine wood's floor as built (ArenaBuilder._ground, _grass; forest_floor.gdshader): under the wood a fine mesh
## the litter's mounds rise in (the big plane drawing only round it, no gap and no overlap between them), the openings
## handed to the shader as Pinewood lays them out; grass thick in the openings and thin under the trees.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var layout := Pinewood.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	var ground: Node = arena.get_node("Ground")
	var fine := ground.get_node_or_null("FloorMounds") as MeshInstance3D
	check(fine != null, "a fine floor mesh under the wood")
	if fine != null:
		var fm := fine.material_override as ShaderMaterial
		var half := (fine.mesh as PlaneMesh).size.x * 0.5
		var step := (fine.mesh as PlaneMesh).size.x / float((fine.mesh as PlaneMesh).subdivide_width + 1)
		print("FLOOR fine mesh %.0f m across, a vertex every %.2f m, mounds up to %.2f m" % [half * 2.0, step, _param(fm, "mound_h")])
		check(_param(fm, "displace") > 0.0 and step < 0.6, "it's fine enough for the mounds and they're drawn on it (%.2f m)" % step)
		check(half >= layout.boundary + 5.0, "it covers the wood (%.0f m from the middle, boundary %.0f)" % [half, layout.boundary])
		var plane: MeshInstance3D = null
		for c in ground.get_children():
			if c is MeshInstance3D and c != fine:
				plane = c
		var hole := _param(plane.material_override as ShaderMaterial, "hole_r")
		# (the plane draws past hole_r; the fine mesh is a square of `half`: hole_r inside the square's inscribed circle, so
		# no gap; and the fine mesh's mounds have faded out by then, so its edge sits flat on the plane: no step)
		check(hole <= half and hole > _param(fm, "fade_r"), "the big plane draws only round it, no gap (hole %.1f, mesh %.1f, mounds gone by %.1f)" % [hole, half, _param(fm, "fade_r")])
		eq(int(fm.get_shader_parameter("opening_count")), layout.openings.size(), "the shader knows every opening")
		var ops: PackedVector4Array = fm.get_shader_parameter("openings")
		var o0: Dictionary = layout.openings[0]
		check(Vector2(ops[0].x, ops[0].y).is_equal_approx(o0.centre) and is_equal_approx(ops[0].z, float(o0.r)), "as Pinewood lays them out")
	# Grass: per square metre, in the openings against under the trees.
	var grass: MultiMeshInstance3D = null
	for c in arena.get_children():
		if c is MultiMeshInstance3D and c.name == "Batch_grass":
			grass = c
	check(grass != null, "grass is drawn")
	if grass != null:
		var inside := 0
		var outside := 0
		for i in grass.multimesh.instance_count:
			var o := grass.multimesh.get_instance_transform(i).origin
			if Pinewood.in_opening(layout, Vector2(o.x, o.z)):
				inside += 1
			else:
				outside += 1
		var open_area := 0.0
		for o in layout.openings:
			open_area += PI * float(o.r) * float(o.r)
		var wood_area := PI * layout.boundary * layout.boundary - open_area
		var d_in := inside / open_area
		var d_out := outside / wood_area
		print("FLOOR grass: %.2f a square metre in the openings, %.3f under the trees" % [d_in, d_out])
		check(d_in > 2.0 and d_in > d_out * 15.0, "thick in the openings, thin under the trees (%.2f v %.3f)" % [d_in, d_out])
	arena.queue_free()
	finish()


## A shader parameter as set, else the shader's own default.
func _param(m: ShaderMaterial, name: String) -> float:
	var v = m.get_shader_parameter(name)
	if v == null:
		v = RenderingServer.shader_get_parameter_default(m.shader.get_rid(), name)
	return float(v)
