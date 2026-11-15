extends TestCase
## The pine wood (Pinewood), as grown: the same seed grows the same wood; pines stand clear below their crowns
## but for short dead stubs, their limbs and needles up in the crown; the oaks -- one in the clearing -- carry
## long limbs to perch on (sloping no more than 25 deg: they needn't be level); every outpost is bolted to its trunk with a landing rail along its
## outer edge that is a perch, facing open air (wood and leaves clear for several metres out), left and right
## of the rail alike, with a way in every bird's planner takes (the final swoop onto the rail, the outposts being the
## bases birds rearm on); the AI's clearance queries see the decks; and the crowns leave sightlines. The stand has
## structure: clumps and open ground, a clearing and a glade, and the young pines out in the light. Every limb's
## perch lies on the limb as drawn (its top surface, thick oak limbs and thin pine ones alike: not inside the wood
## near the trunk, not above it toward the tip). An oak forks in two or three stems, its other limbs off the bole
## spread up it, and no outpost's deck, hangar or the room over it has its tree's limbs in it.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var a := Pinewood.grow(7)
	var b := Pinewood.grow(7)
	eq(a.trees.size(), b.trees.size(), "same seed, same trees")
	eq(a.perches.size(), b.perches.size(), "same seed, same perches")
	check(a.outposts.size() > 0 and b.outposts.size() == a.outposts.size() and (a.outposts[0].centre as Vector3).is_equal_approx(b.outposts[0].centre), "same seed, same outposts")
	_pines(a)
	_oaks(a)
	_outposts(a)
	for other in [3, 11, 21, 5]:   # (outposts face whatever open air a layout leaves: try several)
		_outposts(Pinewood.grow(other))
	_outpost_shuns_leaves()
	_outpost_dodges_limbs()
	_young_pines(a)
	_perches_on_the_wood(a)
	_structure(a)
	_sightlines(a)
	finish()


## Each limb perch's grip line, sampled along it, lies on its tree's drawn limbs' top: its height above the nearest
## drawn axis equals the drawn radius there, within 2 cm.
func _perches_on_the_wood(a: ArenaLayout) -> void:
	var rails := {}
	for o in a.outposts:
		rails[o.rail_perch_id] = true
	var worst := {"oak_limb": 0.0, "limb": 0.0}
	var where := {}
	var n := 0
	for p in a.perches:
		if p.kind != Perch.Kind.BRANCH or rails.has(p.id) or p.tree_id < 0:
			continue
		var t: ArenaLayout.TreeData = a.trees[p.tree_id]
		# Its own limb: the drawn limb whose axis passes nearest the perch's axis (under its middle) -- not a twig
		# that happens to pass close by.
		var own: Array = []
		var own_d := INF
		var mid_axis: Vector3 = p.position - Vector3.UP * p.thickness
		for lb in t.limbs:
			var pts: PackedVector3Array = lb[0]
			for i in pts.size() - 1:
				var d := mid_axis.distance_to(Geometry3D.get_closest_point_to_segment(mid_axis, pts[i], pts[i + 1]))
				if d < own_d:
					own_d = d
					own = lb
		for k in 5:
			var g: Vector3 = p.a.lerp(p.b, k / 4.0)
			var best := INF
			var off := 0.0
			var key := ""
			for lb in [own]:
				var pts: PackedVector3Array = lb[0]
				var radii: PackedFloat32Array = lb[1]
				for i in pts.size() - 1:
					var q := Geometry3D.get_closest_point_to_segment(g, pts[i], pts[i + 1])
					var d := g.distance_to(q)
					if d < best:
						var u := q.distance_to(pts[i]) / maxf(pts[i].distance_to(pts[i + 1]), 1e-5)
						best = d
						off = d - lerpf(radii[i], radii[i + 1], u)
						key = lb[2]
			if worst.has(key):
				n += 1
				if absf(off) > absf(worst[key]):
					worst[key] = off
					where[key] = "perch %d" % p.id
	check(n > 100, "limb perches sampled (%d)" % n)
	for key in worst:
		check(absf(worst[key]) < 0.02, "%s perches lie on the drawn wood (worst %+.3f m, %s: + above it, - inside)" % [key, worst[key], where.get(key, "-")])


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
	print("SIGHTLINES share of level looks reaching 40 m: %s" % ", ".join(hs.map(func(h): return "%.0f m %.0f%%" % [h, float(r[h][2]) * 100.0])))
	for h in hs:
		check(float(r[h][2]) >= 0.33, "at %.0f m, a third of looks reach 40 m (%.0f%%)" % [h, float(r[h][2]) * 100.0])
	check(float(r[12.0][2]) >= 0.75, "under the crowns most looks reach 40 m (%.0f%%)" % (float(r[12.0][2]) * 100.0))


