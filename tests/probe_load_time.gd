extends TestCase
## How long a pine wood takes to load: generating the layout, building it (by stage), and its first frames drawn.
##   Godot --path . -- --run-test probe_load_time   (windowed, for the first frames' shader compiles)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var t0 := Time.get_ticks_msec()
	var layout := Pinewood.generate(7)
	var t1 := Time.get_ticks_msec()
	print("generate: %d ms (%d trees, %d perches)" % [t1 - t0, layout.trees.size(), layout.perches.size()])
	var host := Node3D.new()
	add_child(host)
	ForestLight.setup(host)
	var b := ArenaBuilder.new()
	host.add_child(b)
	b.layout = layout
	var stages := {"ground": b._ground, "pinewood": b._pinewood}
	for k in stages:
		var s := Time.get_ticks_msec()
		(stages[k] as Callable).call()
		print("build %s: %d ms" % [k, Time.get_ticks_msec() - s])
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 20, 30)
	cam.current = true
	for f in 4:
		var s := Time.get_ticks_msec()
		await RenderingServer.frame_post_draw
		print("frame %d: %d ms" % [f, Time.get_ticks_msec() - s])
	print("total: %d ms" % (Time.get_ticks_msec() - t0))
	finish()
