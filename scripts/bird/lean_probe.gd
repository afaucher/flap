class_name LeanProbe
extends SubViewport
## The sitting birds' lean, measured on the GPU (BirdRig.gpu_feathers): how deep the deepest feather tip is inside
## what each bird sits on (BirdRig._posture). The feathers are placed in the shader, so their tips are only there:
## each frame every sitting bird asks (request), gets one pixel of this viewport (lean_probe.gdshader places its
## feathers as the feather shader does and measures their tips), and the row comes back asynchronously
## (RenderingDevice.texture_get_data_async) a frame or two later, never stalling the frame. The lean already eases in
## over a fraction of a second, so the answer arriving that much later doesn't show.

const MAX_BIRDS := 64
const SHADER := preload("res://scripts/bird/lean_probe.gdshader")

static var _inst: LeanProbe

var _rects: Array[ColorRect] = []
var _asked: Array = []    ## this frame's [rig (weak), material] per pixel
var _in_flight := 0


## Ask for `rig`'s deepest tip against `srf` (Bird telemetry's surface) as drawn this frame; the answer lands in
## rig.probe_worst (with rig.probe_frame) when it comes back.
static func request(rig: BirdRig, srf: Dictionary, margin: float) -> void:
	if _inst == null or not is_instance_valid(_inst):
		_inst = LeanProbe.new()
		rig.get_tree().root.add_child.call_deferred(_inst)
	_inst._ask(rig, srf, margin)


func _init() -> void:
	size = Vector2i(MAX_BIRDS, 1)
	use_hdr_2d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in MAX_BIRDS:
		var r := ColorRect.new()
		r.position = Vector2(i, 0)
		r.size = Vector2(1, 1)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		r.material = m
		r.visible = false
		add_child(r)
		_rects.append(r)


func _ready() -> void:
	RenderingServer.frame_post_draw.connect(_drawn)


func _ask(rig: BirdRig, srf: Dictionary, margin: float) -> void:
	var i := _asked.size()
	if i >= MAX_BIRDS:
		return
	var m := _rects[i].material as ShaderMaterial
	m.set_shader_parameter("defs", rig._defs_tex)
	m.set_shader_parameter("pose", rig._pose_tex)
	m.set_shader_parameter("slots", rig._plain_count + rig._emarg_count)
	m.set_shader_parameter("rig_xf", Projection(rig.global_transform))
	m.set_shader_parameter("margin", margin)
	match String(srf.kind):
		"branch":
			m.set_shader_parameter("srf_kind", 0)
			m.set_shader_parameter("srf_a", srf.a)
			m.set_shader_parameter("srf_b", srf.b)
			m.set_shader_parameter("srf_r", float(srf.radius))
		"disc":
			m.set_shader_parameter("srf_kind", 1)
			m.set_shader_parameter("srf_a", srf.centre)
			m.set_shader_parameter("srf_r", float(srf.radius))
		_:
			m.set_shader_parameter("srf_kind", 2)
			m.set_shader_parameter("srf_a", srf.centre)
	_rects[i].visible = true
	_asked.append(weakref(rig))


## After the frame is drawn: read this frame's pixels back without waiting, and free the pixels for the next frame.
func _drawn() -> void:
	if _asked.is_empty():
		return
	var rd := RenderingServer.get_rendering_device()
	var tex := RenderingServer.texture_get_rd_texture(get_texture().get_rid())
	if rd != null and tex.is_valid():
		rd.texture_get_data_async(tex, 0, _landed.bind(_asked.duplicate(), Engine.get_frames_drawn()))
		_in_flight += 1
	for i in _asked.size():
		_rects[i].visible = false
	_asked.clear()


func _landed(data: PackedByteArray, asked: Array, frame: int) -> void:
	_in_flight -= 1
	for i in asked.size():
		var rig := (asked[i] as WeakRef).get_ref() as BirdRig
		if rig == null:
			continue
		var o := i * 8   # (RGBA16F: two bytes a channel)
		rig.probe_worst = data.decode_half(o) + data.decode_half(o + 2) / 2048.0
		rig.probe_frame = frame
