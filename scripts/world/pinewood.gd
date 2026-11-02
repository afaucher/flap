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
## How full the crowns are, 0..1: 1 a dense pine crown (whorls of pads at each limb's end and middle), lower
## airier (fewer whorls, pads only at the tips, smaller, some limbs bare) -- the crown layer's sightlines.
## 0.5: in the crown band (about 22 m) almost half of level looks reach 40 m, against a fifth at 1 (probe_sightlines).
static var crown_density := 0.5
## Whether the dead stubs on the clear trunks are perches. Off: short broken snags read as wood, long level
## perch sticks read as pegs (and switching them off didn't change how often the AI bumps trunks).
static var STUB_PERCHES := false
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
		_grow_sapling(a, t, rng)
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
	# Dead stubs on the clear trunk, where old limbs broke off: few or none on some trees, short, drooping,
	# tapering to a snapped end, scattered rather than at regular heights. (Not perches: as long, level perch
	# sticks they read as pegs.)
	for i in rng.randi_range(0, 4):
		var y := t.height * rng.randf_range(0.2, 0.58)
		var ang := rng.randf() * TAU
		var d := Vector3(sin(ang), 0.0, cos(ang))
		var r := _r_at(t, y)
		var root := c + Vector3.UP * y
		var reach := r + rng.randf_range(0.12, 0.55) * (2.0 if rng.randf() < 0.15 else 1.0)
		var sr := rng.randf_range(0.025, 0.045)
		var droop := rng.randf_range(-0.35, 0.05)
		var tip := root + d * reach + Vector3.UP * droop * (reach - r)
		_branch(a, t, root, tip, sr, STUB_PERCHES, true)
		var spts := PackedVector3Array()
		var srad := PackedFloat32Array()
		for si in 6:
			var u := si / 5.0
			var x := reach * u
			spts.append(root + d * x + Vector3.UP * droop * maxf(x - r, 0.0) * (0.6 + 0.4 * u))
			srad.append(sr * lerpf(1.0, 0.25, pow(u, 1.5)) * (1.0 + 0.9 * exp(-maxf(x - r, 0.0) / (2.0 * sr))))
		t.limbs.append([spts, srad, "stub"])
	# The crown of an old Scots pine: irregular and flat-topped, not a cone -- a few whorls of strongly upswept
	# limbs, the longest high up (an umbrella), each ending in an irregular tuft of needles (a clump of pads,
	# some off to the side, sizes varying), with a tuft part-way along the longer limbs.
	var dens := clampf(crown_density, 0.0, 1.0)
	var whorls := rng.randi_range(4, 6) if dens >= 0.75 else rng.randi_range(3, 4)
	var ang0 := rng.randf() * TAU
	for w in whorls:
		var f := (w + rng.randf_range(0.0, 0.5)) / float(whorls)
		var y := lerpf(t.crown_base, t.height - 1.6, f)
		var reach := lerpf(1.7, 3.1, sin(PI * clampf(f * 0.85 + 0.15, 0.0, 1.0))) * rng.randf_range(0.75, 1.2)
		var n := rng.randi_range(2, 4)
		for k in n:
			if rng.randf() < 0.12:
				continue   # (a limb lost: whorls are rarely complete on an old pine)
			var ang := ang0 + TAU * k / n + rng.randf_range(-0.6, 0.6) + w * 1.3
			var d := Vector3(sin(ang), 0.0, cos(ang))
			var root := c + Vector3.UP * maxf(y + rng.randf_range(-0.25, 0.25), t.crown_base)
			var rise := lerpf(0.35, 0.7, f) * rng.randf_range(0.8, 1.25)
			var rt := _r_at(t, y)
			# Up steeply from the trunk, a long straight upswept middle (the perch), the tip turning up and aside.
			var lim := _limb(a, t, root, d, rt + reach * rng.randf_range(0.85, 1.15), Vector3(rise * 1.6 + 0.25, rise, rise + 0.6), Vector2(0.15, 0.8), lerpf(0.075, 0.04, f), rt, "limb", true, rng.randf_range(-0.35, 0.35))
			var tip: Vector3 = lim.tip
			var s := lerpf(0.75, 1.0, dens) * rng.randf_range(0.8, 1.25)
			var pad := Vector3(1.15, 0.6, 1.15) * s
			t.foliage.append([tip + Vector3.UP * 0.2, pad])
			var side := d.cross(Vector3.UP)
			for q in rng.randi_range(2, 3):
				var off := side * rng.randf_range(-0.55, 0.55) - d * rng.randf_range(0.1, 0.5) + Vector3.UP * rng.randf_range(-0.05, 0.25)
				t.foliage.append([tip + off, pad * rng.randf_range(0.6, 0.9)])
			if reach > 2.3 and rng.randf() < lerpf(0.35, 0.8, dens):
				t.foliage.append([(lim.at as Callable).call((rt + reach) * 0.62) + Vector3.UP * 0.25 + side * rng.randf_range(-0.3, 0.3), pad * 0.7])
	# The leader's tuft and a treetop perch on the broken-off top.
	t.foliage.append([c + Vector3.UP * (t.height - 0.4), Vector3(1.0, 1.2, 1.0)])
	a._add_perch(Perch.treetop(a.perches.size(), t.top() + Vector3.UP * 0.05, maxf(0.05, _r_at(t, t.height) - 0.02), -c, t.id))


