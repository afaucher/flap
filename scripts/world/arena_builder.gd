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
	_boundary_posts()
	if layout.style == "pinewood":
		_pinewood()
	else:
		_lanes()
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
	var mi := _grip_mesh(p, 0.004)   # (a thin line flush with the branch top, where the feet grip)
	mi.material_override = _mat("perch", Color(0.85, 0.78, 0.45), 0.6)
	add_child(mi)


func _grip_mesh(p: Perch, lift: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if p.kind == Perch.Kind.TREETOP:
		var cyl := CylinderMesh.new()
		cyl.top_radius = p.disc
		cyl.bottom_radius = p.disc
		cyl.height = 0.006
		cyl.radial_segments = 16
		mi.mesh = cyl
		mi.position = p.position + Vector3.UP * lift
	else:
		var box := BoxMesh.new()
		box.size = Vector3(maxf(0.03, p.thickness * 0.9), 0.006, p.a.distance_to(p.b))
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


# --- Pine wood (Pinewood) ---------------------------------------------------------------------------------

## The pine wood in greybox: trunks, limbs and foliage drawn as instanced batches (thousands of pieces), each
## tree's trunk and limbs solid; foliage and ferns are drawn only (birds fly through needles and leaves);
## the outposts' decks, rails and hangars solid.
func _pinewood() -> void:
	var trunk_cyl := _cyl(1.0, 0.4, 12)
	var oak_cyl := _cyl(1.0, 0.65, 14)
	var limb_cyl := _cyl(1.0, 0.6, 7)
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 10
	blob.rings = 6
	var batches := {
		"pine_trunk": [trunk_cyl, Color(0.42, 0.33, 0.27), []],
		"oak_trunk": [oak_cyl, Color(0.36, 0.33, 0.29), []],
		"limb": [limb_cyl, Color(0.45, 0.36, 0.29), []],
		"stub": [limb_cyl, Color(0.55, 0.52, 0.48), []],
		"needles": [blob, Color(0.2, 0.33, 0.17), []],
		"leaves": [blob, Color(0.3, 0.42, 0.18), []],
		"sapling": [blob, Color(0.24, 0.4, 0.2), []],
	}
	for t in layout.trees:
		var c := Vector3(t.base.x, ArenaLayout.GROUND_Y, t.base.y)
		var body := StaticBody3D.new()
		body.name = "Tree%d" % t.id
		body.collision_layer = WORLD_LAYER
		body.position = c
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = t.radius
		shape.height = t.height
		cs.shape = shape
		cs.position.y = t.height * 0.5
		body.add_child(cs)
		var key := "oak_trunk" if t.kind == ArenaLayout.Kind.BROADLEAF else "pine_trunk"
		batches[key][2].append(Transform3D(Basis.from_scale(Vector3(t.radius, t.height, t.radius)), c + Vector3.UP * t.height * 0.5))
		for br in t.branches:
			var dir: Vector3 = br.tip - br.root
			var length := dir.length()
			var b := _basis_along(dir / length)
			batches["stub" if br.dead else "limb"][2].append(Transform3D(b * Basis.from_scale(Vector3(br.radius, length, br.radius)), (br.root + br.tip) * 0.5))
			var bcs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = br.radius
			cap.height = length + br.radius * 2.0
			bcs.shape = cap
			bcs.position = (br.root + br.tip) * 0.5 - c
			bcs.basis = b
			body.add_child(bcs)
		var fk := "leaves" if t.kind == ArenaLayout.Kind.BROADLEAF else ("sapling" if t.kind == ArenaLayout.Kind.SAPLING else "needles")
		for f in t.foliage:
			batches[fk][2].append(Transform3D(Basis.from_scale(f[1]), f[0]))
		add_child(body)
		tree_bodies.append(body)
	for key in batches:
		_batch(key, batches[key][0], batches[key][1], batches[key][2])
	_floor()
	for o in layout.outposts:
		_outpost(o)


func _cyl(bottom: float, top: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = 1.0
	m.radial_segments = segs
	m.rings = 1
	return m


func _batch(key: String, mesh: Mesh, color: Color, xfs: Array, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Batch_" + key
	mi.multimesh = mm
	var m := _mat("pw_" + key, color)
	m.vertex_color_use_as_albedo = mm.use_colors
	mi.material_override = m
	add_child(mi)
	return mi


## The forest floor: ferns and bilberry, low flattened clumps scattered over it; drawn only.
func _floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed * 13 + 5
	var fern := SphereMesh.new()
	fern.radius = 1.0
	fern.height = 1.0
	fern.is_hemisphere = true
	fern.radial_segments = 8
	fern.rings = 3
	var xfs := []
	var cols := []
	for i in 2600:
		var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * layout.boundary
		if p.length() > layout.boundary:
			continue
		var r := rng.randf_range(0.25, 0.7)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r * rng.randf_range(0.8, 1.3), r * rng.randf_range(0.5, 0.9), r)), Vector3(p.x, ArenaLayout.GROUND_Y, p.y)))
		cols.append(Color(0.26, 0.42, 0.18).lerp(Color(0.42, 0.45, 0.2), rng.randf()))
	_batch("ferns", fern, Color.WHITE, xfs, cols)


