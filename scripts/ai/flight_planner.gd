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
const REQUEST_EXPANSIONS := 600   ## a bird's route request (plan_to_perch, every way in it tries) ends after this many search
                                  ## steps, route or not: ~20 ms with the lattice's table (prepare). The longest a 3 v 3 needs is ~490.
## The tree a route leaves or lands on isn't ignored, just passed closer: this far, without the perch's own branch
## and the first PUSH_OFF metres (the bird passes through its own tree as it lets go) or the last ones (the catch).
const OWN_TREE_CLEARANCE := 0.4
const PUSH_OFF := 1.0
const START_CLEARANCE := 0.6   ## m: the closest a first leg out of a tight spot may pass the wood (the whiskers')

var layout: ArenaLayout
var clearance := DEFAULT_CLEARANCE
const DEFAULT_CLEARANCE := 0.9
var _node_ok := {}      ## Vector3i -> bool
var _table := {}        ## the layout's table (prepare), and whether it holds this clearance: for this search
var _table_on := false
var _order := 0
var _steps_left := -1   ## search steps left in this route request (REQUEST_EXPANSIONS; -1: no limit, as for a race course)
var _seen := {}         ## Vector3i -> {Vector3i -> bool}: edges checked, where the layout's table hasn't them (_edge_clear)
var _seen_c := -1.0     ## the clearance _seen holds for
var _a_perch := -1      ## the perch the route leaves (its branch is skipped), for the plan in progress
var _b_perch := -1      ## the perch it lands on
var _a_through := false ## leaving through its own tree (no way out past it)
var way := Vector3.ZERO ## the way in the last plan_to_perch came in by (from the perch out)
var heading := Vector3.ZERO   ## the way the bird is flying (horizontal; zero: perched), for ways_in's choice ...
var turn_r := 0.0             ## ... and its turning circle there


func _init(l: ArenaLayout, c := DEFAULT_CLEARANCE) -> void:
	layout = l
	clearance = c


## Where the final approach starts: out from the perch along `dir` (the way in: default the perch's facing) and a little
## below it, so the bird dives under and swoops up into the perch (bleeding speed on the way up, as birds do).
static func approach_point(p: Perch, profile: BirdProfile, dir := Vector3.ZERO) -> Vector3:
	return p.approach_anchor() + _way(p, dir) * approach_length(profile) + Vector3.DOWN * approach_drop(profile, p)


## A point twice as far out, so the bird reaches the approach point already lined up with the perch.
static func pre_approach_point(p: Perch, profile: BirdProfile, dir := Vector3.ZERO) -> Vector3:
	return p.approach_anchor() + _way(p, dir) * approach_length(profile) * 2.0 + Vector3.DOWN * approach_drop(profile, p) * 0.5


## m below the perch the final swoop starts: the height a bird gliding at its best speed zooms up as it slows to its
## catch speed (catch_speed), less what the drag takes (ZOOM_KEPT) -- a falcon's ~1.9 m, a sparrow's ~0.7. A bird
## that can't climb the swoop arrives under the branch; one that starts too high arrives too fast. Under a low perch
## (`p`) no deeper than leaves the approach point APPROACH_FLOOR up: lower, a wide turner lining up there has the ground
## limiting its bank and the understory in its way (the falcon on the big-trees oak's 4.5 m limbs, 50 of 72).
static func approach_drop(profile: BirdProfile, p: Perch = null) -> float:
	var v := catch_speed(profile)
	var drop := clampf((profile.v_best * profile.v_best - v * v) / (2.0 * BirdProfile.G) * ZOOM_KEPT, DROP.x, DROP.y)
	if p != null:
		drop = minf(drop, maxf(DROP.x, p.approach_anchor().y - APPROACH_FLOOR))
	return drop


## m/s: the speed to arrive at a perch at -- the middle of the bird's window between its stall and the fastest it can
## catch at.
static func catch_speed(profile: BirdProfile) -> float:
	return (profile.v_stall + profile.grab_speed_max) * 0.5


