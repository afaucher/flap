class_name ArenaLayout
extends RefCounted
## The arena as pure data: trees (vertical trunks with horizontal branches), perches, open lanes, and the
## geometric queries the AI plans with. ArenaBuilder turns it into meshes and collision.
## (docs/design/flight_model.md, "Arena and flight paths")
##
## Trees come in three height tiers, placed by seeded rejection sampling:
##   UNDERSTORY  many short, thin trunks (4-9 m)   -> the low layer is a dense slalom
##   CANOPY      fewer medium trunks (10-18 m)      -> the middle layer has room to turn
##   EMERGENT    a handful of tall trunks (22-34 m) -> above ~20 m it's open sky with a few pylons
## So trunk density falls with height. Open lanes carve flight paths through the lower tiers: a central
## CLEARING, two crossing AVENUES and a RING lane. Emergents may stand in the ring (they become slalom gates)
## but never in the clearing or avenues.

const GROUND_Y := 0.0
const HASH_CELL := 8.0
const GRIP_TRUNK_GAP := 0.12   ## m, the grip line starts this far out from the trunk's surface
const GRIP_TIP_GAP := 0.08     ## m, and stops this far short of the tip
const BOX_MARGIN := 1e-3       ## m, the slack in a clearance query's box test (rounding in the distance test)
const BAND := 2.0              ## m, the height bands a tree's branches are filed under for clearance queries
const HANGAR_SIZE := Vector3(0.42, 0.5, 0.44)   ## an outpost's hangar, a box on its deck (along the rail, up, out)
const HANGAR_SIDE := -1.0      ## which end of the deck it stands at (deck x): -1, on the right seen from the rail

enum Tier { UNDERSTORY, CANOPY, EMERGENT }
## What a tree is, for drawing it (the greybox arena's are all GENERIC; Pinewood grows the rest). POST: one of the
## arena's edge posts (add_posts), solid like a trunk, its top a perch -- somewhere to rest at the edge.
enum Kind { GENERIC, PINE, BROADLEAF, SAPLING, POST, ROCK }   ## (ROCK: the escarpment, standing in as its perches' "tree")
const POST_COUNT := 48
const POST_HEIGHT := 6.0     ## m
const POST_RADIUS := 0.25    ## m

const TIERS := [
	{"tier": Tier.UNDERSTORY, "count": 90, "h": Vector2(4.0, 9.0), "r": Vector2(0.12, 0.22), "spacing": 5.5, "branch_len": Vector2(0.9, 1.8)},
	{"tier": Tier.CANOPY, "count": 38, "h": Vector2(10.0, 18.0), "r": Vector2(0.25, 0.4), "spacing": 11.0, "branch_len": Vector2(1.4, 2.6)},
	{"tier": Tier.EMERGENT, "count": 9, "h": Vector2(22.0, 34.0), "r": Vector2(0.45, 0.7), "spacing": 26.0, "branch_len": Vector2(2.0, 3.4)},
]


class TreeData:
	var id := 0
	var tier := 0
	var base := Vector2.ZERO        ## x, z
	var height := 0.0
	var radius := 0.0
	var branches: Array = []        ## of BranchData
	var kind := 0                   ## Kind
	var crown_base := 0.0           ## m above the ground where the crown (foliage) starts
	var foliage: Array = []         ## visual only (birds fly through it): [centre: Vector3, radii: Vector3]
	## The limbs as drawn (Pinewood): [points: PackedVector3Array, radii: PackedFloat32Array, material key]. The
	## solid branches (BranchData) are chords along these curves; the perch stretch of a limb is exactly straight.
	var limbs: Array = []

	func top() -> Vector3:
		return Vector3(base.x, ArenaLayout.GROUND_Y + height, base.y)

	## How far any solid wood reaches from the trunk's axis (the farthest end of a solid branch, plus its radius;
	## a limb in two pieces starts its outer piece off the axis).
	var _reach := -1.0
	var _reach_n := -1              ## (branches.size() when _reach was measured)
	func reach() -> float:
		if _reach_n != branches.size():
			_reach_n = branches.size()
			_reach = radius
			var lo := Vector3(base.x, ArenaLayout.GROUND_Y - 1.0, base.y)
			for br in branches:
				if br.solid:
					for q in [br.root, br.tip]:
						_reach = maxf(_reach, q.distance_to(Geometry3D.get_closest_point_to_segment(q, lo, top())) + br.radius)
		return _reach

	## The solid branches filed under the height bands (ArenaLayout.BAND m) they reach into: band -> Array of
	## BranchData. A clearance query visits only the bands its segment spans.
	var _bands := {}
	var _bands_n := -1              ## (branches.size() when they were filed)
	func bands() -> Dictionary:
		if _bands_n != branches.size():
			_bands_n = branches.size()
			_bands = {}
			for br in branches:
				if br.solid:
					var k0 := floori((minf(br.root.y, br.tip.y) - br.radius) / ArenaLayout.BAND)
					var k1 := floori((maxf(br.root.y, br.tip.y) + br.radius) / ArenaLayout.BAND)
					for k in range(k0, k1 + 1):
						if not _bands.has(k):
							_bands[k] = []
						_bands[k].append(br)
		return _bands


