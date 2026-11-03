class_name Escarpment
extends RefCounted
## The arena's edge beyond the boundary (docs/design/arena_edge.md, docs/images/concepts/r5_edge_split.jpg): a broken
## limestone escarpment along one sector of the ring, sunlit (it stands on the side away from the sun, its face
## toward it, turned RAKE so the light falls across it), and open heath round the rest. Pure: the escarpment is a
## height over the ground, h(x, z), that the mesh, its collision, the AI's clearance queries (ArenaLayout.rock_clear)
## and the tests all read (EdgeBuilder builds them).
##
## Birds may fly in to it: in its sector the soft wall stands REACH past its foot, not at the boundary, and it has
## perches (perch_spots): flat stones on the scree and spots on the ledges' lips, many low down and fewer the higher
## they are (PERCH_EVERY), none on the top -- the cliff is somewhere to drop in on, not to sit above the fight.
##
## Across the sector, out from the middle: a scree slope from SCREE inside the cliff's foot, then TIERS -- each a
## steep face and a ledge set back behind it -- up to the top, then a plateau rising a little to PLATEAU and level
## beyond. Each tier is broken along its length into blocks a few metres wide (the rock's vertical joints): a block
## stands proud of its neighbours or is set back, a little taller or shorter, so the faces meet at square corners.
## The foot wanders in and out (bays and buttresses), and toward the ends of the sector it comes down tier by tier
## into the heath.

const HALF := deg_to_rad(52.0)      ## the sector's half width
const RAKE := deg_to_rad(50.0)      ## how far round from straight away from the sun its middle stands (so the sun
                                    ## rakes across the face and every block casts a shadow)
const FOOT := 14.0                  ## m past the boundary: the cliff's foot (the scree starts SCREE inside that)
const SCREE := 11.0                 ## m: the scree's width, out to the foot
const SCREE_H := 5.5                ## m: how high it piles at the foot
## [face height, ledge width] m, foot to top: as in the concept, a lower broken tier and its heathery ledge, a
## second short one, then the tall wall to the top.
const TIERS := [[5.5, 4.5], [6.0, 3.0], [19.0, 0.0]]
const DIP := Vector4(30.0, 60.0, 0.35, 1.8)   ## the beds' fault blocks: m long (least, most), face scale (least, most)
const SKYLINE := Vector3(24.0, 30.0, 44.0)    ## the top: m per stretch, its height (least, most)
const GULLY := Vector3(28.0, 4.5, 1.6)   ## m: a deep cleft in the cliff about every x along it, y deep, z wide
const BLOCK := Vector2(7.0, 1.5)    ## m: a tier's blocks' mean width along it, and how much wider each tier up
const FACE := 0.9                   ## m: how far a face leans back, bottom to top (steep: about 80 deg)
const RECESS := 2.4                 ## m: the most a block stands back from its tier's line
const PLATEAU := 30.0               ## m past the top's edge it rises (the hills take over beyond)
const BUTTRESS := 4.5               ## m the foot wanders in and out
const REACH := 24.0                 ## m past the foot: the soft wall in its sector (just past the top's edge)
const STONES := 9                   ## flat-topped stones on the scree, perches
const STONE_R := Vector2(0.9, 1.6)  ## m: their tops' radius
const STONE_H := Vector2(1.6, 3.2)  ## m: their tops' height
const PERCH_EVERY := [11.0, 26.0]   ## m along the cliff between perches on each tier's ledge, foot up
                                                ## (none on the top tier: nothing up there to settle on)
const PERCH_DISC := 0.45            ## m: a ledge perch's footing (Perch.treetop's disc)

var _stones := []   ## [Vector2 centre, top radius, top height] (stones())

var at := 0.0      ## the sector's middle, as an angle round the ring (x = sin, z = cos)
var foot := 97.0   ## m from the middle: the mean foot
var seed := 0


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


## 1 in the middle of the sector, falling to 0 at its ends (the cliff coming down into the heath tier by tier).
func taper(theta: float) -> float:
	var u := absf(off(theta)) / HALF
	return 1.0 - smoothstep(0.5 + 0.1 * _n1(theta * 3.0 + 7.0), 0.94, u)


## The height of the ground above GROUND_Y at (x, z): 0 off the escarpment.
func height(x: float, z: float) -> float:
	return height_in(column(atan2(x, z)), Vector2(x, z).length())


