class_name RaceCourse
extends RefCounted
## A race course through the wood (docs/design/race.md): gates to fly through in order, from a start perch (an
## outpost's rail) and back to it, generated from the layout so every gate is flyable and the next one can always be seen.
##   post    two posts standing on open ground with a banner between their tops; low (a window 0.8-3.8 m up) or
##           tall (5.5-8.5 m), facing any way (turned to the course: the bisector of the legs in and out)
##   trunk   between two pines 3.6-6 m apart, a banner from trunk to trunk over the window, at any height under
##           the crowns
##   hoop    a ring hung on ropes, from an oak's or a pine's long limb ("limb") or from a rope strung between two
##           pines 8-16 m apart ("span")
## The rules every course keeps (`problems()` checks them; test_race). Those about flying it come from the birds that
## race it (`envelope`: the widest turning circle and the widest wings among them; by default all five, so the hawk's):
##   - each window is clear of wood, and so is the lane through it;
##   - a clear way in and out: ENTRY_RUNS turning circles of straight in front of each window and EXIT_RUNS past it,
##     clear by half a wingspan and WING_MARGIN, and the lanes along the window's four edges clear RIM_LANE m either side;
##   - each leg's flown line (flown_line: leaving one gate along its way through, arriving along the next's, a smooth
##     curve between, down to the window's height DIVE_RUN before it) turns no tighter than the widest turning circle
##     and is clear of wood by half a wingspan and WING_MARGIN, of the gates' posts by POST_CLEAR and of every rope
##     by ROPE_CLEAR; the course never comes back within SPACING of a gate;
##   - a leg meets the gate it leaves and the one it enters within ENTRY_DEG of their way through (so a turn at a
##     gate is at most 2 x ENTRY_DEG), climbs at most CLIMB_MAX and dives at most DIVE_MAX, over the leg less the
##     metres it spends turning (turn_arc: no steep dive or climb banked hard) and DIVE_RUN level before the gate
##     (_grade_ok; LinePilot and probe_flyable found the legs that broke this);
##   - the next gate can be seen (its centre and 3 of 4 points round its rim, past trunks, branches and needles)
##     from the gate you're passing and from SIGHT_BACK m before it on the way in;
##   - so can the one after it, within NEXT_TWO_MAX m, unless the turn at the next gate is tighter than TIGHT_DEG
##     (that gate is flagged `marked`: course markers round the turn, to come).
## Built by a beam search over the candidate gates, scored for variety: heights, kinds, turns both ways.

const GATES := 10
const BEAM := 32
const TAKE := 8                   ## options a beam keeps at each step
const TRIES := 300                 ## options a beam checks at each step (best first) before giving up on more
const LEG := Vector2(14.0, 40.0)  ## m in plan from a gate to the next (a style may change it: STYLES)
## Course styles: a shape (how long the legs, how hard the turns, how much it keeps to the wood) and heights (level, or
## high and low), "<shape>-<heights>"; "" is the old all-round course. Each sets the search's scoring, and legs:
##   gates    how many
##   leg      m in plan from a gate to the next, and the length it aims for
##   turn     deg the turns at the gates are scored for falling between
##   wood     score for a gate in the wood (between trunks, a hoop) over posts in the open
##   route    a leg the smooth curve can't fly clear is routed through the wood instead (route_line)
##   zigzag   score for a turn the other way from the last (S-bends: hard turns that don't wind the course round)
##   birds    the birds it's planned for, if not those racing (technical: the agile ones -- the hawk and falcon can't
##            make its turns, by design)
##   eight    planned as a figure-eight that crosses itself (EIGHT_GATES gates; the search follows a guide, _guide_for);
##            if no figure-eight fits round the nearest starts, the free search's course
##   dy, spread  score per m a leg climbs or dives (capped at 8), and per m of the whole course's height range
const SHAPES := {
	"": {"gates": 10, "leg": Vector2(14.0, 40.0), "aim": 25.0, "turn": Vector2(20.0, 70.0), "wood": 0.0},
	"technical": {"gates": 12, "leg": Vector2(12.0, 24.0), "aim": 16.0, "turn": Vector2(40.0, 90.0), "wood": 1.0, "zigzag": 2.5, "birds": ["crow", "owl", "sparrow"], "eight": true},
	"long": {"gates": 7, "leg": Vector2(26.0, 55.0), "aim": 40.0, "turn": Vector2(5.0, 40.0), "wood": 1.5, "route": true},
}
const HEIGHTS := {
	"": {"dy": 0.25, "spread": 0.5},
	"level": {"dy": -0.6, "spread": -1.0},
	"high-low": {"dy": 0.6, "spread": 1.2},
}
const STYLES := ["technical-level", "technical-high-low", "long-level", "long-high-low"]
const ENTRY_DEG := 45.0
const TIGHT_DEG := 60.0
const START_DEG := 60.0           ## the first leg leaves the start perch within this of the way it faces
const CLIMB_MAX := 0.27           ## (15 deg)
const DIVE_MAX := 0.7             ## (35 deg)
const CLIMB_RUN := 4.0            ## m of a leg not counted for its climb (the zoom out of the gate before)
const DIVE_RUN := 8.0             ## m of a leg flown level at the window's height before the gate, at least ...
const DIVE_RUN_S := 0.9           ## ... s of it at the fastest racer's cruise (Envelope.dive_run: the falcon needs ~11 m)
const RARITY := {"trunk": 1.5, "hoop limb": 1.5, "hoop span": 0.5}   ## score for the kinds that fit in fewer places
const POST_TURN := 20.0           ## deg a post gate may be turned off its leg in, to find a clear way in
const SPACING := 10.0             ## m between any two gates
const POST_CLEAR := 1.0           ## m from a gate post
const ROPE_CLEAR := 1.5           ## m from any rope
const OWN_ROPE_CLEAR := 1.0       ## m from the ropes over the window it passes through
const SIGHT_BACK := 10.0
const NEXT_TWO_MAX := 60.0
const HALF := 1.5                 ## m: a window's half width and half height; a hoop's radius
const MARGIN := 0.6               ## m from a window's side to the post or trunk beside it
const BANNER := 0.3               ## m above the window
const POST_R := 0.1
const POST_LEVELS := [2.3, 7.0]   ## m above the ground: a post gate's window centre (low, tall)
const TRUNK_GAP := Vector2(3.6, 6.0)   ## m, trunk surface to trunk surface
const SPAN := Vector2(8.0, 16.0)       ## m between the trunks a hoop's rope is strung between
const HOOP_DROP := 1.0            ## m from the limb or span rope down to the hoop's top
const LEVELS := [2.5, 5.0, 8.0, 11.0, 14.0, 17.0, 20.0]   ## m: window centres tried on trunks and spans
const CELL := 20.0
const ENTRY_RUNS := 1.5           ## turning circles of clear straight in front of each window
const EXIT_RUNS := 0.8            ## ... and past it
const WING_MARGIN := 0.4          ## m beyond half a wingspan the flown line keeps from wood
const RIM_LANE := 3.0             ## m either side of the window its edges' lanes run clear
const CURVE_STEPS := 10           ## chords of a leg's flown line
const MISS_NEAR := 10.0           ## m: crossing a gate's plane this close outside its window is a miss
const ROUTE_MIN := 24.0           ## m in plan: a leg shorter than this is never routed (it must curve clear)
const HOME_MAX := 45.0            ## m in plan from the last gate to the rail (the way home, flown and landed)
const HOME_REACH := 25.0          ## m toward home a leg can be counted on to make: every gate stays within reach of it
const HOME_PULL := 5              ## the last this many legs are scored for heading home
const HOME_OUT := 15.0            ## m further out in front of the run-in the last legs head for
const WIND_MAX := 200.0           ## deg the course may wind round one way in all (home from in front: about 180)
const HOME_LEAVE := 90.0          ## deg at most the way home turns from the last gate's way through
const HOME_TURN_IN := 120.0       ## deg at most from the way home onto the rail's run-in, at its start
## A figure-eight course (a style's "eight"): two lobes (circles) joined by the two lines through the 8's middle that
## touch both, crossing there. The way out from the rail runs on along the first of them, past where it touches the
## second lobe (EIGHT_LEAD m out), through the middle, round the first lobe, back through the middle across the way
## out, and round the second lobe the other way until it heads home from in front of the rail (_guide_for). Its way out
## leaves EIGHT_BEARING off the rail's facing, to the side away from the second lobe (straighter, the second lobe swings
## round behind the rail); tried round the EIGHT_STARTS nearest rails, either lobe first, each rail's EIGHT_TRIES with a
## candidate gate near the most of their way (_eight_guides), the seed's rail first. The search keeps each gate within
## EIGHT_OFF m of the guide (free within EIGHT_SLACK), a little further along it than the last, the last within
## EIGHT_END of its end; a course of EIGHT_GATES - EIGHT_SHORT gates or more that has crossed itself and keeps the way
## home's rules is a figure-eight.
const EIGHT_SHAPES := [[22.0, 22.0, 90.0], [24.0, 24.0, 90.0], [26.0, 22.0, 90.0], [20.0, 20.0, 90.0], [24.0, 20.0, 100.0]]   ## [first lobe's radius, second's, crossing deg]: wide enough for 12-24 m legs (16 m turns ~40 deg on 22)
const EIGHT_LEAD := [6.0, 12.0]   ## m from the rail along the way out to where it touches the second lobe
const EIGHT_BEARING := [30.0, 45.0, 60.0]   ## deg the way out leaves off the rail's facing, away from the second lobe
const EIGHT_TRIES := 6            ## guides tried from each rail
const EIGHT_OFF := 20.0           ## m off the guide a gate may be at most ...
const EIGHT_SLACK := 6.0          ## ... at no cost within this ...
const EIGHT_COST := 3.0           ## ... and a point of its score for each this many m further
const EIGHT_END := 14.0           ## m from the guide's end the last gate may be
const EIGHT_GATES := 18           ## gates a figure-eight has at most (its style's gate count otherwise) ...
const EIGHT_SHORT := 4            ## ... and this many fewer at least, ending where it has crossed itself and home is clear
const EIGHT_STARTS := 2           ## the rails a figure-eight is tried from (nearest the middle first)
const HOME_NEAR := 3.0            ## m from the rail within which its own tree and outpost don't count on the line home


