class_name RouteView
extends Node3D
## How an AI bird plans its flight, drawn (the bird lab's route view, P): visual only, it reads the pilot and its
## planner and changes nothing they do.
##   lattice     FlightPlanner's free-air nodes (LATTICE m apart at its LEVELS) within `lattice_radius` of the bird (or,
##               `centre_on` "target", of its perch's approach point): usable ones (clear of the wood by the planner's
##               clearance + 0.3) teal; the rejected ones red, with `rejected` on
##   route       AIPilot.route as flown (the bird a blue dot): the legs passed grey, the leg it's on and the ones ahead white, every waypoint
##               a dot (the current one, route[wp], yellow and a line to it from the bird)
##   target      the perch it's going to (its grip line magenta), its approach point and pre-approach point
##               (FlightPlanner.approach_point / pre_approach_point, raised as the planner raises them) as rings
##   predicted   the stretch AIPilot's avoidance last predicted toward the aim (AIPilot.predicted): green while clear,
##               red from where it would meet wood (a red star there); while avoiding, the escape it flies instead
##               (AIPilot.escape) orange
## Drawn over everything (no depth test) except the lattice. `surfaces` names each drawn surface ([mesh, index]),
## for tests to read back what was drawn.

# (Linear, as drawn before the tonemapper, which brightens mid values: these stay apart on screen.)
const COL_USABLE := Color(0.1, 0.8, 0.7, 0.85)
const COL_REJECTED := Color(1.0, 0.02, 0.02, 0.6)
const COL_PASSED := Color(0.2, 0.2, 0.2)
const COL_ROUTE := Color(1.0, 1.0, 1.0)
const COL_CURRENT := Color(1.0, 1.0, 0.0)
const COL_PERCH := Color(1.0, 0.0, 0.8)
const COL_APPROACH := Color(1.0, 0.1, 0.8)
const COL_CLEAR := Color(0.0, 1.0, 0.05)
const COL_BLOCKED := Color(1.0, 0.0, 0.0)
const COL_ESCAPE := Color(1.0, 0.18, 0.0)
const COL_BIRD := Color(0.3, 0.6, 1.0)

var pilot: AIPilot
var bird: Bird
var lattice := true
var rejected := false
var lattice_radius := 24.0
var centre_on := "bird"         ## "bird" or "target" (its approach point; the bird's when it has none)
var surfaces := {}              ## name -> [ImmediateMesh, surface index], as last drawn
var _over: ImmediateMesh        ## no depth test: route, target, prediction (lines)
var _dots: ImmediateMesh        ## no depth test: the waypoints (points: a material with a point size draws only points)
var _nodes: ImmediateMesh       ## depth tested: the lattice
var _usable := {}               ## Vector3i -> bool, at _usable_clearance (the view's own: the planner's cache is left alone)
var _usable_clearance := -1.0
var _usable_layout: ArenaLayout


func _ready() -> void:
	_over = _layer(true, 0.0)
	_dots = _layer(true, 9.0)
	_nodes = _layer(false, 5.0)


## A mesh drawn unshaded in its vertex colours, over everything (`on_top`) or not; `point_size` > 0: a points layer.
func _layer(on_top: bool, point_size: float) -> ImmediateMesh:
	var mi := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = on_top
	mat.disable_fog = true
	if point_size > 0.0:
		mat.use_point_size = true
		mat.point_size = point_size
	mat.render_priority = 1 if on_top else 0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0   # (drawn in world space round a moving bird: never culled)
	add_child(mi)
	return mesh


## Redraw from the pilot as it is now (call every frame while shown).
func refresh() -> void:
	if _over == null:
		_ready()
	_over.clear_surfaces()
	_dots.clear_surfaces()
	_nodes.clear_surfaces()
	surfaces.clear()
	if pilot == null or bird == null or not is_instance_valid(bird):
		return
	if lattice:
		_draw_lattice()
	_draw_route()
	_draw_target()
	_draw_predicted()


## The point the lattice is drawn round.
func lattice_centre() -> Vector3:
	if centre_on == "target" and pilot.target != null:
		return _approach(pilot.target)
	return bird.global_position


## The lattice nodes within `lattice_radius` of `c`: [usable keys, rejected keys].
func lattice_near(c: Vector3) -> Array:
	var planner := pilot.planner
	if planner.clearance != _usable_clearance or planner.layout != _usable_layout:
		_usable.clear()
		_usable_clearance = planner.clearance
		_usable_layout = planner.layout
	var ok: Array[Vector3i] = []
	var no: Array[Vector3i] = []
	var n := ceili(lattice_radius / FlightPlanner.LATTICE)
	var cx := roundi(c.x / FlightPlanner.LATTICE)
	var cz := roundi(c.z / FlightPlanner.LATTICE)
	for ly in FlightPlanner.LEVELS.size():
		for dx in range(-n, n + 1):
			for dz in range(-n, n + 1):
				var k := Vector3i(cx + dx, ly, cz + dz)
				if FlightPlanner.node_pos(k).distance_to(c) > lattice_radius:
					continue
				if not _usable.has(k):
					_usable[k] = planner.node_usable(k)
				(ok if _usable[k] else no).append(k)
	return [ok, no]


func _draw_lattice() -> void:
	var near := lattice_near(lattice_centre())
	_points(_nodes, "lattice", near[0].map(func(k): return FlightPlanner.node_pos(k)), COL_USABLE)
	if rejected:
		_points(_nodes, "rejected", near[1].map(func(k): return FlightPlanner.node_pos(k)), COL_REJECTED)


