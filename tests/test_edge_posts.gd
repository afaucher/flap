extends TestCase
## The arena's edge posts (ArenaLayout.add_posts): in both arenas, a ring of posts just inside the boundary, each a
## solid post as built (a bird can't fly through it: a ray along the ground hits it) with a perch on its top
## facing the middle -- a fallback resting spot, which the flight AI only picks when nothing else is in reach.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	for style in ["greybox", "pinewood"]:
		var a := ArenaLayout.generate(7) if style == "greybox" else Pinewood.generate(7)
		var posts := []
		for t in a.trees:
			if t.kind == ArenaLayout.Kind.POST:
				posts.append(t)
		check(posts.size() >= ArenaLayout.POST_COUNT * 0.6, "%s: a ring of edge posts (%d)" % [style, posts.size()])
		var tops := 0
		for t in posts:
			check(absf((t.base as Vector2).length() - a.boundary) < 1.0, "%s: post %d stands at the edge (%.1f m out, boundary %.0f)" % [style, t.id, (t.base as Vector2).length(), a.boundary])
			for p in a.perches:
				if p.tree_id == t.id and p.kind == Perch.Kind.TREETOP and p.fallback and absf(p.position.y - t.height) < 0.1:
					tops += 1
					check(p.facing.dot(Vector3(-t.base.x, 0.0, -t.base.y).normalized()) > 0.99, "%s: post %d's perch faces the middle" % [style, t.id])
		eq(tops, posts.size(), "%s: a perch on every post's top" % style)
		# Built: each post is solid where it's drawn.
		var vp := SubViewport.new()
		vp.own_world_3d = true
		add_child(vp)
		var b := ArenaBuilder.new()
		vp.add_child(b)
		b.build(a)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := b.get_world_3d().direct_space_state
		var solid := 0
		for t in posts:
			var c := Vector3(t.base.x, 3.0, t.base.y)
			var side := Vector3(-t.base.y, 0.0, t.base.x).normalized()
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c - side * 2.0, c + side * 2.0, ArenaBuilder.WORLD_LAYER))
			if not hit.is_empty() and (hit.position as Vector3).distance_to(c) < ArenaLayout.POST_RADIUS + 0.05:
				solid += 1
		eq(solid, posts.size(), "%s: every post is solid where it's drawn" % style)
		vp.queue_free()
	finish()
