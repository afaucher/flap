extends TestCase
## The pine wood (Pinewood), as grown: the same seed grows the same wood; pines stand clear below their crowns
## but for short dead stubs, their limbs and needles up in the crown; the oaks -- one in the clearing -- carry
## long, nearly level limbs to perch on; every outpost is bolted to its trunk with a landing rail along its
## outer edge that is a perch, facing open air (wood and leaves clear for several metres out), left and right
## of the rail alike, with a way in every bird's planner takes (the final swoop onto the rail, the outposts being the
## bases birds rearm on); the AI's clearance queries see the decks; and the crowns leave sightlines. The stand has
## structure: clumps and open ground, a clearing and a glade, and the young pines out in the light.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var a := Pinewood.generate(7)
	var b := Pinewood.generate(7)
	eq(a.trees.size(), b.trees.size(), "same seed, same trees")
	eq(a.perches.size(), b.perches.size(), "same seed, same perches")
	check(a.outposts.size() > 0 and b.outposts.size() == a.outposts.size() and (a.outposts[0].centre as Vector3).is_equal_approx(b.outposts[0].centre), "same seed, same outposts")
	_pines(a)
	_oaks(a)
	_outposts(a)
	for other in [3, 11, 21, 5]:   # (outposts face whatever open air a layout leaves: try several)
		_outposts(Pinewood.generate(other))
	_young_pines(a)
	_structure(a)
	_sightlines(a)
	finish()


## Clumps and open ground: the openings (the clearing, a glade, gaps) have no standing pine inside their edges;
## the pines are clumped, not evenly spread; much of the floor lies far from any trunk; and the young pines grow
## out in the light.
func _structure(a: ArenaLayout) -> void:
	var kinds := {}
	for o in a.openings:
		kinds[o.kind] = kinds.get(o.kind, 0) + 1
	eq(kinds.get("clearing", 0), 1, "a clearing")
	eq(kinds.get("glade", 0), 1, "a glade")
	check(kinds.get("gap", 0) >= 5, "gaps (%d)" % kinds.get("gap", 0))
	var inside := 0
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.PINE and Pinewood.in_opening(a, t.base):
			inside += 1
	eq(inside, 0, "no standing pine in an opening")
	for o in a.openings:
		if o.kind != "gap":
			check(float(o.r) >= 16.0, "the %s is over 30 m across (%.0f m)" % [o.kind, float(o.r) * 2.0])
	# Clumped: pine counts in 16 m squares vary more than a random scatter's (variance over mean above 1; the
	# old even stand's was under).
	var counts := {}
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.PINE:
			var c := Vector2i(floori(t.base.x / 16.0), floori(t.base.y / 16.0))
			counts[c] = counts.get(c, 0) + 1
	var cells: Array[float] = []
	for cx in range(-5, 5):
		for cz in range(-5, 5):
			if Vector2(cx + 0.5, cz + 0.5).length() * 16.0 < a.boundary - 10.0:
				cells.append(float(counts.get(Vector2i(cx, cz), 0)))
	var mean := 0.0
	for c in cells:
		mean += c
	mean /= cells.size()
	var v := 0.0
	for c in cells:
		v += (c - mean) * (c - mean)
	v /= cells.size() - 1
	print("STRUCTURE pines in 16 m squares: mean %.2f, variance %.2f, ratio %.2f" % [mean, v, v / mean])
	check(v / mean > 1.15, "the pines are clumped (variance over mean %.2f)" % (v / mean))
	var open := 0
	var total := 0
	var lit_floor := 0.0
	for x in range(-80, 81, 4):
		for z in range(-80, 81, 4):
			var p := Vector2(x, z)
			if p.length() > a.boundary - 6.0:
				continue
			total += 1
			lit_floor += Pinewood.light(a, p)
			var d := INF
			for t in a.trees:
				if t.kind == ArenaLayout.Kind.PINE:
					d = minf(d, p.distance_to(t.base))
				elif t.kind == ArenaLayout.Kind.BROADLEAF:
					d = minf(d, p.distance_to(t.base) - 9.0)
			if d > 9.0:
				open += 1
	check(open > total * 0.03, "open ground: %.0f%% of the floor more than 9 m from a trunk" % (open * 100.0 / total))
	var lit_young := 0.0
	var young := 0
	var shaded := 0
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.SAPLING:
			young += 1
			lit_young += Pinewood.light(a, t.base)
			shaded += int(Pinewood.light(a, t.base) < 0.6)
	print("STRUCTURE open sky over the young pines %.2f, over the floor %.2f; %d of %d young pines in shade" % [lit_young / young, lit_floor / total, shaded, young])
	check(lit_young / young > lit_floor / total + 0.15 and shaded < young * 0.2, "young pines grow in the light (%.2f open sky over them, %.2f over the floor; %d of %d in shade)" % [lit_young / young, lit_floor / total, shaded, young])


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
				if br.root.distance_to(br.tip) > 1.4 + t.radius:
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


## A bird brushes through a young pine's twigs: a line through its branches, clear of its stem, is open to
## the planner (left and right of the stem).
func _young_pines(a: ArenaLayout) -> void:
	var n := 0
	var blocked := 0
	for t in a.trees:
		if t.kind != ArenaLayout.Kind.SAPLING or t.branches.size() < 4:
			continue
		n += 1
		var y: float = t.height * 0.4
		for s in [-1.0, 1.0]:
			var off := Vector3(s * (t.radius + 0.15), 0.0, 0.0)
			var p0 := Vector3(t.base.x, y, t.base.y) + off + Vector3(0, 0, -2.0)
			var p1 := Vector3(t.base.x, y, t.base.y) + off + Vector3(0, 0, 2.0)
			if not a.segment_clear(p0, p1, 0.05):
				blocked += 1
	check(n > 50, "young pines (%d)" % n)
	check(blocked < n * 0.1, "birds brush through young pines' twigs (%d of %d paths blocked)" % [blocked, n * 2])


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
		# Every species can plan its final swoop onto the rail (a base it can't land on, it can't rearm on).
		for id in ["crow", "sparrow", "hawk", "falcon", "owl"]:
			var prof := BirdProfile.by_id(id)
			check(FlightPlanner.new(a, AIPilot.plan_clearance(prof)).swoop_clear(p, prof), "outpost %d (wood %d): a %s can swoop onto the rail" % [o.id, a.seed, id])
		# The AI sees the deck: a line straight through it is not clear.
		check(not a.segment_clear(o.centre - side * o.width + Vector3.DOWN * 0.03, o.centre + side * o.width + Vector3.DOWN * 0.03, 0.05), "outpost %d: the deck blocks a path through it" % o.id)
