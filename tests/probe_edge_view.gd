extends TestCase
## The arena's edge as it is today, from inside the pine wood looking out across the boundary: reference shots for
## designing what lies beyond it (a cliff, a river and a rival wood, a balloon line, heath). A falcon with its rider
## and tack in the chase camera's place in most of them. Windowed:
##   Godot --path . -- --run-test probe_edge_view --out-dir <dir> [--seed 7] [--heading away | side | into | heath | cliff | fence | extents | top | top_aligned] [--look <name>] [--no-fog] [--tag <suffix>]
## Views: chase_canopy (at crown height, the edge 40 m ahead), chase_above (over the canopy), low_trunks (among the
## trunks at 6 m), overview (60 m up from the far side, the whole wood to its far edge).


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := Boot.arg_value(args, "--out-dir")
	var seed_arg := Boot.arg_value(args, "--seed")
	var heading := Boot.arg_value(args, "--heading")
	get_window().size = Vector2i(1376, 768)   # (the main window, as the game draws it: a SubViewport loses the sky)
	var root := Node3D.new()
	add_child(root)
	var layout := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	ForestLight.setup(root)
	if args.has("--no-fog"):   # (diagnostic: how much of what we see far off is the haze)
		for c in root.get_children():
			if c is WorldEnvironment:
				(c as WorldEnvironment).environment.volumetric_fog_enabled = false
				(c as WorldEnvironment).environment.fog_enabled = false
	var arena := ArenaBuilder.new()
	root.add_child(arena)
	var t0 := Time.get_ticks_msec()
	arena.build(layout)
	print("arena built in %d ms" % (Time.get_ticks_msec() - t0))
	var t1 := Time.get_ticks_msec()
	var again := EdgeBuilder.new()
	again.build(layout)
	again.free()
	print("(of which the edge, built again alone: %d ms)" % (Time.get_ticks_msec() - t1))
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 1500.0
	root.add_child(cam)
	cam.current = true
	# Which way we look out: with the sun behind us (away), across it (side), or into it (into).
	var to_sun := (Basis.from_euler(Vector3(deg_to_rad(-ForestLight.SUN_ELEVATION), deg_to_rad(ForestLight.SUN_AZIMUTH), 0.0)) * Vector3.BACK).normalized()
	var sun_h := Vector3(to_sun.x, 0.0, to_sun.z).normalized()
	var d := -sun_h
	if heading == "side":
		d = sun_h.rotated(Vector3.UP, PI * 0.5)
	elif heading == "into":
		d = sun_h
	elif heading == "heath":   # (well round from the escarpment, the sun to one side)
		d = (-sun_h).rotated(Vector3.UP, deg_to_rad(105.0))
	elif heading == "cliff":   # (straight at the escarpment's middle)
		d = Vector3(sin(float(layout.escarpment.at)), 0.0, cos(float(layout.escarpment.at)))
	var rig := BirdRig.new()
	root.add_child(rig)
	rig.build(BirdProfile.by_id("falcon"))
	RigPoses.apply(rig, "glide", 0.0)
	var tack := Tack.fit(rig)
	var edge := layout.boundary
	# [name, bird at (null: no bird), camera, looking at]
	var views := [
		["chase_canopy", d * (edge - 40.0) + Vector3.UP * 20.0],
		["chase_above", d * (edge - 45.0) + Vector3.UP * 34.0],
		["low_trunks", null, d * (edge - 30.0) + Vector3.UP * 6.0, d * (edge + 40.0) + Vector3.UP * 8.0],
		["overview", null, -d * 40.0 + Vector3.UP * 60.0, d * edge * 0.7],
	]
	if heading == "extents":   # (from the play area's far reaches at the ceiling: the far side, and either flank)
		var at := float(layout.escarpment.at)
		var mid := Vector3(sin(at), 0.0, cos(at))
		var side := Vector3.UP.cross(mid).normalized()
		var hgt := layout.ceiling - 2.0
		views = [
			["extents_far", null, -mid * (edge - 2.0) + Vector3.UP * hgt, mid * layout.rock.foot + Vector3.UP * 25.0],
			["extents_left", null, side * (edge - 2.0) + Vector3.UP * hgt, mid * layout.rock.foot * 0.6 + side * 40.0 + Vector3.UP * 25.0],
			["extents_right", null, -side * (edge - 2.0) + Vector3.UP * hgt, mid * layout.rock.foot * 0.6 - side * 40.0 + Vector3.UP * 25.0],
			["extents_flank_out", null, side * (edge - 2.0) + Vector3.UP * hgt, side * 400.0 + mid * 150.0 + Vector3.UP * 30.0],
		]
	if heading == "top" or heading == "top_aligned":   # (the cliff's middle from straight above, orthographic, 120 m
		# across: beside tools/cliff_plan.py; top_aligned: turned so the cliff runs across and the plateau is at the top,
		# 3:1 and the wood hidden, as docs/images/edge/concept_cliff_plan.png is framed)
		var aligned := heading == "top_aligned"
		get_window().size = Vector2i(1536, 512) if aligned else Vector2i(1024, 1024)
		if aligned:
			for c in arena.get_children():
				if c != arena.edge and c.name != "Ground":
					c.visible = false
			for c in arena.edge.get_children():
				if c is VisualInstance3D and (String(c.name).begins_with("Edge_tufts") or String(c.name).begins_with("Edge_heather") or c == arena.edge.wires or String(c.name).begins_with("Edge_fence")):
					(c as VisualInstance3D).visible = false
		for c in root.get_children():
			if c is WorldEnvironment and (c as WorldEnvironment).camera_attributes is CameraAttributesPractical:
				((c as WorldEnvironment).camera_attributes as CameraAttributesPractical).dof_blur_far_enabled = false
		var mid := Vector3(sin(float(layout.escarpment.at)), 0.0, cos(float(layout.escarpment.at))) * layout.rock.foot
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 40.0 if aligned else 120.0
		cam.far = 600.0
		var outward := mid.normalized()
		var centre := mid + outward * (6.0 if aligned else 0.0)   # (aligned: the face a little above the middle, talus below)
		cam.look_at_from_position(centre + Vector3.UP * 300.0, centre, outward if aligned else Vector3.FORWARD)   # (-z up the image, +x right: as seen from above, as the plan)
		await frames(40)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if out_dir != "":
			var name := "edge_top_aligned.png" if aligned else "edge_top.png"
			img.save_png(out_dir.path_join(name))
			print("shot: ", out_dir.path_join(name))
		finish()
		return
	if heading == "ortho":   # (the cliff straight on, a long lens with no perspective, the wood and the heath's cover
		# hidden: to set beside docs/images/edge/concept_cliff_ortho.png and measure with tools/cliff_edges.py)
		await _ortho(layout, arena, cam, out_dir)
		finish()
		return
	if heading == "fence":   # (as the heath concept is framed: low, just inside the posts, looking along them, the
		# wood on the left and the heath on the right, the falcon flying ahead low over the fence line; on the far
		# side of the ring from the escarpment)
		var ca := float(layout.escarpment.at) + PI * 0.8
		d = Vector3(sin(ca), 0.0, cos(ca))
		var fwd := Vector3.UP.cross(d).normalized().rotated(Vector3.UP, deg_to_rad(-14.0))
		var cam_at := d * (edge - 1.8) + Vector3.UP * 3.8
		var at := cam_at + fwd * 6.0 + Vector3.UP * -0.9
		views = [["along_fence", null, cam_at, cam_at + fwd * 60.0 + Vector3.UP * -2.0, at, fwd]]
	for v in views:
		var bird_at = v[1]
		if bird_at != null:
			bird_at = _clear_line(layout, bird_at, d)
		rig.visible = bird_at != null or v.size() > 4
		if v.size() > 4:   # (a set view with the bird in it: [name, null, camera, looking at, bird at, its heading])
			rig.global_transform = Transform3D(Basis.looking_at(v[5], Vector3.UP), v[4])
			tack.update(0.0)
			cam.look_at_from_position(v[2], v[3], Vector3.UP)
		elif bird_at != null:
			rig.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), bird_at)
			tack.update(0.0)
			cam.look_at_from_position(bird_at - d * 2.2 + Vector3.UP * 0.65, bird_at + d * 30.0 + Vector3.UP * -1.5, Vector3.UP)
		else:
			cam.look_at_from_position(v[2], v[3], Vector3.UP)
		await frames(30)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if out_dir != "":
			var path := out_dir.path_join("edge_%s_%s%s.png" % [v[0], heading if heading != "" else "away", Boot.arg_value(args, "--tag")])
			img.save_png(path)
			print("shot: ", path)
	finish()


