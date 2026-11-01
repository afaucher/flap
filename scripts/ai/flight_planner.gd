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

var layout: ArenaLayout
var clearance := 0.9
var _node_ok := {}      ## Vector3i -> bool


func _init(l: ArenaLayout, c := 0.9) -> void:
	layout = l
	clearance = c


## Where the final approach starts: out along the perch's facing and a little below it, so the bird
## dives under and swoops up into the perch (bleeding speed on the way up, as birds do).
static func approach_point(p: Perch, profile: BirdProfile) -> Vector3:
	return p.position + p.facing * approach_length(profile) + Vector3.DOWN * 1.2


## A point twice as far out, so the bird reaches the approach point already lined up with the perch.
static func pre_approach_point(p: Perch, profile: BirdProfile) -> Vector3:
	return p.position + p.facing * approach_length(profile) * 2.0 + Vector3.DOWN * 0.6


static func approach_length(profile: BirdProfile) -> float:
	return maxf(6.0, profile.v_best * 0.8)


## Waypoints from `from` to perch `p` (ending at the perch's grip point), or [] if no route was found.
## `from_tree`: the tree the bird is leaving (ignored for the first leg, which starts right beside it).
func plan_to_perch(from: Vector3, p: Perch, profile: BirdProfile, from_tree := -1) -> Array[Vector3]:
	var start := Vector3(from.x, maxf(from.y, clearance + 0.6), from.z)   # (a bird on the ground)
	var app := approach_point(p, profile)
	app.y = maxf(app.y, clearance + 0.5)
	var pre := pre_approach_point(p, profile)
	pre.y = maxf(pre.y, clearance + 0.5)
	# Line up through the pre-approach point when that leg is open; otherwise straight to the approach point.
	var lined_up := layout.segment_clear(pre, app, clearance, p.tree_id)
	var route := plan(start, pre if lined_up else app, from_tree, p.tree_id)
	if route.is_empty():
		return route
	if lined_up:
		route.append(app)
	route.append(p.position)
	return route


## Waypoints from `a` to `b` through free air (both included), or [] if none found. `a_tree` is ignored on
## legs leaving `a`, `b_tree` on legs arriving at `b` (a perch's own tree, a departure tree).
func plan(a: Vector3, b: Vector3, a_tree := -1, b_tree := -1) -> Array[Vector3]:
	if layout.segment_clear(a, b, clearance, a_tree) and layout.segment_clear(a, b, clearance, b_tree):
		return [a, b]
	var starts := _attach(a, a_tree)
	var goals := _attach(b, b_tree)
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


## Leg i -> j of a route: the start's tree only counts for legs leaving the start, the goal's only for legs
## reaching the goal.
func _leg_clear(pts: Array[Vector3], i: int, j: int, a_tree: int, b_tree: int) -> bool:
	var last := pts.size() - 1
	if i == 0 and j == last:
		return layout.segment_clear(pts[i], pts[j], clearance, a_tree) and layout.segment_clear(pts[i], pts[j], clearance, b_tree)
	if i == 0:
		return layout.segment_clear(pts[i], pts[j], clearance, a_tree)
	if j == last:
		return layout.segment_clear(pts[i], pts[j], clearance, b_tree)
	return layout.segment_clear(pts[i], pts[j], clearance)


func _cost(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b) + maxf(0.0, b.y - a.y) * CLIMB_COST


func _pos(k: Vector3i) -> Vector3:
	return Vector3(k.x * LATTICE, LEVELS[k.y], k.z * LATTICE)


func _usable(k: Vector3i) -> bool:
	if _node_ok.has(k):
		return _node_ok[k]
	var p := _pos(k)
	var ok := Vector2(p.x, p.z).length() < layout.boundary - 2.0 and p.y < layout.ceiling and layout.obstacle_distance(p) > clearance + 0.3
	_node_ok[k] = ok
	return ok


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


## Lattice nodes near `p` that it can fly to directly.
func _attach(p: Vector3, ignore_tree: int) -> Array[Vector3i]:
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
				if _usable(k) and layout.segment_clear(p, _pos(k), clearance, ignore_tree):
					out.append(k)
	return out
