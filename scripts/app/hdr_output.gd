class_name HdrOutput
extends CanvasLayer
## HDR display output (Godot 4.7): the scene is lit in HDR anyway; this asks the window to send it to an HDR
## monitor as HDR (Windows HDR on), so highlights -- sunlit feather edges, glints, the sun through the leaves --
## go brighter than paper white instead of being rolled off at it. F4 toggles it; a corner label says what the
## display reports. On by default where the display supports it (--sdr: off). Needs the Direct3D 12 renderer on
## Windows (Vulkan reports no HDR support there), the project's default there (project.godot,
## rendering_device/driver.windows). Whether the display offers it is asked again every POLL s, so it follows the
## window dragged to another monitor and Windows HDR turned on or off while the game runs.
##   HdrOutput.add(self)   # in a scene's _ready

const POLL := 0.5   ## s between asking the display whether it offers HDR

## Whether the window's display offers HDR output now (a test stands in a display of its own before adding it).
var display_offers := func() -> bool: return DisplayServer.window_is_hdr_output_supported(get_window().get_window_id())
var requested := false   ## HDR output asked for now: wanted and offered
var _label: Label
var _shown := 0.0
var _want := false      ## HDR wanted (F4, --sdr), whether or not the display offers it
var _offered := false   ## whether the display offered it when last asked
var _poll := POLL


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
	_want = on
	_offered = display_offers.call()
	requested = on and _offered
	_poll = POLL
	# (asking an SDR display, or the Vulkan renderer on Windows, only earns an engine warning: the window is asked
	# only where the display itself says yes, whatever a test's stand-in says)
	get_window().hdr_output_requested = requested and DisplayServer.window_is_hdr_output_supported(get_window().get_window_id())
	_shown = 4.0
	await get_tree().process_frame
	await get_tree().process_frame
	_report()


func _report() -> void:
	var id := get_window().get_window_id()
	var supported := DisplayServer.window_is_hdr_output_supported(id)
	var enabled := DisplayServer.window_is_hdr_output_enabled(id)
	var text := ""
	if not supported and OS.get_name() == "Windows" and RenderingServer.get_current_rendering_driver_name() != "d3d12":
		text = "HDR: needs Direct3D 12 (running %s)  F4" % RenderingServer.get_current_rendering_driver_name()
	elif not supported:
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
	# (dragged to another monitor, or Windows HDR switched: ask again)
	_poll -= dt
	if _poll <= 0.0:
		_poll = POLL
		if display_offers.call() != _offered:
			set_hdr(_want)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F4:
		set_hdr(not _want)