class BranchData:
	var tree_id := 0
	var root := Vector3.ZERO        ## where it leaves the trunk axis
	var tip := Vector3.ZERO
	var radius := 0.06
	var perch_id := -1
	var dead := false               ## a dead stub (bare, greyer)
	var solid := true               ## false: a twig drawn but brushed through (no collision; the planner ignores it)


## An outpost: a timber deck bolted to a trunk, its outer edge a rounded landing rail (a branch perch), a
## nest-box hangar and crates on the deck, braces under it.
class OutpostData:
	var id := 0
	var tree_id := 0
	var centre := Vector3.ZERO      ## the deck's top, middle
	var out := Vector3.FORWARD      ## horizontal, from the trunk out to the rail (the approach side)
	var width := 1.6                ## m along the rail
	var depth := 1.1                ## m from the trunk to the rail
	var thickness := 0.07
	var rail_radius := 0.045
	var rail_perch_id := -1
	var lines := []                 ## deck_lines(), once asked for


var seed := 0
var half_extent := 90.0             ## the ground square is [-half_extent, half_extent] on x and z
var boundary := 85.0                ## the arena is this circle: trees inside it, birds pushed back past it
var ceiling := 60.0                 ## soft ceiling
var clearing_radius := 16.0
var avenues: Array = []             ## of [Vector2 a, Vector2 b, float half_width]
## Open ground in the wood (Pinewood): {centre: Vector2, r: float, ph: float, kind: "clearing" | "glade" | "gap"}
## -- no standing pine inside its edge (Pinewood.edge: irregular, about r out).
var openings: Array = []
## Beyond the boundary (Pinewood; Escarpment, EdgeBuilder): {at: angle round the ring, foot: m, seed} -- a cliff
## along one sector, heath round the rest. Drawn and solid, all outside the boundary; in its sector the soft wall
## stands out by the cliff (reach()), and it has perches (add_rock).
var escarpment := {}
var rock: Escarpment                ## the escarpment's shape (null: none), for the queries below
var rock_tree := -1                 ## its ROCK entry in `trees` (its perches' tree_id)
var ring_radius := 56.0
var ring_half_width := 5.0
var trees: Array = []               ## of TreeData
var outposts: Array = []            ## of OutpostData
var style := "greybox"              ## "greybox" (generate) or "pinewood" (Pinewood.generate)
var perches: Array[Perch] = []
var _perch_hash := {}               ## Vector2i -> Array[int] perch ids
var max_perch_reach := 0.0          ## m, the longest half grip line (for hashed lookups)
var max_tree_reach := 0.0           ## m, beyond 4 m: how far a limb reaches from its trunk (hashed lookups)
var _tree_hash := {}                ## Vector2i -> Array[int] tree ids


static func generate(s: int) -> ArenaLayout:
	var a := ArenaLayout.new()
	a.seed = s
	a._generate()
	a.add_posts()
	return a


