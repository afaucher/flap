extends TestCase
## HDR display output reaches an HDR monitor: on Windows the game renders on Direct3D 12 (Godot 4.7's Vulkan reports
## no HDR there, and it was the default: HDR never came on outside .\hdr.ps1). HdrOutput follows the display: with a
## stand-in display that offers HDR, then doesn't, then does again (the window dragged between monitors, or Windows
## HDR switched), it asks for HDR only while it's offered, and F4 (set_hdr(false)) keeps it off. Where this machine
## has a screen with Windows HDR on, the real window too: HDR on there, off on a screen without it, back on when the
## window returns. A GPU test: runs windowed.


func _init() -> void:
	timeout_sec = 30.0


func setup() -> void:
	if OS.get_name() == "Windows":
		eq(RenderingServer.get_current_rendering_driver_name(), "d3d12", "the renderer on Windows (HDR output needs Direct3D 12)")
	await _stand_in()
	await _real_screens()
	finish()


## A display of our own, any machine.
func _stand_in() -> void:
	var offers := [false]
	var h := HdrOutput.new()
	h.display_offers = func() -> bool: return offers[0]
	add_child(h)
	await _settle()
	check(not h.requested, "stand-in: not asked for where the display doesn't offer it")
	offers[0] = true
	await _polled()
	check(h.requested, "stand-in: asked for once the display offers it (the window moved to an HDR screen)")
	offers[0] = false
	await _polled()
	check(not h.requested, "stand-in: dropped when the display stops offering it")
	offers[0] = true
	await _polled()
	check(h.requested, "stand-in: back on when it offers it again")
	h.set_hdr(false)   # (F4)
	await _settle()
	check(not h.requested, "stand-in: F4 turns it off")
	offers[0] = false
	await _polled()
	offers[0] = true
	await _polled()
	check(not h.requested, "stand-in: turned off, it stays off as the display changes")
	h.set_hdr(true)
	await _settle()
	check(h.requested, "stand-in: F4 again turns it on")
	h.queue_free()
	await _settle()


## This machine's own screens, where one offers HDR.
func _real_screens() -> void:
	var win := get_window()
	var id := win.get_window_id()
	var hdr_screens: Array[int] = []
	var sdr_screens: Array[int] = []
	for s in DisplayServer.get_screen_count():
		win.current_screen = s
		await _settle()
		(hdr_screens if DisplayServer.window_is_hdr_output_supported(id) else sdr_screens).append(s)
	print("screens with HDR: %s, without: %s" % [hdr_screens, sdr_screens])
	if hdr_screens.is_empty():
		print("(no screen offers HDR here: the real window wasn't checked)")
		return
	win.current_screen = hdr_screens[0]
	await _settle()
	var h := HdrOutput.add(self)
	await _settle()
	check(DisplayServer.window_is_hdr_output_enabled(id), "HDR on, on a screen that offers it")
	if not sdr_screens.is_empty():
		win.current_screen = sdr_screens[0]
		await _polled()
		check(not win.hdr_output_requested, "not asked for on a screen without HDR")
		win.current_screen = hdr_screens[0]
		await _polled()
		check(DisplayServer.window_is_hdr_output_enabled(id), "HDR back on when the window returns to the HDR screen")
	h.set_hdr(false)   # (F4)
	await _settle()
	check(not DisplayServer.window_is_hdr_output_enabled(id), "F4 turns it off")
	h.queue_free()


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame


## Long enough for HdrOutput to have asked the display again (POLL), and the window to follow.
func _polled() -> void:
	for i in int(HdrOutput.POLL * 60.0) + 12:
		await get_tree().process_frame
