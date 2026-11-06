class_name FlightPlanner
extends RefCounted
## Global route planning for AI birds (docs/design/flight_model.md, "AI pilot").
##
## Free air is sampled as a lattice (LATTICE m apart, at LEVELS heights). A node is usable if it is
## `clearance` from every trunk and branch; an edge is usable if the straight flight along it is (both from
## ArenaLayout's geometry, so planning needs no physics). A* runs from the bird to the perch's APPROACH
## POINT with an energy-aware cost: climbing a metre costs CLIMB_COST metres of flight (it takes flapping),
## descending is free height the bird gets to glide with. The result is string-pulled (any waypoint whose
## neighbours see each other is dropped) and ends with the perch itself.

const LATTICE := 6.0
const LEVELS: Array[float] = [3.0, 6.0, 10.0, 15.0, 21.0, 28.0, 36.0]
const CLIMB_COST := 4.0
const MAX_EXPANSIONS := 8000
## The tree a route leaves or lands on isn't ignored, just passed closer: this far, without the perch's own branch
## and the first PUSH_OFF metres (the bird passes through its own tree as it lets go) or the last ones (the catch).
const OWN_TREE_CLEARANCE := 0.4
const PUSH_OFF := 1.0
const START_CLEARANCE := 0.6   ## m: the closest a first leg out of a tight spot may pass the wood (the whiskers')

var layout: ArenaLayout
var clearance := 0.9
var _node_ok := {}      ## Vector3i -> bool
var _a_perch := -1      ## the perch the route leaves (its branch is skipped), for the plan in progress
var _b_perch := -1      ## the perch it lands on
var _a_through := false ## leaving through its own tree (no way out past it)
var way := Vector3.ZERO ## the way in the last plan_to_perch came in by (from the perch out)
var heading := Vector3.ZERO   ## the way the bird is flying (horizontal; zero: perched), for ways_in's choice ...
var turn_r := 0.0             ## ... and its turning circle there


func _init(l: ArenaLayout, c := 0.9) -> void:
	layout = l
	clearance = c


## Where the final approach starts: out from the perch along `dir` (the way in: default the perch's facing) and a little
## below it, so the bird dives under and swoops up into the perch (bleeding speed on the way up, as birds do).
static func approach_point(p: Perch, profile: BirdProfile, dir := Vector3.ZERO) -> Vector3:
	return p.approach_anchor() + _way(p, dir) * approach_length(profile) + Vector3.DOWN * approach_drop(profile)


## A point twice as far out, so the bird reaches the approach point already lined up with the perch.
static func pre_approach_point(p: Perch, profile: BirdProfile, dir := Vector3.ZERO) -> Vector3:
	return p.approach_anchor() + _way(p, dir) * approach_length(profile) * 2.0 + Vector3.DOWN * approach_drop(profile) * 0.5


## m below the perch the final swoop starts: the height a bird gliding at its best speed zooms up as it slows to its
## catch speed (catch_speed), less what the drag takes (ZOOM_KEPT) -- a falcon's ~1.9 m, a sparrow's ~0.7. A bird
## that can't climb the swoop arrives under the branch; one that starts too high arrives too fast.
static func approach_drop(profile: BirdProfile) -> float:
	var v := catch_speed(profile)
	return clampf((profile.v_best * profile.v_best - v * v) / (2.0 * BirdProfile.G) * ZOOM_KEPT, DROP.x, DROP.y)


## m/s: the speed to arrive at a perch at -- the middle of the bird's window between its stall and the fastest it can
## catch at.
static func catch_speed(profile: BirdProfile) -> float:
	return (profile.v_stall + profile.grab_speed_max) * 0.5


const ZOOM_KEPT := 0.6           ## share of the zoom's height the drag leaves it
const DROP := Vector2(0.6, 2.5)  ## m: the approach drop at least and at most


static func _way(p: Perch, dir: Vector3) -> Vector3:
	return dir if dir != Vector3.ZERO else p.facing


static func approach_length(profile: BirdProfile) -> float:
	return maxf(6.0, profile.v_best * 0.8)


