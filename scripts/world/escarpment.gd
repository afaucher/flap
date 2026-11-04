class_name Escarpment
extends RefCounted
## The arena's edge beyond the boundary (docs/design/arena_edge.md, docs/images/concepts/r5_edge_split.jpg): a broken
## limestone escarpment along one sector of the ring, sunlit (it stands on the side away from the sun, its face
## toward it, turned RAKE so the light falls across it), and open heath round the rest. Pure: what EdgeBuilder draws
## and what the collision, the AI's clearance queries (ArenaLayout.rock_clear) and the tests read.
##
## The rock as limestone is: BEDS of uneven thickness, all dipping together along the cliff (BED_DIP) and stepped
## at faults (FAULT), each hard or soft; cut by two sets of near-vertical joints at uneven spacings (JOINTS), each
## joint running through a few beds and stopping; so the wall is panels -- a bed between two joints -- each set back
## from the foot by its bed's softness (hard beds over soft jut as lips, overhanging), its own random amount, now and
## then a lost block, a slight tilt of its own, and the tiers below it (TIERS: the cliff steps back at two beds,
## coming and going along the cliff). The wall is a sheet, radius out from the middle against height, per angle
## (column(): rows up each bed); the ground over it, the height field, is its envelope (height_in: the highest rock
## at that distance out -- solid under the lips, for the collision and the AI), with the scree in front (and flat
## stones on it) and the plateau behind the top, which steps and tilts on its own (skyline). Toward the ends of the
## sector it all comes down into the heath (taper).
##
## Birds may fly in to it: in its sector the soft wall stands REACH past its foot, not at the boundary, and it has
## perches (perch_spots): flat stones on the scree and spots on the ledges, many low down and fewer the higher they
## are (PERCH_EVERY), none on the top -- the cliff is somewhere to drop in on, not to sit above the fight.

const HALF := deg_to_rad(115.0)     ## the sector's half width: most of the ring
## Toward its ends the cliff curves outward, away from the wood, BEND m by its very ends, from BEND_FROM of the way
## along: from anywhere a bird can fly, its ends lie hidden behind its own face, far off.
const BEND := 230.0
const BEND_FROM := 0.45
const RAKE := deg_to_rad(50.0)      ## how far round from straight away from the sun its middle stands (so the sun
                                    ## rakes across the face and every block casts a shadow)
