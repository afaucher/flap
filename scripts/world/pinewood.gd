class_name Pinewood
extends RefCounted
## The pine wood (docs/design/concept_briefs.html, round four's outpost): an ArenaLayout grown like an open
## stand of old Scots pines, for greyboxing the setting.
##   PINES      tall (24-32 m), straight, widely spaced; clear trunks up to ~2/3 of their height, a few dead
##              stubs below (short perches), the crown at the top: whorls of upswept limbs (perches) with pads of
##              needles at their ends (foliage: drawn, not solid).
##   OAKS       a few old broadleaf "perch trees" standing in glades: a stout trunk, long level limbs at three
##              heights (long perches), a broad canopy over them. Most perching off the outposts is here.
##   SAPLINGS   young pines on the floor: a slalom under ~6 m.
##   OUTPOSTS   timber decks bolted to trunks between the stubs and the crown (and to the oaks between their
##              limbs), facing open air: the outer edge is a rounded landing rail -- the perch -- with a nest-box
##              hangar and crates on the deck. Supplied from the air (no ladders, no hoists).
## The clearing in the middle has the biggest oak; the AI plans through it with the same queries as ever.

const PINE := {"count": 260, "h": Vector2(24.0, 32.0), "r": Vector2(0.22, 0.34), "spacing": 9.0, "clear": Vector2(0.6, 0.72)}
const OAK := {"count": 4, "h": Vector2(17.0, 22.0), "r": Vector2(0.65, 0.9), "limb": Vector2(6.0, 9.5), "glade": 11.0}
const SAPLING := {"count": 140, "h": Vector2(1.6, 6.0), "r": Vector2(0.03, 0.08), "spacing": 3.2}
const OUTPOSTS := 9
const GRIP_TRUNK_GAP := ArenaLayout.GRIP_TRUNK_GAP
const GRIP_TIP_GAP := ArenaLayout.GRIP_TIP_GAP


static func generate(s: int) -> ArenaLayout:
	var a := ArenaLayout.new()
	a.seed = s
	a.style = "pinewood"
	a.avenues = []
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var e := a.half_extent
	# Oaks first: the biggest in the clearing, the others in glades round it.
	var oak_sites: Array[Vector2] = [Vector2.ZERO]
	var tries := 0
	while oak_sites.size() < OAK.count and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (a.boundary - 22.0)
		if p.length() < 34.0 or p.length() > a.boundary - 18.0:
			continue
		var ok := true
		for q in oak_sites:
			if p.distance_to(q) < 40.0:
				ok = false
		if ok:
			oak_sites.append(p)
	for i in oak_sites.size():
		var t := _tree(a, ArenaLayout.Kind.BROADLEAF, oak_sites[i], rng.randf_range(OAK.h.x, OAK.h.y) + (3.0 if i == 0 else 0.0), rng.randf_range(OAK.r.x, OAK.r.y) * (1.15 if i == 0 else 1.0))
		_grow_oak(a, t, rng, i == 0)
	# Pines, kept out of the glades and the clearing.
	tries = 0
	var placed := 0
	while placed < PINE.count and tries < PINE.count * 60:
		tries += 1
		var p := Vector2(rng.randf_range(-e + 4.0, e - 4.0), rng.randf_range(-e + 4.0, e - 4.0))
		if p.length() > a.boundary - 3.0 or not _clear_of(a, p, PINE.spacing, OAK.glade + OAK.limb.y * 0.6):
			continue
		var t := _tree(a, ArenaLayout.Kind.PINE, p, rng.randf_range(PINE.h.x, PINE.h.y), rng.randf_range(PINE.r.x, PINE.r.y))
		_grow_pine(a, t, rng)
		placed += 1
	# Saplings in the gaps.
	tries = 0
	placed = 0
	while placed < SAPLING.count and tries < SAPLING.count * 40:
		tries += 1
		var p := Vector2(rng.randf_range(-e + 4.0, e - 4.0), rng.randf_range(-e + 4.0, e - 4.0))
		if p.length() > a.boundary - 3.0 or p.length() < a.clearing_radius or not _clear_of(a, p, SAPLING.spacing, OAK.glade):
			continue
		var t := _tree(a, ArenaLayout.Kind.SAPLING, p, rng.randf_range(SAPLING.h.x, SAPLING.h.y), rng.randf_range(SAPLING.r.x, SAPLING.r.y))
		t.crown_base = t.height * rng.randf_range(0.1, 0.3)
		_cone_pads(t, t.crown_base, t.height, t.height * 0.28, rng)
		placed += 1
	_outposts(a, rng)
	return a


