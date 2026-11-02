extends TestCase
## Diagnostic (run by name): a ground take-off's flight attitude, frame by frame (`-- --bird <id>`, default
## sparrow): the path direction, lift direction, speed, alpha and the body's turn a frame.


func setup() -> void:
	var id := Boot.arg_value(OS.get_cmdline_user_args(), "--bird")
	if id == "":
		id = "sparrow"
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var ctl := ScriptedInput.new()
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, ctl)
	b.arena = arena
	b.fly_from(Vector3(0, 0.3, 0), Vector3(1, -1, 0).normalized(), 1.0)
	for i in 30:
		await frames(1)
		if b.state == Bird.State.GROUNDED:
			break
	await frames(30)
	ctl.flap = true
	ctl.hold = true
	var last := b.global_basis.get_rotation_quaternion()
	for i in 60:
		await frames(1)
		var m := b.model
		var q := b.global_basis.get_rotation_quaternion()
		var r := b.rig
		var hd := (r.global_transform.basis * (r.head_basis * Vector3.FORWARD)).normalized()
		var nose := -r.global_transform.basis.z
		var tgt := (b.telemetry().look_target as Vector3) - b.global_position
		print("%2d %-8s dir %s v %.2f turn %.1f  nose %.0f  head %.0f  target %.0f  look_dir %s  blink %.2f" % [i, Bird.State.keys()[b.state], m.flight_dir().snapped(Vector3.ONE * 0.01), m.speed, rad_to_deg(last.angle_to(q)), rad_to_deg(asin(nose.y)), rad_to_deg(asin(hd.y)), rad_to_deg(asin(tgt.normalized().y)), r.look_dir.snapped(Vector3.ONE * 0.01), r.blink])
		last = q
	finish()