## What the course is planned for: the widest-turning and widest-winged of the birds racing it (by default all five:
## the hawk turns widest, ~6.9 m at cruise, and spans 1.3 m).
class Envelope:
	var turn_r := 0.0      ## m: the widest cruise turning circle (AIPilot.cruise_turn_radius)
	var half_span := 0.0   ## m: half the widest wingspan
	var v_fast := 0.0      ## m/s: the fastest cruise (v*)
	var birds: Array = []

	static func of(ids: Array) -> Envelope:
		var e := Envelope.new()
		e.birds = ids.duplicate()
		for id in ids:
			var p := BirdProfile.by_id(id)
			e.turn_r = maxf(e.turn_r, AIPilot.cruise_turn_radius(p))
			e.half_span = maxf(e.half_span, p.span * 0.5)
			e.v_fast = maxf(e.v_fast, p.v_best)
		return e

	## m flown level at the window's height before a gate after a dive (settled out of it)
	func dive_run() -> float:
		return maxf(DIVE_RUN, v_fast * DIVE_RUN_S)

	## m of straight, clear run in front of a gate's window (ENTRY_RUNS turning circles: rolled out and lined up)
	func entry() -> float:
		return maxf(6.0, turn_r * ENTRY_RUNS)

	## m of it past the window (before the bird turns for the next gate)
	func exit() -> float:
		return maxf(4.0, turn_r * EXIT_RUNS)

	## m the flown line keeps from wood: half a wingspan and a margin
	func clearance() -> float:
		return half_span + WING_MARGIN


class Gate:
	var kind := "post"           ## "post" | "trunk" | "hoop"
	var hang := ""               ## a hoop's: "limb" | "span"
	var centre := Vector3.ZERO
	var normal := Vector3.FORWARD   ## horizontal: the way through
	var half_w := HALF           ## the window's half width (a hoop's radius)
	var half_h := HALF
	var poles: Array[Vector2] = []   ## post and trunk gates: the axes either side (xz)
	var pole_r: Array[float] = []
	var anchor := Vector3.ZERO   ## a limb hoop: where its ropes meet the limb
	var span: Array[Vector3] = []   ## a span hoop: the rope's ends on the two trunks
	var trees: Array[int] = []   ## the trees it hangs on, or (post) its posts once applied
	var post_h := 0.0            ## m: a post gate's posts' height
	var marked := false          ## the turn here is too tight to see the gate after it: needs course markers

	func round_window() -> bool:
		return kind == "hoop"

	func right() -> Vector3:
		return normal.cross(Vector3.UP).normalized()

	## Is `p` (on the gate's plane) inside the window?
	func inside(p: Vector3) -> bool:
		var o := p - centre
		var x := o.dot(right())
		if kind == "hoop":
			return x * x + o.y * o.y <= half_w * half_w
		return absf(x) <= half_w and absf(o.y) <= half_h

	## Where along a -> b (0..1) the move goes through the window the way the gate faces, or -1.
	func crossing(a: Vector3, b: Vector3) -> float:
		var da := (a - centre).dot(normal)
		var db := (b - centre).dot(normal)
		if not (da < 0.0 and db >= 0.0):
			return -1.0
		var f := da / (da - db)
		return f if inside(a.lerp(b, f)) else -1.0

	## Did a -> b cross the gate's plane the way it faces outside the window, within MISS_NEAR of it?
	func missed(a: Vector3, b: Vector3) -> bool:
		var da := (a - centre).dot(normal)
		var db := (b - centre).dot(normal)
		if not (da < 0.0 and db >= 0.0):
			return false
		var p := a.lerp(b, da / (da - db))
		return not inside(p) and p.distance_to(centre) < MISS_NEAR

	## Four points round the window, just inside it: right, left, top, bottom.
	func rim() -> Array[Vector3]:
		var r := right()
		return [centre + r * half_w * 0.85, centre - r * half_w * 0.85, centre + Vector3.UP * half_h * 0.85, centre - Vector3.UP * half_h * 0.85]

	## The banner's height (post and trunk gates).
	func banner_y() -> float:
		return centre.y + half_h + BANNER

	## The ropes as segments [a, b]: a post or trunk gate's banner; a hoop's hanging ropes (and a span hoop's span).
	func ropes() -> Array:
		var out := []
		if kind == "hoop":
			var top := centre + Vector3.UP * (half_h + HOOP_DROP)
			var hang_from := anchor if hang == "limb" else top
			for s: float in [-1.0, 1.0]:
				var at := centre + right() * s * sin(deg_to_rad(40.0)) * half_w + Vector3.UP * cos(deg_to_rad(40.0)) * half_h
				out.append([hang_from, at])
			if hang == "span":
				out.append([span[0], span[1]])
			return out
		var y := banner_y()
		out.append([Vector3(poles[0].x, y, poles[0].y), Vector3(poles[1].x, y, poles[1].y)])
		return out

	## Turn a post gate to face `n` (its posts move with it).
	func face(n: Vector3, ground_y: float) -> void:
		normal = n
		if kind != "post":
			return
		var r := right() * (half_w + MARGIN + POST_R)
		poles = [Vector2(centre.x + r.x, centre.z + r.z), Vector2(centre.x - r.x, centre.z - r.z)]
		pole_r = [POST_R, POST_R]
		post_h = centre.y - ground_y + half_h + BANNER + 0.3

	func describe() -> String:
		return "%s%s" % [kind, (" " + hang) if hang != "" else ""]


var layout: ArenaLayout
var seed := 0
var envelope := Envelope.of(BirdProfile.IDS)
var style := ""                  ## STYLES' (or "": the all-round course)
var gate_count := GATES          ## gates (the style's)
var leg_range := LEG             ## m in plan from a gate to the next (the style's)
var _shape: Dictionary = SHAPES[""]
var _heights: Dictionary = HEIGHTS[""]
var _planner: FlightPlanner      ## (routed legs) the AI's route planner, at the course's clearance
var _routes := {}                ## leg key -> its routed line (empty: none, the smooth curve)
var _guide := PackedVector2Array()   ## (a figure-eight) the line the search follows, in plan, from the rail ...
var _guide_s := PackedFloat32Array() ## ... and the m along it at each point
var eight := false               ## planned as a figure-eight (it crosses itself: crossings())
var start: Perch
var gates: Array[Gate] = []
var build_ms := 0.0
static var debug := false        ## print the build's progress
static var eights := true        ## a style's "eight" planned as one (off: the free search's course, for an A/B)
static var debug_eight := -1     ## (debug) keep the figure-eight try of this number, whatever it makes

var _pool: Array[Gate] = []      ## candidate gates (post ones unturned)
var _valid := {}                 ## candidate index -> bool (checked when first wanted)
var _hash := {}                  ## Vector2i -> candidate indices
var _pads := {}                  ## Vector3i (LEAF_CELL) -> the needle pads [centre, radii] whose box touches it
const LEAF_CELL := 3.0
var _rng := RandomNumberGenerator.new()
var why := {}                    ## (debug) how many options each rule turned away