## The ways in to perch `p` (horizontal, from the perch out to where the approach starts), the side `from` is on first:
## a branch's from either side across it, square on and WAY_SKEW deg either way (along it the trunk or the tip is in
## the way); a treetop's from every side. Given the way the bird is flying (`heading`) and its turning circle (`turn_r`),
## the one it can line up on soonest first instead: the shortest turn-straight-turn path (Dubins) from `from` to each
## one's approach point, heading in -- near it (LINEUP_NEAR turning circles), one whose path is clear of `layout`'s wood
## before one whose isn't.
static func ways_in(p: Perch, from: Vector3, profile: BirdProfile = null, heading := Vector3.ZERO, turn_r := 0.0, layout: ArenaLayout = null, clearance := 0.9) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if p.kind == Perch.Kind.TREETOP:
		for k in 8:
			out.append(p.facing.rotated(Vector3.UP, TAU * k / 8.0))
	else:
		for side: float in [1.0, -1.0]:
			for skew: float in [0.0, WAY_SKEW, -WAY_SKEW]:
				out.append((p.facing * side).rotated(Vector3.UP, deg_to_rad(skew)))
	var to := Vector3(from.x - p.position.x, 0.0, from.z - p.position.z)
	if profile != null and heading != Vector3.ZERO and turn_r > 0.0:
		var cost := {}
		for d in out:
			var app := approach_point(p, profile, d)
			if on_line(p, profile, d, from, heading):
				cost[d] = Vector2(app.x - from.x, app.z - from.z).length()   # (in on it already: straight in)
				continue
			var ways := Dubins.all(Vector2(from.x, from.z), Vector2(heading.x, heading.z).normalized(), Vector2(app.x, app.z), Vector2(-d.x, -d.z).normalized(), turn_r)
			cost[d] = (ways[0] as PackedVector2Array).size() if not ways.is_empty() else INF
			if layout != null and cost[d] < INF and Vector2(app.x - from.x, app.z - from.z).length() < LINEUP_NEAR * turn_r + LINEUP_NEAR_PAD \
					and not _turn_clear(layout, ways[0], from.y, maxf(app.y, clearance + 0.5), AIPilot.lineup_clearance(profile)):
				cost[d] += BLOCKED_LINEUP   # (near: a way in it can't turn onto clear of the wood comes after those it can)
		out.sort_custom(func(x: Vector3, y: Vector3): return cost[x] < cost[y])
	elif to.length() > 0.5:
		var t := to.normalized()
		out.sort_custom(func(x: Vector3, y: Vector3): return x.dot(t) > y.dot(t))
	return out


## Is a bird at `from` flying `heading` already on the way in `d` to perch `p`: out in front of the perch along it (at
## least half the approach's length), nose within ON_LINE_DEG of it, and as near its line as the final can correct?
static func on_line(p: Perch, profile: BirdProfile, d: Vector3, from: Vector3, heading: Vector3) -> bool:
	var to := p.approach_anchor() - from
	var inward := -Vector3(d.x, 0.0, d.z).normalized()
	var along := Vector3(to.x, 0.0, to.z).dot(inward)
	var side := (Vector3(to.x, 0.0, to.z) - inward * along).length()
	return along > approach_length(profile) * 0.5 and heading.dot(inward) > cos(deg_to_rad(ON_LINE_DEG)) and side < ON_LINE_SIDE + along * 0.15


const ON_LINE_DEG := 25.0
const ON_LINE_SIDE := 1.0        ## m off the line (and 15% of the way in) a bird on the way in may be


## Is the turn-straight-turn path `flat` (x, z points; its height eased from `y0` to `y1`) clear of the wood by `c`?
static func _turn_clear(layout: ArenaLayout, flat: PackedVector2Array, y0: float, y1: float, c: float) -> bool:
	var n := flat.size()
	var prev := Vector3(flat[0].x, y0, flat[0].y)
	for q in range(2, n + 1, 2):
		var k := mini(q, n - 1)
		var pt := Vector3(flat[k].x, lerpf(y0, y1, smoothstep(0.0, 1.0, float(k) / maxf(n - 1, 1))), flat[k].y)
		if not layout.segment_clear(prev, pt, c):
			return false
		prev = pt
	return true


const LINEUP_NEAR := 3.0         ## turning circles (and LINEUP_NEAR_PAD m) from an approach point within which a way in's
const LINEUP_NEAR_PAD := 25.0    ## line-up path must be clear to be first choice
const BLOCKED_LINEUP := 1000.0
const WAY_SKEW := 35.0   ## deg a way in to a branch may come in off square across it
const WAYS_PLANNED := 3  ## open ways in planned to (best first) before giving up on a perch