## The bird lab's arena: one tree at the origin with a single long, level branch along +X at 3.5 m (its grip
## line from just clear of the trunk to just short of the tip, facing -Z: the side approaches come from)
## and a treetop disc.
static func lab() -> ArenaLayout:
	var a := ArenaLayout.new()
	a.seed = -1
	var t := TreeData.new()
	t.tier = Tier.CANOPY
	t.height = 7.0
	t.radius = 0.22
	a.trees.append(t)
	_add_to_hash(a._tree_hash, t.base, t.id)
	var b := BranchData.new()
	b.root = Vector3(0.0, 3.5, 0.0)
	b.tip = Vector3(3.4, 3.5, 0.0)
	b.radius = 0.07
	var length := b.root.distance_to(b.tip)
	var up := Vector3.UP * b.radius
	var p := Perch.branch(0, b.root.lerp(b.tip, (t.radius + GRIP_TRUNK_GAP) / length) + up, b.root.lerp(b.tip, 1.0 - GRIP_TIP_GAP / length) + up, Vector3.FORWARD, 0, b.radius)
	b.perch_id = p.id
	a._add_perch(p)
	t.branches.append(b)
	a._add_perch(Perch.treetop(1, t.top() + Vector3.UP * 0.05, t.radius * 0.75 - 0.03, Vector3.FORWARD, 0))
	return a


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var e := half_extent
	avenues = [
		[Vector2(-e, -e * 0.35), Vector2(e, e * 0.45), 5.0],
		[Vector2(-e * 0.45, e), Vector2(e * 0.25, -e), 5.0],
	]
	# Tallest first: the big trees claim their spacing, the understory fills around them.
	for ti in range(TIERS.size() - 1, -1, -1):
		var spec: Dictionary = TIERS[ti]
		var placed := 0
		var attempts := 0
		while placed < spec.count and attempts < spec.count * 60:
			attempts += 1
			var pos := Vector2(rng.randf_range(-e + 4.0, e - 4.0), rng.randf_range(-e + 4.0, e - 4.0))
			if not _site_ok(pos, ti, spec.spacing):
				continue
			var t := TreeData.new()
			t.id = trees.size()
			t.tier = spec.tier
			t.base = pos
			t.height = rng.randf_range(spec.h.x, spec.h.y)
			t.radius = rng.randf_range(spec.r.x, spec.r.y)
			trees.append(t)
			_add_to_hash(_tree_hash, pos, t.id)
			placed += 1
	for t in trees:
		_grow(t, rng)


func _site_ok(pos: Vector2, tier_index: int, spacing: float) -> bool:
	if pos.length() < clearing_radius + 3.0 or pos.length() > boundary - 4.0:
		return false
	for av in avenues:
		if _dist_to_segment_2d(pos, av[0], av[1]) < av[2] + 2.0:
			return false
	if tier_index != Tier.EMERGENT and absf(pos.length() - ring_radius) < ring_half_width + 1.5:
		return false
	for t in trees:
		var need: float = (spacing + float(TIERS[t.tier].spacing)) * 0.5
		if pos.distance_to(t.base) < need:
			return false
	return true