## The course for `l` (seed `s`): gates and start; apply() then puts its posts into the layout.
static func generate(l: ArenaLayout, s: int, birds: Array = BirdProfile.IDS, style_name := "") -> RaceCourse:
	var c := RaceCourse.new()
	c.layout = l
	c.seed = s
	c.set_style(style_name)
	c.envelope = Envelope.of(c._shape.get("birds", birds))
	c._rng.seed = s * 7919 + 17
	var t0 := Time.get_ticks_usec()
	c._index_pads()
	var t1 := Time.get_ticks_usec()
	c._candidates()
	var t2 := Time.get_ticks_usec()
	if debug:
		print("RaceCourse: pads %.0f ms, %d candidates %.0f ms" % [(t1 - t0) / 1000.0, c._pool.size(), (t2 - t1) / 1000.0])
	# From the outpost nearest the middle; if no full course leaves it, from the next one out (the best course found).
	var best: Array[Gate] = []
	var best_start: Perch = null
	var starts := starts_for(l)
	if c._shape.get("eight", false) and eights:   # (a figure-eight if one fits, round any of the guides from the nearest starts)
		c.gate_count = EIGHT_GATES
		var guides := []   # (each start's best in turn, the seed's start first: courses round both)
		var near := starts.slice(0, EIGHT_STARTS)
		for k in near.size():
			c.start = near[(k + s) % near.size()]
			for t in c._eight_guides():
				t.start = c.start
				guides.append(t)
		for k in guides.size():
			var t: Dictionary = guides[k]
			c.start = t.start
			c._guide_for(t)
			c._search()
			if debug:
				print("RaceCourse: eight %d from %d (%.2f): %d gates, %d crossings, %s" % [k, c.start.id, t.score, c.gates.size(), c.crossings(), str(c.problems().slice(0, 2))])
			if k == debug_eight or (c.gates.size() >= c.gate_count - EIGHT_SHORT and c.crossings() > 0 and c.problems().is_empty()):
				best = c.gates
				best_start = c.start
				c.eight = true
				break
		if not c.eight:
			c._guide_for({})
			c.gate_count = c._shape.gates
	for st in (starts if not c.eight else []):
		c.start = st
		c._search()
		if c.gates.size() > best.size():
			best = c.gates
			best_start = st
		if best.size() >= c.gate_count:
			break
	c.start = best_start if best_start != null else l.start_perch()
	c.gates = best
	if c.eight:
		c.gate_count = best.size()
	c.build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return c


## Take style `name` ("<shape>-<heights>", or "").
func set_style(name: String) -> void:
	style = name
	var shape := name.get_slice("-", 0) if name != "" else ""
	var heights := name.substr(shape.length() + 1) if name != "" else ""
	assert(SHAPES.has(shape) and HEIGHTS.has(heights), "a course style: %s" % name)
	_shape = SHAPES[shape]
	_heights = HEIGHTS[heights]
	leg_range = _shape.leg
	gate_count = _shape.gates


## Where a course may start, best first: the outposts' rails, nearest the middle of the wood first (a deck faces open
## air: Pinewood's outposts keep a clear way in), or the layout's start perch if it has none.
static func starts_for(l: ArenaLayout) -> Array[Perch]:
	var out: Array[Perch] = []
	for o in l.outposts:
		if o.rail_perch_id >= 0:
			out.append(l.perches[o.rail_perch_id])
	out.sort_custom(func(a: Perch, b: Perch): return Vector2(a.position.x, a.position.z).length() < Vector2(b.position.x, b.position.z).length())
	if out.is_empty():
		out.append(l.start_perch())
	return out


## A course from gates placed by hand (tests).
static func from_gates(l: ArenaLayout, st: Perch, gs: Array[Gate]) -> RaceCourse:
	var c := RaceCourse.new()
	c.layout = l
	c.start = st
	c.gates = gs
	return c


## Put the post gates' posts into the layout (solid wood: collision, the AI's avoidance, the reflexes). Before the
## arena is built.
func apply(l: ArenaLayout) -> void:
	for g in gates:
		if g.kind == "post" and g.trees.is_empty():
			for i in 2:
				g.trees.append(l.add_post(g.poles[i], g.post_h, POST_R).id)


# --- Candidates ---------------------------------------------------------------------------------------------

func _candidates() -> void:
	var l := layout
	var lim := l.boundary - 8.0
	var pines := []
	for t in l.trees:
		if t.kind == ArenaLayout.Kind.PINE:
			pines.append(t)
	for t in pines:
		for u in l.trees_near_segment(Vector3(t.base.x, 0.0, t.base.y), Vector3(t.base.x, 0.0, t.base.y), SPAN.y):
			if u.kind != ArenaLayout.Kind.PINE or u.id <= t.id:
				continue
			var d: float = t.base.distance_to(u.base)
			var mid: Vector2 = (t.base + u.base) * 0.5
			if mid.length() > lim:
				continue
			var along: Vector2 = (u.base - t.base) / d
			var n := Vector3(-along.y, 0.0, along.x)
			var top := minf(t.crown_base, u.crown_base) - 0.5
			var gap: float = d - t.radius - u.radius
			if gap >= TRUNK_GAP.x and gap <= TRUNK_GAP.y:
				var c2: Vector2 = t.base + along * (t.radius + gap * 0.5)
				for y: float in LEVELS:
					var gy := l.ground(c2.x, c2.y)
					if gy + y - HALF < gy + 0.8 or gy + y + HALF + BANNER > top:
						continue
					var g := Gate.new()
					g.kind = "trunk"
					g.centre = Vector3(c2.x, gy + y, c2.y)
					g.normal = n
					g.half_w = gap * 0.5 - MARGIN
					g.poles = [t.base, u.base]
					g.pole_r = [t.radius, u.radius]
					g.trees = [t.id, u.id]
					_add(g)
			if d >= SPAN.x and d <= SPAN.y:
				for y: float in LEVELS:
					var gy := l.ground(mid.x, mid.y)
					var rope_y := gy + y + HALF + HOOP_DROP
					if gy + y - HALF < gy + 0.8 or rope_y > top:
						continue
					var g := Gate.new()
					g.kind = "hoop"
					g.hang = "span"
					g.centre = Vector3(mid.x, gy + y, mid.y)
					g.normal = n
					g.span = [Vector3(t.base.x, rope_y, t.base.y), Vector3(u.base.x, rope_y, u.base.y)]
					g.trees = [t.id, u.id]
					_add(g)
	# Hoops hung from long, nearly level limbs: far enough out that the hoop clears the trunk.
	for t in l.trees:
		if t.kind != ArenaLayout.Kind.PINE and t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		for br in t.branches:
			if not br.solid:
				continue
			var dir: Vector3 = br.tip - br.root
			var flat := Vector2(dir.x, dir.z)
			if flat.length() < 0.5 or absf(dir.y) / flat.length() > 0.35:
				continue
			var axis := Vector2(t.base.x, t.base.y)
			var want := HALF + 1.4
			var r0 := Vector2(br.root.x, br.root.z).distance_to(axis)
			var r1 := Vector2(br.tip.x, br.tip.z).distance_to(axis)
			if r1 < want + 0.2 or r1 <= r0:
				continue
			var at: Vector3 = br.root.lerp(br.tip, clampf((want - r0) / (r1 - r0), 0.0, 1.0)) + Vector3.DOWN * br.radius
			var c3 := at + Vector3.DOWN * (HOOP_DROP + HALF)
			if c3.y - HALF < l.ground(c3.x, c3.z) + 0.8 or Vector2(c3.x, c3.z).length() > lim:
				continue
			var g := Gate.new()
			g.kind = "hoop"
			g.hang = "limb"
			g.centre = c3
			g.normal = Vector3(-flat.y, 0.0, flat.x).normalized()
			g.anchor = at
			g.trees = [t.id]
			_add(g)
	# Post gates on open ground: wherever a window fits facing any way.
	var step := 6.0
	var x := -lim
	while x <= lim:
		var z := -lim
		while z <= lim:
			var p := Vector2(x, z) + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0))
			if p.length() < lim:
				for lv: float in POST_LEVELS:
					var gy := l.ground(p.x, p.y)
					var g := Gate.new()
					g.kind = "post"
					g.centre = Vector3(p.x, gy + lv, p.y)
					g.face(Vector3.FORWARD, gy)
					_add(g)
			z += step
		x += step


func _add(g: Gate) -> void:
	var i := _pool.size()
	_pool.append(g)
	var k := Vector2i(floori(g.centre.x / CELL), floori(g.centre.z / CELL))
	if not _hash.has(k):
		_hash[k] = []
	_hash[k].append(i)