const FOOT := 26.0                  ## m past the boundary: the cliff's mean foot (its talus reaches out in front)
const SCREE := 11.0                 ## m: the least talus width (the scree blocks' sorting is by share of the width)
const SCREE_H := 2.0                ## m: the least talus height
## The talus the wall stands in: piled up in places and thin between (TALUS.x of the cliff's mean height up its face
## between the piles, up to TALUS.y on a pile's crest; TALUS_PILE: m along the cliff from pile to pile, and how much of
## it they cover -- the higher, the less), highest under the clefts; sloping at TALUS.z deg, as the concept's cross-
## sections (docs/design/cliff_from_concept.md: burying 0.3-0.4 of it where it's piled, at 26-30 deg).
const TALUS := Vector3(0.07, 0.48, 33.0)
const TALUS_PILE := Vector2(34.0, 0.55)
const BAY := Vector2(24.0, 10.0)    ## the foot's bays and buttresses: m along (their size), m in and out
const BED := Vector2(3.4, 0.5)     ## a bed's thickness: m (its median), and its spread (lognormal)
const BED_DIP := 0.05               ## how the beds rise along the cliff (m per m: about 3 deg)
const FAULT := Vector3(35.0, 70.0, 2.6)   ## fault blocks along the cliff: m long (least, most), the most a fault throws
const FAULT_RAMP := 9.0             ## m along the cliff a fault's step takes (the beds bend through it: no wall across)
const JOINTS := [Vector2(8.0, 0.5), Vector2(14.0, 0.55)]   ## two sets: spacing m along a bed (median), its spread
const RUN_ON := 0.6                 ## the chance a joint carries on into the bed above (long joints, as the concept's)
const SLANT := Vector2(0.45, 0.35)  ## the share of beds whose joints run aslant, and the most they lean (m per m up)
const SOFT := 0.55                  ## m a soft bed stands back behind a hard one (so a hard one over it juts)
const PANEL := 0.45                 ## m each panel stands out or back on its own
const LOSS := Vector2(0.05, 1.3)    ## the chance a panel's block is gone, and how deep the hole
const PANEL_TILT := 0.08            ## the most a panel's face turns from the cliff's line (m per m along it)
const LEAN := 0.06                  ## m the wall leans back per m up
## Each bed's face leans its own way (m per m up, least to most), on top of LEAN, from where the bed below left off:
## from just past upright (overhanging) to well back, so the face is pieces from about 80 deg to just overhanging, as
## the concept's cross-sections -- one face bending bed by bed, not steps at every bedding plane (those make benches).
const BED_LEAN := Vector2(-0.08, 0.26)
## The ledges (docs/design/cliff_from_concept.md: each hard unit's front retreats on its own; a ledge is the strip
## between two fronts): in LEDGES sets, one above another, each set a run of strips along the cliff (LEDGE_RUN: m of
## cliff per strip, the chance there's one, m its tips take to pinch out) -- each strip on a bed of its own at a height
## of its own within its set's (m, least to most), so no two lie level with each other, the beds above it standing
## back TIER_BACK m (least, most, varying along it) and pinching back in at its ends, sharp, where the two fronts meet.
## Each strip's back wanders a little in plan (TIER_WANDER m) and its bed loses blocks there (TIER_NOTCH: the chance,
## the most depth), so its back is notched and its lip straight.
const LEDGES := [Vector2(2.0, 9.0), Vector2(9.0, 19.0), Vector2(18.0, 29.0)]
const LEDGE_RUN := Vector3(38.0, 0.85, 10.0)
const TIER_BACK := Vector2(2.5, 6.0)
const TIER_WANDER := 1.0
const TIER_NOTCH := Vector2(0.3, 1.2)
const ROW_F := [0.03, 0.18, 0.34, 0.5, 0.66, 0.82, 0.97]   ## the sheet's rows up each bed (fractions, foot to top)
const BULGE := Vector2(0.4, 0.15)   ## m: a face's gentle swell over a few metres, and its roughness over one
## A panel's face broken into planar facets -- the rock's own fracturing, not a texture: [m across, the most one
## stands back, the most it tilts (m per m)], big ones that break up the whole face, small ones over them.
const FRACTURES := [Vector3(3.4, 0.5, 0.22), Vector3(1.3, 0.14, 0.12)]
const SKYLINE := Vector3(40.0, 35.0, 39.0)    ## the top: m per stretch, its height (least, most)
const GULLY := Vector3(28.0, 3.0, 1.6)   ## m: a deep cleft in the cliff about every x along it, y deep, z wide
const PLATEAU := 30.0               ## m past the top's edge it rises (the hills take over beyond)
const BUTTRESS := 4.5               ## m the foot wanders in and out
const REACH := 40.0                 ## m past the foot: the soft wall in its sector (just past the top's edge)
const STONES := 9                   ## flat-topped stones on the scree, perches
const STONE_R := Vector2(0.9, 1.6)  ## m: their tops' radius
const STONE_H := Vector2(1.6, 3.2)  ## m: their tops' height
const PERCH_EVERY := [10.0, 32.0]   ## m along the cliff between perches on each tier's ledge, foot up
                                                ## (none on the top tier: nothing up there to settle on)
const PERCH_DISC := 0.45            ## m: a ledge perch's footing (Perch.treetop's disc)
const LEDGE_BANDS := [Vector2(0.5, 9.0), Vector2(9.0, 18.0)]   ## m above the talus: the heights each tier's perches are sought at
const COLUMN_STEP := 0.002          ## rad: columns are cached to this (20 cm at the foot)

var at := 0.0      ## the sector's middle, as an angle round the ring (x = sin, z = cos)
var foot := 97.0   ## m from the middle: the mean foot
var seed := 0

