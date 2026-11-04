extends TestCase
## Close-ups of an outpost's timber (ArenaBuilder._outpost, the pine wood's materials) as a 3 x 2 sheet: the deck's
## outer edge (the planks' ends), the hangar's corner, the rail's end, the bearers and braces from below, the deck
## and hangar framed like docs/images/concepts/r4_aces_outpost.jpg, the roundel on the hangar's front. `--warm`: a low warm sun
## (the concept's light) in place of the game's. Windowed:
##   .\probe.ps1 probe_timber --out <png> [--warm]

const VIEWS := [   ## [label, camera, looking at] (outpost frame: the deck's middle at y 1, out +z, its side -x)
	["Deck edge: the plank ends", Vector3(0.35, 1.05, 1.15), Vector3(0.0, 0.96, 0.52)],
	["The hangar's corner: its slatted opening", Vector3(1.05, 1.55, 0.45), Vector3(0.55, 1.22, -0.22)],
	["The rail's end", Vector3(1.2, 1.12, 0.8), Vector3(0.8, 1.03, 0.5)],
	["Bearers and braces, from below", Vector3(0.55, 0.45, 1.0), Vector3(0.15, 0.9, 0.1)],
	["As the concept: over the deck to the hangar", Vector3(0.75, 2.05, 1.55), Vector3(-0.3, 1.05, -0.15)],
	["The roundel, on the hangar's front", Vector3(0.35, 1.38, 0.9), Vector3(0.53, 1.26, -0.03)],
]
const COLS := 3
const W := 800
const H := 500


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	Game.add_environment(vp)
	if args.has("--warm"):
		for c in vp.get_children():
			if c is DirectionalLight3D:
				c.rotation_degrees = Vector3(-28, 130, 0)
				c.light_color = Color(1.0, 0.82, 0.6)
				c.light_energy = 1.6
	var b := ArenaBuilder.new()
	b.layout = ArenaLayout.new()
	b.layout.style = "pinewood"
	b.layout.seed = 7
	vp.add_child(b)
	var o := ArenaLayout.OutpostData.new()
	o.centre = Vector3(0, 1, 0)
	o.out = Vector3.BACK
	b._outpost(o)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.01
	vp.add_child(cam)
	cam.current = true
	var sheet := Image.create(W * COLS, H * 2, false, Image.FORMAT_RGB8)
	for i in VIEWS.size():
		cam.position = VIEWS[i][1]
		cam.look_at(VIEWS[i][2])
		await frames(6)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i % COLS) * W, (i / COLS) * H))
		print("view: ", VIEWS[i][0])
	if out != "":
		sheet.save_png(out)
		print("sheet: ", out)
	finish()