func _near(p: Vector3, r: float) -> Array:
	var out := []
	var c0 := Vector2i(floori((p.x - r) / CELL), floori((p.z - r) / CELL))
	var c1 := Vector2i(floori((p.x + r) / CELL), floori((p.z + r) / CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			out.append_array(_hash.get(Vector2i(cx, cz), []))
	return out


## Is candidate `i`'s window clear of wood, and the lane through it (checked once, when first wanted)?
func _ok(i: int) -> bool:
	if not _valid.has(i):
		_valid[i] = window_clear(_pool[i])
	return _valid[i]


## The window and the lane 5 m either side of it free of wood (a post gate: for any way it faces, and its posts
## standing clear).
func window_clear(g: Gate) -> bool:
	var l := layout
	var c := g.centre
	if g.kind == "post":
		var reach := g.half_w + MARGIN + POST_R + 0.4
		for dy: float in [-g.half_h, 0.0, g.half_h]:
			if not l.clear_by(c + Vector3.UP * dy, reach):
				return false
		return l.clear_by(Vector3(c.x, l.ground(c.x, c.z) + g.post_h, c.z), reach)
	var r := g.right()
	var n := g.normal
	if not l.segment_clear(c - n * 5.0, c + n * 5.0, 1.0):
		return false
	for f: float in [-0.85, 0.0, 0.85]:
		var half := g.half_w * (sqrt(1.0 - f * f) if g.round_window() else 1.0)
		var y := c + Vector3.UP * g.half_h * f
		if not l.segment_clear(y - r * half, y + r * half, 0.25):
			return false
	if g.kind == "hoop" and not l.clear_by(c, g.half_w + 0.3):
		return false
	return true


# --- The search ---------------------------------------------------------------------------------------------

class Plan:
	var gates: Array[Gate] = []
	var used := {}
	var score := 0.0
	var along := 0.0               ## (a figure-eight) m along the guide its last gate is
	var turns: Array[float] = []   ## signed turn at each gate after the first (deg, + left)


func _search() -> void:
	var got := _beam()
	gates = got[0]
	_turn_posts()


## The beam search from the start: [gates, score] of the best plan found.
func _beam() -> Array:
	var beams: Array[Plan] = [Plan.new()]
	var best: Plan = null
	var done: Plan = null
	for k in gate_count:
		var grown: Array[Plan] = []
		for b in beams:
			grown.append_array(_grow(b))
		if debug:
			print("RaceCourse: gate %d, %d plans, %d checked, %d ms" % [k, grown.size(), _valid.size(), Time.get_ticks_msec()])
		if grown.is_empty():
			break
		grown.sort_custom(func(x: Plan, y: Plan): return x.score > y.score)
		if not _guide.is_empty() and k + 1 >= gate_count - EIGHT_SHORT and k + 1 < gate_count:
			for p in grown:   # (a figure-eight may end once it has crossed itself, wherever home is clear)
				if (done == null or p.gates.size() > done.gates.size() or p.score > done.score) and crossings_of(p.gates) > 0 and home_problem(p.gates) == "":
					done = p
		beams = []
		var lasts := {}
		for p in grown:
			var key: int = p.used.keys()[-1]
			if lasts.has(key):
				continue
			lasts[key] = true
			beams.append(p)
			if beams.size() >= BEAM:
				break
		for p in beams:
			var s := p.score + _finish_score(p)
			if best == null or p.gates.size() > best.gates.size() or (p.gates.size() == best.gates.size() and s > best.score + _finish_score(best)):
				best = p
	if best == null:
		return [[] as Array[Gate], -INF]
	if done != null and best.gates.size() < gate_count:
		return [done.gates, done.score + _finish_score(done)]
	return [best.gates, best.score + _finish_score(best)]


## A plan's whole-course score: heights spread, both turn directions, every kind.
func _finish_score(p: Plan) -> float:
	var lo := INF
	var hi := -INF
	var kinds := {}
	for g in p.gates:
		lo = minf(lo, g.centre.y)
		hi = maxf(hi, g.centre.y)
		kinds[g.kind] = int(kinds.get(g.kind, 0)) + 1
	var s := (hi - lo) * float(_heights.spread) + kinds.size() * 1.5
	var left := p.turns.filter(func(t: float): return t > 15.0).size()
	var right := p.turns.filter(func(t: float): return t < -15.0).size()
	var wound := 0.0
	for t in p.turns:
		wound += t
	var posts: int = kinds.get("post", 0)
	return s + 3.0 * mini(left, right) - absf(wound) / 45.0 - maxf(posts - gate_count / 2.0, 0) * 1.5


## The plans one gate longer than `b`.
func _grow(b: Plan) -> Array[Plan]:
	var from := _from(b)
	var has_last := not b.gates.is_empty()
	var last_n: Vector3 = b.gates[-1].normal if has_last else Vector3.ZERO
	var opts := []
	var posts_so_far := b.gates.filter(func(g: Gate): return g.kind == "post").size()
	for i in _near(from, leg_range.y):
		if b.used.has(i):
			continue
		var last_leg := b.gates.size() == gate_count - 1
		var cand := _pool[i]
		var leg := cand.centre - from
		var plan := Vector2(leg.x, leg.z).length()
		if plan < leg_range.x or plan > leg_range.y:
			continue
		if not _grade_ok(leg.y, plan):   # (cheap first; the turn's share is checked once the gate's way is known)
			continue
		var ld := Vector3(leg.x, 0.0, leg.z) / plan
		var n: Vector3 = ld if cand.kind == "post" else (cand.normal if cand.normal.dot(ld) >= 0.0 else -cand.normal)
		if last_leg and cand.kind == "post":   # (the last post gate turned halfway to home)
			n = (ld + _flat(home_in() - cand.centre).normalized()).normalized()
		if rad_to_deg(n.angle_to(ld)) > ENTRY_DEG:
			continue
		var goal_in := home_in() + _flat(start.facing) * HOME_OUT   # (home from out in front: the side the rail faces)
		var home_d := Vector2(cand.centre.x - goal_in.x, cand.centre.z - goal_in.z).length()
		if home_d > HOME_MAX + (gate_count - 1 - b.gates.size()) * HOME_REACH * float(_shape.aim) / 25.0:
			continue   # (home out of reach of the legs left)
		if has_last and rad_to_deg(last_n.angle_to(ld)) > ENTRY_DEG:
			continue
		if not _grade_ok(leg.y, plan, turn_arc(last_n if has_last else start.facing, ld, n)):
			continue
		if not has_last and rad_to_deg(_flat(start.facing).angle_to(ld)) > START_DEG:
			continue
		var spaced := true
		for g in b.gates:
			if g.centre.distance_to(cand.centre) < SPACING:
				spaced = false
				break
		if not spaced:
			continue
		var turn := 0.0
		if b.gates.size() >= 1:
			var prev_from := _from_at(b, b.gates.size() - 1)
			var in_leg := b.gates[-1].centre - prev_from
			turn = rad_to_deg(AIPilot._signed_heading(Vector3(in_leg.x, 0.0, in_leg.z), ld)) * -1.0
		var on := 0.0   # (a figure-eight: m along the guide, and off it)
		var off := 0.0
		if not _guide.is_empty():
			var first := b.gates.is_empty()   # (the first gate: anywhere near the way out)
			var gu := _on_guide(cand.centre, 0.0 if first else b.along, b.along + leg_range.y * 2.0)
			var left_after := gate_count - 1 - b.gates.size()
			if gu[0] > EIGHT_OFF or _guide_s[-1] - gu[1] > left_after * leg_range.y + EIGHT_END:
				continue   # (off the guide, or its end out of reach)
			if last_leg and _guide_s[-1] - gu[1] > EIGHT_END:
				continue
			off = gu[0]
			on = gu[1]
		var aim: float = _shape.aim
		var s := -absf(plan - aim) / (aim * 0.4) + minf(absf(leg.y), 8.0) * float(_heights.dy) + _rng.randf() * 0.8 + float(RARITY.get(cand.describe(), 0.0))
		if cand.kind != "post":
			s += float(_shape.wood)
		s -= maxf(off - EIGHT_SLACK, 0.0) / EIGHT_COST
		if _guide.is_empty() and b.gates.size() >= gate_count - HOME_PULL:   # (the last legs: toward home's run-in)
			var pull := float(b.gates.size() - (gate_count - HOME_PULL) + 1) / HOME_PULL   # (stronger the nearer the end)
			s += pull * (Vector2(from.x - goal_in.x, from.z - goal_in.z).length() - home_d) / 5.0
		if cand.kind == "post" and posts_so_far >= gate_count / 2.0 - 1.0:
			s -= 2.0   # (posts fit anywhere: past half the course, the other kinds first)
		if not b.gates.is_empty():
			if cand.kind != b.gates[-1].kind:
				s += 1.0
			elif b.gates.size() >= 2 and b.gates[-2].kind == cand.kind:
				s -= 1.5
			if absf(turn) >= float(_shape.turn.x) and absf(turn) <= float(_shape.turn.y):
				s += 1.0
			if not b.turns.is_empty() and signf(turn) != signf(b.turns[-1]) and absf(turn) > 15.0 and _guide.is_empty():
				s += float(_shape.get("zigzag", 0.5))
			var wound := 0.0   # (the course's turning so far: turning back against it keeps it from spiralling)
			for t0 in b.turns:
				wound += t0
			# (Home is the way the rail faces from, so the course turns about half round in all, out and back: winding on
			# past WIND_MAX would bring it home from behind the rail.)
			if not _guide.is_empty():   # (a figure-eight winds round each lobe in turn: the guide says how far)
				pass
			elif absf(turn) > 15.0 and signf(turn) != signf(wound) and absf(wound) > WIND_MAX - 60.0:
				s += minf((absf(wound) - WIND_MAX + 120.0) / 60.0, 3.0)
			if _guide.is_empty() and absf(wound + turn) > WIND_MAX and absf(wound + turn) > absf(wound):
				s -= 1.5 + (absf(wound + turn) - WIND_MAX) / 30.0   # (winding on round one way)
		opts.append([s, i, n, turn, on])
	opts.sort_custom(func(x, y): return x[0] > y[0])
	var out: Array[Plan] = []
	var tried := 0
	for o in opts:
		if out.size() >= TAKE or tried >= TRIES:
			break
		var i: int = o[1]
		if not _ok(i):
			continue
		tried += 1
		var marked := absf(o[3]) > TIGHT_DEG
		var ways: Array = [o[2]]
		if _pool[i].kind == "post":   # (a post gate faces any way: turned a little, its way in may clear)
			ways.append((o[2] as Vector3).rotated(Vector3.UP, deg_to_rad(POST_TURN)))
			ways.append((o[2] as Vector3).rotated(Vector3.UP, deg_to_rad(-POST_TURN)))
			if not _guide.is_empty():   # (a figure-eight's lobes turn hard: a post turned further toward the turn)
				ways.append((o[2] as Vector3).rotated(Vector3.UP, deg_to_rad(2.0 * POST_TURN)))
				ways.append((o[2] as Vector3).rotated(Vector3.UP, deg_to_rad(-2.0 * POST_TURN)))
		var g: Gate = null
		var no := ""
		for way in ways:
			g = _oriented(_pool[i], way)
			no = _fits(b, g, marked)
			if no == "":
				break
		if no != "":
			why[no] = int(why.get(no, 0)) + 1
			continue
		var p := Plan.new()
		p.gates = b.gates.duplicate()
		if marked:
			var last := _copy(p.gates[-1])
			last.marked = true
			p.gates[-1] = last
		p.gates.append(g)
		p.used = b.used.duplicate()
		p.used[i] = true
		p.turns = b.turns.duplicate()
		if b.gates.size() >= 1:
			p.turns.append(o[3])
		p.score = b.score + float(o[0]) - (1.0 if marked else 0.0)
		p.along = o[4]
		out.append(p)
	return out


## Can a leg rising `dy` over `plan` m be flown: a climb at most CLIMB_MAX over the leg less CLIMB_RUN, a dive at most
## DIVE_MAX over the leg less the level run-in (Envelope.dive_run: the bird is down at the window's height that far
## before it)?
##   `arc`: m of the leg spent turning (turn_arc), which count for neither: a bird can't dive or climb steeply banked hard.
func _grade_ok(dy: float, plan: float, arc := 0.0) -> bool:
	if dy >= 0.0:
		return dy <= maxf(plan - CLIMB_RUN - arc, 0.0) * CLIMB_MAX + 1e-3
	return -dy <= maxf(plan - envelope.dive_run() - arc, 0.0) * DIVE_MAX + 1e-3


## m of a leg spent turning: from the way out of the gate before (`na`) to the leg's way (`ld`), then to the way into
## its gate (`nb`), on the widest turning circle the course is planned for.
func turn_arc(na: Vector3, ld: Vector3, nb: Vector3) -> float:
	return envelope.turn_r * (_flat(na).angle_to(ld) + ld.angle_to(_flat(nb)))


## Is leg `k`'s climb or dive flyable, the turn out of the gate before it left out (_grade_ok)?
func leg_grade_ok(all: Array, k: int) -> bool:
	var a := _from_at_all(all, k)
	var g: Gate = all[k]
	var leg := g.centre - a
	var plan := Vector2(leg.x, leg.z).length()
	var ld := Vector3(leg.x, 0.0, leg.z) / maxf(plan, 1e-3)
	var na: Vector3 = _flat(start.facing) if k == 0 else all[k - 1].normal
	return _grade_ok(leg.y, plan, turn_arc(na, ld, g.normal))


## Where the leg to the next gate of `b` starts: its last gate, or the start perch.
func _from(b: Plan) -> Vector3:
	return b.gates[-1].centre if not b.gates.is_empty() else start.position + Vector3.UP * 0.3


## Where the leg into gate `k` of `b` starts.
func _from_at(b: Plan, k: int) -> Vector3:
	return b.gates[k - 1].centre if k > 0 else start.position + Vector3.UP * 0.3


func _oriented(src: Gate, n: Vector3) -> Gate:
	var g := _copy(src)
	if g.kind == "post":
		g.face(n, layout.ground(g.centre.x, g.centre.z))
	else:
		g.normal = n
	return g


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


static func _copy(src: Gate) -> Gate:
	var g := Gate.new()
	g.kind = src.kind
	g.hang = src.hang
	g.centre = src.centre
	g.normal = src.normal
	g.half_w = src.half_w
	g.half_h = src.half_h
	g.poles = src.poles.duplicate()
	g.pole_r = src.pole_r.duplicate()
	g.anchor = src.anchor
	g.span = src.span.duplicate()
	g.trees = src.trees.duplicate()
	g.post_h = src.post_h
	g.marked = src.marked
	return g


## Does gate `g` fit as `b`'s next: its leg clear (of wood, posts and ropes), and seen in time? "" if so, else the rule
## it breaks.
func _fits(b: Plan, g: Gate, marked: bool) -> String:
	var all := b.gates.duplicate()
	all.append(g)
	var k := all.size() - 1
	if not leg_grade_ok(all, k):
		return "grade"
	if not lanes_clear(g):
		return "entry/exit"
	var line := flown_line(all, k)
	var routed := is_routed(all, k)
	if not routed and not turn_ok(all, k):
		return "turn"
	if not _line_clear(line, k):
		return "flown line"
	# Every leg's flown line against every gate's posts and ropes (the new one against all; the new gate's against all).
	for j in all.size():
		var lj := line if j == k else flown_line(all, j)
		for h in all.size():
			if h != k and j != k:
				continue
			if not _line_clear_of(lj, all[h], h == j):
				return "posts/ropes"
	# Sight: the new gate from the one before it (and from SIGHT_BACK before that on its way in) -- a routed leg's not
	# (through the wood, the HUD's arrow shows the way) ...
	if not routed and not _sees_from(_viewpoints(all, k - 1), g):
		return "sight"
	# ... and from the one before that, unless the turn between is tight.
	if not routed and k >= 1 and not marked:
		var far: Vector3 = all[k - 2].centre if k >= 2 else start.position + Vector3.UP * 0.3
		if far.distance_to(g.centre) > NEXT_TWO_MAX or not _sees(far, g):
			return "sight two back"
	if k == gate_count - 1:
		var why := home_problem(all)
		if why != "":
			var r := RegEx.create_from_string("[0-9.]+")
			return "home: " + r.sub(why, "#", true)
	return ""


## The figure-eights to try from the start, best first: [{x: the middle (in plan), u: its long axis toward the first
## lobe, m: 1 or -1 (which way round), r, r2: the first and second lobes' radii, cross: deg, score: the share of its
## way with a clear candidate gate near}], the EIGHT_TRIES best whose guide stays inside the arena and comes home.
func _eight_guides() -> Array:
	var o := Vector2(start.position.x, start.position.z)
	var f := Vector2(start.facing.x, start.facing.z).normalized()
	var scored := []
	for lead in EIGHT_LEAD:
		for bearing in EIGHT_BEARING:
			for m in [1.0, -1.0]:
				var e1 := f.rotated(deg_to_rad(-m * bearing))   # (the second lobe in front of the rail: straighter out, it swings round behind)
				for sh in EIGHT_SHAPES:
					var cross: float = sh[2]
					var psi := deg_to_rad(cross) * 0.5
					var x: Vector2 = o + e1 * (lead + float(sh[1]) / tan(psi))   # (the way out runs on along the 8's first line)
					var t := {"x": x, "u": e1.rotated(-m * psi), "m": m, "r": sh[0], "r2": sh[1], "cross": cross}
					_guide_for(t)
					if _guide.is_empty():
						continue
					var near := 0
					var n := 0
					var inside := true
					for i in _guide.size():
						if _guide[i].length() > layout.boundary - 6.0:
							inside = false
							break
						if i % 3 != 0 or _guide_s[i] < 8.0:
							continue
						n += 1
						var q := Vector3(_guide[i].x, 0.0, _guide[i].y)
						for j in _near(q, EIGHT_OFF):
							if Vector2(_pool[j].centre.x - q.x, _pool[j].centre.z - q.z).length() < EIGHT_OFF * 0.7 and _ok(j):
								near += 1
								break
					if inside and n > 0:
						t.score = float(near) / n + _rng.randf() * 0.05
						scored.append(t)
	scored.sort_custom(func(p, q): return p.score > q.score)
	if debug:
		print("RaceCourse: eights from %d: %d of them fit" % [start.id, scored.size()])
	return scored.slice(0, EIGHT_TRIES)


## Set the figure-eight guide `t` (_eight_guides' terms; {}: none): from the rail straight out to the middle `x`, along
## the line through it to the first lobe (a circle of `r`), round it (turning by 180 + `cross` deg), back through the
## middle across the way out, round the second lobe (of `r2`) the other way as far as it heads home best (empty if it
## never heads home, near enough).
func _guide_for(t: Dictionary) -> void:
	_guide = PackedVector2Array()
	_guide_s = PackedFloat32Array()
	if t.is_empty():
		return
	var x: Vector2 = t.x
	var u: Vector2 = t.u
	var v: Vector2 = u.rotated(PI / 2.0) * float(t.m)
	var r: float = t.r
	var r2: float = t.r2
	var psi := deg_to_rad(float(t.cross)) * 0.5
	var at := func(p: Vector2) -> Vector2: return x + u * p.x + v * p.y   # (the 8's own frame: x along u, y along v)
	var o := Vector2(start.position.x, start.position.z)
	var pts := PackedVector2Array()
	var line := func(a: Vector2, b: Vector2) -> void:
		var n := maxi(int(a.distance_to(b) / 2.0), 1)
		for i in n:
			pts.append(a.lerp(b, float(i) / n))
	# (Each lobe's centre is r / sin(psi) out from the middle along the 8's axis; the lines through the middle touch it
	# r / tan(psi) from the middle.)
	line.call(o, x)
	line.call(x, at.call(Vector2(cos(psi), sin(psi)) * r / tan(psi)))
	var steps := int((PI + 2.0 * psi) * r / 2.0)
	for i in steps:   # (the first lobe, turning the way the 8's frame turns clockwise)
		var a := PI / 2.0 + psi - (PI + 2.0 * psi) * i / steps
		pts.append(at.call(Vector2(r / sin(psi), 0.0) + Vector2(cos(a), sin(a)) * r))
	line.call(at.call(Vector2(cos(psi), -sin(psi)) * r / tan(psi)), at.call(Vector2(-cos(psi), sin(psi)) * r2 / tan(psi)))
	var home := Vector2(home_in().x, home_in().z)
	var best := -1
	var best_cost := INF
	var steps2 := int((PI + 2.0 * psi) * r2 / 2.0)
	for i in steps2 + 1:   # (the second lobe, the other way, as far as it heads home best)
		var a := PI / 2.0 - psi + (PI + 2.0 * psi) * i / steps2
		var p: Vector2 = at.call(Vector2(-r2 / sin(psi), 0.0) + Vector2(cos(a), sin(a)) * r2)
		pts.append(p)
		var head: Vector2 = (u * -sin(a) + v * cos(a))   # (the way round: +a in the 8's frame)
		var to := home - p
		var off := rad_to_deg(head.angle_to(to))
		var turn_in := rad_to_deg(to.angle_to(-Vector2(start.facing.x, start.facing.z)))
		if float(i) / steps2 > 0.1 and absf(off) < 50.0 and absf(turn_in) < HOME_TURN_IN - 30.0 and to.length() < HOME_MAX - 5.0 and to.length() > 10.0:
			var cost := absf(off) + absf(turn_in) * 0.5 + to.length() * 0.5
			if cost < best_cost:
				best_cost = cost
				best = pts.size()
	if best < 0:
		return
	_guide = pts.slice(0, best)
	_guide_s.append(0.0)
	for i in range(1, _guide.size()):
		_guide_s.append(_guide_s[-1] + _guide[i].distance_to(_guide[i - 1]))


## How far `p` is from the guide between `s0` and `s1` m along it, and where: [m off it (in plan), m along].
func _on_guide(p: Vector3, s0: float, s1: float) -> Array:
	var q := Vector2(p.x, p.z)
	var best := [INF, s0]
	for i in range(maxi(_guide_s.bsearch(s0) - 1, 0), _guide.size() - 1):
		if _guide_s[i] > s1:
			break
		var c := Geometry2D.get_closest_point_to_segment(q, _guide[i], _guide[i + 1])
		var at := _guide_s[i] + c.distance_to(_guide[i])
		if at < s0 or at > s1:
			continue
		var off := c.distance_to(q)
		if off < best[0]:
			best = [off, at]
	return best


## How many times the course crosses itself in plan (its legs, gate centre to gate centre, from the rail and home to
## it, each against every leg but the ones either side).
func crossings() -> int:
	return crossings_of(gates)


## How many times gates `gs` cross themselves, from the rail and home (crossings()).
func crossings_of(gs: Array) -> int:
	var pts: Array[Vector2] = [Vector2(start.position.x, start.position.z)]
	for g in gs:
		pts.append(Vector2(g.centre.x, g.centre.z))
	pts.append(pts[0])
	var n := 0
	for i in pts.size() - 1:
		for j in range(i + 2, pts.size() - 1):
			if i == 0 and j == pts.size() - 2:
				continue   # (the way out and the way home meet at the rail)
			if Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], pts[j], pts[j + 1]) != null:
				n += 1
	return n