## Branches spiral up the trunk, each carrying a perch: the grip line along its top, from just clear of the
## trunk to just short of the tip. Every tree also has a treetop perch: a grip disc on top of the trunk.
func _grow(t: TreeData, rng: RandomNumberGenerator) -> void:
	var spec: Dictionary = TIERS[t.tier]
	var n := maxi(1, int(t.height / 4.5))
	var angle := rng.randf() * TAU
	for i in n:
		var y := lerpf(0.35, 0.88, (i + rng.randf_range(0.0, 0.6)) / float(n)) * t.height
		angle += rng.randf_range(1.6, 2.8)   # roughly a phyllotaxis spiral
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var b := BranchData.new()
		b.tree_id = t.id
		b.root = Vector3(t.base.x, y, t.base.y)
		var length := rng.randf_range(spec.branch_len.x, spec.branch_len.y) + t.radius
		b.tip = b.root + dir * length + Vector3.UP * rng.randf_range(0.0, 0.25)
		b.radius = clampf(t.radius * 0.35, 0.04, 0.12)
		# (Measured along the horizontal: the branch rises a little toward its tip.)
		var t0 := clampf((t.radius + GRIP_TRUNK_GAP) / length, 0.0, 0.6)
		var t1 := clampf(1.0 - GRIP_TIP_GAP / length, t0 + 0.1, 1.0)
		var up := Vector3.UP * b.radius
		# The default facing (spawning, the AI's approach side) is across the branch, at random to one side:
		# the drop-off falls clear of the branch and the approach never aims at the trunk.
		var across := dir.rotated(Vector3.UP, PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		var p := Perch.branch(perches.size(), b.root.lerp(b.tip, t0) + up, b.root.lerp(b.tip, t1) + up, across, t.id, b.radius)
		b.perch_id = p.id
		_add_perch(p)
		t.branches.append(b)
	# Treetop: faces the arena centre, so a bird sitting up there looks over the clearing.
	var to_center := Vector3(-t.base.x, 0.0, -t.base.y)
	var top := Perch.treetop(perches.size(), t.top() + Vector3.UP * 0.05, maxf(0.03, t.radius * 0.75 - 0.03), to_center if to_center.length() > 0.1 else Vector3.FORWARD, t.id)
	_add_perch(top)


## The edge posts: POST_COUNT round the arena just inside its boundary (the soft wall), each a solid post with a
## perch on its top facing the middle (a fallback: the AI rests there only when nothing else is in reach); none
## where a trunk stands within a metre of it, nor in an avenue.
func add_posts() -> void:
	for i in POST_COUNT:
		var ang := TAU * i / POST_COUNT
		var p := Vector2(sin(ang), cos(ang)) * (boundary - 0.5)
		var crowded := false
		for t in trees_near_segment(Vector3(p.x, 0.0, p.y), Vector3(p.x, 0.0, p.y), 2.0):
			if (t as TreeData).base.distance_to(p) < (t as TreeData).radius + POST_RADIUS + 1.0:
				crowded = true
		for av in avenues:
			if Geometry2D.get_closest_point_to_segment(p, av[0], av[1]).distance_to(p) < float(av[2]) + 1.0:
				crowded = true
		if crowded:
			continue
		var t := TreeData.new()
		t.id = trees.size()
		t.kind = Kind.POST
		t.tier = Tier.UNDERSTORY
		t.base = p
		t.height = POST_HEIGHT
		t.radius = POST_RADIUS
		t.crown_base = POST_HEIGHT
		trees.append(t)
		_add_to_hash(_tree_hash, p, t.id)
		var top := Perch.treetop(perches.size(), t.top() + Vector3.UP * 0.05, POST_RADIUS * 0.75 - 0.03, Vector3(-p.x, 0.0, -p.y).normalized(), t.id)
		top.fallback = true
		_add_perch(top)


## The escarpment (`escarpment` set): its shape for the queries, a ROCK entry in `trees` standing in as its perches'
## tree (no trunk, no branches; not in the tree hash: the queries test the rock itself, rock_clear), and its perches
## (Escarpment.perch_spots: stones on the scree, ledges, fewer the higher).
func add_rock() -> void:
	rock = Escarpment.of(self)
	if rock == null:
		return
	var t := TreeData.new()
	t.id = trees.size()
	t.kind = Kind.ROCK
	t.tier = Tier.UNDERSTORY
	t.base = Vector2(sin(rock.at), cos(rock.at)) * rock.foot
	t.height = 0.0
	t.radius = 0.0
	t.crown_base = 0.0
	trees.append(t)
	rock_tree = t.id
	for spot in rock.perch_spots():
		_add_perch(Perch.treetop(perches.size(), spot[0], Escarpment.PERCH_DISC, spot[1], t.id))


## The soft wall's radius toward `xz` (the boundary, or out by the cliff in the escarpment's sector).
func reach(xz: Vector2) -> float:
	return boundary if rock == null else rock.reach(atan2(xz.x, xz.y), boundary)


## Is `pos` at least `d` clear of the escarpment's rock? (Its height under pos and a few points d round it.)
func rock_clear(pos: Vector3, d: float) -> bool:
	if rock == null or Vector2(pos.x, pos.z).length() < rock.foot - Escarpment.SCREE - d - 0.5:
		return true
	var y := pos.y - GROUND_Y - d
	for o in [Vector2.ZERO, Vector2(d, 0.0), Vector2(-d, 0.0), Vector2(0.0, d), Vector2(0.0, -d)]:
		if y < rock.height(pos.x + o.x, pos.z + o.y):
			return false
	return true


## (Pinewood builds through these too.)
func _add_perch(p: Perch) -> void:
	perches.append(p)
	max_perch_reach = maxf(max_perch_reach, p.reach())
	_add_to_hash(_perch_hash, Vector2(p.position.x, p.position.z), p.id)


static func _cell(xz: Vector2) -> Vector2i:
	return Vector2i(floori(xz.x / HASH_CELL), floori(xz.y / HASH_CELL))


static func _add_to_hash(h: Dictionary, xz: Vector2, value: int) -> void:
	var c := _cell(xz)
	if not h.has(c):
		h[c] = []
	h[c].append(value)


static func _dist_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Queries -----------------------------------------------------------------------------------

## Perches with a grip point within `radius` of `pos`, nearest grip first.
func perches_near(pos: Vector3, radius: float) -> Array[Perch]:
	var out: Array[Perch] = []
	var r := radius + max_perch_reach   # (perches are hashed by their middle)
	var c0 := _cell(Vector2(pos.x - r, pos.z - r))
	var c1 := _cell(Vector2(pos.x + r, pos.z + r))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for pid in _perch_hash.get(Vector2i(cx, cz), []):
				var p: Perch = perches[pid]
				if p.distance_to(pos) <= radius:
					out.append(p)
	out.sort_custom(func(a: Perch, b: Perch): return a.distance_to(pos) < b.distance_to(pos))
	return out


## Trees whose trunk could be within `radius` (horizontally) of the box spanned by a and b.
func trees_near_segment(a: Vector3, b: Vector3, radius: float) -> Array:
	var out := []
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * (radius + 4.0 + max_tree_reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * (radius + 4.0 + max_tree_reach)
	var c0 := _cell(lo)
	var c1 := _cell(hi)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for tid in _tree_hash.get(Vector2i(cx, cz), []):
				out.append(trees[tid])
	return out


## Is the straight flight from a to b clear of trunks, branches and the ground by `clearance` metres?
## (`ignore_tree`: a tree to skip, e.g. the one being perched on or departed from.)
func segment_clear(a: Vector3, b: Vector3, clearance: float, ignore_tree := -1) -> bool:
	return segment_clear_among(trees_near_segment(a, b, clearance), a, b, clearance, ignore_tree)


## segment_clear against `near` (trees_near_segment of an area the segment lies in), for many checks in one
## place (the AI's predicted paths); `ignore_also`: a second tree to skip; `decks`: the outposts that could be
## near (null: all of them).
func segment_clear_among(near: Array, a: Vector3, b: Vector3, clearance: float, ignore_tree := -1, ignore_also := -1, decks: Variant = null) -> bool:
	if a.y < GROUND_Y + clearance or b.y < GROUND_Y + clearance:
		return false
	# (the rock too, unless it's the "tree" left out: coming in to, or leaving, one of its perches)
	if rock != null and ignore_tree != rock_tree and ignore_also != rock_tree and maxf(Vector2(a.x, a.z).length(), Vector2(b.x, b.z).length()) > rock.foot - Escarpment.SCREE - clearance - 0.5:
		var n := maxi(1, ceili(a.distance_to(b) / 0.25))   # (the rock, sampled along the segment: only out by it)
		for k in n + 1:
			if not rock_clear(a.lerp(b, float(k) / n), clearance):
				return false
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * clearance
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * clearance
	for t in near:
		if t.id == ignore_tree or t.id == ignore_also:
			continue
		var r: float = t.reach()   # (nothing of the tree reaches further from its axis: skip it if the box can't meet it)
		if t.base.x < lo.x - r or t.base.x > hi.x + r or t.base.y < lo.y - r or t.base.y > hi.y + r:
			continue
		if not _tree_clear(t, a, b, clearance, -1):
			return false
	for o in (outposts if decks == null else decks):
		if o.tree_id == ignore_tree or o.tree_id == ignore_also:
			continue
		var od: float = o.width + o.depth   # (the deck lies well within this of its centre)
		if o.centre.x < lo.x - od or o.centre.x > hi.x + od or o.centre.z < lo.y - od or o.centre.z > hi.y + od:
			continue
		for seg in deck_lines(o):
			var dp := Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])
			if dp[0].distance_to(dp[1]) < float(seg[2]) + clearance:
				return false
	return true


