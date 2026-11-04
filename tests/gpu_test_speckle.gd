extends TestCase
## No speckle of black dots on the outposts' wood: the menu's outpost (MenuBackdrop: the game's light, its soft
## shadows) close to a bird on the rail, the deck below it in and out of shadow -- few of the deck's pixels are much
## darker than the pixels round them. An over-steep relief (its slope taken from the screen's per-pixel derivatives)
## once tipped pixels edge-on, black, all along the boards and in the shadows' edges.
## A GPU test: runs windowed.

const SIZE := Vector2i(1280, 720)
const DECK := Rect2i(0, 560, 330, 160)   ## the deck in the frame (in and out of the hangar's shadow)


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var bd := MenuBackdrop.new()
	vp.add_child(bd)
	await frames(2)
	bd.cam.position = bd.rigs[2].global_position + Vector3(-0.35, 0.12, 0.55)
	bd.cam.look_at(bd.rigs[2].global_position + Vector3(0.1, -0.05, 0.0))
	await frames(30)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if OS.has_environment("TIMBER_SHOTS"):
		img.save_png(OS.get_environment("TIMBER_SHOTS").path_join("speckle.png"))
	var dark := 0
	var n := 0
	for y in range(DECK.position.y + 1, DECK.end.y - 1):
		for x in range(DECK.position.x + 1, DECK.end.x - 1):
			var c := img.get_pixel(x, y).get_luminance()
			var around := []   # (the 3 x 3 round it: its median)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					around.append(img.get_pixel(x + dx, y + dy).get_luminance())
			around.sort()
			if float(around[4]) - c > 0.1:
				dark += 1
			n += 1
	var share := 100.0 * dark / maxf(n, 1)
	print("deck speckle: %.2f%% of pixels much darker than their neighbours" % share)
	check(share < 0.4, "no speckle of black dots on the deck (%.2f%% of its pixels much darker than their neighbours)" % share)
	finish()