func _pines(a: ArenaLayout) -> void:
	var n := 0
	var low_live := 0
	var long_stubs := 0
	var crown_ok := 0
	var forms := {"": [], "pole": [], "veteran": []}   # (each pine's [height, trunk radius, crown reach, thickest limb])
	for t in a.trees:
		if t.kind != ArenaLayout.Kind.PINE:
			continue
		n += 1
		var reach := 0.0
		var thick := 0.0
		for lb in t.limbs:
			if lb[2] != "limb":
				continue
			thick = maxf(thick, float(lb[1][0]))
			for q in lb[0]:
				reach = maxf(reach, Vector2(q.x, q.z).distance_to(t.base))
		forms[t.form].append([t.height, t.radius, reach, thick])
		var limbs_up := 0
		for br in t.branches:
			if br.dead:
				if br.root.distance_to(br.tip) > 1.4 + t.radius:
					long_stubs += 1
			elif br.root.y < t.crown_base - 0.01:
				low_live += 1
			else:
				limbs_up += 1
		var cb: Vector2 = {"": Vector2(0.55, 0.75), "pole": Vector2(0.4, 0.6), "veteran": Vector2(0.38, 0.52)}[t.form]
		if t.crown_base > t.height * cb.x and t.crown_base < t.height * cb.y and limbs_up >= (4 if t.form == "veteran" else 6):
			crown_ok += 1
		for f in t.foliage:
			if (f[0] as Vector3).y < t.crown_base - 0.5:
				low_live += 1
	check(n > 150, "a stand of pines (%d)" % n)
	eq(low_live, 0, "no live limb or needles on a pine below its crown")
	eq(long_stubs, 0, "the dead stubs are short")
	eq(crown_ok, n, "every pine's crown is up top (a pole's and a veteran's lower), with its whorls of limbs")
	# Mixed ages: pole-stage pines fill the heights between the saplings and the mature stand, their crowns
	# narrow and their trunks slim; a few veterans, shorter than the mature pines, thicker, their crowns broader
	# on heavier limbs. (Measured from the trees as grown: their drawn limbs.)
	var med := func(rows: Array, i: int) -> float:
		var v := []
		for r in rows:
			v.append(r[i])
		v.sort()
		return v[v.size() / 2] if v.size() > 0 else NAN
	var mid := 0
	for f in forms:
		for r in forms[f]:
			mid += int(r[0] > 8.0 and r[0] < 18.0)
	print("AGES mature %d (height %.1f, crown reach %.1f m), pole %d (%.1f, %.1f m), veteran %d (%.1f, %.1f m, trunk r %.2f, limbs r %.3f against %.3f)" % [forms[""].size(), med.call(forms[""], 0), med.call(forms[""], 2), forms.pole.size(), med.call(forms.pole, 0), med.call(forms.pole, 2), forms.veteran.size(), med.call(forms.veteran, 0), med.call(forms.veteran, 2), med.call(forms.veteran, 1), med.call(forms.veteran, 3), med.call(forms[""], 3)])
	check(mid >= 30, "pole-stage pines fill the middle heights (%d pines 8-18 m)" % mid)
	check(forms.veteran.size() >= 4, "a few veterans (%d)" % forms.veteran.size())
	check(med.call(forms.pole, 2) < med.call(forms[""], 2) * 0.6 and med.call(forms.pole, 1) < 0.2, "a pole's crown is narrow (reach %.1f m against %.1f) and its trunk slim" % [med.call(forms.pole, 2), med.call(forms[""], 2)])
	check(med.call(forms.veteran, 2) > med.call(forms[""], 2) * 1.35, "a veteran's crown is broad (reach %.1f m against %.1f)" % [med.call(forms.veteran, 2), med.call(forms[""], 2)])
	var mature_r := 0.0
	var mature_h := INF
	for r in forms[""]:
		mature_r = maxf(mature_r, r[1])
		mature_h = minf(mature_h, r[0])
	var stout := 0
	for r in forms.veteran:
		stout += int(r[1] > mature_r and r[0] < mature_h and r[3] > med.call(forms[""], 3) * 1.5)
	eq(stout, forms.veteran.size(), "every veteran is thicker and shorter than any mature pine, on heavier limbs")
	for o in a.outposts:
		check(a.trees[o.tree_id].form == "", "outpost %d is on a mature pine or an oak, not a pole or a veteran" % o.id)


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
			if br.perch_id >= 0 and d.length() > 3.0 and absf(rise) < 25.0:
				long_level += 1
		check(long_level >= 8, "oak %d carries long limbs to perch on (%d)" % [t.id, long_level])
		# Its bole ends over the fork: up its axis through the crown there's air between the limbs, no stem.
		var open := 0
		var n := 12
		for k in n:
			var y := lerpf(t.crown_base + 3.0, t.height * 0.9, k / float(n - 1))
			open += int(a.obstacle_distance(Vector3(t.base.x, ArenaLayout.GROUND_Y + y, t.base.y)) > 0.0)
		check(open >= n / 2, "oak %d: no stem up through its crown (%d of %d points up its axis in the air)" % [t.id, open, n])
		# Its fork, as drawn: of the limbs leaving the bole (starting on its axis), two or three leave from the fork up
		# (its stems), no more than three leave any metre of it (not eight from one spot), and they're spread up it.
		var off_bole: Array[float] = []
		for l in t.limbs:
			var p0: Vector3 = (l[0] as PackedVector3Array)[0]
			if Vector2(p0.x - t.base.x, p0.z - t.base.y).length() < 0.05:
				off_bole.append(p0.y)
		off_bole.sort()
		var stems := off_bole.filter(func(y): return y >= t.crown_base - 0.01).size()
		check(stems >= 2 and stems <= 3, "oak %d forks in two or three stems (%d limbs leave from its fork up)" % [t.id, stems])
		var crowded := 0
		for y0 in off_bole:
			crowded = maxi(crowded, off_bole.filter(func(y): return y >= y0 and y < y0 + 1.0).size())
		check(crowded <= 3, "oak %d: no more than three limbs leave any metre of its bole (%d)" % [t.id, crowded])
		check(off_bole.size() >= 4 and off_bole[-1] - off_bole[0] >= 1.5, "oak %d: its limbs off the bole are spread up it (%d, over %.1f m)" % [t.id, off_bole.size(), off_bole[-1] - off_bole[0] if off_bole.size() > 0 else 0.0])
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