## A limb drawn as a smooth curve: out along horizontal `d` for `length` m (from `root`, at the trunk's axis),
## its rise per metre changing smoothly from `slopes.x` at the trunk to `slopes.y` along the middle -- the
## stretch from `span.x` to `span.y` of its length, exactly straight, its perch -- to `slopes.z` at the tip, the
## tip curling `curl` m sideways; radius `r0` tapering to `taper` of it, with a collar where it leaves the
## trunk (radius `trunk_r` there). Solid as five chords (BranchData), the middle one the perch (if `perch`);
## drawn as the curve (`key`: its material). Returns {pts, mid: BranchData, tip}.
static func _limb(a: ArenaLayout, t: ArenaLayout.TreeData, root: Vector3, d: Vector3, length: float, slopes: Vector3, span: Vector2, r0: float, trunk_r: float, key: String, perch := true, curl := 0.0, taper := 0.35, solid := true) -> Dictionary:
	var side := d.cross(Vector3.UP).normalized()
	var xb := span.x * length
	var xt := span.y * length
	var yb := (slopes.x + slopes.y) * 0.5 * xb
	var yt := yb + slopes.y * (xt - xb)
	var at := func(x: float) -> Vector3:
		var y := 0.0
		var g := 0.0
		if x < xb:
			y = slopes.x * x + (slopes.y - slopes.x) * x * x / (2.0 * xb)
		elif x <= xt:
			y = yb + slopes.y * (x - xb)
		else:
			var u := x - xt
			y = yt + slopes.y * u + (slopes.z - slopes.y) * u * u / (2.0 * (length - xt))
			g = curl * pow(u / (length - xt), 2.0)
		return root + d * x + Vector3.UP * y + side * g
	var rad := func(x: float, collar: bool) -> float:
		var r := r0 * lerpf(1.0, taper, x / length)
		if collar:
			r *= 1.0 + 0.75 * exp(-maxf(x - trunk_r, 0.0) / (2.2 * r0))
		return r
	var xs := PackedFloat32Array()
	for i in 6:
		xs.append(xb * i / 6.0)
	for i in 4:
		xs.append(lerpf(xb, xt, i / 4.0))
	for i in 7:
		xs.append(lerpf(xt, length, i / 6.0))
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for x in xs:
		pts.append(at.call(x))
		radii.append(rad.call(x, true))
	t.limbs.append([pts, radii, key])
	var chords := [[0.0, xb * 0.5], [xb * 0.5, xb], [xb, xt], [xt, (xt + length) * 0.5], [(xt + length) * 0.5, length]]
	var mid: ArenaLayout.BranchData = null
	for ci in chords.size():
		var x0: float = chords[ci][0]
		var x1: float = chords[ci][1]
		var br := _branch(a, t, at.call(x0), at.call(x1), (rad.call(x0, false) + rad.call(x1, false)) * 0.5, perch and ci == 2)
		br.solid = solid
		if ci == 2:
			mid = br
	return {"pts": pts, "mid": mid, "tip": pts[pts.size() - 1], "at": at}


