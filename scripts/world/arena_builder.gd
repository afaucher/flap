class_name ArenaBuilder
extends Node3D
## Greybox meshes and collision for an ArenaLayout: a gridded ground, trunks and branches (static bodies on
## layer 1), a perch marker on every grip point, pale ground strips under the open lanes, boundary posts,
## and the landing mark: a short bar on the perch where the bird would land, green or red (show_candidate).

const WORLD_LAYER := 1

var layout: ArenaLayout
var tree_bodies: Array[StaticBody3D] = []   ## by tree id
var highlight: MeshInstance3D      ## the landing mark (show_candidate)
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
	if layout.style != "pinewood":   # (in the pine wood perches are just wood; the catch ring shows on approach)
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
	sm.shader = load("res://scripts/world/forest_floor.gdshader" if layout.style == "pinewood" else "res://scripts/world/ground_grid.gdshader")
	if layout.style == "pinewood":
		var g := "res://assets/textures/ground/forrest_ground_03/forrest_ground_03"
		sm.set_shader_parameter("use_scan", true)
		sm.set_shader_parameter("scan_albedo", load(g + "_diff_2k.jpg"))
		sm.set_shader_parameter("scan_normal", load(g + "_nor_gl_2k.jpg"))
		sm.set_shader_parameter("scan_arm", load(g + "_arm_2k.jpg"))
		sm.set_shader_parameter("scan_tint", Color(0.62, 0.58, 0.52))
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


## The landing mark's colours: slow enough to catch, or too fast.
const MARK_OK := Color(0.3, 1.0, 0.4)
const MARK_FAST := Color(1.0, 0.3, 0.25)
const MARK_THICK := 0.08     ## m, a treetop disc's thickness
const MARK_WRAP := 0.012     ## m the band stands proud of the branch, all round
const MARK_HALF := 0.5       ## of the catch radius each side of the landing point: the bar's half length


func _highlight() -> void:
	highlight = MeshInstance3D.new()
	var bar := CylinderMesh.new()   # (unit height and diameter, sized each frame)
	bar.top_radius = 0.5
	bar.bottom_radius = 0.5
	bar.height = 1.0
	bar.radial_segments = 12
	bar.rings = 1
	highlight.mesh = bar
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.albedo_color = MARK_OK
	highlight.material_override = _hl_mat
	highlight.visible = false
	add_child(highlight)


## Mark where the bird would land on `p`: a band round the branch itself, centred on `grip` and as long as the catch
## reach either side (cut at the branch's ends) -- or a small disc on a treetop. Depth-tested like the wood, so the
## needles in front of the branch hide it as they hide the branch. Green while the bird is slow enough to catch it,
## red while too fast (it can only be too fast). Null hides it.
func show_candidate(p: Perch, too_fast: bool, grab_radius: float, grip := Vector3.ZERO) -> void:
	if p == null:
		highlight.visible = false
		return
	highlight.visible = true
	_hl_mat.albedo_color = MARK_FAST if too_fast else MARK_OK
	var at := grip if grip != Vector3.ZERO else p.position
	if p.kind == Perch.Kind.TREETOP:
		var r := minf(p.disc, grab_radius * MARK_HALF)
		highlight.basis = Basis.from_scale(Vector3(r * 2.0, MARK_THICK * 0.5, r * 2.0))
		highlight.position = at + Vector3.UP * MARK_THICK * 0.5
		return
	var along := p.b - p.a
	var n := along.length()
	var dir := along / maxf(n, 1e-4)
	var u := clampf((at - p.a).dot(dir), 0.0, n)
	var half := grab_radius * MARK_HALF
	var u0 := maxf(u - half, 0.0)
	var u1 := minf(u + half, n)
	var mid := p.a + dir * (u0 + u1) * 0.5 - Vector3.UP * p.thickness   # (the grip line is the branch's top; thickness its radius)
	var y_axis := dir
	var x_axis := y_axis.cross(Vector3.UP)
	x_axis = x_axis.normalized() if x_axis.length() > 1e-3 else Vector3.RIGHT
	var z_axis := x_axis.cross(y_axis).normalized()
	var d := 2.0 * (p.thickness + MARK_WRAP)
	highlight.basis = Basis(x_axis * d, y_axis * maxf(u1 - u0, d), z_axis * d)
	highlight.position = mid


# --- Pine wood (Pinewood) ---------------------------------------------------------------------------------

## The pine wood in greybox: trunks, limbs and foliage drawn as instanced batches (thousands of pieces), each
## tree's trunk and limbs solid; foliage and ferns are drawn only (birds fly through needles and leaves);
## the outposts' decks, rails and hangars solid.
func _pinewood() -> void:
	# Trunks and limbs as built meshes (smooth, tapered, curved; a collar where a limb leaves its trunk, a flare
	# at a trunk's foot, a little wobble round and up it), grouped by material in 32 m cells so cells off
	# screen and outside a shadow cascade are skipped; collision as before (trunk cylinders, limb capsules).
	var cells := {}
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
		var oak: bool = t.kind == ArenaLayout.Kind.BROADLEAF
		var seed := fmod(t.id * 0.6180339, 1.0)
		var cell := Vector2i(floori(t.base.x / 32.0), floori(t.base.y / 32.0))
		_trunk(_cell(cells, cell, "oak_trunk" if oak else "pine_trunk"), t, seed)
		for lb in t.limbs:
			_tube(_cell(cells, cell, lb[2]), lb[0], lb[1], 9 if float(lb[1][0]) > 0.05 else 6, _TILE[lb[2]], fmod(seed + (lb[0] as PackedVector3Array)[0].y * 0.37, 1.0))
		for br in t.branches:
			if not br.solid:
				continue
			var dir: Vector3 = br.tip - br.root
			var length := dir.length()
			var bcs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = br.radius
			cap.height = length + br.radius * 2.0
			bcs.shape = cap
			bcs.position = (br.root + br.tip) * 0.5 - c
			bcs.basis = _basis_along(dir / length)
			body.add_child(bcs)
		add_child(body)
		tree_bodies.append(body)
	for k in cells:
		var arr: Array = cells[k]
		if (arr[0] as PackedVector3Array).is_empty():
			continue
		var surf := []
		surf.resize(Mesh.ARRAY_MAX)
		surf[Mesh.ARRAY_VERTEX] = arr[0]
		surf[Mesh.ARRAY_NORMAL] = arr[1]
		surf[Mesh.ARRAY_TANGENT] = arr[2]
		surf[Mesh.ARRAY_TEX_UV] = arr[3]
		surf[Mesh.ARRAY_TEX_UV2] = arr[4]
		surf[Mesh.ARRAY_INDEX] = arr[5]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
		var mi := MeshInstance3D.new()
		mi.name = "Wood_%s" % k
		mi.mesh = m
		mi.material_override = _bark(String(k).get_slice("@", 0))
		add_child(mi)
	_crowns()
	_floor()
	for o in layout.outposts:
		_outpost(o)


