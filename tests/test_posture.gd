extends TestCase
## Sitting, a bird keeps its tail and wingtips out of what it sits on (BirdRig._posture), measured on the drawn
## feathers' tips against the surface the Bird reports, every species:
## - perched facing across a branch, the arena's thinnest and thickest (as it lands): the tail hangs behind it, nothing digs in, the posture is the
##   species' own (no lean) on the thin one;
## - turned to face along the branch: the bird levels out until every tip clears it;
## - standing on the ground: every tip clears the ground.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var thin: Perch = null
	var thick: Perch = null
	for q in layout.perches:
		if q.kind == Perch.Kind.BRANCH:
			thin = q if thin == null or q.thickness < thin.thickness else thin
			thick = q if thick == null or q.thickness > thick.thickness else thick
	for p in BirdProfile.all():
		for perch: Perch in [thin, thick]:
			var tag := "%s on a %.0f cm branch" % [p.id, perch.thickness * 200.0]
			var b := Bird.new()
			add_child(b)
			b.setup(p, layout, ScriptedInput.new())
			b.arena = arena
			b.perch_at(perch)
			await frames(90)
			check(_deepest(b) < 0.0, "%s, across it: tail and wingtips clear it (deepest %.4f m)" % [tag, _deepest(b)])
			if perch == thin:   # (on the thickest, 24 cm across, an upright tail reaches the far side: it leans a little)
				check(b.rig.lean < 0.15, "%s, across it: its own posture (lean %.2f)" % [tag, b.rig.lean])
			var along := perch.b - perch.a
			along.y = 0.0
			b.facing = along.normalized()
			await frames(150)
			check(_deepest(b) < 0.0, "%s, along it: tail and wingtips clear it (deepest %.4f m)" % [tag, _deepest(b)])
			b.queue_free()
			await frames(1)
		var g := Bird.new()
		add_child(g)
		g.setup(p, layout, ScriptedInput.new())
		g.arena = arena
		g.fly_from(Vector3(0, 0.3, 0), Vector3(1, -1, 0).normalized(), 1.0)
		for i in 30:
			await frames(1)
			if g.state == Bird.State.GROUNDED:
				break
		await frames(150)
		eq(g.state, Bird.State.GROUNDED, p.id + " on the ground")
		check(_deepest(g) < 0.0, "%s on the ground: tail and wingtips clear it (deepest %.4f m)" % [p.id, _deepest(g)])
		g.queue_free()
		await frames(1)
	finish()


## The deepest drawn feather tip inside the surface the bird sits on (m; negative: all clear).
func _deepest(b: Bird) -> float:
	if b.rig.gpu_place:   # (placed on the GPU, as drawn: the rig's own placement of this pose, to measure)
		b.rig._cpu_feathers = true
		b.rig.apply_pose()
		b.rig._cpu_feathers = false
	var srf: Dictionary = b.telemetry().surface
	var xf := b.rig.global_transform
	var worst := -INF
	for f in b.rig.feather_xforms:
		worst = maxf(worst, BirdRig._depth(srf, xf * (f.origin + f.basis.z)))
	return worst