## A thin drawn-only twig (no solid, no perch): a gentle arc from `root` along `d`, `length` m, rising `rise` per
## metre and curling up (`up`) or drooping (negative) at the end.
static func _twig(t: ArenaLayout.TreeData, root: Vector3, d: Vector3, length: float, rise: float, up: float, r0: float, key: String, rng: RandomNumberGenerator) -> PackedVector3Array:
	var side := d.cross(Vector3.UP).normalized()
	var wob := rng.randf_range(-0.12, 0.12) * length
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 7:
		var u := i / 6.0
		pts.append(root + d * length * u + Vector3.UP * (rise * length * u + up * length * u * u) + side * wob * u * u)
		radii.append(r0 * lerpf(1.0, 0.3, u) * (1.0 + 0.5 * exp(-u * 8.0)))
	t.limbs.append([pts, radii, key])
	return pts


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
			var r0 := lerpf(0.22, 0.14, li / 2.0)
			var total := t.radius + length
			# Rising out of the trunk, a long nearly level run (the perch), the end lifting toward the light.
			var lim := _limb(a, t, root, d, total, Vector3(0.55, rng.randf_range(-0.04, 0.05), rng.randf_range(0.35, 0.6)), Vector2(0.1, 0.86), r0, t.radius, "oak_limb", true, rng.randf_range(-0.6, 0.6), 0.3)
			var at: Callable = lim.at
			# Side twigs off its outer half (drawn only, inside the leaves).
			for q in rng.randi_range(2, 4):
				var x := total * rng.randf_range(0.45, 0.9)
				var sd := d.rotated(Vector3.UP, (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.6, 1.2))
				_twig(t, at.call(x), sd, rng.randf_range(0.9, 2.0), rng.randf_range(0.15, 0.45), rng.randf_range(0.0, 0.3), r0 * 0.28, "oak_limb", rng)
			# Leaves over the limb's outer half and its tip.
			t.foliage.append([at.call(total * 0.7) + Vector3.UP * 1.0, Vector3(2.4, 1.3, 2.4)])
			t.foliage.append([(lim.tip as Vector3) + Vector3.UP * 0.9, Vector3(2.0, 1.2, 2.0)])
	# The crown over the top.
	var top := c + Vector3.UP * t.height
	t.foliage.append([top + Vector3.UP * 0.5, Vector3(5.0, 3.0, 5.0)])
	for k in 5:
		var ang := ang0 + TAU * k / 5.0
		t.foliage.append([top + Vector3(sin(ang), -0.25, cos(ang)) * 5.0, Vector3(3.2, 2.2, 3.2)])
	a.max_tree_reach = maxf(a.max_tree_reach, longest - 4.0)