var _stones := []   ## [Vector2 centre, top radius, top height] (stones())
var _beds := PackedFloat32Array()   ## each bed's foot's height at the sector's middle, before the dip and the faults
var _hard := PackedFloat32Array()   ## each bed's hardness, 0..1
var _joints := []   ## per bed, the joints crossing it: PackedFloat32Array of m along the cliff, sorted
var _slant := PackedFloat32Array()   ## per bed, how its joints lean (m along per m up; 0: upright)
var _lean := PackedFloat32Array()    ## per bed, how its face leans (BED_LEAN)
var _lean_at := PackedFloat32Array() ## per bed, how far its foot stands back for the leans of the beds under it
var _cache := {}    ## column(), by angle in COLUMN_STEPs
var _facets := []   ## per FRACTURES size: each cell's [jitter along, jitter up, set back, tilt along, tilt up], flat
var _facet_n := []  ## and how many cells along and up (Vector2i)
var _span := 0.0    ## m either side of the middle the tables reach


## The escarpment of arena `a` (none for an arena without one).
static func of(a: ArenaLayout) -> Escarpment:
	if a.escarpment.is_empty():
		return null
	var e := Escarpment.new()
	e.at = float(a.escarpment.at)
	e.foot = float(a.escarpment.foot)
	e.seed = int(a.escarpment.seed)
	return e


## How far round from the sector's middle angle `theta` is, -PI..PI.
func off(theta: float) -> float:
	return wrapf(theta - at, -PI, PI)


## 1 in the middle of the sector, falling to 0 at its ends (the cliff coming down into the heath).
func taper(theta: float) -> float:
	var u := absf(off(theta)) / HALF
	return 1.0 - smoothstep(0.86 + 0.04 * _n1(theta * 3.0 + 7.0), 0.99, u)   # (full height until far round its curve)


## The height of the ground above GROUND_Y at (x, z): 0 off the escarpment.
func height(x: float, z: float) -> float:
	return height_in(column(atan2(x, z)), Vector2(x, z).length())


# --- The rock's structure -------------------------------------------------------------------

## The beds, their joints and their benches, laid down once (deterministic from the seed).
func _lay() -> void:
	if not _beds.is_empty():
		return
	var z := -6.0   # (from below the ground: the dip and the faults lift beds into view)
	var k := 0
	while z < SKYLINE.z + 8.0:
		_beds.append(z)
		_hard.append(smoothstep(0.3, 0.7, _n1(k * 0.28 + 3.0)))   # (hard and soft come in long runs: lips where they change)
		var g := sqrt(-2.0 * log(maxf(_h(k * 5.1 + 0.9), 1e-4))) * cos(TAU * _h(k * 2.3 + 0.2))   # (a normal deviate)
		z += clampf(BED.x * exp(BED.y * g), 0.9, 7.0)
		k += 1
	_beds.append(z)   # (the last bed's top)
	var n := _beds.size() - 1
	var lean_sum := 0.0
	for b in n:
		_joints.append([])
		_slant.append(SLANT.y * (_h(b * 6.7 + 2.2) * 2.0 - 1.0) if _h(b * 3.1 + 8.8) < SLANT.x else 0.0)
		_lean.append(lerpf(BED_LEAN.x, BED_LEAN.y, _h(b * 8.3 + 1.7)))
		_lean_at.append(lean_sum)
		lean_sum += _lean[b] * (_beds[b + 1] - _beds[b])
	var span := HALF * foot + 12.0
	for b in n:   # (each bed its own joints, both sets; a share carried on from the bed below, the rest stopping there)
		for s in JOINTS.size():
			var spec: Vector2 = JOINTS[s]
			var arc := -span + spec.x * _h(b * 3.9 + s * 7.0)
			var j := 0
			while arc < span:
				var id := float(b * 997 + s * 131 + j)
				var g := sqrt(-2.0 * log(maxf(_h(id * 1.31 + 0.5), 1e-4))) * cos(TAU * _h(id * 2.71))
				arc += clampf(spec.x * exp(spec.y * g), 1.2, spec.x * 4.0)
				if _h(id * 4.9) > RUN_ON:   # (as many of its own as don't come up from below)
					_joints[b].append(arc)
				j += 1
		if b > 0:
			for a in _joints[b - 1]:
				if _h(a * 13.7 + b * 3.3) < RUN_ON:
					_joints[b].append(a)
	for b in n:
		var arr: Array = _joints[b]
		arr.sort()
		_joints[b] = PackedFloat32Array(arr)
	_span = HALF * foot + 12.0
	for f in FRACTURES.size():   # (the facet tables: one cell's point and plane per entry)
		var spec: Vector3 = FRACTURES[f]
		var nx := ceili(_span * 2.0 / spec.x) + 3
		var nz := ceili((SKYLINE.z + 20.0) / spec.x) + 3
		var t := PackedFloat32Array()
		t.resize(nx * nz * 5)
		for i in nx * nz:
			var id := float(i) * 1.618 + f * 977.0
			t[i * 5] = _h(id + 0.1)
			t[i * 5 + 1] = _h(id + 0.6)
			t[i * 5 + 2] = _h(id + 4.1)
			t[i * 5 + 3] = _h(id + 1.3) * 2.0 - 1.0
			t[i * 5 + 4] = _h(id + 2.9) * 2.0 - 1.0
		_facets.append(t)
		_facet_n.append(Vector2i(nx, nz))