## The bark materials (bark.gdshader; textures in assets/textures/bark, assets/LICENSES.md): [A, B, settings].
const _BARK := {
	"pine_trunk": ["pine_bark", "knotted_pine_bark", {"tile_a": 2.0, "tile_b": 1.7, "tint_a": Color(0.82, 0.78, 0.76), "tint_b": Color(1.25, 0.82, 0.6), "blend_lo": 0.48, "blend_hi": 0.78}],
	"limb": ["knotted_pine_bark", "knotted_pine_bark", {"tile_b": 0.6, "tint_b": Color(1.2, 0.8, 0.58), "b_only": true, "detail_scale": 0.015}],
	"stub": ["knotted_pine_bark", "knotted_pine_bark", {"tile_b": 0.5, "tint_b": Color(0.95, 0.92, 0.9), "b_only": true, "detail_scale": 0.012}],
	"oak_trunk": ["jolcham_oak_bark_01", "jolcham_oak_bark_01", {"tile_b": 1.0, "aspect_b": 2.0, "b_only": true}],
	"oak_limb": ["jolcham_oak_bark_01", "jolcham_oak_bark_01", {"tile_b": 0.5, "aspect_b": 2.0, "b_only": true, "detail_scale": 0.015}],
	"twig": ["knotted_pine_bark", "knotted_pine_bark", {"tile_b": 0.3, "tint_b": Color(0.78, 0.62, 0.5), "b_only": true, "detail_scale": 0.008}],
}
const BARK_SHADER := preload("res://scripts/world/bark.gdshader")
## m each bark photo spans round a built mesh (bark.gdshader's tile for that material)
const _TILE := {"pine_trunk": 2.0, "oak_trunk": 1.0, "limb": 0.6, "stub": 0.5, "oak_limb": 0.5, "twig": 0.3}


## The arrays for material `key` in `cell`: [verts, normals, tangents, uv, uv2, indices].
func _cell(cells: Dictionary, cell: Vector2i, key: String) -> Array:
	var k := "%s@%d_%d" % [key, cell.x, cell.y]
	if not cells.has(k):
		cells[k] = [PackedVector3Array(), PackedVector3Array(), PackedFloat32Array(), PackedVector2Array(), PackedVector2Array(), PackedInt32Array()]
	return cells[k]


## A tube through `pts` with `radii` (per point), `segs` round, appended to `arr`. UV in metres -- round the tube
## a whole number of `tile`s at its base radius (no seam), along it its length -- UV2 (share of its length, seed).
## Normals radial; frames carried along the curve without twisting.
func _tube(arr: Array, pts: PackedVector3Array, radii: PackedFloat32Array, segs: int, tile: float, seed: float, rings := []) -> void:
	var n := pts.size()
	var base: int = (arr[0] as PackedVector3Array).size()
	var around: float = maxf(1.0, roundf(TAU * radii[0] / tile)) * tile
	var total := 0.0
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
	var t0 := (pts[1] - pts[0]).normalized()
	var nrm := t0.cross(Vector3.UP if absf(t0.y) < 0.95 else Vector3.RIGHT).normalized()
	var run := 0.0
	for i in n:
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm = (nrm - tg * nrm.dot(tg)).normalized()
		var bn := tg.cross(nrm)
		if i > 0:
			run += pts[i].distance_to(pts[i - 1])
		for j in segs + 1:
			var ang := TAU * j / segs
			var radial := nrm * cos(ang) + bn * sin(ang)
			var r: float = radii[i] * (float(rings[i][j % segs]) if not rings.is_empty() else 1.0)
			arr[0].append(pts[i] + radial * r)
			arr[1].append(radial)
			var tan := -nrm * sin(ang) + bn * cos(ang)
			arr[2].append_array(PackedFloat32Array([tan.x, tan.y, tan.z, 1.0]))
			arr[3].append(Vector2(around * j / segs, run))
			arr[4].append(Vector2(run / maxf(total, 1e-4), seed))
	for i in n - 1:
		for j in segs:
			var v := base + i * (segs + 1) + j
			var w := v + segs + 1
			arr[5].append_array(PackedInt32Array([v, w, v + 1, v + 1, w, w + 1]))


## A trunk: tapering, flared at its foot, a little out of round and wobbling up its height; capped at the top.
func _trunk(arr: Array, t: ArenaLayout.TreeData, seed: float) -> void:
	var c := Vector3(t.base.x, ArenaLayout.GROUND_Y, t.base.y)
	var oak := t.kind == ArenaLayout.Kind.BROADLEAF
	var top_share := 0.65 if oak else (0.4 if t.kind == ArenaLayout.Kind.PINE else 0.25)
	var flare := 0.55 if oak else (0.3 if t.kind == ArenaLayout.Kind.PINE else 0.1)
	var segs := 22 if oak else (18 if t.kind == ArenaLayout.Kind.PINE else 7)
	var n := 26 if t.kind != ArenaLayout.Kind.SAPLING else 5
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var rings := []
	for i in n:
		var u := pow(float(i) / (n - 1), 1.6)   # (rings closer near the foot, where the flare turns)
		var y := t.height * u - 0.15
		pts.append(c + Vector3.UP * y)
		radii.append(t.radius * lerpf(1.0, top_share, clampf(y / t.height, 0.0, 1.0)) * (1.0 + flare * exp(-maxf(y, 0.0) / (0.9 if oak else 0.6))))
		var ring := []
		for j in segs:
			var a := TAU * j / segs
			ring.append(1.0 + 0.03 * sin(3.0 * a + seed * 9.0 + y * 0.35) + 0.02 * sin(5.0 * a + seed * 4.0 - y * 0.8) + (0.06 * flare * sin(4.0 * a + seed * 7.0) * exp(-maxf(y, 0.0) / 0.7)))
		rings.append(ring)
	_tube(arr, pts, radii, segs, _TILE["oak_trunk" if oak else "pine_trunk"], seed, rings)