## The nearest spot to `at`, sideways, from which the chase camera sees 30 m ahead along `d` with no wood or leaves
## in the way (so the shot isn't a branch in the lens).
func _clear_line(layout: ArenaLayout, at: Vector3, d: Vector3) -> Vector3:
	var side := d.cross(Vector3.UP).normalized()
	for k in 40:
		var p := at + side * (float((k + 1) / 2) * 1.5 * (1.0 if k % 2 == 0 else -1.0))
		var cam := p - d * 2.2 + Vector3.UP * 0.65
		var ok := layout.segment_clear(cam, p + d * 30.0, 0.6)
		for i in 32:
			if ok and not Pinewood._leaf_free(layout, cam + d * float(i), 0.6):
				ok = false
		if ok:
			return p
	return at


## The escarpment's middle straight on in an orthographic camera, ORTHO_SIZE m high, with everything in front of it
## hidden (the wood, the heath's cover, the fence, the posts): edge_ortho.png.
const ORTHO_SIZE := 54.0
func _ortho(layout: ArenaLayout, arena: ArenaBuilder, cam: Camera3D, out_dir: String) -> void:
	get_window().size = Vector2i(1536, 512)
	for c in arena.get_children():
		if c != arena.edge and c.name != "Ground":
			c.visible = false
	for c in arena.edge.get_children():
		var keep := c == arena.edge.rock or c == arena.edge.wall or String(c.name).begins_with("Edge_blocks") or String(c.name).begins_with("Edge_scree") or String(c.name).begins_with("Edge_ledge") or c == arena.edge.hills
		if c is VisualInstance3D:
			(c as VisualInstance3D).visible = keep
	var d := Vector3(sin(float(layout.escarpment.at)), 0.0, cos(float(layout.escarpment.at)))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_SIZE
	cam.near = 1.0
	cam.far = 600.0
	for c in arena.get_parent().get_children():   # (no far blur: it's all far, and the point is the detail)
		if c is WorldEnvironment and (c as WorldEnvironment).camera_attributes is CameraAttributesPractical:
			((c as WorldEnvironment).camera_attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	cam.look_at_from_position(d * (layout.rock.foot - 120.0) + Vector3.UP * (ORTHO_SIZE * 0.5 - 4.0), d * layout.rock.foot + Vector3.UP * (ORTHO_SIZE * 0.5 - 4.0), Vector3.UP)
	await frames(40)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if out_dir != "":
		var path := out_dir.path_join("edge_ortho.png")
		img.save_png(path)
		print("shot: ", path)