## Everything about the escarpment at angle `theta` that doesn't depend on the distance out (its taper, its foot,
## each tier's face and ledge), worked out once for a whole column of heights (height_in): empty off it.
## [w, r0, theta, then per tier: face start, face width, face height, ledge width, height at the face's foot,
## shelf; then where the top starts and its height].
func column(theta: float) -> PackedFloat32Array:
	var col := PackedFloat32Array()
	if absf(off(theta)) > HALF:
		return col
	var w := taper(theta)
	if w <= 0.0:
		return col
	var r0 := foot + BUTTRESS * (_n1(theta * 9.0) * 0.7 + _n1(theta * 31.0 + 3.0) * 0.3)
	col.append_array([w, r0, theta])
	var h := SCREE_H * w
	var e := 0.0   # where the current tier's face starts, m past the foot
	var arc := off(theta) * foot   # (m along the cliff)
	var cleft := gully(arc) * GULLY.y * w
	for i in TIERS.size():
		var tier: Array = TIERS[i]
		# (block widths vary: the joint lines wander, so the blocks run from about half to half again the mean)
		var cell := floorf(arc / (BLOCK.x + BLOCK.y * i) + 0.37 * i + 0.35 * sin(arc * 0.21 + i * 1.7))
		var b1 := _h(cell * 7.13 + i * 13.7 + 0.5)
		var b2 := _h(cell * 3.71 + i * 5.3 + 0.25)
		var last := i == TIERS.size() - 1
		var face_h: float
		if last:   # (the top tier makes up the skyline, which steps and tilts on its own, not with the beds below)
			face_h = maxf(skyline(arc) * w - h, 3.0 * w) * (0.92 + 0.16 * b2)
		else:   # (the lower tiers' beds dip: each rises and falls along the cliff in its own fault blocks)
			face_h = float(tier[0]) * w * dip(arc, i) * (0.85 + 0.3 * b2)
		e += RECESS * b1 * w + (cleft if i == 0 else 0.0)
		var face := FACE * (0.7 + 0.6 * b2)
		# (and a ledge runs out here and there: the faces above and below meet in one)
		var ledge := float(tier[1]) * (0.5 + _n1(theta * (17.0 + i * 3.0) + i * 5.0)) * (1.0 - 0.6 * b1) * smoothstep(0.28, 0.45, _n1(arc / 37.0 + i * 5.3 + 2.0))
		col.append_array([e, face, face_h, ledge, h, 0.35 + 0.3 * _n1(theta * 23.0 + i * 7.0)])
		h += face_h + ledge * 0.12
		e += face + ledge
	col.append_array([e, h])
	return col


## The height `r` m out from the middle in the column `col` (column()).
func height_in(col: PackedFloat32Array, r: float) -> float:
	if col.is_empty():
		return 0.0
	var w := col[0]
	var theta := col[2]
	var s := r - col[1]
	if s < -SCREE:
		return 0.0
	if s < 0.0:   # (the scree: piled at the foot, lumpy, and the flat stones standing on it)
		var k := (s + SCREE) / SCREE
		var h0 := SCREE_H * w * k * k * (0.8 + 0.4 * _n1(theta * 60.0 + s * 0.7))
		var p := Vector2(sin(theta), cos(theta)) * r
		for st in stones():
			var d := p.distance_to(st[0])
			var rim := float(st[1]) + 0.6
			if d < rim:   # (a flat top, its edge rounding off over 0.6 m)
				h0 = maxf(h0, float(st[2]) * (1.0 - smoothstep(float(st[1]), rim, d) * 0.7))
		return h0
	for i in TIERS.size():
		var b := 3 + i * 6
		var e := col[b]
		var face := col[b + 1]
		var h := col[b + 4]
		if s < e:   # (in front of a set-back block: the ledge below runs on)
			return h + 0.12 * _n1(theta * 80.0 + s)
		if s < e + face:
			return h + col[b + 2] * _face(clampf((s - e) / face, 0.0, 1.0), col[b + 5])
		if s < e + face + col[b + 3]:   # (a ledge: near level, a little rubble on it)
			return h + col[b + 2] + (s - e - face) * 0.12 + 0.12 * _n1(theta * 80.0 + s)
	var n := col.size()
	# The top: rising a little, then level, its blocks' steps smoothing out to the cliff's mean height away from the
	# edge (so the hills beyond carry no ridges from them).
	var t := s - col[n - 2]
	return lerpf(col[n - 1], mean_top() * w, smoothstep(0.0, PLATEAU, t)) + minf(t, PLATEAU) * 0.1 * w


## A face's profile, 0..1 up it over 0..1 across it: steep, with a little overhanging lip near the top and
## broken shelves partway (so the face isn't one clean ramp).
func _face(t: float, shelf: float) -> float:
	var y := smoothstep(0.0, 1.0, t)
	y += 0.08 * sin(t * PI * 3.0 + shelf * 6.0) * t * (1.0 - t)
	return clampf(y, 0.0, 1.0)


## The outward ground normal at (x, z), from the height's slope.
func normal(x: float, z: float, step := 0.25) -> Vector3:
	var hx := height(x + step, z) - height(x - step, z)
	var hz := height(x, z + step) - height(x, z - step)
	return Vector3(-hx, 2.0 * step, -hz).normalized()


## How much tier `i`'s face height is scaled `arc` m along the cliff: the rock broken into fault blocks DIP.x-DIP.y
## m long, its beds tilted in each (a straight ramp from one height to another) and stepped at the faults between
## them, so the ledges run diagonally, rise and fall, and don't line up with each other.
func dip(arc: float, i: int) -> float:
	var len := lerpf(DIP.x, DIP.y, _h(i * 9.1 + 3.0))
	var u := arc / len + 0.43 * i
	var cell := floorf(u)
	var f := u - cell
	var a := lerpf(DIP.z, DIP.w, _h(cell * 5.17 + i * 31.0 + 1.0))
	var b := lerpf(DIP.z, DIP.w, _h(cell * 5.17 + i * 31.0 + 2.7))
	return lerpf(a, b, f)