## segment_clear_among for each chord of the polyline `pts` in turn, in one call (an AI's predicted path): the index
## of the first chord that isn't clear, or -1 if none.
func path_blocked_at(near: Array, pts: PackedVector3Array, clearance: float, ignore_tree := -1, ignore_also := -1, decks: Variant = null) -> int:
	var ts := []
	var rs := []
	for t in near:
		if t.id != ignore_tree and t.id != ignore_also:
			ts.append(t)
			rs.append(t.reach())
	var os := []
	for o in (outposts if decks == null else decks):
		if o.tree_id != ignore_tree and o.tree_id != ignore_also:
			os.append(o)
	var floor_y := GROUND_Y + clearance
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if a.y < floor_y or b.y < floor_y:
			return i
		if ts.is_empty() and os.is_empty():
			continue
		var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * clearance
		var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * clearance
		for j in ts.size():
			var t: TreeData = ts[j]
			var r: float = rs[j]
			if t.base.x < lo.x - r or t.base.x > hi.x + r or t.base.y < lo.y - r or t.base.y > hi.y + r:
				continue
			if not _tree_clear(t, a, b, clearance, -1):
				return i
		for o in os:
			var od: float = o.width + o.depth
			if o.centre.x < lo.x - od or o.centre.x > hi.x + od or o.centre.z < lo.y - od or o.centre.z > hi.y + od:
				continue
			for seg in deck_lines(o):
				var dp := Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])
				if dp[0].distance_to(dp[1]) < float(seg[2]) + clearance:
					return i
	return -1