## Where the rail's run-in starts: out in front of it (the way it faces) by a turning circle and a half, a little
## below it (the landing comes up to the rail).
func home_in() -> Vector3:
	return start.position + _flat(start.facing) * envelope.entry() + Vector3.DOWN * 0.8


## What's wrong with the way home from the last of `all` to the rail ("" if nothing): at most HOME_MAX in plan; the
## rail in sight from the last gate; the straight line from it to the run-in's start (home_in) clear of the wood by
## half a wingspan and a margin and of every gate's posts and ropes, turning at most HOME_LEAVE from the last gate's way
## through and HOME_TURN_IN onto the run-in; the run-in itself clear (its last HOME_NEAR m by the rail's own tree and
## outpost aside); a climb the birds can make. No detour round a tree: home is straight there, then straight in.
func home_problem(all: Array) -> String:
	var last: Gate = all[-1]
	var rail := start.position + Vector3.UP * 0.3
	var a := home_in()
	var leg := a - last.centre
	var plan := Vector2(leg.x, leg.z).length()
	var ld := _flat(leg).normalized()
	var in_dir := -_flat(start.facing)
	if Vector2(rail.x - last.centre.x, rail.z - last.centre.z).length() > HOME_MAX:
		return "home %.0f m from the last gate" % Vector2(rail.x - last.centre.x, rail.z - last.centre.z).length()
	if plan > 1.0 and rad_to_deg(last.normal.angle_to(ld)) > HOME_LEAVE:
		return "home turns %.0f deg out of the last gate" % rad_to_deg(last.normal.angle_to(ld))
	if plan > 1.0 and rad_to_deg(ld.angle_to(in_dir)) > HOME_TURN_IN:
		return "home turns %.0f deg onto the rail's run-in" % rad_to_deg(ld.angle_to(in_dir))
	if not _grade_ok(rail.y - last.centre.y, plan + envelope.entry()):
		return "home climbs %.1f m in %.1f m" % [rail.y - last.centre.y, plan + envelope.entry()]
	var c := envelope.clearance()
	if not layout.segment_clear(last.centre + last.normal * 1.0, a, c):
		return "wood on the line home"
	if not layout.segment_clear(a, rail - in_dir * HOME_NEAR, c):
		return "the rail's run-in isn't clear"
	for g: Gate in all:
		if not _leg_clear_of(last.centre, a, g, g == last) or not _leg_clear_of(a, rail, g, false):
			return "the line home passes a gate's posts or ropes"
	if not line_of_sight(last.centre, rail):
		return "the rail not seen from the last gate"
	return ""