## An outpost: a deck of planks on two bearers and a pair of braces to the trunk; the rounded landing rail
## along its outer edge (the perch, rope-wrapped where the feet go); a nest-box hangar with a roundel by the
## trunk; a few small crates.
func _outpost(o: ArenaLayout.OutpostData) -> void:
	var body := StaticBody3D.new()
	body.name = "Outpost%d" % o.id
	body.collision_layer = WORLD_LAYER
	add_child(body)
	var side := o.out.cross(Vector3.UP).normalized()
	var frame := Basis(side, Vector3.UP, -o.out)   # (x along the rail, y up, z back toward the trunk)
	var at := func(x: float, y: float, z: float) -> Vector3:   # deck frame, m: z out from the deck's middle
		return o.centre + side * x + Vector3.UP * y + o.out * z
	var wood := _mat("pw_plank", Color(0.6, 0.48, 0.34))
	var dark := _mat("pw_bearer", Color(0.42, 0.33, 0.25))
	var n := 9
	for i in n:
		var x := lerpf(-o.width * 0.5, o.width * 0.5, (i + 0.5) / n)
		_box(body, at.call(x, -o.thickness * 0.3, 0.0), frame, Vector3(o.width / n - 0.012, o.thickness * 0.6, o.depth), wood, false)
	for z in [-o.depth * 0.3, o.depth * 0.3]:
		_box(body, at.call(0.0, -o.thickness * 0.8, z), frame, Vector3(o.width, o.thickness * 0.5, 0.07), dark, false)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(o.width, o.thickness, o.depth)
	col.shape = box
	col.transform = Transform3D(frame, at.call(0.0, -o.thickness * 0.5, 0.0))
	body.add_child(col)
	# Braces: from under the outer corners down and back to the trunk.
	for e in [-1.0, 1.0]:
		_rod(at.call(e * o.width * 0.38, -o.thickness, o.depth * 0.3), at.call(e * o.width * 0.12, -0.9, -o.depth * 0.5 + 0.1), 0.035, dark)
	# The landing rail: a peeled log along the outer edge, rope-wrapped in the middle.
	var r0: Vector3 = at.call(-o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	var r1: Vector3 = at.call(o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	_rod(r0, r1, o.rail_radius, _mat("pw_rail", Color(0.66, 0.54, 0.4)))
	_rod(r0.lerp(r1, 0.3), r0.lerp(r1, 0.7), o.rail_radius + 0.006, _mat("pw_rope", Color(0.72, 0.64, 0.46)))
	var rc := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = o.rail_radius
	cap.height = o.width + o.rail_radius * 2.0
	rc.shape = cap
	rc.transform = Transform3D(_basis_along(side), (r0 + r1) * 0.5)
	body.add_child(rc)
	# The hangar: a nest box by the trunk to one side, its door toward the rail, a roundel on its outer side.
	var hx := o.width * 0.5 - 0.27
	var hz := -o.depth * 0.5 + 0.3
	var hangar := _box(body, at.call(hx, 0.25, hz), frame, Vector3(0.42, 0.5, 0.44), _mat("pw_hangar", Color(0.52, 0.4, 0.3)), true)
	hangar.name = "Hangar"
	_box(body, at.call(hx, 0.52, hz), frame * Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0.5, 0.03, 0.54), dark, false)
	_disc(at.call(hx, 0.22, hz + 0.222), o.out, 0.09, _mat("pw_door", Color(0.05, 0.04, 0.03)))
	var rings := [[0.13, Color(0.85, 0.72, 0.25)], [0.1, Color(0.15, 0.25, 0.55)], [0.045, Color(0.85, 0.72, 0.25)]]
	for i in rings.size():
		_disc(at.call(hx + 0.212 + 0.001 * i, 0.27, hz), side, rings[i][0], _mat("pw_roundel%d" % i, rings[i][1]))
	# Crates: small, stacked by the hangar.
	var crate := _mat("pw_crate", Color(0.55, 0.44, 0.22))
	for q in [[-0.05, 0.0, 0.0], [0.05, 0.0, 0.02], [0.0, 0.06, 0.01], [0.16, 0.0, -0.06]]:
		_box(body, at.call(hx - 0.36 + q[0], 0.03 + q[1], hz + 0.05 + q[2]), frame, Vector3(0.09, 0.06, 0.06), crate, false)


func _box(body: Node3D, c: Vector3, b: Basis, size: Vector3, m: Material, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.transform = Transform3D(b, c)
	add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.transform = Transform3D(b, c)
		body.add_child(cs)
	return mi


func _rod(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = m
	mi.transform = Transform3D(_basis_along(b - a), (a + b) * 0.5)
	add_child(mi)


## A thin disc facing `n`.
func _disc(c: Vector3, n: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.004
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = m
	mi.transform = Transform3D(_basis_along(n), c)
	add_child(mi)