static func _tree(a: ArenaLayout, kind: int, p: Vector2, h: float, r: float) -> ArenaLayout.TreeData:
	var t := ArenaLayout.TreeData.new()
	t.id = a.trees.size()
	t.kind = kind
	t.tier = ArenaLayout.Tier.EMERGENT if kind == ArenaLayout.Kind.PINE else (ArenaLayout.Tier.CANOPY if kind == ArenaLayout.Kind.BROADLEAF else ArenaLayout.Tier.UNDERSTORY)
	t.base = p
	t.height = h
	t.radius = r
	a.trees.append(t)
	ArenaLayout._add_to_hash(a._tree_hash, p, t.id)
	return t


## Far enough from every tree (by its own spacing) and out of the oaks' glades.
static func _clear_of(a: ArenaLayout, p: Vector2, spacing: float, glade: float) -> bool:
	for t in a.trees:
		var need := spacing
		match t.kind:
			ArenaLayout.Kind.BROADLEAF: need = glade
			ArenaLayout.Kind.PINE: need = maxf(spacing, PINE.spacing * 0.55)
			_: need = minf(spacing, SAPLING.spacing)
		if p.distance_to(t.base) < need:
			return false
	return true


## A branch from `root` to `tip` with a perch along its top (if long enough to grip).
static func _branch(a: ArenaLayout, t: ArenaLayout.TreeData, root: Vector3, tip: Vector3, radius: float, perch := true, dead := false) -> ArenaLayout.BranchData:
	var b := ArenaLayout.BranchData.new()
	b.tree_id = t.id
	b.root = root
	b.tip = tip
	b.radius = radius
	b.dead = dead
	var length := root.distance_to(tip)
	if perch:
		var flat := Vector3(tip.x - root.x, 0.0, tip.z - root.z)
		var t0 := clampf((t.radius + GRIP_TRUNK_GAP) / length, 0.0, 0.6) if root.distance_to(Vector3(t.base.x, root.y, t.base.y)) < t.radius + 0.01 else 0.02
		var t1 := clampf(1.0 - GRIP_TIP_GAP / length, t0 + 0.1, 1.0)
		if length * (t1 - t0) > 0.15 and flat.length() > 0.1:
			var across := flat.normalized().rotated(Vector3.UP, PI * 0.5)
			var up := Vector3.UP * radius
			var pr := Perch.branch(a.perches.size(), root.lerp(tip, t0) + up, root.lerp(tip, t1) + up, across, t.id, radius)
			b.perch_id = pr.id
			a._add_perch(pr)
	t.branches.append(b)
	return b