func _draw_route() -> void:
	var r := pilot.route
	if r.size() < 2:
		return
	var wp := clampi(pilot.wp, 1, r.size() - 1)
	var cols := []
	for i in r.size():
		cols.append(COL_PASSED if i < wp - 1 else COL_ROUTE)
	_strip(_over, "route", Array(r), cols)
	var dot_cols := []
	for i in r.size():
		dot_cols.append(COL_CURRENT if i == wp else (COL_PASSED if i < wp else COL_ROUTE))
	_points(_dots, "waypoints", Array(r), dot_cols)
	_lines(_over, "current", [bird.global_position, r[wp]], COL_CURRENT)
	_points(_dots, "bird", [bird.global_position], COL_BIRD)


func _draw_target() -> void:
	var t := pilot.target
	if t == null:
		return
	var pts := [t.a, t.b] if t.a.distance_to(t.b) > 0.05 else [t.position + Vector3(-0.15, 0, 0), t.position + Vector3(0.15, 0, 0)]
	pts.append_array(_ring(_approach(t), 0.6))
	pts.append_array(_ring(_pre_approach(t), 0.45))
	_lines(_over, "target", pts, COL_PERCH)
	_points(_dots, "approach", [_approach(t), _pre_approach(t)], COL_APPROACH)


## The approach points as the planner uses them (raised clear of the ground).
func _approach(t: Perch) -> Vector3:
	var p := FlightPlanner.approach_point(t, bird.profile)
	p.y = maxf(p.y, pilot.planner.clearance + 0.5)
	return p


func _pre_approach(t: Perch) -> Vector3:
	var p := FlightPlanner.pre_approach_point(t, bird.profile)
	p.y = maxf(p.y, pilot.planner.clearance + 0.5)
	return p


func _draw_predicted() -> void:
	var p := pilot.predicted
	if p.size() >= 2:
		var cut := p.size() if pilot.predicted_clear >= pilot.predict_horizon else clampi(roundi(pilot.predicted_clear / AIPilot.PREDICT_STEP), 0, p.size() - 1)
		var cols := []
		for i in p.size():
			cols.append(COL_CLEAR if i < cut else COL_BLOCKED)
		_strip(_over, "predicted", Array(p), cols)
		if cut < p.size():
			_lines(_over, "blocked", _star(p[cut], 0.35), COL_BLOCKED)
			_points(_dots, "blocked_dot", [p[cut]], COL_BLOCKED)
	if pilot.escape.size() >= 2:
		var cols := []
		cols.resize(pilot.escape.size())
		cols.fill(COL_ESCAPE)
		_strip(_over, "escape", Array(pilot.escape), cols)


## Where the predicted path would meet wood (null: it's clear all the way).
func blocked_point() -> Variant:
	var p := pilot.predicted
	if p.size() < 2 or pilot.predicted_clear >= pilot.predict_horizon:
		return null
	return p[clampi(roundi(pilot.predicted_clear / AIPilot.PREDICT_STEP), 0, p.size() - 1)]


# --- Drawing -------------------------------------------------------------------------------------------

func _begin(mesh: ImmediateMesh, name_: String, prim: Mesh.PrimitiveType) -> void:
	surfaces[name_] = [mesh, mesh.get_surface_count()]
	mesh.surface_begin(prim)


func _strip(mesh: ImmediateMesh, name_: String, pts: Array, cols: Array) -> void:
	if pts.size() < 2:
		return
	_begin(mesh, name_, Mesh.PRIMITIVE_LINE_STRIP)
	for i in pts.size():
		mesh.surface_set_color(cols[i])
		mesh.surface_add_vertex(pts[i])
	mesh.surface_end()


func _lines(mesh: ImmediateMesh, name_: String, pts: Array, col: Color) -> void:
	if pts.size() < 2:
		return
	_begin(mesh, name_, Mesh.PRIMITIVE_LINES)
	for v in pts:
		mesh.surface_set_color(col)
		mesh.surface_add_vertex(v)
	mesh.surface_end()


func _points(mesh: ImmediateMesh, name_: String, pts: Array, col: Variant) -> void:
	if pts.is_empty():
		return
	_begin(mesh, name_, Mesh.PRIMITIVE_POINTS)
	for i in pts.size():
		mesh.surface_set_color(col[i] if col is Array else col)
		mesh.surface_add_vertex(pts[i])
	mesh.surface_end()


## A horizontal ring round `c` (as line pairs).
static func _ring(c: Vector3, r: float, n := 16) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		out.append(c + Vector3(cos(a), 0.0, sin(a)) * r)
		out.append(c + Vector3(cos(b), 0.0, sin(b)) * r)
	return out


## Three crossed lines through `c` (as line pairs).
static func _star(c: Vector3, r: float) -> Array:
	return [c + Vector3(-r, 0, 0), c + Vector3(r, 0, 0), c + Vector3(0, -r, 0), c + Vector3(0, r, 0), c + Vector3(0, 0, -r), c + Vector3(0, 0, r)]


## The vertices drawn in surface `name_` (empty if it wasn't drawn).
func drawn(name_: String) -> PackedVector3Array:
	if not surfaces.has(name_):
		return PackedVector3Array()
	var mesh: ImmediateMesh = surfaces[name_][0]
	return mesh.surface_get_arrays(surfaces[name_][1])[Mesh.ARRAY_VERTEX]