## Are gate `g`'s way in and out clear: ENTRY_RUNS turning circles of straight in front of it and EXIT_RUNS past it,
## by half a wingspan and a margin, and the lanes along the window's four edges RIM_LANE m either side?
func lanes_clear(g: Gate) -> bool:
	var n := g.normal
	if not layout.segment_clear(g.centre - n * envelope.entry(), g.centre + n * envelope.exit(), envelope.clearance()):
		return false
	for p in g.rim():
		if not layout.segment_clear(p - n * RIM_LANE, p + n * RIM_LANE, 0.15):
			return false
	return true


## The line a bird flies into gate `k`: leaving the gate before along its way through (or the start perch the way
## it faces), arriving along gate k's, a smooth curve between (a cubic Bezier, handles a third of the way); the height
## changing only once the turn is done (turn_arc), down to the window's height DIVE_RUN before it on a dive.
func flown_line(all: Array, k: int) -> PackedVector3Array:
	var smooth := smooth_line(all, k)
	if not bool(_shape.get("route", false)) or all[k].kind == "home":
		return smooth
	var key := _leg_key(all, k)
	if not _routes.has(key):
		var r := PackedVector3Array()
		var a := _from_at_all(all, k)
		if Vector2(all[k].centre.x - a.x, all[k].centre.z - a.z).length() >= ROUTE_MIN and not _line_clear(smooth, k):
			r = route_line(all, k)
		_routes[key] = r
	var got: PackedVector3Array = _routes[key]
	return got if got.size() > 0 else smooth