## Is the straight flight from a to b clear of one tree's trunk, branches and outposts by `clearance`, leaving
## out the branch that carries perch `skip_perch`? (Taking off or coming in to land: the rest of the perch's own
## tree still counts.)
func tree_clear(tree_id: int, a: Vector3, b: Vector3, clearance: float, skip_perch := -1) -> bool:
	if not _tree_clear(trees[tree_id], a, b, clearance, skip_perch):
		return false
	for o in outposts:
		if o.tree_id == tree_id:
			for seg in deck_lines(o):
				var dp := Geometry3D.get_closest_points_between_segments(a, b, seg[0], seg[1])
				if dp[0].distance_to(dp[1]) < float(seg[2]) + clearance:
					return false
	return true


func _tree_clear(t: TreeData, a: Vector3, b: Vector3, clearance: float, skip_perch: int) -> bool:
	var base := Vector3(t.base.x, GROUND_Y - 1.0, t.base.y)
	var pts := Geometry3D.get_closest_points_between_segments(a, b, base, t.top())
	var d := pts[0].distance_to(pts[1])
	if d < t.radius + clearance:
		return false
	if d >= t.reach() + clearance:
		return true   # (every branch leaves the trunk's axis, so none comes nearer than this)
	var y0 := minf(a.y, b.y) - clearance
	var y1 := maxf(a.y, b.y) + clearance
	# (Across, a branch whose box is farther than this from the segment's can't come within the clearance; the
	# margin keeps the skip on the safe side of the distance test's rounding.)
	var x0 := minf(a.x, b.x) - clearance - BOX_MARGIN
	var x1 := maxf(a.x, b.x) + clearance + BOX_MARGIN
	var z0 := minf(a.z, b.z) - clearance - BOX_MARGIN
	var z1 := maxf(a.z, b.z) + clearance + BOX_MARGIN
	var bands := t.bands()   # (the solid branches at the segment's height; one reaching across bands may come twice)
	for k in range(floori(y0 / BAND), floori(y1 / BAND) + 1):
		for br in bands.get(k, []):
			if skip_perch >= 0 and br.perch_id == skip_perch:
				continue
			if br.root.y - br.radius > y1 and br.tip.y - br.radius > y1 or br.root.y + br.radius < y0 and br.tip.y + br.radius < y0:
				continue   # (wholly above or below the segment)
			if minf(br.root.x, br.tip.x) - br.radius > x1 or maxf(br.root.x, br.tip.x) + br.radius < x0 \
					or minf(br.root.z, br.tip.z) - br.radius > z1 or maxf(br.root.z, br.tip.z) + br.radius < z0:
				continue   # (wholly to one side)
			var bp := Geometry3D.get_closest_points_between_segments(a, b, br.root, br.tip)
			if bp[0].distance_to(bp[1]) < br.radius + clearance:
				return false
	return true


## The hangar's place on an outpost's deck, in the deck's frame (x along the rail, z out from the deck's middle): by
## the trunk, at one end of the deck.
static func hangar_x(o: OutpostData) -> float:
	return HANGAR_SIDE * (o.width * 0.5 - 0.27)


static func hangar_z(o: OutpostData) -> float:
	return -o.depth * 0.5 + 0.3


## An outpost's deck as capsules for clearance queries: [a, b, radius] lines across it, near edge to rail, and its
## hangar standing on it (worked out on the first query, once the outpost is built).
func deck_lines(o: OutpostData) -> Array:
	if o.lines.is_empty():
		o.lines = _deck_lines(o)
	return o.lines