## How much the beds stand raised `arc` m along the cliff: the dip, a fault block's throw, a gentle warp.
func _lift(arc: float) -> float:
	var len := lerpf(FAULT.x, FAULT.y, 0.5)
	var u := arc / len + 0.35 * sin(arc * 0.031)
	var cell := floorf(u)
	# (a fault's throw taken up over FAULT_RAMP m: a steep step the wall's sheet can draw, not a sliver)
	var k := smoothstep(1.0 - FAULT_RAMP / len, 1.0, u - cell)
	var throw := FAULT.z * lerpf(_h(cell * 4.13 + 9.0) * 2.0 - 1.0, _h((cell + 1.0) * 4.13 + 9.0) * 2.0 - 1.0, k)
	return BED_DIP * arc + throw + 0.8 * (_n1(arc / 19.0 + 3.0) - 0.5)


## How far panel (bed `b`, at `arc`) stands back from the cliff's line: its bed's softness, its own amount, a lost
## block now and then (more often at the back of a ledge: `ls`, the column's ledges), its own slight turn.
func _panel(b: int, arc: float, ls: Array) -> float:
	var js: PackedFloat32Array = _joints[b]
	var i := js.bsearch(arc)
	var lo := js[i - 1] if i > 0 else arc - 6.0
	var hi := js[i] if i < js.size() else arc + 6.0
	var id := float(b * 4099 + i)
	var back := PANEL * (_h(id * 0.73 + 1.0) * 2.0 - 1.0)
	var foot_bed := false   # (the bed rising from a ledge: its back, notched)
	for l in ls:
		if (l as Vector3).x > 0.0 and int((l as Vector3).y) == b:
			foot_bed = true
	var loss: Vector2 = TIER_NOTCH if foot_bed else LOSS
	if _h(id * 1.37 + 5.0) < loss.x:
		back += loss.y * (0.5 + 0.5 * _h(id * 2.11))
	back += PANEL_TILT * (_h(id * 3.3 + 2.0) * 2.0 - 1.0) * (arc - (lo + hi) * 0.5)
	return back + (1.0 - _hard[b]) * SOFT


## How far the face stands back for its fracture facet at (`arc` m along, `z` m up) in bed `b`: the face split into
## cells FRACTURES[k].x across (the nearest of jittered points: Voronoi), each a plane of its own -- set back by its
## own amount and tilted its own way -- so the surface is faceted and stepped, sharp where two facets meet, as broken
## rock is, not smooth. (From the tables _lay made: each cell's point and plane; a bed reads them shifted along.)
func _facet(arc: float, z: float, b: int, k: int) -> float:
	var spec: Vector3 = FRACTURES[k]
	var t: PackedFloat32Array = _facets[k]
	var nx: int = _facet_n[k].x
	var nz: int = _facet_n[k].y
	var s := spec.x
	var u := (arc + _span) / s
	var v := (z + 8.0) / s
	var cx := floori(u)
	var cz := floori(v)
	var best := INF
	var out := 0.0
	for ix in range(cx - 1, cx + 2):
		var row := posmod(ix + b * 13, nx) * nz
		for iz in range(maxi(cz - 1, 0), mini(cz + 2, nz)):
			var o := (row + iz) * 5
			var du := u - (ix + t[o])
			var dv := v - (iz + t[o + 1])
			var d := du * du + dv * dv
			if d < best:
				best = d
				out = spec.y * t[o + 2] + (t[o + 3] * du + t[o + 4] * dv) * s * spec.z
	return out


