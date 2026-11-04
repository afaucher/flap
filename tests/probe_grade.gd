extends TestCase
## The pine wood in ForestLight from three fixed views (toward the sun, across it, away from it), 1376 x 768 each,
## for grading against the concept art (docs/images/concepts/r4_aces_outpost.jpg). Windowed:
##   .\probe.ps1 probe_grade --out <prefix> [--look <name>] [--set '<json>']
## --set overrides properties after the look: {"env.tonemap_exposure": 1.3, "sun.light_energy": 3.5,
## "sky.turbidity": 12, "sun.rotation_degrees": [-18, 205, 0]} (colours as [r, g, b]).

const VIEWS := [   ## [name, yaw from the sun's way (deg), pitch (deg), height (m)]
	["away", 0.0, -12.0, 14.0],      # (the sun behind the camera: everything front-lit)
	["across", 90.0, -14.0, 14.0],
	["toward", 180.0, -10.0, 14.0],  # (into the sun: backlit, the haze and its shafts, as the concept art is)
]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var vp := SubViewport.new()
	vp.size = Vector2i(1376, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var layout := Pinewood.generate(7)
	var b := ArenaBuilder.new()
	vp.add_child(b)
	b.build(layout)
	var sun := ForestLight.setup(vp)
	var we: WorldEnvironment = null
	for c in vp.get_children():
		if c is WorldEnvironment:
			we = c
	var sets := Boot.arg_value(args, "--set")
	if sets != "":
		var d: Dictionary = JSON.parse_string(sets)
		for k in d:
			var obj: Object = {"env": we.environment, "sun": sun, "sky": we.environment.sky.sky_material, "cam": we.camera_attributes}[k.get_slice(".", 0)]
			var v = d[k]
			var cur = obj.get(k.get_slice(".", 1))
			if cur is Color:
				v = Color(v[0], v[1], v[2])
			elif cur is Vector3:
				v = Vector3(v[0], v[1], v[2])
			obj.set(k.get_slice(".", 1), v)
	var cam := Camera3D.new()
	cam.fov = 60.0
	vp.add_child(cam)
	cam.current = true
	var to_sun := -(Basis.from_euler(Vector3(0.0, deg_to_rad(sun.rotation_degrees.y), 0.0)) * Vector3.BACK)
	for v in VIEWS:
		var dir := to_sun.rotated(Vector3.UP, deg_to_rad(v[1]))
		cam.position = Vector3(0.0, v[3], 0.0) - dir * 6.0
		cam.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(v[2]))
		await frames(30)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if out != "":
			img.save_png("%s_%s.png" % [out, v[0]])
		print("view: ", v[0])
	finish()
