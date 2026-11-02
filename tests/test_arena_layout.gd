extends TestCase
## The generated arena: deterministic per seed, trunk density falls with height, lanes are open, every
## perch is reachable air (above ground, inside the boundary, not inside a trunk), and the clearance
## query agrees with the geometry.


func setup() -> void:
	var a := ArenaLayout.generate(7)
	var b := ArenaLayout.generate(7)
	eq(a.trees.size(), b.trees.size(), "same seed, same trees")
	eq(a.perches.size(), b.perches.size(), "same seed, same perches")
	near(a.perches[10].position.x, b.perches[10].position.x, 1e-6, "same seed, same perch spots")
	check(ArenaLayout.generate(8).perches[10].position != a.perches[10].position, "different seed, different arena")
	print("trees %d, perches %d" % [a.trees.size(), a.perches.size()])
	var counts := [0, 0, 0]
	for t in a.trees:
		counts[t.tier] += 1
	print("tiers: understory %d, canopy %d, emergent %d" % counts)
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] >= 4, "more short trees than tall ones")

	# Density by height: strictly falling, and the sky above 20 m is nearly open.
	var d2 := a.trunk_density_above(2.0)
	var d10 := a.trunk_density_above(10.0)
	var d20 := a.trunk_density_above(20.0)
	print("trunks per 1000 m2 above 2 m: %.2f, 10 m: %.2f, 20 m: %.2f" % [d2, d10, d20])
	check(d2 > d10 * 2.0 and d10 > d20 * 3.0, "density falls with height")

	# Lanes are open below the canopy.
	for t in a.trees:
		check(t.base.length() > a.clearing_radius, "clearing is empty")
		for av in a.avenues:
			check(ArenaLayout._dist_to_segment_2d(t.base, av[0], av[1]) > av[2], "avenue is empty")
		if t.tier != ArenaLayout.Tier.EMERGENT:
			check(absf(t.base.length() - a.ring_radius) > a.ring_half_width, "ring lane is clear of low trees")
	# A pass straight down an avenue at 6 m is clear; a pass straight through a trunk is not.
	var av0: Array = a.avenues[0]
	var from := Vector3(av0[0].x, 6.0, av0[0].y).lerp(Vector3(av0[1].x, 6.0, av0[1].y), 0.1)
	var to := Vector3(av0[0].x, 6.0, av0[0].y).lerp(Vector3(av0[1].x, 6.0, av0[1].y), 0.9)
	check(a.segment_clear(from, to, 1.0), "avenue flight is clear")
	var t0: ArenaLayout.TreeData = a.trees[0]
	check(not a.segment_clear(Vector3(t0.base.x - 5, 2.0, t0.base.y), Vector3(t0.base.x + 5, 2.0, t0.base.y), 0.3), "flying through a trunk is blocked")
	check(not a.segment_clear(Vector3(0, 0.1, 0), Vector3(5, 0.1, 0), 0.3), "skimming the ground is blocked")

	# Every perch: above ground, inside the boundary, outside its trunk, facing horizontal.
	var kinds := [0, 0]
	for p in a.perches:
		kinds[p.kind] += 1
		check(p.position.y > 1.0, "perch above ground")
		check(Vector2(p.position.x, p.position.z).length() < a.boundary, "perch near the arena")
		near(p.facing.y, 0.0, 1e-6, "facing is horizontal")
		near(p.facing.length(), 1.0, 1e-4, "facing is unit")
		var tr: ArenaLayout.TreeData = a.trees[p.tree_id]
		if p.kind == Perch.Kind.BRANCH:
			# The grip line runs along the top of the branch, from clear of the trunk toward the tip.
			check(Vector2(p.a.x, p.a.z).distance_to(tr.base) >= tr.radius + ArenaLayout.GRIP_TRUNK_GAP - 1e-3, "grip line starts clear of the trunk")
			check(p.a.distance_to(p.b) > 0.3, "grip line has length (%.2f m)" % p.a.distance_to(p.b))
			near(p.facing.dot((p.b - p.a).normalized()), 0.0, 0.15, "default facing is across the branch")
			var side := Vector3.UP.cross((p.b - p.a).normalized()).normalized()
			check(p.closest_grip(p.position + side).distance_to(p.position) < 1e-4, "closest grip from beside the middle is the middle")
			check(p.closest_grip(p.a + (p.a - p.b) * 3.0).distance_to(p.a) < 1e-4, "closest grip clamps to the line's end")
			# Flying across the branch, the aim point is where the path crosses it, not the nearest point.
			var across := Vector3.UP.cross((p.b - p.a).normalized()).normalized()
			var cross_at := p.a.lerp(p.b, 0.8)
			var start := cross_at - across * 2.0 + (p.a - p.b).normalized() * 0.5
			var aim := p.aim_grip(start, (cross_at - start).normalized(), 4.0)
			check(aim.distance_to(cross_at) < 1e-3, "aim point is where the path meets the branch")
			check(aim.distance_to(p.closest_grip(start)) > 0.2, "aim point differs from the nearest point")
		else:
			check(p.disc > 0.0, "treetop has a grip disc")
			check(p.closest_grip(p.position + Vector3(5, 0, 0)).distance_to(p.position) <= p.disc + 1e-4, "treetop grip stays on its disc")
	check(kinds[Perch.Kind.TREETOP] == a.trees.size(), "one treetop perch per tree")
	check(kinds[Perch.Kind.BRANCH] > a.trees.size(), "more branch perches than trees")
	# Perches at every altitude band, most of them low.
	var low := 0
	var high := 0
	for p in a.perches:
		if p.position.y < 10.0: low += 1
		elif p.position.y > 20.0: high += 1
	check(low > high and high > 5, "perches at every height, most of them low (%d low, %d high)" % [low, high])

	# Spatial queries match brute force.
	var probe := Vector3(20, 6, -15)
	var near_list := a.perches_near(probe, 12.0)
	var brute := 0
	for p in a.perches:
		if p.distance_to(probe) <= 12.0:
			brute += 1
	eq(near_list.size(), brute, "perches_near finds them all")
	for i in range(1, near_list.size()):
		check(near_list[i - 1].distance_to(probe) <= near_list[i].distance_to(probe), "nearest grip first")
	var sp := a.start_perch()
	check(sp != null and sp.kind == Perch.Kind.TREETOP and sp.position.y > 15.0, "start on a tall treetop")
	finish()