## How far bed `b` stands back at `arc` for the ledges under it (`ls`, the column's: ledge()), each with its wander.
func _tier_back(b: int, arc: float, ls: Array) -> float:
	var back := 0.0
	for k in ls.size():
		var l: Vector3 = ls[k]
		if l.x > 0.0 and b >= int(l.y):
			back += l.x + TIER_WANDER * (_n1(arc / 14.0 + k * 7.7) - 0.5) * 2.0 * l.z
	return back


## The ledge of set `k` (LEDGES) `arc` m along the cliff: (how deep it is, the bed it lies on, how far in from its tips
## (0 at them, 1 along its run)); depth 0 where there's none.
func ledge(k: int, arc: float) -> Vector3:
	var span := LEDGE_RUN.x
	var phase := _h(k * 3.7 + 1.1) * span
	var cell := floorf((arc + phase) / span)
	var id := cell * 7.13 + k * 101.0
	if _h(id + 0.3) > LEDGE_RUN.y:
		return Vector3(0.0, -1.0, 0.0)
	var len := span * lerpf(0.45, 0.95, _h(id + 1.7))
	var t := arc - (cell * span - phase + (span - len) * _h(id + 2.9))
	if t <= 0.0 or t >= len:
		return Vector3(0.0, -1.0, 0.0)
	var tip := minf(LEDGE_RUN.z * lerpf(0.6, 1.4, _h(id + 4.1)), len * 0.35)
	var on := clampf(minf(t, len - t) / tip, 0.0, 1.0)   # (pinching straight in to a point at each end: 20-45 deg)
	var band: Vector2 = LEDGES[k]
	var b := _bed_near(lerpf(band.x, band.y, _h(id + 5.3)))
	return Vector3(on * lerpf(TIER_BACK.x, TIER_BACK.y, _n1(arc / 11.0 + k * 2.3)), float(b), on)


## The bed whose foot lies nearest height `z` (at the sector's middle), above the lowest.
func _bed_near(z: float) -> int:
	var i := clampi(_beds.bsearch(z), 1, _beds.size() - 2)
	return i - 1 if i > 1 and absf(_beds[i - 1] - z) < absf(_beds[i] - z) else i


## The wall at angle `theta`, worked out once for a whole column of heights (height_in): empty off it.
## [w, r0, theta, top, rows, then each row's height and radius (ROW_F up each bed, bottom to top), then the rows'
## radii's running minimum from the top down (for height_in's search)].
func column(theta: float) -> PackedFloat32Array:
	var key := roundi(off(theta) / COLUMN_STEP)
	if _cache.has(key):
		return _cache[key]
	var col := _column(at + key * COLUMN_STEP)
	_cache[key] = col
	return col


func _column(theta: float) -> PackedFloat32Array:
	var col := PackedFloat32Array()
	if absf(off(theta)) > HALF:
		return col
	var w := taper(theta)
	if w <= 0.0:
		return col
	_lay()
	var arc := off(theta) * foot   # (m along the cliff)
	var r0 := foot_r(theta)
	var top := maxf(skyline(arc) * w, 1.0)
	var lift := _lift(arc)
	var cleft := gully(arc) * GULLY.y
	var n := _beds.size() - 1
	var rows := n * ROW_F.size()
	col.append_array([w, r0, theta, top, rows])
	var last_r := r0
	var ls := []   # (the ledges here, each set's)
	for k in LEDGES.size():
		ls.append(ledge(k, arc))
	for b in n:
		# (the beds keep their thickness toward the ends: the top comes down through them, so the cliff ends as a low
		# wall of a bed or two, not a staircase of thin ones)
		var z0 := _beds[b] + lift
		var z1 := _beds[b + 1] + lift
		var bed_back := _tier_back(b, arc, ls) + cleft
		var zc := (z0 + z1) * 0.5
		for f in ROW_F:
			var z := lerpf(z0, z1, f)
			var back := bed_back + _panel(b, arc - _slant[b] * (z - zc), ls) + _lean_at[b] + _lean[b] * (z - z0)   # (its joints aslant, in some beds)
			# (a face isn't a plane: it swells and hollows gently over a few metres, rougher over one)
			var swell := BULGE.x * (_n1(arc / 2.6 + z / 2.1 + b * 3.1) - 0.5) * 2.0 + BULGE.y * (_n1(arc * 1.1 + z * 0.9 + b * 7.0) - 0.5) * 2.0
			var r := r0 + maxf(back + LEAN * z + swell + _facet(arc, z, b, 0) + _facet(arc, z, b, 1), -0.8)
			if z > top:   # (above the top: none -- the rows close up on the top's edge)
				z = top
				r = last_r
			elif z < 0.0:
				z = 0.0
			col.append_array([z, r])
			last_r = r
	var mins := PackedFloat32Array()   # (from the top row down, the nearest the wall comes out)
	mins.resize(rows)
	var m := INF
	for j in range(rows - 1, -1, -1):
		m = minf(m, col[6 + j * 2])
		mins[j] = m
	col.append_array(mins)
	return col