## An outpost turns away from leaves in front of its rail, even a small mass in front of one end only. (Today's trees
## carry no leaves at deck height, so the wood alone can't show it: this oak's outpost is built again with a leaf
## mass put in front of one end of its rail, beside the line out from the rail's middle and missing it.) Both ways:
## built again without the leaves, it faces the same way.
func _outpost_shuns_leaves() -> void:
	var a := Pinewood.grow(7)
	var o: ArenaLayout.OutpostData = null
	for oo in a.outposts:
		if a.trees[oo.tree_id].kind == ArenaLayout.Kind.BROADLEAF:
			o = oo
			break
	check(o != null, "an oak with an outpost")
	if o == null:
		return
	var t: ArenaLayout.TreeData = a.trees[o.tree_id]
	var d0: Vector3 = o.out
	var y0: float = o.centre.y
	var rebuilt := func(leaves: bool) -> ArenaLayout.OutpostData:
		a.outposts.erase(o)
		if leaves:
			var side := d0.cross(Vector3.UP).normalized()
			var from := Vector3(t.base.x, y0 + 0.3, t.base.y) + d0 * (t.radius + 1.4)
			t.foliage.append([from + d0 * 3.5 + side * 1.0, Vector3(0.3, 0.4, 0.3)])
		var rng := RandomNumberGenerator.new()
		check(Pinewood._outpost(a, t, rng), "the oak's outpost built again (leaves %s)" % leaves)
		var n: ArenaLayout.OutpostData = a.outposts.pop_back()
		a.outposts.append(o)
		if leaves:
			t.foliage.pop_back()
		return n
	var same: ArenaLayout.OutpostData = rebuilt.call(false)
	check(same.out.dot(d0) > 0.99 and absf(same.centre.y - y0) < 0.01, "built again without leaves, the outpost faces the same way")
	var moved: ArenaLayout.OutpostData = rebuilt.call(true)
	check(moved.out.dot(d0) < 0.99 or absf(moved.centre.y - y0) > 0.01, "with leaves in front of one end of its rail, it faces elsewhere")


