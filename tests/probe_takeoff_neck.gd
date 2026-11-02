extends TestCase
## Diagnostic (run by name): the head against the drawn body through a lab ground take-off (`-- --bird <id>`,
## default hawk; `-- --scenario takeoff` for the perch): per tick, the head's place in the body's frame (m, up and
## forward), its lag (head_offset), the bird's speed; and a count of the neck's flicks -- reversals of the head's
## up-down motion bigger than 1 % of L.


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var id := Boot.arg_value(args, "--bird")
	if id == "":
		id = "hawk"
	var sid := Boot.arg_value(args, "--scenario")
	if sid == "":
		sid = "ground"
	var lab := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(lab)
	await frames(2)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), lab, null)
	b.arena = arena
	LabScenarios.start(LabScenarios.by_id(sid), b, lab)
	var L := b.profile.body_length
	var ys := PackedFloat32Array()
	var left := -1
	for i in 240:
		await frames(1)
		var r := b.rig
		var hp := r.global_transform.affine_inverse() * r._head.global_position
		if left < 0 and b.state == Bird.State.FLYING and i > 20:
			left = i
		if left >= 0 and i - left < 60:
			ys.append(hp.y)
			print("%3d %-8s speed %5.2f  head up %.3f fwd %.3f  lag %.3f" % [i - left, Bird.State.keys()[b.state], b.model.velocity.length(), hp.y, -hp.z, r.head_offset.length()])
	var flicks := 0
	var dir := 0
	var turn_at := ys[0] if not ys.is_empty() else 0.0
	for k in range(1, ys.size()):
		var d := ys[k] - ys[k - 1]
		if absf(d) < 1e-5:
			continue
		var s := 1 if d > 0.0 else -1
		if dir != 0 and s != dir:
			if absf(ys[k - 1] - turn_at) > L * 0.01:
				flicks += 1
			turn_at = ys[k - 1]
		dir = s
	print("neck flicks in the first second: %d" % flicks)
	finish()
