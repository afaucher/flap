extends TestCase
## Diagnostic: a LabScenarios scenario (REFLEX_SCENARIO, default wing_clip) flown by a crow in the lab, tick by tick:
## its reflex, fold, flare, strikes, distance of its body from the trunk; REFLEX_OFF=tuck_reflex etc. sets one to 0. Headless.

func setup() -> void:
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	var tree: ArenaLayout.TreeData = layout.trees[0]
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, null)
	b.arena = arena
	b.rig.visible = false
	var sc := OS.get_environment("REFLEX_SCENARIO") if OS.get_environment("REFLEX_SCENARIO") != "" else "wing_clip"
	var pilot := LabScenarios.start(LabScenarios.by_id(sc), b, layout)
	if OS.get_environment("REFLEX_OFF") != "":
		b.set(OS.get_environment("REFLEX_OFF"), 0.0)
	for f in 120:
		await get_tree().physics_frame
		var d := Vector2(b.global_position.x - tree.base.x, b.global_position.z - tree.base.y).length() - tree.radius
		if d < 1.5 or b.reflex != "":
			print("f %3d d %.2f y %.2f v %.2f reflex %-6s fold %.2f flare %.2f strikes %d tucks %d flares %d braces %d catch %s state %d" % [f, d, b.global_position.y, b.model.speed, b.reflex, b.model.fold, b.model.flare, b.wing_strikes, b.tucks, b.flares, b.braces, b.last_input.catch_held, b.state])
	finish()
