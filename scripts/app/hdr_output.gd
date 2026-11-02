class_name HdrOutput
extends CanvasLayer
## HDR display output (Godot 4.7): the scene is lit in HDR anyway; this asks the window to send it to an HDR
## monitor as HDR (Windows HDR on), so highlights -- sunlit feather edges, glints, the sun through the leaves --
## go brighter than paper white instead of being rolled off at it. F4 toggles it; a corner label says what the
## display reports. On by default where the display supports it (--sdr: off). Needs the Direct3D 12 renderer on
## Windows (Vulkan reports no HDR support there): `.\hdr.ps1` runs the game so.
##   HdrOutput.add(self)   # in a scene's _ready

var _label: Label
var _shown := 0.0


static func add(parent: Node) -> HdrOutput:
	var h := HdrOutput.new()
	h.name = "HdrOutput"
	parent.add_child(h)
	return h


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.position = Vector2(-330, 8)
	_label.size = Vector2(320, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	# (off for screenshots and sheets: they're saved, and measured, as ordinary SDR images)
	var args := OS.get_cmdline_user_args()
	set_hdr(not (args.has("--sdr") or args.has("--shot") or args.has("--sheet")))


func set_hdr(on: bool) -> void:
	# (asking an SDR display, or the Vulkan renderer on Windows, only earns an engine warning)
	var ok := DisplayServer.window_is_hdr_output_supported(get_window().get_window_id())
	get_window().hdr_output_requested = on and ok
	_shown = 4.0
	await get_tree().process_frame
	await get_tree().process_frame
	_report()


func _report() -> void:
	var id := get_window().get_window_id()
	var supported := DisplayServer.window_is_hdr_output_supported(id)
	var enabled := DisplayServer.window_is_hdr_output_enabled(id)
	var text := ""
	if not supported:
		text = "HDR: this display doesn't offer it (Windows HDR off?)  F4"
	elif enabled:
		text = "HDR on: peak %.0f nits, white %.0f nits  F4" % [DisplayServer.window_get_hdr_output_current_max_luminance(id), DisplayServer.window_get_hdr_output_current_reference_luminance(id)]
	else:
		text = "HDR off (SDR)  F4"
	_label.text = text
	print(text)


func _process(dt: float) -> void:
	_shown = maxf(_shown - dt, 0.0)
	_label.modulate.a = clampf(_shown, 0.0, 1.0)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F4:
		set_hdr(not get_window().hdr_output_requested)