const ZOOM_KEPT := 0.6           ## share of the zoom's height the drag leaves it
const DROP := Vector2(0.6, 2.5)  ## m: the approach drop at least and at most
const APPROACH_FLOOR := 3.3      ## m up the approach point stays at least, where the perch allows (approach_drop)


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
	_steps_left = REQUEST_EXPANSIONS
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
		_steps_left = -1
		return route
	_steps_left = -1
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
	# (The open set's cheapest node comes off a binary heap -- the first opened of equals, as a scan of it in order
	# took them, so the routes are the same.)
	_table = layout.get_meta(EDGE_TABLE, {})
	_table_on = float((_table.get("c_set", {}) as Dictionary).get(clearance, -1.0)) >= 0.0
	var open := {}          # key -> f
	var opened := {}        # key -> the order it was opened in (kept while it's open)
	var heap := []          # [f, order, key]
	var g_cost := {}
	var came := {}
	for s in starts:
		var c := _cost(a, _pos(s))
		g_cost[s] = c
		_open(open, opened, heap, s, c + _pos(s).distance_to(b))
		came[s] = null
	var found = null
	var expansions := 0
	while not open.is_empty() and expansions < MAX_EXPANSIONS and _steps_left != 0:
		expansions += 1
		if _steps_left > 0:
			_steps_left -= 1
		var cur = _pop(open, opened, heap)
		open.erase(cur)
		opened.erase(cur)
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
			if not _edge_clear(cur, nk, cp, np):
				continue
			g_cost[nk] = ng
			came[nk] = cur
			_open(open, opened, heap, nk, ng + np.distance_to(b))
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


## Put `key` in the open set at `f` (or lower it there), and on the heap.
func _open(open: Dictionary, opened: Dictionary, heap: Array, key: Variant, f: float) -> void:
	if not opened.has(key):
		opened[key] = _order
		_order += 1
	open[key] = f
	heap.append([f, opened[key], key])
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) >> 1
		if not _before(heap[i], heap[up]):
			break
		var t = heap[i]
		heap[i] = heap[up]
		heap[up] = t
		i = up


## The open node with the lowest f (the first opened of equals); entries a lowered f left behind are skipped.
func _pop(open: Dictionary, opened: Dictionary, heap: Array) -> Variant:
	while not heap.is_empty():
		var top: Array = heap[0]
		var last = heap.pop_back()
		if not heap.is_empty():
			heap[0] = last
			var i := 0
			var n := heap.size()
			while true:
				var l := 2 * i + 1
				if l >= n:
					break
				var c := l + 1 if l + 1 < n and _before(heap[l + 1], heap[l]) else l
				if not _before(heap[c], heap[i]):
					break
				var t = heap[i]
				heap[i] = heap[c]
				heap[c] = t
				i = c
		var k = top[2]
		if open.has(k) and float(open[k]) == float(top[0]) and int(opened[k]) == int(top[1]):
			return k
	return null


static func _before(x: Array, y: Array) -> bool:
	return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1])


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
## Is the lattice edge a -> b (at `pa`, `pb`) clear of the wood by `clearance`? From the layout's table (prepare)
## when it has one for this clearance, else checked and kept (one way: the check isn't quite symmetric) -- the same
## answer either way. In a big wood a check is ~60 us and a search asks thousands.
func _edge_clear(a: Vector3i, b: Vector3i, pa: Vector3, pb: Vector3) -> bool:
	if _table_on:
		var row: Dictionary = (_table.e as Dictionary).get(a, {})
		if row.has(b):
			return float(row[b]) >= clearance
	if _seen_c != clearance:
		_seen_c = clearance
		_seen.clear()
	var r2: Dictionary = _seen.get(a, {})
	if r2.has(b):
		return r2[b]
	var ok := layout.segment_clear(pa, pb, clearance)
	r2[b] = ok
	_seen[a] = r2
	return ok


const EDGE_TABLE := "plan_edge_table"
static var prepare_jobs := 0   ## threads prepare uses (0: the cores less one, at most PREPARE_JOBS)
const PREPARE_JOBS := 6        ## (more contend: on 32 cores 6 threads took 2.8 s, 16 took 32 s)


## The clearances planners use (each species' AIPilot.plan_clearance, and the default), widest first.
static func species_clearances() -> Array[float]:
	var cs: Array[float] = [DEFAULT_CLEARANCE]   # (a planner not yet fitted to its bird plans with this)
	for id in BirdProfile.IDS:
		var c := AIPilot.plan_clearance(BirdProfile.by_id(id))
		if not cs.has(c):
			cs.append(c)
	cs.sort()
	cs.reverse()
	return cs