func _bark(key: String) -> ShaderMaterial:
	var spec: Array = _BARK[key]
	var m := ShaderMaterial.new()
	m.shader = BARK_SHADER
	for slot in [["_a", spec[0]], ["_b", spec[1]]]:
		var dir := "res://assets/textures/bark/%s/%s" % [slot[1], slot[1]]
		m.set_shader_parameter("albedo" + slot[0], load(dir + "_diff_2k.jpg"))
		m.set_shader_parameter("normal" + slot[0], load(dir + "_nor_gl_2k.jpg"))
		m.set_shader_parameter("arm" + slot[0], load(dir + "_arm_2k.jpg"))
		if slot[0] == "_a":
			m.set_shader_parameter("disp_a", load(dir + "_disp_2k.jpg"))
	for k in (spec[2] as Dictionary):
		m.set_shader_parameter(k, spec[2][k])
	m.set_shader_parameter("built", true)
	return m


func _cyl(bottom: float, top: float, segs: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = 1.0
	m.radial_segments = segs
	m.rings = 1
	return m


func _batch(key: String, mesh: Mesh, color: Color, xfs: Array, colors := [], customs := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not customs.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, customs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Batch_" + key
	mi.multimesh = mm
	var m := _mat("pw_" + key, color)
	m.vertex_color_use_as_albedo = mm.use_colors
	mi.material_override = m
	add_child(mi)
	return mi


## The crowns: each foliage clump (TreeData.foliage, an ellipsoid) filled with alpha-tested cards
## (foliage.gdshader, FoliageTex) -- sprays of needles on the pines and saplings, leaf clusters on the oaks --
## set mostly round the clump's shell, facing out and up, their sprays pointing outward; drawn only.
const _CARDS := {
	"needles": {"tex": "needles", "aspect": FoliageTex.NEEDLE_ASPECT, "size": Vector2(0.35, 0.6), "per_m3": 70.0, "n": Vector2i(40, 120), "tint": Color(0.86, 0.98, 0.98), "tex_size": 1024.0, "scissor": 0.4, "boost": 0.3, "boost_from": 3.0},
	"sapling": {"tex": "needles", "aspect": FoliageTex.NEEDLE_ASPECT, "size": Vector2(0.2, 0.34), "per_m3": 110.0, "n": Vector2i(10, 30), "tint": Color(0.9, 1.0, 0.95), "tex_size": 1024.0, "scissor": 0.4, "boost": 0.3, "boost_from": 3.0},
	"leaves": {"tex": "oak", "size": Vector2(0.6, 0.95), "per_m3": 6.0, "n": Vector2i(16, 80), "tint": Color(1.0, 1.0, 1.0)},
}
const FOLIAGE_SHADER := preload("res://scripts/world/foliage.gdshader")


func _crowns() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed * 7 + 3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var sets := {}
	for k in _CARDS:
		sets[k] = [[], [], []]
	for t in layout.trees:
		var k := "leaves" if t.kind == ArenaLayout.Kind.BROADLEAF else ("sapling" if t.kind == ArenaLayout.Kind.SAPLING else "needles")
		var spec: Dictionary = _CARDS[k]
		for f in t.foliage:
			var c: Vector3 = f[0]
			var r: Vector3 = f[1]
			var n := clampi(int(r.x * r.y * r.z * 4.19 * float(spec.per_m3)), spec.n.x, spec.n.y)
			var phase := rng.randf()
			for i in n:
				var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
				var p := c + d * r * pow(rng.randf(), 0.35) * 0.85
				var normal := (d + Vector3.UP * 0.7 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.6).normalized()
				var outward := Vector3(d.x, 0.0, d.z)
				outward = outward.normalized() if outward.length() > 0.05 else Vector3.RIGHT
				outward = outward.rotated(normal, rng.randf_range(-1.2, 1.2) * (1.8 if k != "leaves" else 1.0))   # (no two sprays point quite the same way; pine shoots any way round the tuft)
				var x := (outward - normal * outward.dot(normal)).normalized()
				var y := normal.cross(x)
				var size := rng.randf_range(spec.size.x, spec.size.y)
				var aspect: float = spec.get("aspect", 1.0)
				var b := Basis(x * size, y * size * aspect, normal * size)
				sets[k][0].append(Transform3D(b, p + x * size * 0.3))
				sets[k][1].append(Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.8), rng.randf()) * rng.randf_range(0.85, 1.1))
				sets[k][2].append(Color(c.x, c.y, c.z, phase))
	for k in _CARDS:
		var mi := _batch("cards_" + k, quad, Color.WHITE, sets[k][0], sets[k][1], sets[k][2])
		mi.material_override = _foliage_mat(k, _CARDS[k])