func _deck_lines(o: OutpostData) -> Array:
	var side := o.out.cross(Vector3.UP).normalized()
	var out := []
	var r := o.depth * 0.25
	for f in [0.25, 0.75]:
		var c: Vector3 = o.centre + o.out * (f - 0.5) * o.depth - Vector3.UP * o.thickness * 0.5
		out.append([c - side * (o.width * 0.5 - r), c + side * (o.width * 0.5 - r), r])
	var h: Vector3 = o.centre + side * hangar_x(o) + o.out * hangar_z(o)
	out.append([h, h + Vector3.UP * HANGAR_SIZE.y, Vector2(HANGAR_SIZE.x, HANGAR_SIZE.z).length() * 0.5])
	return out


## Is `pos` farther than `d` from every trunk, branch and deck: obstacle_distance(pos, search) > d, answered at the
## first piece of wood within d (and without measuring any tree that can't reach that close).
func clear_by(pos: Vector3, d: float, search := 12.0) -> bool:
	if not rock_clear(pos, d):
		return false
	for t in trees_near_segment(pos, pos, search):
		if Vector2(pos.x, pos.z).distance_to(t.base) - t.reach() - BOX_MARGIN > d:
			continue
		var axis := Geometry3D.get_closest_point_to_segment(pos, Vector3(t.base.x, GROUND_Y, t.base.y), t.top())
		if pos.distance_to(axis) - t.radius <= d:
			return false
		for br in t.branches:
			if not br.solid:
				continue
			if maxf(minf(br.root.y, br.tip.y) - pos.y, pos.y - maxf(br.root.y, br.tip.y)) - br.radius - BOX_MARGIN > d:
				continue
			var q := Geometry3D.get_closest_point_to_segment(pos, br.root, br.tip)
			if pos.distance_to(q) - br.radius <= d:
				return false
	for o in outposts:
		if Vector2(o.centre.x - pos.x, o.centre.z - pos.z).length() < search:
			for seg in deck_lines(o):
				var q := Geometry3D.get_closest_point_to_segment(pos, seg[0], seg[1])
				if pos.distance_to(q) - float(seg[2]) <= d:
					return false
	return true


## Distance from `pos` to the nearest trunk or branch surface (inf if none nearby).
func obstacle_distance(pos: Vector3, search := 12.0) -> float:
	var best := INF
	# Nearest trunk first, and none whose wood can't come nearer than the best so far: everything of a tree lies within
	# reach() of its axis, so its distance - reach() bounds all of it from below (likewise a branch's height).
	var order := []
	for t in trees_near_segment(pos, pos, search):
		order.append([Vector2(pos.x, pos.z).distance_to(t.base) - t.reach(), t])
	order.sort_custom(func(x, y): return x[0] < y[0])
	for e in order:
		if float(e[0]) - BOX_MARGIN >= best:
			break
		var t: TreeData = e[1]
		var axis := Geometry3D.get_closest_point_to_segment(pos, Vector3(t.base.x, GROUND_Y, t.base.y), t.top())
		best = minf(best, pos.distance_to(axis) - t.radius)
		for br in t.branches:
			if not br.solid:
				continue
			if maxf(minf(br.root.y, br.tip.y) - pos.y, pos.y - maxf(br.root.y, br.tip.y)) - br.radius - BOX_MARGIN >= best:
				continue
			var q := Geometry3D.get_closest_point_to_segment(pos, br.root, br.tip)
			best = minf(best, pos.distance_to(q) - br.radius)
	for o in outposts:
		if Vector2(o.centre.x - pos.x, o.centre.z - pos.z).length() < search:
			for seg in deck_lines(o):
				var q := Geometry3D.get_closest_point_to_segment(pos, seg[0], seg[1])
				best = minf(best, pos.distance_to(q) - float(seg[2]))
	return best


## Trunks per 1000 m^2 that reach above height `h` (the density-by-height curve).
func trunk_density_above(h: float) -> float:
	var n := 0
	for t in trees:
		if t.height > h:
			n += 1
	return n / (PI * boundary * boundary) * 1000.0


## The perch a fresh bird starts on: the highest treetop near the clearing.
func start_perch() -> Perch:
	var best: Perch = null
	var best_score := -INF
	for p in perches:
		var d := Vector2(p.position.x, p.position.z).length()
		var score := p.position.y - d * 0.4
		if score > best_score:
			best_score = score
			best = p
	return best