## A young Scots pine: a whorl of branches a year (~0.45 m apart) almost to the ground, each a little longer than
## the one above (a cone), angled up, a tuft of needles at its end and one part-way along the longer ones; the
## leader's tuft on top. Its twigs are too thin to perch on, and birds brush through them (drawn, not solid).
static func _grow_sapling(a: ArenaLayout, t: ArenaLayout.TreeData, rng: RandomNumberGenerator) -> void:
	var c := Vector3(t.base.x, 0.0, t.base.y)
	t.crown_base = t.height * rng.randf_range(0.04, 0.16)
	var whorls := clampi(int((t.height - t.crown_base) / 0.45), 3, 12)
	var ang0 := rng.randf() * TAU
	for w in whorls:
		var f := (w + rng.randf_range(0.0, 0.3)) / float(whorls)
		var y := lerpf(t.crown_base, t.height - 0.4, f) + rng.randf_range(-0.06, 0.06)
		var full := (lerpf(0.36, 0.07, f) * t.height + 0.12)
		var n := rng.randi_range(3, 6)
		var dead := f < 0.22 and rng.randf() < 0.7   # (the lowest whorls die back in the shade: bare and grey)
		for k in n:
			if rng.randf() < 0.15:
				continue
			var ang := ang0 + TAU * k / n + rng.randf_range(-0.6, 0.6) + w * 0.9
			var d := Vector3(sin(ang), 0.0, cos(ang))
			var root := c + Vector3.UP * y
			var reach := full * rng.randf_range(0.6, 1.2) * (0.7 if dead else 1.0)
			var rise := rng.randf_range(0.15, 0.5)
			var tip := root + d * reach + Vector3.UP * reach * rise
			var br := _branch(a, t, root, tip, lerpf(0.022, 0.009, f), false)
			br.solid = false   # (twigs: a bird brushes through them, so does its planner)
			var pts := _twig(t, root, d, reach, rise, -0.25 if dead else rng.randf_range(0.05, 0.3), lerpf(0.02, 0.008, f), "stub" if dead else "twig", rng)
			if dead:
				continue
			var rp := (0.2 + 0.24 * reach) * rng.randf_range(0.85, 1.15)
			t.foliage.append([pts[pts.size() - 1] + Vector3.UP * 0.04, Vector3(rp, rp * 0.65, rp)])
			if reach > 0.3:
				t.foliage.append([pts[3] + Vector3.UP * 0.05, Vector3(rp, rp * 0.65, rp) * 0.8])
			if reach > 0.7:
				t.foliage.append([pts[5] + Vector3.UP * 0.05, Vector3(rp, rp * 0.65, rp) * 0.7])
	t.foliage.append([c + Vector3.UP * (t.height - 0.15), Vector3(0.16, 0.32, 0.16)])


## (the greybox saplings' stacked cones; unused since the young pines grow whorls)
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
			var across := d.cross(Vector3.UP).normalized() * 0.6   # (both ends of the rail, as well as its middle)
			while run < 30.0 and a.segment_clear(from, from + d * (run + 2.0), 0.6, -1) and a.segment_clear(from + across, from + across + d * (run + 2.0), 0.5, -1) and a.segment_clear(from - across, from - across + d * (run + 2.0), 0.5, -1) and _leaf_free(a, from + d * (run + 2.0), 0.6) and _leaf_free(a, from + d * (run + 1.0), 0.6) and _leaf_free(a, from + across + d * (run + 1.5), 0.4) and _leaf_free(a, from - across + d * (run + 1.5), 0.4):
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


## How far one can see from `from` along `dir` (unit) before wood -- or, with `leaves`, foliage -- blocks the
## view, up to `max_d` m, stepping `step` m (for sightline measures: Pinewood.sightlines).
static func sight_distance(a: ArenaLayout, from: Vector3, dir: Vector3, max_d: float, leaves: bool, step := 0.75) -> float:
	var d := 0.0
	while d < max_d:
		var p := from + dir * d
		if p.y < ArenaLayout.GROUND_Y or a.obstacle_distance(p, 3.0) < 0.0:
			return d
		if leaves and not _leaf_free(a, p, 0.0):
			return d
		d += step
	return max_d


## Sightlines by height: for each height, `n` points scattered over the wood looking level in random
## directions; returns {height: [median, 25th percentile, share reaching `far` m]}.
static func sightlines(a: ArenaLayout, heights: Array, n: int, far: float, leaves: bool, s := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var out := {}
	for h in heights:
		var ds: Array[float] = []
		var reach := 0
		while ds.size() < n:
			var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (a.boundary - 15.0)
			var o := Vector3(p.x, float(h), p.y)
			if a.obstacle_distance(o, 3.0) < 0.3 or (leaves and not _leaf_free(a, o, 0.2)):
				continue
			var ang := rng.randf() * TAU
			var dd := sight_distance(a, o, Vector3(sin(ang), 0.0, cos(ang)), far, leaves)
			ds.append(dd)
			reach += int(dd >= far)
		ds.sort()
		out[h] = [ds[n / 2], ds[n / 4], float(reach) / n]
	return out