## A Scots pine: clear below, a few dead stubs, whorls of upswept limbs in the crown with needle pads, a
## treetop perch.
static func _grow_pine(a: ArenaLayout, t: ArenaLayout.TreeData, rng: RandomNumberGenerator) -> void:
	t.crown_base = t.height * rng.randf_range(PINE.clear.x, PINE.clear.y)
	var c := Vector3(t.base.x, 0.0, t.base.y)
	# Dead stubs on the clear trunk: short, bare, roughly level.
	for i in rng.randi_range(2, 5):
		var y := t.height * rng.randf_range(0.25, 0.58)
		var ang := rng.randf() * TAU
		var d := Vector3(sin(ang), 0.0, cos(ang))
		var r := _r_at(t, y)
		var root := c + Vector3.UP * y
		var tip := root + d * (r + rng.randf_range(0.25, 0.7)) + Vector3.UP * rng.randf_range(-0.08, 0.12)
		_branch(a, t, root, tip, rng.randf_range(0.025, 0.045), true, true)
	# The crown: whorls of 3-5 limbs, longest low, upswept, a pad of needles at each limb's end and middle.
	var whorls := rng.randi_range(4, 6)
	var ang0 := rng.randf() * TAU
	for w in whorls:
		var f := (w + rng.randf_range(0.0, 0.5)) / float(whorls)
		var y := lerpf(t.crown_base, t.height - 1.2, f)
		var reach := lerpf(3.0, 1.1, f) * rng.randf_range(0.8, 1.15)
		var n := rng.randi_range(3, 5)
		for k in n:
			var ang := ang0 + TAU * k / n + rng.randf_range(-0.3, 0.3) + w * 0.9
			var d := Vector3(sin(ang), 0.0, cos(ang))
			var root := c + Vector3.UP * y
			var tip := root + d * (_r_at(t, y) + reach) + Vector3.UP * reach * rng.randf_range(0.15, 0.45)
			var br := _branch(a, t, root, tip, lerpf(0.07, 0.035, f), true)
			var pad := Vector3(reach * 0.45 + 0.4, 0.35 + 0.15 * reach, reach * 0.45 + 0.4)
			t.foliage.append([br.tip + Vector3.UP * 0.15, pad])
			t.foliage.append([br.root.lerp(br.tip, 0.6) + Vector3.UP * 0.25, pad * 0.8])
	# The leader's tuft and a treetop perch on the broken-off top.
	t.foliage.append([c + Vector3.UP * (t.height - 0.4), Vector3(1.0, 1.2, 1.0)])
	a._add_perch(Perch.treetop(a.perches.size(), t.top() + Vector3.UP * 0.05, maxf(0.05, _r_at(t, t.height) - 0.02), -c, t.id))


## The trunk's radius at height y (tapering to 40% at the top).
static func _r_at(t: ArenaLayout.TreeData, y: float) -> float:
	return t.radius * lerpf(1.0, 0.4, clampf(y / t.height, 0.0, 1.0))


## An old oak: long, nearly level limbs at three heights (each in two pieces: out level, then a little up at
## the tip -- two perches), a few short limbs between, and a broad canopy.
static func _grow_oak(a: ArenaLayout, t: ArenaLayout.TreeData, rng: RandomNumberGenerator, big: bool) -> void:
	var c := Vector3(t.base.x, 0.0, t.base.y)
	t.crown_base = t.height * 0.3
	var levels := [0.27, 0.45, 0.63]
	var ang0 := rng.randf() * TAU
	var longest := 0.0
	for li in levels.size():
		var y: float = t.height * float(levels[li]) + rng.randf_range(-0.6, 0.6)
		var n := 4 if li < 2 else 3
		for k in n:
			var ang := ang0 + TAU * k / n + li * 0.8 + rng.randf_range(-0.25, 0.25)
			var d := Vector3(sin(ang), 0.0, cos(ang))
			var length := rng.randf_range(OAK.limb.x, OAK.limb.y) * lerpf(1.0, 0.7, li / 2.0) * (1.15 if big else 1.0)
			longest = maxf(longest, length + t.radius)
			var root := c + Vector3.UP * y
			var mid := root + d * (t.radius + length * 0.65) + Vector3.UP * rng.randf_range(-0.25, 0.1)
			var tip := mid + d * length * 0.35 + Vector3.UP * rng.randf_range(0.3, 0.8)
			var r0 := lerpf(0.22, 0.14, li / 2.0)
			_branch(a, t, root, mid, r0, true)
			_branch(a, t, mid, tip, r0 * 0.6, true)
			# Leaves over the limb's outer half and its tip.
			t.foliage.append([mid + Vector3.UP * 1.0, Vector3(2.4, 1.3, 2.4)])
			t.foliage.append([tip + Vector3.UP * 0.9, Vector3(2.0, 1.2, 2.0)])
	# The crown over the top.
	var top := c + Vector3.UP * t.height
	t.foliage.append([top + Vector3.UP * 0.5, Vector3(5.0, 3.0, 5.0)])
	for k in 5:
		var ang := ang0 + TAU * k / 5.0
		t.foliage.append([top + Vector3(sin(ang), -0.25, cos(ang)) * 5.0, Vector3(3.2, 2.2, 3.2)])
	a.max_tree_reach = maxf(a.max_tree_reach, longest - 4.0)