## Waypoints from `from` to perch `p` (ending at its approach anchor, on the outer part of the branch), or [] if no route was found.
## `from_tree`: the tree the bird is leaving (passed closer on the first leg, which starts right beside it;
## `from_perch` the perch it is on there). The perch's own tree is passed closer on the last legs. It comes in by the
## first way in (ways_in: the side it's on first) whose final swoop is clear and that it finds a route to; the way
## chosen is left in `way`.
func plan_to_perch(from: Vector3, p: Perch, profile: BirdProfile, from_tree := -1, from_perch := -1) -> Array[Vector3]:
	var none: Array[Vector3] = []
	var start := Vector3(from.x, maxf(from.y, clearance + 0.6), from.z)   # (a bird on the ground)
	var tried := 0
	for d in ways_in(p, from, profile, heading, turn_r, layout, clearance):
		if tried >= WAYS_PLANNED:
			break
		if not swoop_clear(p, profile, d):
			continue
		tried += 1
		var app := approach_point(p, profile, d)
		app.y = maxf(app.y, clearance + 0.5)
		var pre := pre_approach_point(p, profile, d)
		pre.y = maxf(pre.y, clearance + 0.5)
		_a_perch = from_perch
		_b_perch = p.id
		# Line up through the pre-approach point when that leg is open (and the bird isn't in on the line already: it
		# needn't go back out); otherwise straight to the approach point.
		var lined_up := not (heading != Vector3.ZERO and on_line(p, profile, d, start, heading)) and _leg_ok(pre, app, -1, p.tree_id)
		var route := plan(start, pre if lined_up else app, from_tree, p.tree_id, from_perch, p.id)
		if route.is_empty():
			continue
		if lined_up:
			route.append(app)
		route.append(p.approach_anchor())
		way = d
		return route
	return none


## Is the final swoop from the approach point along `dir` (default: the perch's facing) onto perch `p` clear (the wood
## by `clearance`, its own tree closer)?
func swoop_clear(p: Perch, profile: BirdProfile, dir := Vector3.ZERO) -> bool:
	var app := approach_point(p, profile, dir)
	app.y = maxf(app.y, clearance + 0.5)
	_b_perch = p.id
	return _leg_ok(app, p.approach_anchor(), -1, p.tree_id)


## Has perch `p` any way in (ways_in) whose final swoop is clear? Without one, there's no route to it.
func has_way_in(p: Perch, profile: BirdProfile) -> bool:
	for d in ways_in(p, p.position + p.facing):
		if swoop_clear(p, profile, d):
			return true
	return false


## Waypoints from `a` to `b` through free air (both included), or [] if none found. `a_tree` is ignored on
## legs leaving `a`, `b_tree` on legs arriving at `b` (a perch's own tree, a departure tree).
## `a_perch` / `b_perch`: the perches there (their branches don't count).
func plan(a: Vector3, b: Vector3, a_tree := -1, b_tree := -1, a_perch := -1, b_perch := -1) -> Array[Vector3]:
	_a_perch = a_perch
	_b_perch = b_perch
	_a_through = false
	if _leg_ok(a, b, a_tree, b_tree):
		return [a, b]
	var starts := _attach(a, a_tree, true)
	if starts.is_empty() and a_tree >= 0:
		# Deep in a crown, every way out passes close to another of its own limbs: leave through them (it passes
		# through its own tree as it lets go, and the avoidance steers it clear of the tree it left).
		_a_through = true
		starts = _attach(a, a_tree, true)
	if starts.is_empty():
		# Wedged in (its berth from the wood overlaps a neighbour's crown): the first leg out may pass closer.
		starts = _attach(a, a_tree, true, minf(clearance, START_CLEARANCE))
	var goals := _attach(b, b_tree, false)
	if starts.is_empty() or goals.is_empty():
		return []
	var goal_set := {}
	for g in goals:
		goal_set[g] = true
	# A* over lattice keys.
	var open := {}          # key -> f
	var g_cost := {}
	var came := {}
	for s in starts:
		var c := _cost(a, _pos(s))
		g_cost[s] = c
		open[s] = c + _pos(s).distance_to(b)
		came[s] = null
	var found = null
	var expansions := 0
	while not open.is_empty() and expansions < MAX_EXPANSIONS:
		expansions += 1
		var cur = null
		var best := INF
		for k in open:
			if open[k] < best:
				best = open[k]
				cur = k
		open.erase(cur)
		if goal_set.has(cur):
			found = cur
			break
		var cp := _pos(cur)
		for nk in _neighbours(cur):
			if not _usable(nk):
				continue
			var np := _pos(nk)
			var ng: float = g_cost[cur] + _cost(cp, np)
			if g_cost.has(nk) and ng >= g_cost[nk]:
				continue
			if not layout.segment_clear(cp, np, clearance):
				continue
			g_cost[nk] = ng
			came[nk] = cur
			open[nk] = ng + np.distance_to(b)
	if found == null:
		return []
	var keys := []
	var k = found
	while k != null:
		keys.push_front(k)
		k = came[k]
	var pts: Array[Vector3] = [a]
	for key in keys:
		pts.append(_pos(key))
	pts.append(b)
	return smooth(pts, a_tree, b_tree)


