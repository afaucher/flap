extends TestCase
## The pine wood's clearing thermal as a soaring bird sees it: from inside the column at 30 m, and from its edge.
##   .\probe.ps1 probe_thermal_view --out <prefix>


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var out := Boot.arg_value(OS.get_cmdline_user_args(), "--out")
	var vp := SubViewport.new()
	vp.size = Vector2i(1376, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var layout := Pinewood.generate(7)
	var b := ArenaBuilder.new()
	vp.add_child(b)
	b.build(layout)
	ForestLight.setup(vp)
	var fx := AirFx.new()
	vp.add_child(fx)
	fx.build(layout.air)
	var cam := Camera3D.new()
	cam.fov = 70.0
	vp.add_child(cam)
	cam.current = true
	var views := [["low", Vector3(4, 6, 3), Vector3(-8, 8, -9)], ["low, sun behind", Vector3(-4, 6, -4), Vector3(8, 6, 9)], ["inside", Vector3(6, 30, 4), Vector3(-4, 26, -12)], ["edge", Vector3(26, 24, 18), Vector3(0, 22, 0)], ["above", Vector3(10, 48, 10), Vector3(0, 25, 0)], ["from 70 m", Vector3(58, 22, 38), Vector3(0, 20, 0)]]
	for v in views:
		cam.position = v[1]
		cam.look_at(v[2])
		await frames(40)
		await RenderingServer.frame_post_draw
		if out != "":
			vp.get_texture().get_image().save_png("%s_%s.png" % [out, v[0]])
	finish()