## Is leg `k` routed through the wood (flown_line is its route_line, not the smooth curve)?
func is_routed(all: Array, k: int) -> bool:
	flown_line(all, k)
	return (_routes.get(_leg_key(all, k), PackedVector3Array()) as PackedVector3Array).size() > 0


func _leg_key(all: Array, k: int) -> String:
	var a := _from_at_all(all, k)
	var na: Vector3 = _flat(start.facing) if k == 0 else all[k - 1].normal
	return "%s|%s|%s|%s" % [str(a.snapped(Vector3.ONE * 0.01)), str(na.snapped(Vector3.ONE * 0.01)), str(all[k].centre.snapped(Vector3.ONE * 0.01)), str(all[k].normal.snapped(Vector3.ONE * 0.01))]


## Leg `k` routed through the wood: straight out of the gate before along its way through (its exit lane), the flight
## planner's route (FlightPlanner: the AI's, through free air at the course's clearance) to the start of gate k's entry
## lane, straight in along its way through. Empty if there's no route, or it climbs or dives more steeply than a leg
## may.
func route_line(all: Array, k: int) -> PackedVector3Array:
	if _planner == null:
		_planner = FlightPlanner.new(layout, envelope.clearance())
	var a := _from_at_all(all, k)
	var na: Vector3 = _flat(start.facing) if k == 0 else all[k - 1].normal
	var g: Gate = all[k]
	var out_pt := a + na * envelope.exit()
	var in_pt := g.centre - g.normal * envelope.entry()
	var path := _planner.plan(out_pt, in_pt, start.tree_id if k == 0 else -1)
	if path.size() < 2:
		return PackedVector3Array()
	var pts := PackedVector3Array([a])
	for p in path:
		pts.append(p)
	pts.append(g.centre)
	for i in pts.size() - 1:
		var d := pts[i + 1] - pts[i]
		var run := Vector2(d.x, d.z).length()
		if d.y > run * CLIMB_MAX + 0.5 or -d.y > run * DIVE_MAX + 0.5:
			return PackedVector3Array()
	return pts


## The smooth line into gate `k` (a leg's flown line unless it's routed: flown_line).
func smooth_line(all: Array, k: int) -> PackedVector3Array:
	var a := _from_at_all(all, k)
	var na: Vector3 = _flat(start.facing) if k == 0 else all[k - 1].normal
	var b: Vector3 = all[k].centre
	var nb: Vector3 = all[k].normal
	var p0 := Vector2(a.x, a.z)
	var p3 := Vector2(b.x, b.z)
	var plan := p0.distance_to(p3)
	var h := plan / 3.0
	var p1 := p0 + Vector2(na.x, na.z).normalized() * h
	var p2 := p3 - Vector2(nb.x, nb.z).normalized() * h
	var arc := turn_arc(na, Vector3(p3.x - p0.x, 0.0, p3.y - p0.y).normalized(), nb)
	var pts := PackedVector3Array()
	for i in CURVE_STEPS + 1:
		var t := float(i) / CURVE_STEPS
		var q := (1.0 - t) * (1.0 - t) * (1.0 - t) * p0 + 3.0 * (1.0 - t) * (1.0 - t) * t * p1 + 3.0 * (1.0 - t) * t * t * p2 + t * t * t * p3
		var s0 := minf(arc / maxf(plan, 1.0), 0.9)   # (it turns first, then climbs or dives)
		var f := smoothstep(s0, maxf(1.0 - envelope.dive_run() / maxf(plan, 1.0), s0 + 0.05), t) if b.y < a.y else smoothstep(minf(s0 + CLIMB_RUN / maxf(plan, 1.0), 0.95), 1.0, t)
		pts.append(Vector3(q.x, lerpf(a.y, b.y, f), q.y))
	return pts


## Does leg `k`'s flown line turn no tighter than the widest turning circle the course is planned for?
func turn_ok(all: Array, k: int) -> bool:
	return _leg_radius(all, k) >= envelope.turn_r - 0.01


## The tightest radius of leg `k`'s flown line (in plan).
func _leg_radius(all: Array, k: int) -> float:
	var na: Vector3 = _flat(start.facing) if k == 0 else all[k - 1].normal
	return tightest_radius(_from_at_all(all, k), na, all[k].centre, all[k].normal)


## Is a flown line clear of the wood by half a wingspan and a margin (leg 0: the start perch's tree left out for its
## first metres)?
func _line_clear(line: PackedVector3Array, k: int) -> bool:
	var c := envelope.clearance()
	for i in line.size() - 1:
		var skip := start.tree_id if k == 0 and line[i].distance_to(line[0]) < 4.0 else -1
		if not layout.segment_clear(line[i], line[i + 1], c, skip):
			return false
	return true


## Is the flown line clear of gate `g`'s posts and ropes (`own`: the gate it ends at)?
func _line_clear_of(line: PackedVector3Array, g: Gate, own: bool) -> bool:
	for i in line.size() - 1:
		if not _leg_clear_of(line[i], line[i + 1], g, own):
			return false
	return true


func _from_at_all(all: Array, k: int) -> Vector3:
	return all[k - 1].centre if k > 0 else start.position + Vector3.UP * 0.3


## Where leg `k` (into gate k) starts: just out of the gate before it, or off the start perch.
func _leg_start(all: Array, k: int) -> Vector3:
	if k == 0:
		var to: Vector3 = all[0].centre - start.position
		return start.position + Vector3.UP * 0.3 + Vector3(to.x, 0.0, to.z).normalized() * 2.0
	return all[k - 1].centre + all[k - 1].normal * 2.0


## Is the leg a -> b clear of gate `g`'s posts and ropes (`own`: g is the gate the leg ends at, which it passes
## through between its posts)?
func _leg_clear_of(a: Vector3, b: Vector3, g: Gate, own: bool) -> bool:
	if g.kind == "post":
		for i in 2:
			var p0 := Vector3(g.poles[i].x, 0.0, g.poles[i].y)
			var p1 := p0 + Vector3.UP * (layout.ground(p0.x, p0.z) + g.post_h)
			var d := Geometry3D.get_closest_points_between_segments(a, b, p0, p1)
			if d[0].distance_to(d[1]) < (MARGIN if own else POST_CLEAR) + POST_R:
				return false
	for r in g.ropes():   # (its own: the ones over the window it flies through, a metre off at least)
		var d := Geometry3D.get_closest_points_between_segments(a, b, r[0], r[1])
		if d[0].distance_to(d[1]) < (OWN_ROPE_CLEAR if own else ROPE_CLEAR):
			return false
	return true


## Where gate k+1 must be seen from: gate k, and SIGHT_BACK m before it on the leg into it (the start: the perch).
func _viewpoints(all: Array, k: int) -> Array:
	if k < 0:
		return [start.position + Vector3.UP * 0.3]
	var at: Vector3 = all[k].centre
	var from := _leg_start(all, k)
	var back := at + (from - at).normalized() * minf(SIGHT_BACK, from.distance_to(at))
	return [at, back]