## The ground's height `r` m out from the middle in the column `col` (column()): the scree in front of the wall, the
## highest rock at that distance (solid under any lip above), the plateau behind the top.
func height_in(col: PackedFloat32Array, r: float) -> float:
	if col.is_empty():
		return 0.0
	var w := col[0]
	var theta := col[2]
	var rows := int(col[4])
	var foot_r := col[6]   # (the wall's foot, its lowest row)
	var s := r - foot_r
	var mins := 5 + rows * 2
	var tal := talus_in(col, r)
	if s < 0.0 and r < col[mins]:   # (in front of all of it: the talus, and the flat stones standing on it)
		var h0 := tal
		var p := Vector2(sin(theta), cos(theta)) * r   # (the stones wherever they stand, at the talus's edge too)
		for st in stones():
			var d := p.distance_to(st[0])
			var rim := float(st[1]) + 0.6
			if d < rim:   # (a flat top, its edge rounding off over 0.6 m)
				h0 = maxf(h0, float(st[2]) * (1.0 - smoothstep(float(st[1]), rim, d) * 0.7))
		return h0
	# The highest row the wall has come out to r by: the running minimum is ordered, so a binary search finds it.
	var lo := 0
	var hi := rows - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if col[mins + mid] <= r:
			lo = mid
		else:
			hi = mid - 1
	var h := col[5 + lo * 2]
	if lo < rows - 1 or r < col[6 + lo * 2]:
		return maxf(h + 0.12 * _n1(theta * 80.0 + r), tal)   # (the talus piled up against the face)
	# The top: rising a little, then level, its steps smoothing out to the cliff's mean height away from the edge
	# (so the hills beyond carry no ridges from them).
	var t := r - col[6 + lo * 2]
	return maxf(lerpf(col[3], mean_top() * w, smoothstep(0.0, PLATEAU, t)) + minf(t, PLATEAU) * 0.1 * w, tal)


## The ledges in column `col`: runs of level rock at least `least` m deep, below the top, above the scree:
## [[from (m out), to, height]], low to high.
func ledges(col: PackedFloat32Array, least := 1.4) -> Array:
	var out := []
	if col.is_empty():
		return out
	var top := col[3]
	var r := col[6]
	var start := r
	var h0 := height_in(col, r)
	while r < col[6] + 40.0:
		r += 0.2
		var h := height_in(col, r)
		if absf(h - h0) > 0.3 or h >= top - 0.5:
			if r - start >= least and h0 > talus(col).y + 0.5 and h0 < top - 0.5:
				out.append([start, r - 0.2, h0])
			start = r
			h0 = h
		if h >= top - 0.5:
			break
	return out


## Where the top begins in column `col` (m out from the middle: its edge).
func top_start(col: PackedFloat32Array) -> float:
	if col.is_empty():
		return INF
	var rows := int(col[4])
	return col[6 + (rows - 1) * 2]


## The outward ground normal at (x, z), from the height's slope.
func normal(x: float, z: float, step := 0.25) -> Vector3:
	var hx := height(x + step, z) - height(x - step, z)
	var hz := height(x, z + step) - height(x, z - step)
	return Vector3(-hx, 2.0 * step, -hz).normalized()


## The top's height (before the taper) `arc` m along the cliff: a level run, a step, a tilt, in stretches SKYLINE.x
## long, between SKYLINE.y and SKYLINE.z m.
func skyline(arc: float) -> float:
	var u := arc / SKYLINE.x + 0.21
	var cell := floorf(u)
	var f := smoothstep(0.0, 1.0, clampf((u - cell - 0.5) / 0.5, 0.0, 1.0))   # (level, then a slope down or up)
	var a := lerpf(SKYLINE.y, SKYLINE.z, _h(cell * 3.3 + 7.0))
	var b := lerpf(SKYLINE.y, SKYLINE.z, _h((cell + 1.0) * 3.3 + 7.0))
	return lerpf(a, b, f)


