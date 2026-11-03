extends TestCase
## A bird drawn with its feathers placed and its neck, arm wings and trousers built on the GPU (BirdRig.gpu_feathers,
## gpu_body) looks as it does with the rig doing all of it (its trousers built at the pose, not skinned since a rebuild): every species rendered both ways, spread and folded, the head turned, from above and
## below, the pictures compared pixel by pixel.
## (The silhouette cards share the feather material: placed by the shader as feathers, they stood off the body.)
## A GPU test: runs windowed.

const SIZE := Vector2i(320, 240)


func _init() -> void:
	timeout_sec = 180.0


func setup() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	vp.add_child(sun)
	for p in BirdProfile.all():
		for fold in [0.0, 1.0]:
			for view in [Vector3(1.0, 0.9, -1.3), Vector3(-0.8, -0.9, 1.1)]:
				var shots: Array[Image] = []
				for gpu in [false, true]:
					BirdRig.gpu_feathers = gpu
					BirdRig.gpu_body = gpu
					var rig := BirdRig.new()
					rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # (posed by hand, as Bird's rig is: drawn as posed)
					vp.add_child(rig)
					rig.build(p)
					rig.set_clock(1.0)
					rig.fold = fold
					rig.tail_spread = 0.6
					rig.look_dir = Vector3(0.6, 0.2, -0.75).normalized()   # (the head turned: the neck twists)
					if not gpu and rig.legs != null:   # (the rig's trousers built at this very pose, not skinned since the last)
						rig.legs._tr = [{}, {}]
						rig.legs._loop_key = [PackedFloat32Array(), PackedFloat32Array()]
					rig.apply_pose()
					cam.position = view.normalized() * p.span * (1.3 if fold < 0.5 else 0.7)   # (folded: closer)
					cam.look_at(Vector3.ZERO)
					for k in 3:
						await RenderingServer.frame_post_draw
					shots.append(vp.get_texture().get_image())
					rig.queue_free()
					await get_tree().process_frame
				BirdRig.gpu_feathers = false
				BirdRig.gpu_body = false
				var a := shots[0]
				var b := shots[1]
				var differ := 0
				var drawn := 0
				var bg := a.get_pixel(0, 0)
				for y in SIZE.y:
					for x in SIZE.x:
						var ca := a.get_pixel(x, y)
						var cb := b.get_pixel(x, y)
						if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) > 8.0 / 255.0:
							differ += 1
						if not ca.is_equal_approx(bg):
							drawn += 1
				var tag := "%s fold %.0f view %s" % [p.id, fold, "above" if view.y > 0.0 else "below"]
				check(drawn > 2000, "%s: the bird is in the picture (%d px)" % [tag, drawn])
				if differ >= 40 and OS.has_environment("FLAP_SHOTS"):
					a.save_png(OS.get_environment("FLAP_SHOTS") + "/%s_%d_%s_cpu.png" % [p.id, int(fold), "above" if view.y > 0.0 else "below"])
					b.save_png(OS.get_environment("FLAP_SHOTS") + "/%s_%d_%s_gpu.png" % [p.id, int(fold), "above" if view.y > 0.0 else "below"])
				check(differ < 40, "%s: drawn the same with the feathers and the body's surfaces on the GPU (%d px differ)" % [tag, differ])
	finish()