func _foliage_mat(key: String, spec: Dictionary, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("tex", FoliageTex.get_tex(spec.tex))
	m.set_shader_parameter("tint", spec.tint)
	for p in ["tex_size", "scissor", "boost", "boost_from"]:
		if spec.has(p):
			m.set_shader_parameter(p, spec[p])
	for e in extra:
		m.set_shader_parameter(e, extra[e])
	return m


## The forest floor: bracken, clumps of arching fronds (cards bent in the shader), thick away from the trunks'
## feet; drawn only.
func _floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed * 13 + 5
	var frond := QuadMesh.new()
	frond.size = Vector2.ONE
	frond.subdivide_depth = 8
	frond.center_offset = Vector3(0.0, 0.5, 0.0)   # (the base at the origin, the frond up +Y)
	var xfs := []
	var cols := []
	var cus := []
	# (bracken grows where the light gets in: thick in the gaps and glades, thin under the clumps)
	for i in 6400:
		var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * layout.boundary
		if p.length() > layout.boundary:
			continue
		var lit := Pinewood.light(layout, p)
		if rng.randf() > lerpf(0.4, 1.0, lit):
			continue
		var base := Vector3(p.x, ArenaLayout.GROUND_Y, p.y)
		var size := rng.randf_range(0.6, 1.4) * lerpf(0.8, 1.2, lit)
		var phase := rng.randf()
		var tint := Color(1, 1, 1).lerp(Color(1.1, 1.0, 0.75), rng.randf()) * rng.randf_range(0.85, 1.05)
		var fronds := rng.randi_range(4, 7)
		var a0 := rng.randf() * TAU
		for j in fronds:
			var az := a0 + TAU * j / fronds + rng.randf_range(-0.3, 0.3)
			var out := Vector3(sin(az), 0.0, cos(az))
			var up := (Vector3.UP * rng.randf_range(0.9, 1.6) + out).normalized()   # the frond's line, out and up
			var side := out.cross(Vector3.UP).normalized()
			var nrm := side.cross(up).normalized()   # (faces up and out; the shader droops the tip toward its back)
			if nrm.y < 0.0:
				nrm = -nrm
				side = -side
			var b := Basis(side * size * 0.6, up * size, nrm * size)
			xfs.append(Transform3D(b, base))
			cols.append(tint)
			cus.append(Color(base.x, base.y + size * 0.4, base.z, phase))
	var mi := _batch("ferns", frond, Color.WHITE, xfs, cols, cus)
	mi.material_override = _foliage_mat("ferns", {"tex": "fern", "tint": Color(1, 1, 1)}, {"bend": 0.35, "clump_normal": 0.45, "sway": 0.015, "flutter": 0.01, "backlight": 0.7})


## An outpost (docs/images/concepts/r4_aces_outpost.jpg): a deck of hand-sawn planks nailed across two heavy
## squared bearers and a rim beam each side, braced to the trunk by squared struts with iron plates and bolts; the
## round landing rail along its outer edge (the perch), rope-wound where the feet go and strapped down at its ends;
## a hangar of vertical boards on battens under a plank roof, a roundel painted on its outer side, its door toward
## the rail; brass-bound ammo boxes stacked by it. The planks are their own meshes (_plank_mesh, test_planks); all
## the rest is one TimberMesh (one draw call: _outpost_frame), shared by every outpost of a size.
func _outpost(o: ArenaLayout.OutpostData) -> void:
	var body := StaticBody3D.new()
	body.name = "Outpost%d" % o.id
	body.collision_layer = WORLD_LAYER
	add_child(body)
	var side := o.out.cross(Vector3.UP).normalized()
	var frame := Basis(side, Vector3.UP, -o.out)   # (x along the rail, y up, z back toward the trunk)
	var at := func(x: float, y: float, z: float) -> Vector3:   # deck frame, m: z out from the deck's middle
		return o.centre + side * x + Vector3.UP * y + o.out * z
	var zo := _bearer_z(o, true)
	var zi := _bearer_z(o, false)
	var wood := _timber("plank", {"nails": true, "nail_at": Vector2(-zo, -zi), "weather": 0.7})   # (a plank's z runs back: frame z = -out)
	# The planks: sawn by hand, no two quite alike (_plank_mesh), laid edge to edge with small uneven gaps.
	var prng := RandomNumberGenerator.new()
	prng.seed = 7919 * (o.id + 1) + layout.seed
	var n := 9
	var widths := []
	var wsum := 0.0
	for i in n:
		widths.append(prng.randf_range(0.82, 1.18))
		wsum += widths[i]
	var x0 := -o.width * 0.5
	for i in n:
		var w: float = o.width * widths[i] / wsum
		var gap := prng.randf_range(0.006, 0.016)
		var mi := MeshInstance3D.new()
		mi.name = "Outpost%d_Plank%d" % [o.id, i]
		mi.mesh = _plank_mesh(w - gap, o.thickness * 0.6, o.depth, prng, (i + o.id * 4) % 9)
		mi.material_override = wood
		mi.transform = Transform3D(frame, at.call(x0 + w * 0.5, -o.thickness * 0.3, 0.0))
		add_child(mi)
		x0 += w
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(o.width, o.thickness, o.depth)
	col.shape = box
	col.transform = Transform3D(frame, at.call(0.0, -o.thickness * 0.5, 0.0))
	body.add_child(col)
	# The landing rail's collision: a capsule along the outer edge (the perch; drawn in the frame mesh).
	var r0: Vector3 = at.call(-o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	var r1: Vector3 = at.call(o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	var rc := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = o.rail_radius
	cap.height = o.width + o.rail_radius * 2.0
	rc.shape = cap
	rc.transform = Transform3D(_basis_along(side), (r0 + r1) * 0.5)
	body.add_child(rc)
	# The hangar's collision: its box (drawn as boards in the frame mesh).
	var hx := _hangar_x(o)
	var hz := _hangar_z(o)
	var hs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = HANGAR_SIZE
	hs.shape = hb
	hs.transform = Transform3D(frame, at.call(hx, HANGAR_SIZE.y * 0.5, hz))
	hs.name = "Hangar"
	body.add_child(hs)
	# Everything else: one mesh in the deck's frame.
	var fr := _outpost_frame(o)
	var fm := MeshInstance3D.new()
	fm.name = "Outpost%d_Frame" % o.id
	fm.mesh = fr[0]
	fm.set_meta("pieces", fr[1])
	fm.material_override = _timber("frame", {"weather": 0.5, "roundel_c": Vector3(hx + HANGAR_SIZE.x * 0.5, ROUNDEL_Y, -hz), "roundel_n": Vector3.RIGHT, "roundel_r": ROUNDEL_R})
	fm.transform = Transform3D(frame, o.centre)
	add_child(fm)


const HANGAR_SIZE := ArenaLayout.HANGAR_SIZE   ## the hangar's box (its collision), deck frame
const ROUNDEL_Y := 0.27
const ROUNDEL_R := 0.15

static func _hangar_x(o: ArenaLayout.OutpostData) -> float:
	return ArenaLayout.hangar_x(o)


static func _hangar_z(o: ArenaLayout.OutpostData) -> float:
	return ArenaLayout.hangar_z(o)


## The bearers' z in the deck frame (out from its middle): the outer one under the plank ends by the rail, the
## inner one against the trunk.
static func _bearer_z(o: ArenaLayout.OutpostData, outer: bool) -> float:
	return o.depth * 0.5 - 0.085 if outer else -o.depth * 0.5 + 0.13


var _frames := {}

## The outpost's framing, rail, hangar and crates as one TimberMesh, in the deck's own frame (x along the rail,
## y up, z back toward the trunk -- so deck z goes in negated): [ArrayMesh, pieces].
func _outpost_frame(o: ArenaLayout.OutpostData) -> Array:
	var key := "%.3f_%.3f_%.3f_%.3f" % [o.width, o.depth, o.thickness, o.rail_radius]
	if _frames.has(key):
		return _frames[key]
	var tm := TimberMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4243
	var d := func(x: float, y: float, z: float) -> Vector3:   # deck (x, y up, z out) -> the mesh's frame
		return Vector3(x, y, -z)
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3(0.0, 0.0, -1.0)   # (deck out, in the mesh's frame)
	var pt := o.thickness * 0.6        # (the planks' thickness: their underside at -pt)
	var heart := func() -> Vector2:     # a boxed heart: the pith near the middle of a squared beam's section
		return Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012))
	# Bearers: heavy squared timbers across under the planks, their ends standing out past the deck's sides.
	var bh := 0.09
	var bw := 0.075
	var blen := o.width + 0.14
	var by := -pt - bh * 0.5
	for outer in [true, false]:
		var z := _bearer_z(o, outer)
		var xf := TimberMesh.frame_along(d.call(-blen * 0.5, by, z), d.call(blen * 0.5, by, z), Y)
		tm.box("bearer_out" if outer else "bearer_in", xf, Vector3(bh, blen, bw), TimberMesh.Kind.BEAM, rng.randf(), heart.call())
		# Bolted through where the rim beams butt on, and along the front between.
		var face: float = z + (bw * 0.5 if outer else -bw * 0.5)
		var bx := [-o.width * 0.5 + 0.035, o.width * 0.5 - 0.035]
		if outer:
			bx += [-0.42, -0.14, 0.14, 0.42]
		for x in bx:
			tm.bolt(d.call(x, by + 0.014, face), Z if outer else -Z, 0.0095, rng.randf())
	# Rim beams: along each side under the outermost planks, between the bearers.
	var rw := 0.06
	var rh := 0.075
	var z0 := _bearer_z(o, false) + bw * 0.5
	var z1 := _bearer_z(o, true) - bw * 0.5
	for e: float in [-1.0, 1.0]:
		var x: float = e * (o.width * 0.5 - rw * 0.5 - 0.005)
		var y := -pt - rh * 0.5
		var xf := TimberMesh.frame_along(d.call(x, y, z0), d.call(x, y, z1), Y)
		tm.box("rim_r" if e > 0.0 else "rim_l", xf, Vector3(rh, z1 - z0, rw), TimberMesh.Kind.BEAM, rng.randf(), heart.call())
		for k in 3:
			tm.bolt(d.call(x + e * rw * 0.5, y, lerpf(z0, z1, (k + 0.5) / 3.0)), X * e, 0.008, rng.randf())
	# Braces: squared struts from under the outer bearer down and back to the trunk, iron-plated at the head.
	var bs := 0.06
	for e: float in [-1.0, 1.0]:
		var top: Vector3 = d.call(e * o.width * 0.36, by - bh * 0.5 + 0.02, _bearer_z(o, true))
		var foot: Vector3 = d.call(e * o.width * 0.12, -0.9, -o.depth * 0.5 - 0.06)   # (its foot let into the trunk)
		var xf := TimberMesh.frame_along(foot, top, X)
		var ln := foot.distance_to(top)
		tm.box("brace_r" if e > 0.0 else "brace_l", xf, Vector3(bs, ln, bs), TimberMesh.Kind.BEAM, rng.randf(), heart.call())
		var ax := xf.basis.y
		for sg: float in [-1.0, 1.0]:   # (a plate each side of the strut's head, two bolts through)
			var nrm: Vector3 = xf.basis.x * sg
			var pc: Vector3 = top - ax * 0.09 + nrm * bs * 0.5
			tm.plate(pc, nrm, ax, Vector3(0.13, bs * 0.85, 0.004), rng.randf())
			for k: float in [-1.0, 1.0]:
				tm.bolt(pc + nrm * 0.004 + ax * k * 0.04, nrm, 0.007, rng.randf())
		# A strap on the bearer's face over the strut's head.
		var sp: Vector3 = d.call(e * o.width * 0.36, by, _bearer_z(o, true) + bw * 0.5)
		tm.plate(sp, Z, Y, Vector3(bh * 0.95, 0.07, 0.004), rng.randf())
		for k: float in [-1.0, 1.0]:
			tm.bolt(sp + Z * 0.004 + Y * k * 0.025, Z, 0.0075, rng.randf())
	# The landing rail: a peeled log along the outer edge (the perch), rope-wound in the middle, strapped at the ends.
	var ra: Vector3 = d.call(-o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	var rb: Vector3 = d.call(o.width * 0.5, o.rail_radius - o.thickness * 0.2, o.depth * 0.5 - o.rail_radius)
	var rxf := TimberMesh.frame_along(ra, rb, Y)
	tm.cylinder("rail", rxf, o.rail_radius, ra.distance_to(rb), TimberMesh.Kind.ROUND, rng.randf(), 18)
	tm.cylinder("rope", Transform3D(rxf.basis, ra.lerp(rb, 0.5)), o.rail_radius + 0.006, ra.distance_to(rb) * 0.4, TimberMesh.Kind.ROPE, rng.randf(), 18)
	for u: float in [0.06, 0.94]:
		tm.cylinder("strap", Transform3D(rxf.basis, ra.lerp(rb, u)), o.rail_radius + 0.0025, 0.022, TimberMesh.Kind.IRON, rng.randf(), 18)
	_hangar_frame(tm, o, rng, d)
	_crates(tm, o, rng, d)
	var out := [tm.commit(), tm.pieces]
	_frames[key] = out
	return out


## The hangar (in the deck frame by `d`): a dark box inside, walls of vertical boards with gaps (the outer side's
## carrying the painted roundel), battens nailed across them low and high, corner boards, a plank roof falling to
## the back with a fascia, a door toward the rail with a landing board under it.
func _hangar_frame(tm: TimberMesh, o: ArenaLayout.OutpostData, rng: RandomNumberGenerator, d: Callable) -> void:
	var hx := _hangar_x(o)
	var hz := _hangar_z(o)
	var S := HANGAR_SIZE
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3(0.0, 0.0, -1.0)
	var bt := 0.016   # (board thickness)
	var pitch := tan(deg_to_rad(8.0))
	var roof_y := func(z: float) -> float:   # the roof's underside over deck z
		return S.y - 0.01 + (z - hz) * pitch
	tm.box("hangar_core", Transform3D(Basis(), d.call(hx, S.y * 0.48, hz)), Vector3(S.x - 0.02, S.y * 0.96, S.z - 0.02), TimberMesh.Kind.DARK, 0.0)
	# The walls: [name, outward normal (deck), the wall's middle, its width, whether it runs along deck z]
	var walls := [
		["px", Vector3(1, 0, 0), Vector3(hx + S.x * 0.5 - bt * 0.5, 0.0, hz), S.z, true],
		["nx", Vector3(-1, 0, 0), Vector3(hx - S.x * 0.5 + bt * 0.5, 0.0, hz), S.z, true],
		["pz", Vector3(0, 0, 1), Vector3(hx, 0.0, hz + S.z * 0.5 - bt * 0.5), S.x - bt * 2.0, false],
		["nz", Vector3(0, 0, -1), Vector3(hx, 0.0, hz - S.z * 0.5 + bt * 0.5), S.x - bt * 2.0, false],
	]
	for wall in walls:
		var nm: Vector3 = wall[1]
		var c: Vector3 = wall[2]
		var wlen: float = wall[3]
		var along_z: bool = wall[4]
		var flags := TimberMesh.PAINTED if wall[0] == "px" else 0
		var nmesh := Vector3(nm.x, nm.y, -nm.z)
		var t_dir: Vector3 = Z if along_z else X   # (across the wall, in the mesh frame)
		# Four boards of uneven width, small gaps between.
		var nb := 4
		var ws := []
		var tot := 0.0
		for i in nb:
			ws.append(rng.randf_range(0.85, 1.15))
			tot += ws[i]
		var gap := 0.005
		var pos := -wlen * 0.5
		for i in nb:
			var bwid: float = (wlen - gap * (nb - 1)) * ws[i] / tot
			var mid := pos + bwid * 0.5
			var bc: Vector3 = c + (Vector3(0, 0, mid) if along_z else Vector3(mid, 0, 0))
			var top: float = roof_y.call(bc.z) + 0.004
			var xf := TimberMesh.frame_along(d.call(bc.x, 0.0, bc.z), d.call(bc.x, top, bc.z), t_dir)
			if xf.basis.z.dot(nmesh) < 0.0:   # (through the board: out of the wall)
				xf.basis.x = -xf.basis.x
				xf.basis.z = -xf.basis.z
			tm.box("hangar_board_%s_%d" % [wall[0], i], xf, Vector3(bwid, top, bt), TimberMesh.Kind.BOARD, rng.randf(), Vector2(rng.randf_range(-0.1, 0.1), -rng.randf_range(0.12, 0.3)), -1, flags)
			pos += bwid + gap
		# Battens across the boards, low and high, on the outside, nailed through to each board.
		var bat_h := 0.04
		var bat_t := 0.012
		var highs: float = roof_y.call(c.z) - 0.065
		if wall[0] == "px":
			highs = minf(highs, ROUNDEL_Y + ROUNDEL_R + 0.045)
		for bat_y: float in [0.06, highs]:
			var bcen: Vector3 = c + nm * (bt * 0.5 + bat_t * 0.5) + Vector3(0, bat_y, 0)
			var l2 := wlen * 0.5 - 0.012
			var off: Vector3 = Vector3(0, 0, l2) if along_z else Vector3(l2, 0, 0)
			var a0: Vector3 = bcen - off
			var a1: Vector3 = bcen + off
			var bxf := TimberMesh.frame_along(d.call(a0.x, a0.y, a0.z), d.call(a1.x, a1.y, a1.z), Y)
			if bxf.basis.z.dot(nmesh) < 0.0:
				bxf.basis.x = -bxf.basis.x
				bxf.basis.z = -bxf.basis.z
			tm.box("hangar_batten_%s" % wall[0], bxf, Vector3(bat_h, l2 * 2.0, bat_t), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, -rng.randf_range(0.1, 0.25)), -1, flags)
			for k in 4:
				var u := lerpf(-l2 + 0.04, l2 - 0.04, k / 3.0)
				var np: Vector3 = bcen + nm * bat_t * 0.5 + (Vector3(0, 0, u) if along_z else Vector3(u, 0, 0))
				tm.bolt(d.call(np.x, np.y, np.z), nmesh, 0.0035, rng.randf())
	# Corner boards up the front and back corners.
	for zs: float in [-1.0, 1.0]:
		for xs: float in [-1.0, 1.0]:
			var cz: float = hz + zs * (S.z * 0.5 + 0.006)
			var cx: float = hx + xs * (S.x * 0.5 - 0.018)
			var top: float = roof_y.call(cz)
			var xf := TimberMesh.frame_along(d.call(cx, 0.0, cz), d.call(cx, top, cz), X)
			tm.box("hangar_corner", xf, Vector3(0.036, top, 0.012), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, -0.15))
	# The roof: boards front to back, pitched to the back, overhanging, a fascia along the front.
	var rl := S.z + 0.14
	var rwid := S.x + 0.1
	var nr := 4
	var rgap := 0.006
	var rbw := (rwid - rgap * (nr - 1)) / nr
	for i in nr:
		var x: float = hx - rwid * 0.5 + rbw * 0.5 + i * (rbw + rgap)
		var zf: float = hz + rl * 0.5 + 0.02
		var zb: float = hz - rl * 0.5 + 0.02
		var a0: Vector3 = d.call(x, roof_y.call(zb) + 0.011, zb)
		var a1: Vector3 = d.call(x, roof_y.call(zf) + 0.011, zf)
		tm.box("roof_%d" % i, TimberMesh.frame_along(a0, a1, X), Vector3(rbw, rl, 0.022), TimberMesh.Kind.BOARD, rng.randf(), Vector2(rng.randf_range(-0.08, 0.08), -rng.randf_range(0.15, 0.3)))
	var fz: float = hz + rl * 0.5 + 0.02 + 0.008
	var fy: float = roof_y.call(fz) - 0.004
	tm.box("fascia", TimberMesh.frame_along(d.call(hx - rwid * 0.5, fy, fz), d.call(hx + rwid * 0.5, fy, fz), Y), Vector3(0.04, rwid, 0.016), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, 0.2))
	# The door: a dark opening toward the rail, framed, a landing board under it.
	var dz := hz + S.z * 0.5
	var dw := 0.15
	var dh := 0.2
	var dy := 0.12
	tm.box("door", Transform3D(Basis(), d.call(hx, dy + dh * 0.5, dz + 0.001)), Vector3(dw, dh, 0.004), TimberMesh.Kind.DARK, 0.0)
	for k in 2:   # (the jambs)
		var jx: float = hx + (k * 2 - 1) * (dw * 0.5 + 0.012)
		tm.box("door_jamb", TimberMesh.frame_along(d.call(jx, dy - 0.012, dz + 0.007), d.call(jx, dy + dh + 0.024, dz + 0.007), X), Vector3(0.024, dh + 0.036, 0.012), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, -0.2))
	tm.box("door_head", TimberMesh.frame_along(d.call(hx - dw * 0.5 - 0.024, dy + dh + 0.012, dz + 0.007), d.call(hx + dw * 0.5 + 0.024, dy + dh + 0.012, dz + 0.007), Y), Vector3(0.024, dw + 0.048, 0.012), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, -0.2))
	tm.box("door_step", TimberMesh.frame_along(d.call(hx - dw * 0.5 - 0.02, dy - 0.008, dz + 0.04), d.call(hx + dw * 0.5 + 0.02, dy - 0.008, dz + 0.04), Z), Vector3(0.075, dw + 0.04, 0.016), TimberMesh.Kind.BOARD, rng.randf(), Vector2(0.0, -0.2))


