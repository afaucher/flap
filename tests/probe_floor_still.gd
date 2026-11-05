extends TestCase
## The pine wood's floor alone (the ground only: no trees, grass or anything that moves), still, from fixed views, in
## ForestLight: two runs of the same floor give the same pixels, so a change meant to leave the floor's look alone
## (forest_floor.gdshader, ArenaBuilder's floor meshes) can be checked to the pixel. Windowed:
##   .\probe.ps1 probe_floor_still --out <prefix>
## then compare the PNGs of a run before the change with one after.

const VIEWS := [   ## [name, camera position, looking at]
	["close", Vector3(3.0, 1.6, -4.0), Vector3(6.0, 0.0, -1.0)],       # (the litter, moss and dirt close up)
	["mid", Vector3(-20.0, 9.0, 25.0), Vector3(5.0, 0.0, 40.0)],
	["wide", Vector3(0.0, 35.0, 0.0), Vector3(90.0, 0.0, 30.0)],        # (out to the edge: the heath, the ring)
	["edge", Vector3(80.0, 2.0, -10.0), Vector3(100.0, 0.0, -14.0)],   # (low over where the wood's floor meets the heath)
	["corner", Vector3(110.0, 6.0, 110.0), Vector3(85.0, 0.0, 85.0)],  # (the fine mesh's corner over the ring)
]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var out := Boot.arg_value(OS.get_cmdline_user_args(), "--out")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var layout := Pinewood.generate(7)
	var b := ArenaBuilder.new()
	vp.add_child(b)
	b.build(layout)
	for c in b.get_children():
		if c is Node3D and c.name != "Ground":
			(c as Node3D).visible = false
	ForestLight.setup(vp)
	var cam := Camera3D.new()
	cam.fov = 60.0
	vp.add_child(cam)
	cam.current = true
	for v in VIEWS:
		cam.position = v[1]
		cam.look_at(v[2])
		await frames(20)
		await RenderingServer.frame_post_draw
		if out != "":
			vp.get_texture().get_image().save_png("%s_%s.png" % [out, v[0]])
		print("view: ", v[0])
	finish()
