extends TestCase
## ArenaBuilder.looks off (headless matches: Duel) builds the same solid world as the full build -- every collision
## shape, the same kind in the same place -- and leaves out only what isn't solid (the bark's dressing, needles and
## leaves, bracken): fewer drawn meshes.


func setup() -> void:
	var layout := Pinewood.generate(3)
	var full := _build(layout, true)
	var solid := _build(layout, false)
	eq(solid.shapes.size(), full.shapes.size(), "the same number of collision shapes (%d)" % full.shapes.size())
	var missing := 0
	for k in full.shapes:
		if not solid.shapes.has(k):
			missing += 1
	eq(missing, 0, "every collision shape of the full build is there, the same kind in the same place")
	check(solid.drawn < full.drawn, "fewer drawn meshes (%d against %d)" % [solid.drawn, full.drawn])
	finish()


func _build(layout: ArenaLayout, looks: bool) -> Dictionary:
	var b := ArenaBuilder.new()
	b.looks = looks
	add_child(b)
	b.build(layout)
	var shapes := {}
	var drawn := 0
	var stack: Array = [b]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is CollisionShape3D and (n as CollisionShape3D).shape != null:
			var cs := n as CollisionShape3D
			var p := cs.global_position
			shapes["%s %.2f %.2f %.2f" % [cs.shape.get_class(), p.x, p.y, p.z]] = true
		elif n is MeshInstance3D or n is MultiMeshInstance3D:
			drawn += 1
	remove_child(b)
	b.free()
	return {"shapes": shapes, "drawn": drawn}
