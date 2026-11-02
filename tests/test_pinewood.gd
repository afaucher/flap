extends TestCase
## The pine wood (Pinewood), as grown: the same seed grows the same wood; pines stand clear below their crowns
## but for short dead stubs, their limbs and needles up in the crown; the oaks -- one in the clearing -- carry
## long, nearly level limbs to perch on; every outpost is bolted to its trunk with a landing rail along its
## outer edge that is a perch, facing open air (wood and leaves clear for several metres out), left and right
## of the rail alike; the AI's clearance queries see the decks; and the crowns leave sightlines.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var a := Pinewood.generate(7)
	var b := Pinewood.generate(7)
	eq(a.trees.size(), b.trees.size(), "same seed, same trees")
	eq(a.perches.size(), b.perches.size(), "same seed, same perches")
	check(a.outposts.size() > 0 and b.outposts.size() == a.outposts.size() and (a.outposts[0].centre as Vector3).is_equal_approx(b.outposts[0].centre), "same seed, same outposts")
	_pines(a)
	_oaks(a)
	_outposts(a)
	_sightlines(a)
	finish()


## The crowns leave sightlines: at every height from the floor to above the crowns, at least a third of
## level looks reach 40 m (the seeker's lock range) past wood and leaves, and under the crowns most do.
func _sightlines(a: ArenaLayout) -> void:
	var hs := [5.0, 12.0, 18.0, 22.0, 26.0, 32.0]
	var r := Pinewood.sightlines(a, hs, 120, 40.0, true)
	for h in hs:
		check(float(r[h][2]) >= 0.33, "at %.0f m, a third of looks reach 40 m (%.0f%%)" % [h, float(r[h][2]) * 100.0])
	check(float(r[12.0][2]) >= 0.75, "under the crowns most looks reach 40 m (%.0f%%)" % (float(r[12.0][2]) * 100.0))


func _pines(a: ArenaLayout) -> void:
	var n := 0
	var low_live := 0
	var long_stubs := 0
	var crown_ok := 0
	for t in a.trees:
		if t.kind != ArenaLayout.Kind.PINE:
			continue
		n += 1
		var limbs_up := 0
		for br in t.branches:
			if br.dead:
				if br.root.distance_to(br.tip) > 0.9 + t.radius:
					long_stubs += 1
			elif br.root.y < t.crown_base - 0.01:
				low_live += 1
			else:
				limbs_up += 1
		if t.crown_base > t.height * 0.55 and limbs_up >= 6:
			crown_ok += 1
		for f in t.foliage:
			if (f[0] as Vector3).y < t.crown_base - 0.5:
				low_live += 1
	check(n > 150, "a stand of pines (%d)" % n)
	eq(low_live, 0, "no live limb or needles on a pine below its crown")
	eq(long_stubs, 0, "the dead stubs are short")
	eq(crown_ok, n, "every pine's crown is up top, with its whorls of limbs")


func _oaks(a: ArenaLayout) -> void:
	var oaks := 0
	var in_clearing := false
	for t in a.trees:
		if t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		oaks += 1
		in_clearing = in_clearing or Vector2(t.base).length() < a.clearing_radius
		var long_level := 0
		for br in t.branches:
			var d: Vector3 = br.tip - br.root
			var rise := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
			if br.perch_id >= 0 and d.length() > 3.5 and absf(rise) < 12.0:
				long_level += 1
		check(long_level >= 8, "oak %d carries long, nearly level limbs to perch on (%d)" % [t.id, long_level])
	check(oaks >= 3, "a few oaks (%d)" % oaks)
	check(in_clearing, "an oak stands in the clearing")


func _outposts(a: ArenaLayout) -> void:
	check(a.outposts.size() >= 6, "outposts (%d)" % a.outposts.size())
	for o in a.outposts:
		var t: ArenaLayout.TreeData = a.trees[o.tree_id]
		var axis := Vector3(t.base.x, o.centre.y, t.base.y)
		var inner: Vector3 = o.centre - o.out * o.depth * 0.5
		var trunk_r := t.radius if t.kind == ArenaLayout.Kind.BROADLEAF else t.radius * lerpf(1.0, 0.4, o.centre.y / t.height)
		check(inner.distance_to(axis) < trunk_r + 0.05, "outpost %d is bolted to its trunk" % o.id)
		var p: Perch = a.perches[o.rail_perch_id]
		var edge: Vector3 = o.centre + o.out * (o.depth * 0.5)
		check(absf((p.position - o.centre).dot(o.out) - o.depth * 0.5) < o.rail_radius * 1.5, "outpost %d: its perch is the rail along the outer edge" % o.id)
		check(p.a.distance_to(p.b) > o.width * 0.8, "outpost %d: the rail perch runs the deck's width" % o.id)
		check(p.facing.dot(o.out) > 0.9, "outpost %d: the rail faces out" % o.id)
		# Open air on approach, at both ends of the rail.
		var side: Vector3 = o.out.cross(Vector3.UP).normalized()
		for e in [-1.0, 1.0]:
			var near: Vector3 = edge + Vector3.UP * 0.4 + side * e * o.width * 0.35 + o.out * 1.0
			var far: Vector3 = near + o.out * 8.0
			check(a.segment_clear(near, far, 0.4), "outpost %d: the approach is clear of wood (side %d)" % [o.id, int(e)])
			var leafy := 0
			for u in 9:
				if not Pinewood._leaf_free(a, near.lerp(far, u / 8.0), 0.3):
					leafy += 1
			eq(leafy, 0, "outpost %d: the approach is clear of leaves (side %d)" % [o.id, int(e)])
		# The AI sees the deck: a line straight through it is not clear.
		check(not a.segment_clear(o.centre - side * o.width + Vector3.DOWN * 0.03, o.centre + side * o.width + Vector3.DOWN * 0.03, 0.05), "outpost %d: the deck blocks a path through it" % o.id)