## 1 in the middle of a cleft at `arc` m along the cliff, falling to 0 out of it over `spread` m (the clefts: GULLY
## apart along it, give or take, not every one there).
func gully(arc: float, spread := 3.0) -> float:
	var cell := roundf(arc / GULLY.x)
	if _h(cell * 7.31 + 2.0) < 0.3:
		return 0.0
	var centre := (cell + (_h(cell * 3.1) - 0.5) * 0.5) * GULLY.x
	var half := GULLY.z * (0.6 + 0.8 * _h(cell * 5.7 + 1.0))
	return 1.0 - smoothstep(half, half + spread, absf(arc - centre))   # (its sides sloping, not walls across the cliff)


## The cliff's top height at full height, on average.
func mean_top() -> float:
	return (SKYLINE.y + SKYLINE.z) * 0.5


## The flat stones on the scree: [Vector2 centre, top radius, top height], spread along the sector's middle part.
func stones() -> Array:
	if not _stones.is_empty():
		return _stones
	for i in STONES:
		var u := ((float(i) + 0.5) / STONES * 1.2 - 0.6 + (_h(i * 3.1 + 0.7) - 0.5) * 0.1) * 0.7
		var theta := at + u * HALF
		var col := column(theta)
		var tw := talus(col)
		var r: float = col[1] - tw.x * lerpf(0.55, 0.8, _h(i * 7.7 + 1.3))   # (low on the talus, out toward its toe)
		var top_r := lerpf(STONE_R.x, STONE_R.y, _h(i * 5.3 + 2.1))
		_stones.append([Vector2(sin(theta), cos(theta)) * r, top_r, talus_in(col, r) + lerpf(STONE_H.x, STONE_H.y, _h(i * 2.9 + 4.4))])
	return _stones


## Where birds can settle on the rock: the stones' tops, and spots on the ledges, PERCH_EVERY apart along the cliff
## at each tier's heights (LEDGE_BANDS: more low down, fewer higher, none on top), where a ledge is deep enough to
## stand on. [centre (on the surface), facing (out over the wood)].
func perch_spots() -> Array:
	var out := []
	for st in stones():
		var c: Vector2 = st[0]
		out.append([Vector3(c.x, ArenaLayout.GROUND_Y + height(c.x, c.y) + 0.03, c.y), Vector3(-c.x, 0.0, -c.y).normalized()])
	for i in PERCH_EVERY.size():
		var step: float = PERCH_EVERY[i]
		var arc := -HALF * foot + step * (0.5 + 0.37 * i)
		while arc < HALF * foot:
			var spot := _ledge_spot(i, arc)   # (here, or the nearest level spot a little either way along)
			for nudge in [1.5, -1.5, 3.0, -3.0, 4.5, -4.5]:   # (the ledges are strips: the nearest one a little either way)
				if spot.is_empty():
					spot = _ledge_spot(i, arc + nudge)
			arc += step
			if not spot.is_empty():
				out.append(spot)
	return out


## A perch on a ledge at tier `i`'s heights `arc` m along the cliff from its middle ([centre, facing]), or [] where
## there's none deep enough there, the cliff is too low, or a joint is near (the ledge not level a metre either side).
func _ledge_spot(i: int, arc: float) -> Array:
	var theta := at + arc / foot
	var col := column(theta)
	if col.is_empty() or col[0] < 0.7 or absf(off(theta)) / HALF > BEND_FROM:   # (not where it curves away)
		return []
	var band: Vector2 = LEDGE_BANDS[i] + Vector2.ONE * talus(col).y
	for l in ledges(col):
		var h: float = l[2]
		if h < band.x or h >= band.y or h > minf(col[3], mean_top()) - 4.0:   # (not up by the top)
			continue
		var depth: float = float(l[1]) - float(l[0])
		var r: float = float(l[0]) + clampf(depth * 0.45, 0.6, 1.2)   # (back from the lip, on the level)
		h = height_in(col, r)
		var level := true   # (level a metre either way along, and half a metre in and out)
		for side in [-1.0, -0.4, 0.4, 1.0]:
			var t2: float = theta + float(side) / r
			if absf(height_in(column(t2), r) - h) > 0.25 or absf(height_in(col, r + float(side) * 0.5) - h) > 0.25:
				level = false
		if not level:
			continue
		var p := Vector2(sin(theta), cos(theta)) * r
		return [Vector3(p.x, ArenaLayout.GROUND_Y + h + 0.03, p.y), Vector3(-p.x, 0.0, -p.y).normalized()]
	return []


