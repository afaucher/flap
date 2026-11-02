class_name ArenaBuilder
extends Node3D
## Greybox meshes and collision for an ArenaLayout: a gridded ground, trunks and branches (static bodies on
## layer 1), a perch marker on every grip point, pale ground strips under the open lanes, boundary posts,
## and one highlight ring that shows the perch the bird could catch.

const WORLD_LAYER := 1

var layout: ArenaLayout
var tree_bodies: Array[StaticBody3D] = []   ## by tree id
var highlight: MeshInstance3D
var _hl_line: MeshInstance3D
var _hl_perch: Perch
var _hl_mat: StandardMaterial3D
var _mats := {}


func build(l: ArenaLayout) -> void:
	layout = l
	_ground()
	_lanes()
	_boundary_posts()
	var tier_colors := [Color(0.34, 0.32, 0.30), Color(0.43, 0.41, 0.38), Color(0.52, 0.50, 0.47)]
	for t in layout.trees:
		_tree(t, tier_colors[t.tier])
	for p in layout.perches:
		_perch_marker(p)
	_highlight()


func _mat(key: String, c: Color, rough := 0.9) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = WORLD_LAYER
	body.add_to_group("ground")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(layout.half_extent * 4.0, 2.0, layout.half_extent * 4.0)
	shape.shape = box
	shape.position.y = ArenaLayout.GROUND_Y - 1.0
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000.0, 2000.0)
	mi.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/world/ground_grid.gdshader")
	mi.material_override = sm
	body.add_child(mi)
	add_child(body)


## Pale strips on the ground under the clearing, avenues and ring: the flight paths, readable from the air.
func _lanes() -> void:
	var m := _mat("lane", Color(0.5, 0.52, 0.42))
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = layout.clearing_radius
	cyl.bottom_radius = layout.clearing_radius
	cyl.height = 0.02
	cyl.radial_segments = 48
	disc.mesh = cyl
	disc.material_override = m
	disc.position.y = 0.02
	add_child(disc)
	for av in layout.avenues:
		var a := Vector3(av[0].x, 0.03, av[0].y)
		var b := Vector3(av[1].x, 0.03, av[1].y)
		add_child(_strip(a, b, av[2] * 2.0, m))
	var segs := 64
	for i in segs:
		var t0 := TAU * i / segs
		var t1 := TAU * (i + 1) / segs
		var a := Vector3(sin(t0), 0.0, cos(t0)) * layout.ring_radius + Vector3.UP * 0.03
		var b := Vector3(sin(t1), 0.0, cos(t1)) * layout.ring_radius + Vector3.UP * 0.03
		add_child(_strip(a, b, layout.ring_half_width * 2.0, m))


func _strip(a: Vector3, b: Vector3, width: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.02, a.distance_to(b) + 0.2)
	mi.mesh = box
	mi.material_override = m
	mi.position = (a + b) * 0.5
	mi.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
	return mi


func _boundary_posts() -> void:
	var m := _mat("post", Color(0.62, 0.36, 0.30))
	var n := 48
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.25
	mesh.height = 6.0
	for i in n:
		var a := TAU * i / n
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(sin(a), 0.0, cos(a)) * (layout.boundary + 2.0) + Vector3.UP * 3.0
		add_child(mi)


func _tree(t: ArenaLayout.TreeData, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "Tree%d" % t.id
	body.collision_layer = WORLD_LAYER
	body.position = Vector3(t.base.x, ArenaLayout.GROUND_Y, t.base.y)
	var mat := _mat("tier%d" % t.tier, color)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = t.radius
	cyl.top_radius = t.radius * 0.75
	cyl.height = t.height
	cyl.radial_segments = 10
	trunk.mesh = cyl
	trunk.material_override = mat
	trunk.position.y = t.height * 0.5
	body.add_child(trunk)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = t.radius
	shape.height = t.height
	cs.shape = shape
	cs.position.y = t.height * 0.5
	body.add_child(cs)
	var bmat := _mat("branch%d" % t.tier, color.lightened(0.12))
	for br in t.branches:
		var dir: Vector3 = br.tip - br.root
		var length := dir.length()
		var mid: Vector3 = (br.root + br.tip) * 0.5 - body.position
		var basis := _basis_along(dir / length)
		var mi := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.bottom_radius = br.radius
		bm.top_radius = br.radius * 0.6
		bm.height = length
		bm.radial_segments = 6
		mi.mesh = bm
		mi.material_override = bmat
		mi.position = mid
		mi.basis = basis
		body.add_child(mi)
		var bcs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = br.radius
		cap.height = length
		bcs.shape = cap
		bcs.position = mid
		bcs.basis = basis
		body.add_child(bcs)
	add_child(body)
	tree_bodies.append(body)


## A basis whose +Y runs along `d` (cylinders and capsules are Y-aligned).
static func _basis_along(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## The grip set, drawn on the wood: a pale strip along the top of the branch, or a disc on the trunk top.
func _perch_marker(p: Perch) -> void:
	var mi := _grip_mesh(p, 0.012)
	mi.material_override = _mat("perch", Color(0.85, 0.78, 0.45), 0.6)
	add_child(mi)


func _grip_mesh(p: Perch, lift: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if p.kind == Perch.Kind.TREETOP:
		var cyl := CylinderMesh.new()
		cyl.top_radius = p.disc
		cyl.bottom_radius = p.disc
		cyl.height = 0.02
		cyl.radial_segments = 16
		mi.mesh = cyl
		mi.position = p.position + Vector3.UP * lift
	else:
		var box := BoxMesh.new()
		box.size = Vector3(maxf(0.03, p.thickness * 0.9), 0.02, p.a.distance_to(p.b))
		mi.mesh = box
		mi.position = p.position + Vector3.UP * lift
		mi.basis = Basis.looking_at((p.b - p.a).normalized(), Vector3.UP)
	return mi


func _highlight() -> void:
	highlight = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	highlight.mesh = torus
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.albedo_color = Color.WHITE
	_hl_mat.no_depth_test = true
	highlight.material_override = _hl_mat
	highlight.visible = false
	add_child(highlight)


## Show the catchable perch: its whole grip line lit, and a ring (the catch reach) at the grip point nearest
## the bird -- where it would land. White = approaching, green = catch now, red = in reach but too fast.
func show_candidate(p: Perch, status: int, grab_radius: float, grip := Vector3.ZERO) -> void:
	if p == null:
		highlight.visible = false
		if _hl_line != null:
			_hl_line.visible = false
		return
	highlight.visible = true
	highlight.position = grip if grip != Vector3.ZERO else p.position
	var s := grab_radius / 0.5 if status != Perch.Catch.OUT_OF_RANGE else 0.6
	highlight.scale = Vector3(s, 1.0, s)
	match status:
		Perch.Catch.OK: _hl_mat.albedo_color = Color(0.3, 1.0, 0.4)
		Perch.Catch.TOO_FAST: _hl_mat.albedo_color = Color(1.0, 0.35, 0.3)
		_: _hl_mat.albedo_color = Color(1, 1, 1, 0.8)
	if p != _hl_perch:
		if _hl_line != null:
			_hl_line.queue_free()
		_hl_line = _grip_mesh(p, 0.03)
		_hl_line.material_override = _hl_mat
		add_child(_hl_line)
		_hl_perch = p
	_hl_line.visible = true