## Ammo boxes (the concept's): olive-painted, brass-bound -- a band round each end, brass corners, a lip round the
## lid, a latch on the front, a handle at each end -- two stacked by the hangar, one beside, one set down askew.
func _crates(tm: TimberMesh, o: ArenaLayout.OutpostData, rng: RandomNumberGenerator, d: Callable) -> void:
	var hx := _hangar_x(o)
	var hz := _hangar_z(o)
	var cs := Vector3(0.15, 0.075, 0.085)   # (x long, y tall, z deep)
	var places := [[hx - 0.38, 0.0, hz + 0.02, 0.0], [hx - 0.375, cs.y, hz + 0.025, 3.0], [hx - 0.37, 0.0, hz + 0.125, -4.0], [hx - 0.13, 0.0, hz + 0.31, 18.0]]
	for p in places:
		var b := Basis(Vector3.UP, deg_to_rad(p[3]))   # (mesh frame: b.x along the box, b.y up, b.z deep)
		var c: Vector3 = d.call(p[0], p[1] + cs.y * 0.5, p[2])
		var xb := Basis(b.y, b.x, -b.z)   # (piece frame: across up, along the box, through)
		var xf := Transform3D(xb, c)
		tm.box("crate", xf, Vector3(cs.y, cs.x, cs.z), TimberMesh.Kind.PAINT, rng.randf())
		for e: float in [-1.0, 1.0]:
			tm.box("crate_band", Transform3D(xb, c + b.x * e * (cs.x * 0.5 - 0.016)), Vector3(cs.y + 0.004, 0.012, cs.z + 0.004), TimberMesh.Kind.BRASS, rng.randf())
			tm.box("crate_handle", Transform3D(xb, c + b.x * e * (cs.x * 0.5 + 0.004) + b.y * 0.008), Vector3(0.008, 0.008, cs.z * 0.5), TimberMesh.Kind.BRASS, rng.randf())
			for ey: float in [-1.0, 1.0]:
				for ez: float in [-1.0, 1.0]:
					tm.box("crate_corner", Transform3D(xb, c + b.x * e * (cs.x * 0.5 - 0.006) + b.y * ey * (cs.y * 0.5 - 0.006) + b.z * ez * (cs.z * 0.5 - 0.006)), Vector3(0.015, 0.015, 0.015), TimberMesh.Kind.BRASS, rng.randf())
		tm.box("crate_lip", Transform3D(xb, c + b.y * (cs.y * 0.5 - 0.016)), Vector3(0.005, cs.x - 0.05, cs.z + 0.003), TimberMesh.Kind.BRASS, rng.randf())
		tm.box("crate_latch", Transform3D(xb, c + b.y * (cs.y * 0.5 - 0.02) - b.z * (cs.z * 0.5 + 0.003)), Vector3(0.022, 0.014, 0.005), TimberMesh.Kind.BRASS, rng.randf())


