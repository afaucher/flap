extends TestCase
## Flying into a trunk bounces off it (never through), costs speed and briefly stuns; a slow touchdown on
## the ground lands; FLAP on the ground takes off.

var layout: ArenaLayout


func setup() -> void:
	layout = ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var p := BirdProfile.crow()
	# Pick a thick canopy trunk and fly straight at it from 8 m at mid height.
	var tree: ArenaLayout.TreeData = null
	for t in layout.trees:
		if t.tier == ArenaLayout.Tier.CANOPY:
			tree = t
			break
	var axis := Vector3(tree.base.x, 0.0, tree.base.y)
	var from := axis + Vector3(8.0, tree.height * 0.25, 0.0)
	var ctl := ScriptedInput.new()
	var b := Bird.new()
	add_child(b)
	b.setup(p, layout, ctl)
	b.perch_assist = 0.0
	b.fly_from(from, Vector3(-1, 0, 0), p.v_best * 1.3)
	var hit := false
	var min_axis := INF
	for i in 120:
		await frames(1)
		var flat := Vector2(b.global_position.x - axis.x, b.global_position.z - axis.z)
		min_axis = minf(min_axis, flat.length())
		if b.bonks > 0 and not hit:
			hit = true
			check(b.stun > 0.0, "a hit stuns")
			check(b.model.velocity.x > -0.5, "bounced back off the trunk")
			check(b.model.velocity.length() < p.v_best * 1.3 * 0.8, "the hit cost speed")
	check(hit, "flew into the trunk")
	check(min_axis > tree.radius, "never inside the trunk (%.2f vs %.2f)" % [min_axis, tree.radius])
	check(b.global_position.x > axis.x, "still on the near side")
	b.queue_free()

	# Slow descent onto open ground (the clearing) lands; SPACE takes off.
	var ctl2 := ScriptedInput.new()
	var g := Bird.new()
	add_child(g)
	g.setup(p, layout, ctl2)
	g.fly_from(Vector3(0, 1.5, 0), Vector3(0, -0.6, -1).normalized(), p.grab_speed_max)
	for i in 120:
		await frames(1)
		if g.state == Bird.State.GROUNDED:
			break
	eq(g.state, Bird.State.GROUNDED, "slow touchdown lands on the ground")
	ctl2.flap = true
	await frames(1)
	eq(g.state, Bird.State.FLYING, "FLAP takes off")
	check(g.model.velocity.y > 0.5, "takes off upward")
	finish()