## Work out every lattice edge's clearance in `l` ahead, for every species' clearance, over the machine's cores (the
## loading screen does it with the layout): each directed edge between nodes free at the narrowest gets the widest
## clearance it clears (or -1) -- the check only gets harder as the clearance grows, so that answers it for each.
## The planners then look edges up instead of checking them: the same routes, without the ~150 ms first searches.
static func prepare(l: ArenaLayout) -> void:
	if l.has_meta(EDGE_TABLE):
		return
	_prepare(l)


## prepare for a scene's layout: in a game with a screen. (Headless -- the tests -- it's left out: the routes are the
## same without it, and many tests loading scenes at once would each spend seconds on it, contending for the cores.)
static func prepare_for_play(l: ArenaLayout) -> void:
	if DisplayServer.get_name() != "headless":
		prepare(l)


static func _prepare(l: ArenaLayout) -> void:
	var t0 := Time.get_ticks_msec()
	for t in l.trees:   # (what the checks build on first use, built now: the threads below only read)
		t.reach()
		t.bands()
	for o in l.outposts:
		l.deck_lines(o)
	var cs := species_clearances()
	var probe := FlightPlanner.new(l, cs[-1])
	var n := int(l.half_extent / LATTICE) + 1
	var free := {}
	var nodes := {}   # (each node: the widest clearance it's free at, or -1 -- node_usable only gets harder as it grows)
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			for y in LEVELS.size():
				var k := Vector3i(x, y, z)
				var w := -1.0
				for c in cs:   # (widest first)
					probe.clearance = c
					if probe.node_usable(k):
						w = c
						break
				nodes[k] = w
				if w >= 0.0:
					free[k] = true
	var edges: Array[Vector3i] = []   # (pairs: from, to)
	for k: Vector3i in free:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var k2 := Vector3i(k.x + dx, k.y + dy, k.z + dz)
					if k2 != k and free.has(k2):
						edges.append(k)
						edges.append(k2)
	var m := edges.size() / 2
	var jobs := clampi(OS.get_processor_count() - 1, 1, PREPARE_JOBS) if prepare_jobs <= 0 else prepare_jobs
	var threads: Array[Thread] = []
	for j in jobs:
		var th := Thread.new()
		th.start(_prepare_part.bind(l, edges, cs, m * j / jobs, m * (j + 1) / jobs))
		threads.append(th)
	var out := PackedFloat64Array()
	for th in threads:
		out.append_array(th.wait_to_finish())   # (in order: each thread's part, edge by edge)
	var e := {}
	for i in m:
		var a := edges[2 * i]
		if not e.has(a):
			e[a] = {}
		e[a][edges[2 * i + 1]] = out[i]
	var c_set := {}
	for c in cs:
		c_set[c] = 0.0
	l.set_meta(EDGE_TABLE, {"e": e, "n": nodes, "c_set": c_set})
	print_verbose("FlightPlanner.prepare: %d edges, %d clearances, %d threads, %d ms" % [m, cs.size(), jobs, Time.get_ticks_msec() - t0])


## (prepare's work for edges i0..i1, on a thread of its own: each edge's widest clearance it clears, by halving.)
static func _prepare_part(l: ArenaLayout, edges: Array[Vector3i], cs: Array[float], i0: int, i1: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in range(i0, i1):
		var pa := node_pos(edges[2 * i])
		var pb := node_pos(edges[2 * i + 1])
		var lo := 0                 # (cs is widest first: find the first index it clears; all after clear too)
		var hi := cs.size()
		while lo < hi:
			var mid := (lo + hi) / 2
			if l.segment_clear(pa, pb, cs[mid]):
				hi = mid
			else:
				lo = mid + 1
		out.append(cs[lo] if lo < cs.size() else -1.0)
	return out


static func node_pos(k: Vector3i) -> Vector3:
	return Vector3(k.x * LATTICE, LEVELS[k.y], k.z * LATTICE)


func _usable(k: Vector3i) -> bool:
	if _node_ok.has(k):
		return _node_ok[k]
	var ok: bool
	var nt: Dictionary = (layout.get_meta(EDGE_TABLE, {}) as Dictionary)
	if nt.has("n") and float((nt.c_set as Dictionary).get(clearance, -1.0)) >= 0.0:
		ok = float((nt.n as Dictionary).get(k, -1.0)) >= clearance   # (prepare's table: the same answer)
	else:
		ok = node_usable(k)
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