## The soft wall's radius toward angle `theta`: REACH past the foot in the sector (coming back to `boundary` only
## where the cliff is down to a third of its height, near its ends), else `boundary`.
func reach(theta: float, boundary: float) -> float:
	if absf(off(theta)) > HALF:
		return boundary
	return lerpf(boundary, minf(foot_r(theta), foot + 8.0) + REACH, smoothstep(0.0, 0.3, taper(theta)) * (1.0 - smoothstep(BEND_FROM, BEND_FROM + 0.12, absf(off(theta)) / HALF)))


## The wall's mean foot toward angle `theta`: bays and buttresses tens of metres across, a little wander over them.
func foot_r(theta: float) -> float:
	var arc := off(theta) * foot
	var bend := smoothstep(BEND_FROM, 1.0, absf(off(theta)) / HALF)
	return foot + BEND * bend * bend + BAY.y * (_n1(arc / BAY.x + 2.0) - 0.5) * 2.0 + BUTTRESS * 0.4 * (_n1(arc / 9.0 + 5.0) - 0.5) * 2.0


## The talus in column `col`: (how far out in front of the wall's foot it reaches, how high it stands against it). Its
## height wanders along the cliff and stands higher under the clefts (the rock comes down them); its width is its
## height over its slope, short of the boundary. It's laid from the foot's smooth line (talus_from), not the wall's
## own lowest row, which steps panel to panel: a talus shifted with each would show a step across the slope at each.
func talus(col: PackedFloat32Array) -> Vector2:
	if col.is_empty():
		return Vector2.ZERO
	var w := col[0]
	var arc := off(col[2]) * foot
	# (piles: where a slow noise runs high, a heap up to TALUS.y, thin between; the highest under a cleft; lumps on both)
	var pile := smoothstep(TALUS_PILE.y, 0.95, _n1(arc / TALUS_PILE.x + 5.0))
	pile = maxf(pile, gully(arc, 6.0) * 0.55)   # (a cone under a cleft)
	var h := mean_top() * w * (lerpf(TALUS.x, TALUS.y, pile) + 0.04 * (_n1(arc / 9.0 + 1.0) - 0.5))
	h = maxf(h, SCREE_H * w)
	var width := minf(h / tan(deg_to_rad(TALUS.z)), talus_from(col) - (foot - FOOT) - 2.0)
	return Vector2(maxf(width, 1.0), h)


## Where the talus's slope tops out in column `col` (m out from the middle): the foot's smooth line, a little into the
## wall (the talus lies level against the face behind it).
func talus_from(col: PackedFloat32Array) -> float:
	return col[1] + 1.5


## The talus's height `r` m out in column `col`: from its toe up its slope (a little concave, lumpy), level with its
## top against the wall.
func talus_in(col: PackedFloat32Array, r: float) -> float:
	var t := talus(col)
	var k := (r - (talus_from(col) - t.x)) / t.x
	if k <= 0.0:
		return 0.0
	k = minf(k, 1.0)
	var arc := off(col[2]) * foot   # (lumps in two directions, not streaks out from the middle)
	return t.y * pow(k, 1.3) * (0.92 + 0.16 * _n1(arc * 0.35 + 3.0) * _n1(r * 0.6 + arc * 0.11))


## The tallest the escarpment stands at angle `theta` (its top's height).
func top(theta: float) -> float:
	var col := column(theta)
	return 0.0 if col.is_empty() else col[3]


## Smooth noise in 0..1 along one coordinate, seeded.
func _n1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_h(i), _h(i + 1.0), f)


func _h(i: float) -> float:
	return fposmod(sin(i * 127.1 + float(seed) * 311.7) * 43758.5453, 1.0)