func _sees_from(views: Array, g: Gate) -> bool:
	for v in views:
		if not _sees(v, g):
			return false
	return true


## Can gate `g` be seen from `v`: its centre and at least 3 of the 4 points round its rim?
func _sees(v: Vector3, g: Gate) -> bool:
	if not line_of_sight(v, g.centre):
		return false
	var n := 0
	for p in g.rim():
		if line_of_sight(v, p):
			n += 1
		if n >= 3:
			return true
	return false


## Is the straight line from `a` to `b` clear of wood and needles (Pinewood._leaf_free's pads, by a grid of them)?
func line_of_sight(a: Vector3, b: Vector3) -> bool:
	if _pads.is_empty():
		_index_pads()
	if not layout.segment_clear(a, b, 0.02):
		return false
	var d := a.distance_to(b)
	var dir := (b - a) / d
	var s := 1.0
	while s < d - 1.0:
		var p := a + dir * s
		for f in _pads.get(Vector3i(floori(p.x / LEAF_CELL), floori(p.y / LEAF_CELL), floori(p.z / LEAF_CELL)), []):
			if ((p - (f[0] as Vector3)) / (f[1] as Vector3)).length() < 1.0:
				return false
		s += 0.75
	return true


func _index_pads() -> void:
	_pads = {"": []}   # (never empty once built, even with no foliage)
	for t in layout.trees:
		for f in t.foliage:
			var c: Vector3 = f[0]
			var r: Vector3 = f[1]
			var lo := ((c - r) / LEAF_CELL).floor()
			var hi := ((c + r) / LEAF_CELL).floor()
			for x in range(int(lo.x), int(hi.x) + 1):
				for y in range(int(lo.y), int(hi.y) + 1):
					for z in range(int(lo.z), int(hi.z) + 1):
						var k := Vector3i(x, y, z)
						if not _pads.has(k):
							_pads[k] = []
						_pads[k].append(f)


## Post gates turned to the bisector of their legs in and out (kept if a rule would break).
func _turn_posts() -> void:
	for k in gates.size():
		var g := gates[k]
		if g.kind != "post":
			continue
		var into := g.centre - (_leg_start_k(k))
		var n := Vector3(into.x, 0.0, into.z).normalized()
		var out := (gates[k + 1].centre if k + 1 < gates.size() else start.position) - g.centre   # (the last: home)
		n = (n + Vector3(out.x, 0.0, out.z).normalized()).normalized()
		var was := _copy(g)
		g.face(n, layout.ground(g.centre.x, g.centre.z))
		if not problems().is_empty():
			gates[k] = was


func _leg_start_k(k: int) -> Vector3:
	return _leg_start(gates, k)


# --- What a course is ---------------------------------------------------------------------------------------

## Everything about this course that breaks the rules (empty: none).
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for k in gates.size():
		var g := gates[k]
		var leg := g.centre - _from_k(k)
		var plan := Vector2(leg.x, leg.z).length()
		var ld := Vector3(leg.x, 0.0, leg.z) / maxf(plan, 1e-3)
		if g.kind != "post" and not window_clear(g):
			out.append("gate %d: wood in the window" % k)
		if g.kind == "post" and not window_clear(g):
			out.append("gate %d: wood by the posts" % k)
		if plan < leg_range.x - 0.01 or plan > leg_range.y + 0.01:
			out.append("gate %d: leg %.1f m" % [k, plan])
		if not leg_grade_ok(gates, k):
			out.append("gate %d: climbs %.1f m in %.1f m, turning" % [k, leg.y, plan])
		if rad_to_deg(g.normal.angle_to(ld)) > ENTRY_DEG + 0.01:
			out.append("gate %d: entered %.0f deg off" % [k, rad_to_deg(g.normal.angle_to(ld))])
		if k == 0 and rad_to_deg(_flat(start.facing).angle_to(ld)) > START_DEG + 0.01:
			out.append("gate 0: %.0f deg off the start perch's facing" % rad_to_deg(_flat(start.facing).angle_to(ld)))
		if k > 0 and rad_to_deg(gates[k - 1].normal.angle_to(ld)) > ENTRY_DEG + 0.01:
			out.append("gate %d: left %.0f deg off" % [k - 1, rad_to_deg(gates[k - 1].normal.angle_to(ld))])
		if not lanes_clear(g):
			out.append("gate %d: its way in or out isn't clear" % k)
		var routed := is_routed(gates, k)
		if not routed and not turn_ok(gates, k):
			out.append("gate %d: the line in turns at %.1f m, under %.1f" % [k, _leg_radius(gates, k), envelope.turn_r])
		var line := flown_line(gates, k)
		if not _line_clear(line, k):
			out.append("gate %d: wood on the line in" % k)
		for h in gates.size():
			if not _line_clear_of(line, gates[h], h == k):
				out.append("gate %d: line in passes gate %d's posts or ropes" % [k, h])
		for h in k:
			if gates[h].centre.distance_to(g.centre) < SPACING:
				out.append("gates %d and %d %.1f m apart" % [h, k, gates[h].centre.distance_to(g.centre)])
		if not routed and not _sees_from(_viewpoints(gates, k - 1), g):
			out.append("gate %d: not seen from the gate before" % k)
		if not routed and k >= 1 and not gates[k - 1].marked:
			var far: Vector3 = gates[k - 2].centre if k >= 2 else start.position + Vector3.UP * 0.3
			if far.distance_to(g.centre) > NEXT_TWO_MAX or not _sees(far, g):
				out.append("gate %d: not seen two gates back" % k)
	if not gates.is_empty():
		var why := home_problem(gates)
		if why != "":
			out.append("home: " + why)
	return out


func _from_k(k: int) -> Vector3:
	return gates[k - 1].centre if k > 0 else start.position + Vector3.UP * 0.3


## The course leg by leg: [{gate, kind, height (above the ground), plan (m), climb (deg), turn (deg at this gate, from
## the leg in to the leg out, + left), radius (m: the tightest turn of a smooth path from the gate before, leaving along its way
## through, to this one, entering along its)}].
func legs() -> Array:
	var out := []
	for k in gates.size():
		var g := gates[k]
		var p0 := _from_k(k)
		var leg := g.centre - p0
		var plan := Vector2(leg.x, leg.z).length()
		var ld := Vector3(leg.x, 0.0, leg.z) / plan
		var n0: Vector3 = gates[k - 1].normal if k > 0 else ld
		var turn := 0.0   # (at this gate: from the leg in to the leg out)
		if k + 1 < gates.size():
			var out_leg := gates[k + 1].centre - g.centre
			turn = -rad_to_deg(AIPilot._signed_heading(ld, Vector3(out_leg.x, 0.0, out_leg.z)))
		out.append({"gate": k, "kind": g.describe(), "height": g.centre.y - layout.ground(g.centre.x, g.centre.z),
			"plan": plan, "climb": rad_to_deg(atan2(leg.y, plan)), "turn": turn,
			"radius": tightest_radius(p0, n0, g.centre, g.normal), "marked": g.marked})
	return out


## The tightest radius (m, in plan) along a smooth path (a cubic Bezier, handles a third of the way) leaving `a`
## along `na` and arriving at `b` along `nb`.
static func tightest_radius(a: Vector3, na: Vector3, b: Vector3, nb: Vector3) -> float:
	var p0 := Vector2(a.x, a.z)
	var p3 := Vector2(b.x, b.z)
	var h := p0.distance_to(p3) / 3.0
	var p1 := p0 + Vector2(na.x, na.z).normalized() * h
	var p2 := p3 - Vector2(nb.x, nb.z).normalized() * h
	var best := INF
	for i in 41:
		var t := i / 40.0
		var d1 := 3.0 * (1.0 - t) * (1.0 - t) * (p1 - p0) + 6.0 * (1.0 - t) * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)
		var d2 := 6.0 * (1.0 - t) * (p2 - 2.0 * p1 + p0) + 6.0 * t * (p3 - 2.0 * p2 + p1)
		var k := absf(d1.x * d2.y - d1.y * d2.x) / pow(maxf(d1.length(), 1e-4), 3.0)
		if k > 1e-6:
			best = minf(best, 1.0 / k)
	return best


## The course's whole length (m, gate centre to gate centre from the start, and home to the rail).
func length() -> float:
	var s := 0.0
	for k in gates.size():
		s += _from_k(k).distance_to(gates[k].centre)
	if not gates.is_empty():
		s += gates[-1].centre.distance_to(start.position)
	return s
