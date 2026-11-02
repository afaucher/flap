class_name WingTrails
extends Node3D
## Wingtip trails (docs/design/combat_concepts.html, "Seeing the fight"): the last LENGTH seconds of each
## wingtip of the birds it tracks, as thin camera-facing ribbons that fade and narrow with age. They thicken
## with load factor (a hard pull makes stronger tip vortices), and fade out close to the camera -- invisible
## within NEAR m, full by FAR m -- so they help at range without cluttering a close fight.
## Reads each bird's rig pose (wing joints) and telemetry only.

const LENGTH := 1.0
const NEAR := 4.0
const FAR := 15.0

var color := Color(1, 1, 1)
var _tracks := {}     ## Bird -> Array of [t, left tip, right tip, load]
var _clock := 0.0
var _mesh: ImmediateMesh


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func track(b: Bird) -> void:
	_tracks[b] = []


func untrack(b: Bird) -> void:
	_tracks.erase(b)


## The two wingtips in world space: past the hand by roughly the longest primary.
static func tips(b: Bird) -> Array:
	var r := b.rig
	if r == null or r.wing_joints[0].size() < 4:
		return []
	var out := []
	for i in 2:
		var j: Array = r.wing_joints[i]
		var hand: Vector3 = j[3]
		var wrist: Vector3 = j[2]
		var tip := hand + (hand - wrist).normalized() * b.profile.span * 0.5 * 0.35
		out.append(r.global_transform * tip)
	return out


func _physics_process(dt: float) -> void:
	_clock += dt
	for b in _tracks.keys():
		if not is_instance_valid(b):
			_tracks.erase(b)
			continue
		var pts: Array = _tracks[b]
		var tp := tips(b)
		if b.state == Bird.State.FLYING and tp.size() == 2:
			pts.append([_clock, tp[0], tp[1], float(b.model.load_factor)])
		while pts.size() > 0 and _clock - float(pts[0][0]) > LENGTH:
			pts.pop_front()


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var started := false
	for b in _tracks:
		var pts: Array = _tracks[b]
		if pts.size() < 2:
			continue
		for side in 2:
			for i in range(1, pts.size()):
				var a: Vector3 = pts[i - 1][side + 1]
				var c: Vector3 = pts[i][side + 1]
				var seg := c - a
				if seg.length() < 1e-4:
					continue
				var k := 1.0 - (_clock - float(pts[i][0])) / LENGTH        # 1 newest .. 0 oldest
				var near := smoothstep(NEAR, FAR, eye.distance_to(c))
				var w := (0.006 + 0.012 * clampf(float(pts[i][3]) - 1.0, 0.0, 2.0)) * (0.3 + 0.7 * k) * maxf(1.0, eye.distance_to(c) * 0.12)
				var col := Color(color.r, color.g, color.b, 0.75 * k * k * near)
				if col.a < 0.01:
					continue
				var s := seg.cross(eye - c).normalized() * w
				if not started:
					_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
					started = true
				for v in [a - s, a + s, c + s, a - s, c + s, c - s]:
					_mesh.surface_set_color(col)
					_mesh.surface_add_vertex(v)
	if started:
		_mesh.surface_end()
