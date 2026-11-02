class_name BoneView
extends MeshInstance3D
## The lab's bone view: a rig's skeleton drawn over it each frame -- every bone as a line from its joint to its
## far end, every joint as a small diamond -- on top of everything (no depth test), coloured by chain: spine
## and tail white, neck and head yellow, the left wing orange, the right wing cyan, the legs green. It reads
## BirdRig.bone_ends (what the rig last posed), so it shows the solve exactly, including the parts the body
## hides (the shoulder, the hip, the folded hand).

const COLORS := {
	"body": Color(0.95, 0.95, 0.95), "tail": Color(0.85, 0.7, 1.0),
	"neck": Color(1.0, 0.85, 0.2), "head": Color(1.0, 0.85, 0.2),
	"wing.L": Color(1.0, 0.55, 0.15), "wing.R": Color(0.2, 0.85, 1.0),
	"leg.L": Color(0.35, 0.95, 0.4), "leg.R": Color(0.2, 0.75, 0.3),
}

var rig: BirdRig
var _im := ImmediateMesh.new()


func _init() -> void:
	mesh = _im
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	material_override = m


static func chain(bone_name: String) -> String:
	var side := bone_name.get_slice(".", 1)
	if bone_name.begins_with("humerus") or bone_name.begins_with("forearm") or bone_name.begins_with("hand"):
		return "wing." + side
	if bone_name.begins_with("femur") or bone_name.begins_with("tibia") or bone_name.begins_with("tarsus"):
		return "leg." + side
	if bone_name.begins_with("neck"):
		return "neck"
	return bone_name


func _process(_dt: float) -> void:
	_im.clear_surfaces()
	if rig == null or not is_instance_valid(rig) or rig.bone_ends.is_empty():
		return
	var xf := rig.global_transform
	var r := rig.body.L * 0.012 if rig.body != null else 0.005
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in rig.bone_ends:
		var ends: Array = rig.bone_ends[n]
		var a: Vector3 = xf * (ends[0] as Vector3)
		var b: Vector3 = xf * (ends[1] as Vector3)
		var c: Color = COLORS.get(chain(n), Color.WHITE)
		_line(a, b, c)
		_diamond(a, r, c)
		_diamond(b, r * 0.5, c.darkened(0.3))
	_im.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_im.surface_set_color(c)
	_im.surface_add_vertex(a)
	_im.surface_set_color(c)
	_im.surface_add_vertex(b)


func _diamond(p: Vector3, r: float, c: Color) -> void:
	var tips := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for i in [0, 1]:
		for j in [2, 3, 4, 5]:
			_line(p + tips[i] * r, p + tips[j] * r, c)
	for j in [2, 3]:
		for k in [4, 5]:
			_line(p + tips[j] * r, p + tips[k] * r, c)