## An outpost rebuilt with a limb laid through where its deck is moves to where no limb is; without the limb it
## comes back where it was (both ways: it shuns wood in its own room, and only that).
func _outpost_dodges_limbs() -> void:
	var a := Pinewood.grow(7)
	var o: ArenaLayout.OutpostData = null
	for oo in a.outposts:
		if a.trees[oo.tree_id].kind == ArenaLayout.Kind.BROADLEAF:
			o = oo
			break
	check(o != null, "an oak with an outpost")
	if o == null:
		return
	var t: ArenaLayout.TreeData = a.trees[o.tree_id]
	var side: Vector3 = o.out.cross(Vector3.UP).normalized()
	# A limb across the deck's middle, a little over it, out from the trunk along the rail's line.
	var across := PackedVector3Array([o.centre + Vector3.UP * 0.25 - side * 1.5, o.centre + Vector3.UP * 0.25 + side * 1.5])
	var rebuilt := func(limb: bool) -> ArenaLayout.OutpostData:
		a.outposts.erase(o)
		if limb:
			t.limbs.append([across, PackedFloat32Array([0.12, 0.12]), "oak_limb"])
		var rng := RandomNumberGenerator.new()
		check(Pinewood._outpost(a, t, rng), "the oak's outpost built again (limb %s)" % limb)
		var n: ArenaLayout.OutpostData = a.outposts.pop_back()
		var cut := _limbs_in_outpost(t, n)
		check(cut.x == 0.0, "rebuilt (limb %s), no limb in its room (%.2f m)" % [limb, cut.x])
		if limb:
			t.limbs.pop_back()
		a.outposts.append(o)
		return n
	var same: ArenaLayout.OutpostData = rebuilt.call(false)
	check(same.out.dot(o.out) > 0.99 and absf(same.centre.y - o.centre.y) < 0.01, "built again with no limb laid through it, the outpost is where it was")
	var moved: ArenaLayout.OutpostData = rebuilt.call(true)
	check(moved.out.dot(o.out) < 0.99 or absf(moved.centre.y - o.centre.y) > 0.01, "with a limb through its deck, it moves")


## How much of `t`'s drawn limbs (m of axis, and the deepest, m) lies in outpost `o`'s deck (and 0.3 m under its
## top), its hangar or the 0.6 m over the deck -- the wood outside the bole only (inside, it's hidden in the trunk), and
## past the deck's inner 0.25 m (bolted against the trunk and the feet of an oak's stems: what it's fixed to).
func _limbs_in_outpost(t: ArenaLayout.TreeData, o: ArenaLayout.OutpostData) -> Vector2:
	var side: Vector3 = o.out.cross(Vector3.UP).normalized()
	var mid: Vector3 = o.centre + Vector3.UP * 0.15 + o.out * 0.125
	var half := Vector3(o.width * 0.5, 0.45, (o.depth - 0.25) * 0.5)
	var axis := Vector2(t.base.x, t.base.y)
	var inside := 0.0
	var deepest := 0.0
	for l in t.limbs:
		var pts: PackedVector3Array = l[0]
		var radii: PackedFloat32Array = l[1]
		for i in pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			var n := maxi(1, ceili(seg / 0.05))
			for k in n:
				var u := (k + 0.5) / n
				var q := pts[i].lerp(pts[i + 1], u)
				var r := lerpf(radii[i], radii[i + 1], u)
				if Vector2(q.x, q.z).distance_to(axis) + r < Pinewood._bole_r(t, q.y):
					continue   # (inside the bole as drawn: hidden)
				var dq := q - mid
				var e := Vector3(absf(dq.dot(side)), absf(dq.y), absf(dq.dot(o.out))) - half
				var out := Vector3(maxf(e.x, 0.0), maxf(e.y, 0.0), maxf(e.z, 0.0)).length() + minf(maxf(e.x, maxf(e.y, e.z)), 0.0)
				if out < r - 0.01:
					inside += seg / n
					deepest = maxf(deepest, r - out)
	return Vector2(inside, deepest)


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
		var cut := _limbs_in_outpost(t, o)
		check(cut.x == 0.0, "outpost %d: no limb of its tree in its deck, hangar or the room over it (%.2f m of limb, %.2f m deep)" % [o.id, cut.x, cut.y])
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
