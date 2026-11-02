extends TestCase
## A ground take-off, every species, frame by frame, as drawn:
## - the body swings into the climb (no snap): the drawn body turns at most BirdRig.ATT_RATE;
## - and once the flight steadies the drawn body is the Bird's own attitude again (it follows, it doesn't lag);
## - the head stays near the horizon and looks ahead, not at the sky up the steep climb or back past vertical;
## - the neck: the head's lag behind its jolted body short in the air, the neck bones inside the drawn neck;
## - the blink: the membrane is a film on the eye's own cap, so it never shows outside the eye.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	for p in BirdProfile.all():
		var ctl := ScriptedInput.new()
		var b := Bird.new()
		add_child(b)
		b.setup(p, layout, ctl)
		b.arena = arena
		b.fly_from(Vector3(0, 0.3, 0), Vector3(1, -1, 0).normalized(), 1.0)
		for i in 30:
			await frames(1)
			if b.state == Bird.State.GROUNDED:
				break
		await frames(60)
		var r := b.rig
		for e in r._membranes:
			check(e.mesh == (e.get_parent().get_child(0) as MeshInstance3D).mesh and e.material_override is ShaderMaterial, p.id + " the membrane is a film on the eye's own cap")
		ctl.flap = true
		ctl.hold = true
		var last := r.global_transform.basis.get_rotation_quaternion()
		var worst_turn := 0.0
		var worst_head := -INF
		var worst_back := INF   # (the head's level direction against the heading: 1 ahead .. -1 behind)
		var worst_lag := 0.0
		var worst_neck := 0.0
		var neck_r: float = r.body.ring_at(r.body.collar_z)[1]
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		for i in 90:
			await frames(1)
			var q := r.global_transform.basis.get_rotation_quaternion()
			worst_turn = maxf(worst_turn, rad_to_deg(last.angle_to(q)))
			last = q
			var hd := (r.global_transform.basis * (r.head_basis * Vector3.FORWARD)).normalized()
			worst_head = maxf(worst_head, rad_to_deg(asin(clampf(hd.y, -1.0, 1.0))))
			var hflat := Vector3(hd.x, 0.0, hd.z)
			if hflat.length() > 0.2:
				worst_back = minf(worst_back, hflat.normalized().dot(b.model.heading_dir()))
			if b.state == Bird.State.FLYING:
				worst_lag = maxf(worst_lag, r.head_offset.length())
			var cv := r._neck_curve()
			for k in [1, 2]:
				var far := INF
				for u in 21:
					far = minf(far, (r.neck_joints[k] as Vector3).distance_to(BirdRig._bezier(cv[0], cv[1], cv[2], cv[3], u / 20.0)))
				worst_neck = maxf(worst_neck, far)
		var step := BirdRig.ATT_RATE * maxf(dt, 1.0 / 60.0) * 2.5   # (a rig tick can carry two physics ticks)
		check(worst_turn < step, "%s take-off: the body swings, no snap (worst %.1f deg a frame)" % [p.id, worst_turn])
		check(worst_head < 50.0, "%s take-off: the head near the horizon (highest %.0f deg)" % [p.id, worst_head])
		check(worst_back > 0.0, "%s take-off: the head looks ahead, not back (worst %.2f)" % [p.id, worst_back])
		check(worst_lag <= p.body_length * 0.05 + 1e-4, "%s take-off: the head's lag short in the air (%.3f m)" % [p.id, worst_lag])
		check(worst_neck < neck_r * 0.75, "%s take-off: the neck bones inside the drawn neck (%.4f m off, neck %.4f)" % [p.id, worst_neck, neck_r])
		ctl.flap = false
		await frames(60)
		var off := rad_to_deg(r.global_transform.basis.get_rotation_quaternion().angle_to(b.global_basis.get_rotation_quaternion()))
		check(off < 1.0, "%s steady flight: drawn as the Bird's own attitude (%.2f deg off)" % [p.id, off])
		b.queue_free()
		await frames(1)
	finish()
