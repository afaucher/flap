extends TestCase
## The menu's outpost (MenuBackdrop: the pine wood, its late-afternoon sun, birds on the rail) framed as
## docs/images/concepts/r4_aces_outpost.jpg is -- from above the deck's front corner, looking across it to the
## hangar and the trunk -- at the concept's size, to set side by side with it; or a close look at a part of it. Windowed:
##   Godot --path . -- --run-test probe_outpost_concept --out <png> [--view concept | under | roundel | opening | ladder] [--warm]

const VIEWS := {   ## [camera, looking at] from the deck's middle (world: out +z, the hangar's side -x)
	"concept": [Vector3(0.95, 1.05, 1.75), Vector3(-0.12, -0.05, -0.1)],
	"under": [Vector3(0.9, -0.55, 1.6), Vector3(-0.1, -0.2, 0.0)],
	"roundel": [Vector3(0.25, 0.42, 1.05), Vector3(0.53, 0.24, -0.05)],
	"opening": [Vector3(1.45, 0.4, 0.35), Vector3(0.74, 0.22, -0.22)],
	"ladder": [Vector3(-1.6, 0.1, 1.3), Vector3(-0.8, -0.35, 0.25)],
}


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var view := Boot.arg_value(args, "--view")
	if view == "":
		view = "concept"
	var vp := SubViewport.new()
	vp.size = Vector2i(1376, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var bd := MenuBackdrop.new()
	vp.add_child(bd)
	await frames(3)
	var o: ArenaLayout.OutpostData = null
	for c in bd.get_children():
		if c is ArenaBuilder:
			o = (c as ArenaBuilder).layout.outposts[0]
	var deck := o.centre
	if args.has("--warm"):   # (the concept's light: the sun low, golden and strong, over the camera's shoulder)
		bd.sun.global_basis = Basis.looking_at(Vector3(-0.75, -0.55, -0.45).normalized())
		bd.sun.light_color = Color(1.0, 0.8, 0.55)
		bd.sun.light_energy = 2.0
	bd.cam.fov = 50.0
	bd.cam.position = deck + VIEWS[view][0]
	bd.cam.look_at(deck + VIEWS[view][1])
	(bd.cam.attributes as CameraAttributesPractical).dof_blur_far_distance = 6.0
	await frames(20)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if out != "":
		img.save_png(out)
		print("shot: ", out)
	finish()