## The top's height (before the taper) `arc` m along the cliff: a level run, a step, a tilt, in stretches SKYLINE.x
## long, between SKYLINE.y and SKYLINE.z m.
func skyline(arc: float) -> float:
	var u := arc / SKYLINE.x + 0.21
	var cell := floorf(u)
	var f := smoothstep(0.0, 1.0, clampf((u - cell - 0.65) / 0.35, 0.0, 1.0))   # (level, then a short slope down or up)
	var a := lerpf(SKYLINE.y, SKYLINE.z, _h(cell * 3.3 + 7.0))
	var b := lerpf(SKYLINE.y, SKYLINE.z, _h((cell + 1.0) * 3.3 + 7.0))
	return lerpf(a, b, f)


## 1 in the middle of a cleft at `arc` m along the cliff, falling to 0 out of it (the clefts: GULLY apart along it,
## give or take, not every one there).
func gully(arc: float) -> float:
	var cell := roundf(arc / GULLY.x)
	if _h(cell * 7.31 + 2.0) < 0.3:
		return 0.0
	var centre := (cell + (_h(cell * 3.1) - 0.5) * 0.5) * GULLY.x
	var half := GULLY.z * (0.6 + 0.8 * _h(cell * 5.7 + 1.0))
	return 1.0 - smoothstep(half, half + 1.0, absf(arc - centre))


## The cliff's top height at full height (the scree, every face at its mean, every ledge's rise).
func mean_top() -> float:
	var h := SCREE_H
	for i in TIERS.size():
		h += float(TIERS[i][0]) + float(TIERS[i][1]) * 0.12
	return h


## The flat stones on the scree: [Vector2 centre, top radius, top height], spread along the sector's middle part.
func stones() -> Array:
	if not _stones.is_empty():
		return _stones
	for i in STONES:
		var u := (float(i) + 0.5) / STONES * 1.2 - 0.6 + (_h(i * 3.1 + 0.7) - 0.5) * 0.1
		var theta := at + u * HALF
		var r0 := foot + BUTTRESS * (_n1(theta * 9.0) * 0.7 + _n1(theta * 31.0 + 3.0) * 0.3)
		var r := r0 - SCREE * lerpf(0.25, 0.6, _h(i * 7.7 + 1.3))
		var top_r := lerpf(STONE_R.x, STONE_R.y, _h(i * 5.3 + 2.1))
		_stones.append([Vector2(sin(theta), cos(theta)) * r, top_r, lerpf(STONE_H.x, STONE_H.y, _h(i * 2.9 + 4.4))])
	return _stones


## Where birds can settle on the rock: the stones' tops, and spots just behind the lips of the ledges, PERCH_EVERY
## apart along each tier (more low down, fewer higher, none on top), where the ledge is wide enough to stand on.
## [centre (on the surface), facing (out over the wood)].
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
			for nudge in [1.5, -1.5, 3.0, -3.0]:
				if spot.is_empty():
					spot = _ledge_spot(i, arc + nudge)
			arc += step
			if not spot.is_empty():
				out.append(spot)
	return out


## A perch on tier `i`'s ledge `arc` m along the cliff from its middle ([centre, facing]), or [] where the ledge is
## too narrow, the cliff too low, or a joint between blocks near (the ledge not level a metre either side).
func _ledge_spot(i: int, arc: float) -> Array:
	var theta := at + arc / foot
	var col := column(theta)
	if col.is_empty() or col[0] < 0.7:
		return []
	var b := 3 + i * 6
	var ledge := col[b + 3]
	if ledge < 1.4:
		return []
	var r := col[1] + col[b] + col[b + 1] + clampf(ledge * 0.45, 0.6, 1.2)   # (back from the lip, on the level)
	var h := height_in(col, r)
	for side in [-1.0, 1.0]:
		var t2: float = theta + float(side) / r
		if absf(height_in(column(t2), r) - h) > 0.25:
			return []
	var p := Vector2(sin(theta), cos(theta)) * r
	return [Vector3(p.x, ArenaLayout.GROUND_Y + h + 0.03, p.y), Vector3(-p.x, 0.0, -p.y).normalized()]


## The soft wall's radius toward angle `theta`: REACH past the foot in the sector (coming back to `boundary` only
## where the cliff is down to a third of its height, near its ends), else `boundary`.
func reach(theta: float, boundary: float) -> float:
	if absf(off(theta)) > HALF:
		return boundary
	return lerpf(boundary, foot + REACH, smoothstep(0.0, 0.3, taper(theta)))


## The tallest the escarpment stands at angle `theta` (its top's height at the plateau's near edge).
func top(theta: float) -> float:
	var col := column(theta)
	return 0.0 if col.is_empty() else col[col.size() - 1]


## Smooth noise in 0..1 along one coordinate, seeded.
func _n1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_h(i), _h(i + 1.0), f)


func _h(i: float) -> float:
	return fposmod(sin(i * 127.1 + float(seed) * 311.7) * 43758.5453, 1.0)