## String-pull: drop every waypoint the previous kept point can see past.
func smooth(pts: Array[Vector3], a_tree := -1, b_tree := -1) -> Array[Vector3]:
	if pts.size() <= 2:
		return pts
	var out: Array[Vector3] = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _leg_clear(pts, i, j, a_tree, b_tree):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## Leg i -> j of a route: the start's tree only gets the closer pass on legs leaving the start, the goal's only
## on legs reaching the goal.
func _leg_clear(pts: Array[Vector3], i: int, j: int, a_tree: int, b_tree: int) -> bool:
	return _leg_ok(pts[i], pts[j], a_tree if i == 0 else -1, b_tree if j == pts.size() - 1 else -1)


## A leg from a to b: clear of the wood by `clearance` (or `c`), except the tree it leaves (`a_tree`) and the one it lands
## on (`b_tree`), which it may pass OWN_TREE_CLEARANCE from, leaving out the perches' branches and the push-off
## and catch at the ends.
func _leg_ok(a: Vector3, b: Vector3, a_tree: int, b_tree: int, c := -1.0) -> bool:
	if c < 0.0:
		c = clearance
	if a_tree < 0 and b_tree < 0:
		return layout.segment_clear(a, b, c)
	if not layout.segment_clear_among(layout.trees_near_segment(a, b, c), a, b, c, a_tree, b_tree):
		return false
	var d := b - a
	var end := minf(PUSH_OFF, d.length() * 0.5)
	var dir := d.normalized()
	if a_tree >= 0 and not _a_through and not layout.tree_clear(a_tree, a + dir * end, b, OWN_TREE_CLEARANCE, _a_perch):
		return false
	if b_tree >= 0 and not layout.tree_clear(b_tree, a, b - dir * end, OWN_TREE_CLEARANCE, _b_perch):
		return false
	return true


func _cost(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b) + maxf(0.0, b.y - a.y) * CLIMB_COST


func _pos(k: Vector3i) -> Vector3:
	return Vector3(k.x * LATTICE, LEVELS[k.y], k.z * LATTICE)


## Where lattice node `k` is (x and z in LATTICE steps, y the index into LEVELS).
static func node_pos(k: Vector3i) -> Vector3:
	return Vector3(k.x * LATTICE, LEVELS[k.y], k.z * LATTICE)


func _usable(k: Vector3i) -> bool:
	if _node_ok.has(k):
		return _node_ok[k]
	var ok := node_usable(k)
	_node_ok[k] = ok
	return ok


## Is lattice node `k` free air the planner may use: inside the arena, under the ceiling, `clearance` + 0.3 from
## the wood? (Not cached: what the planner's own lookups are made of, for a view to ask without touching them.)
func node_usable(k: Vector3i) -> bool:
	var p := node_pos(k)
	return Vector2(p.x, p.z).length() < layout.reach(Vector2(p.x, p.z)) - 2.0 and p.y < layout.ceiling and layout.clear_by(p, clearance + 0.3)


func _neighbours(k: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for dy in [-1, 0, 1]:
		var ly: int = k.y + dy
		if ly < 0 or ly >= LEVELS.size():
			continue
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0 and dy == 0:
					continue
				out.append(Vector3i(k.x + dx, ly, k.z + dz))
	return out


## Lattice nodes near `p` that it can fly to directly (or from, `leaving`); `tree` is the tree at `p`.
func _attach(p: Vector3, tree: int, leaving: bool, c := -1.0) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cx := roundi(p.x / LATTICE)
	var cz := roundi(p.z / LATTICE)
	var levels: Array[int] = []
	for i in LEVELS.size():
		if absf(LEVELS[i] - p.y) < 9.0:
			levels.append(i)
	for ly in levels:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var k := Vector3i(cx + dx, ly, cz + dz)
				if _usable(k) and (_leg_ok(p, _pos(k), tree, -1, c) if leaving else _leg_ok(_pos(k), p, -1, tree, c)):
					out.append(k)
	return out