## A sapling: stacked cones of needles (pads, narrowing to the top).
static func _cone_pads(t: ArenaLayout.TreeData, y0: float, y1: float, r0: float, rng: RandomNumberGenerator) -> void:
	var c := Vector3(t.base.x, 0.0, t.base.y)
	var n := maxi(2, int((y1 - y0) / 0.7))
	for i in n:
		var f := float(i) / (n - 1)
		var r := lerpf(r0, r0 * 0.25, f) * rng.randf_range(0.85, 1.1)
		t.foliage.append([c + Vector3.UP * lerpf(y0 + 0.3, y1 - 0.2, f), Vector3(r, 0.32, r)])


## Is `p` outside every tree's foliage by `margin` (m)?
static func _leaf_free(a: ArenaLayout, p: Vector3, margin: float) -> bool:
	for t in a.trees_near_segment(p, p, 6.0):
		for f in t.foliage:
			var q := (p - (f[0] as Vector3)) / ((f[1] as Vector3) + Vector3.ONE * margin)
			if q.length() < 1.0:
				return false
	return true


## Outposts: on pines between the stubs and the crown, and on the oaks between their limbs, facing the most
## open air; each a deck with a landing rail along its outer edge (the perch).
static func _outposts(a: ArenaLayout, rng: RandomNumberGenerator) -> void:
	var hosts := []
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.BROADLEAF:
			hosts.append(t)
	var pines := []
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.PINE and Vector2(t.base).length() < a.boundary - 12.0:
			pines.append(t)
	for i in range(pines.size() - 1, 0, -1):   # (shuffled with the layout's own RNG: same seed, same outposts)
		var j := rng.randi_range(0, i)
		var tmp = pines[i]
		pines[i] = pines[j]
		pines[j] = tmp
	for t in pines:
		if hosts.size() >= OUTPOSTS:
			break
		var far := true
		for h in hosts:
			if Vector2(t.base).distance_to(h.base) < 24.0:
				far = false
		if far:
			hosts.append(t)
	for t in hosts:
		_outpost(a, t, rng)


static func _outpost(a: ArenaLayout, t: ArenaLayout.TreeData, rng: RandomNumberGenerator) -> void:
	var o := ArenaLayout.OutpostData.new()
	o.id = a.outposts.size()
	o.tree_id = t.id
	var oak := t.kind == ArenaLayout.Kind.BROADLEAF
	var y := t.height * (0.36 if oak else rng.randf_range(0.48, 0.58))
	# (clear of the stubs: a deck isn't bolted over a branch)
	for it in 12:
		var near := false
		for br in t.branches:
			if absf(br.root.y - y) < 0.9 and br.dead:
				near = true
		if not near:
			break
		y += 0.6
	var c := Vector3(t.base.x, 0.0, t.base.y)
	var r := _r_at(t, y) if not oak else t.radius
	# Face the most open direction: the longest run out from the rail clear of wood and leaves, level. (On an
	# oak, try the gaps between its limb levels too.)
	var best := -1.0
	var ys: Array = [y] if not oak else [t.height * 0.36, t.height * 0.54, t.height * 0.72]
	for yy in ys:
		for k in 24:
			var ang := TAU * k / 24.0
			var d := Vector3(sin(ang), 0.0, cos(ang))
			var from := c + Vector3.UP * (float(yy) + 0.3) + d * (r + 1.4)
			var run := 0.0
			while run < 30.0 and a.segment_clear(from, from + d * (run + 2.0), 0.6, -1) and _leaf_free(a, from + d * (run + 2.0), 0.6) and _leaf_free(a, from + d * (run + 1.0), 0.6):
				run += 2.0
			if run > best:
				best = run
				o.out = d
				y = yy
	r = _r_at(t, y) if not oak else t.radius
	o.centre = c + Vector3.UP * y + o.out * (r + o.depth * 0.5 - 0.15)
	var side := o.out.cross(Vector3.UP).normalized()
	var rail := o.centre + o.out * (o.depth * 0.5 - o.rail_radius) + Vector3.UP * (o.rail_radius - o.thickness * 0.2)
	var half := o.width * 0.5 - 0.06
	var p := Perch.branch(a.perches.size(), rail - side * half + Vector3.UP * o.rail_radius, rail + side * half + Vector3.UP * o.rail_radius, o.out, t.id, o.rail_radius)
	o.rail_perch_id = p.id
	a._add_perch(p)
	a.outposts.append(o)