## A hand-sawn plank, centred like a BoxMesh of (w, t, length) -- x across, y up, z along -- but not quite square:
## its edges waver a few mm along the length (low, smooth bends, a little taper), the sawn ends are a touch out of
## square, the corners are knocked off, the upper arrises are worn round (a small bevel that catches the light),
## and the top is very slightly cupped and uneven. Within PLANK_DEV of the box everywhere. Each vertex carries the
## plank's frame for planks.gdshader (TimberMesh's attributes: across x, along z, through y), `board` the scan
## board it is cut from, and its pith: below or above the board for most (flat-sawn: the end grain's rings arcs),
## off to one side for some (quarter-sawn: the rings upright).
const PLANK_DEV := 0.006   ## m: the most any edge strays from the plank's box
const PLANK_STATIONS := 14
static func _plank_mesh(w: float, t: float, length: float, rng: RandomNumberGenerator, board := -1) -> ArrayMesh:
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var taper := rng.randf_range(-0.004, 0.004)
	var end_skew := [rng.randf_range(0.0015, 0.005) * signf(rng.randf() - 0.5), rng.randf_range(0.0015, 0.005) * signf(rng.randf() - 0.5)]   # (each end's run out of square)
	var chip := [rng.randf_range(0.004, 0.012), rng.randf_range(0.004, 0.012), rng.randf_range(0.004, 0.012), rng.randf_range(0.004, 0.012)]
	var bevel := minf(0.004, t * 0.25)
	var cup := rng.randf_range(0.0005, 0.0015)
	# Each edge's offset outward at u (0 .. 1 along): two smooth bends and the taper, kept inside PLANK_DEV.
	var edge := func(side: int, u: float) -> float:
		var a: float = ph[side * 2]
		var b: float = ph[side * 2 + 1]
		var d := 0.0018 * sin(u * PI * 1.3 + a) + 0.0011 * sin(u * PI * 3.7 + b) + taper * (u - 0.5) * (1 if side == 1 else -1)
		return clampf(d, -PLANK_DEV * 0.6, PLANK_DEV * 0.5)
	# The outline, as (x, z) pairs per station from end to end: left and right edge points.
	var rows := []
	for k in PLANK_STATIONS + 1:
		var u := float(k) / PLANK_STATIONS
		var z := lerpf(-length * 0.5, length * 0.5, u)
		var xl: float = -w * 0.5 - edge.call(0, u)
		var xr: float = w * 0.5 + edge.call(1, u)
		rows.append([Vector2(xl, z), Vector2(xr, z)])
	# The ends: out of square (the z of each corner moves), and the corners knocked off along the edge.
	for e in 2:
		var k := 0 if e == 0 else PLANK_STATIONS
		var sgn := -1.0 if e == 0 else 1.0
		var row: Array = rows[k]
		for s in 2:
			var p: Vector2 = row[s]
			p.y += sgn * (end_skew[e] * (1.0 if s == 1 else -1.0) - 0.0015)
			p.x += (chip[e * 2 + s] * 0.5) * (1.0 if s == 0 else -1.0)   # (the knocked-off corner pulls in)
			row[s] = p
	var pith := Vector2(rng.randf_range(-0.06, 0.06), rng.randf_range(0.05, 0.16) * signf(rng.randf() - 0.35))
	if rng.randf() < 0.25:
		pith = Vector2(rng.randf_range(0.1, 0.2) * signf(rng.randf() - 0.5), rng.randf_range(-0.03, 0.03))
	var pseed := rng.randf()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_smooth_group(0xFFFFFFFF)   # (flat: each face its own normal, the worn arrises catching the light)
	var put := func(p: Vector3) -> void:
		st.set_uv(Vector2(p.x, p.z))
		st.set_uv2(Vector2(p.y, pseed))
		st.set_custom(0, Color(w * 0.5, length * 0.5, t * 0.5, float(TimberMesh.Kind.BOARD)))
		st.set_custom(1, Color(pith.x, pith.y, float(board), 0.0))
		st.add_vertex(p)
	var top := t * 0.5
	var bot := -t * 0.5
	# Heights: the top's edges sit a little lower than its middle (cupped and worn), varying along the length.
	var lift := func(u: float) -> float:
		return 0.0006 * sin(u * PI * 2.0 + float(ph[0]))
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v in [a, b, c, a, c, d]:
			put.call(v)
	for k in PLANK_STATIONS:
		var u0 := float(k) / PLANK_STATIONS
		var u1 := float(k + 1) / PLANK_STATIONS
		var r0: Array = rows[k]
		var r1: Array = rows[k + 1]
		var l0: Vector2 = r0[0]
		var rr0: Vector2 = r0[1]
		var l1: Vector2 = r1[0]
		var rr1: Vector2 = r1[1]
		var h0: float = top + lift.call(u0)
		var h1: float = top + lift.call(u1)
		# The top: three strips across (worn edge, cupped middle, worn edge), wound to face up.
		var il0 := Vector3(l0.x + bevel, h0 - cup, l0.y)
		var ir0 := Vector3(rr0.x - bevel, h0 - cup, rr0.y)
		var il1 := Vector3(l1.x + bevel, h1 - cup, l1.y)
		var ir1 := Vector3(rr1.x - bevel, h1 - cup, rr1.y)
		var m0 := Vector3((l0.x + rr0.x) * 0.5, h0, (l0.y + rr0.y) * 0.5)
		var m1 := Vector3((l1.x + rr1.x) * 0.5, h1, (l1.y + rr1.y) * 0.5)
		quad.call(il0, m0, m1, il1)
		quad.call(m0, ir0, ir1, m1)
		# The worn arrises: from the top's edge down to the side, `bevel` in and down.
		var el0 := Vector3(l0.x, h0 - cup - bevel, l0.y)
		var el1 := Vector3(l1.x, h1 - cup - bevel, l1.y)
		var er0 := Vector3(rr0.x, h0 - cup - bevel, rr0.y)
		var er1 := Vector3(rr1.x, h1 - cup - bevel, rr1.y)
		quad.call(el0, il0, il1, el1)
		quad.call(ir0, er0, er1, ir1)
		# The sides, down to the bottom.
		var bl0 := Vector3(l0.x, bot, l0.y)
		var bl1 := Vector3(l1.x, bot, l1.y)
		var br0 := Vector3(rr0.x, bot, rr0.y)
		var br1 := Vector3(rr1.x, bot, rr1.y)
		quad.call(bl0, el0, el1, bl1)
		quad.call(er0, br0, br1, er1)
		# The bottom (face down).
		quad.call(bl0, bl1, br1, br0)
	# The sawn ends: the end's section, from the bottom edge up over the worn arrises to the top's middle.
	for e in 2:
		var k := 0 if e == 0 else PLANK_STATIONS
		var u := float(k) / PLANK_STATIONS
		var r: Array = rows[k]
		var l: Vector2 = r[0]
		var rr: Vector2 = r[1]
		var h: float = top + lift.call(u)
		var ring := [Vector3(l.x, bot, l.y), Vector3(l.x, h - cup - bevel, l.y), Vector3(l.x + bevel, h - cup, l.y), Vector3((l.x + rr.x) * 0.5, h, (l.y + rr.y) * 0.5), Vector3(rr.x - bevel, h - cup, rr.y), Vector3(rr.x, h - cup - bevel, rr.y), Vector3(rr.x, bot, rr.y)]
		var c := Vector3((l.x + rr.x) * 0.5, (bot + h) * 0.5, (l.y + rr.y) * 0.5)
		for q in ring.size():
			var a: Vector3 = ring[q]
			var b: Vector3 = ring[(q + 1) % ring.size()]
			var tri := [c, b, a] if e == 0 else [c, a, b]
			for p in tri:
				put.call(p)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


const PLANKS_SHADER := preload("res://scripts/world/planks.gdshader")


## Weathered timber (planks.gdshader), one material per use.
func _timber(key: String, params: Dictionary) -> Material:
	if layout.style != "pinewood":
		return _mat("pw_" + key, params.get("wood", Color(0.55, 0.44, 0.32)))
	var k := "timber_" + key + str(params)
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = PLANKS_SHADER
		var w := "res://assets/textures/planks/weathered_planks/weathered_planks"
		m.set_shader_parameter("scan_albedo", load(w + "_diff_2k.jpg"))
		m.set_shader_parameter("scan_normal", load(w + "_nor_gl_2k.jpg"))
		m.set_shader_parameter("scan_arm", load(w + "_arm_2k.jpg"))
		m.set_shader_parameter("scan_tint", Color(1.45, 1.3, 1.1))
		for p in params:
			m.set_shader_parameter(p, params[p])
		_mats[k] = m
	return _mats[k]
