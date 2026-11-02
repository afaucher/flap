extends TestCase
## Diagnostic (run by name): hunts pose jerks -- a frame where part of the drawn bird moves far more than it does in
## the frames around it. Every species flies every bird-lab scenario (the perch take-off, the drop-off, the ground
## take-off, the landings) and sits a while after; each physics tick the probe reads drawn points in the bird's own
## world axes relative to the Bird's position (as a chase camera sees it: the flight through the world doesn't
## count, every turn of the drawn body does): the head, the beak tip, the neck's middle, the tail tip, both
## wingtips, both feet, two points on the drawn body's axes; and the Bird's own position in the world (a teleport). A tick is a jerk when a point's second difference |p(t+1) - 2 p(t) + p(t-1)| (its sudden change of
## velocity) is above JERK_MIN x L and SPIKE x its median over the ticks around it (steady wingbeats accelerate
## hard every tick, so they don't count; a one-tick snap does). Prints each jerk with the state the bird was in.
##   .\test_runner.ps1 -TestName probe_pose_jerks [-- --only <bird id>] [-- --scenario <id>]

const JERK_MIN := 0.03   ## share of L: smaller sudden changes aren't visible
const SPIKE := 6.0       ## how far out of line with the ticks around it
const WINDOW := 30       ## ticks either side for the local median
const POINTS := ["head", "beak", "neck", "tail", "wing L", "wing R", "foot L", "foot R", "body z", "body y", "position"]


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var only := Boot.arg_value(args, "--only")
	var only_s := Boot.arg_value(args, "--scenario")
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var total := 0
	for p in BirdProfile.all():
		if only != "" and p.id != only:
			continue
		for s in LabScenarios.LIST:
			if LabScenarios.is_pose(s) or (only_s != "" and s.id != only_s):
				continue
			var b := Bird.new()
			add_child(b)
			b.setup(p, layout, null)
			b.arena = arena
			LabScenarios.start(s, b, layout)
			var track: Array = []   # per tick: [points (Array[Vector3]), state name]
			var settled := -1
			for i in 900:
				await frames(1)
				track.append([_points(b), Bird.State.keys()[b.state]])
				if settled < 0 and b.state != Bird.State.FLYING and b.state != Bird.State.LANDING and i > 30:
					settled = i
				if settled >= 0 and i > settled + 120:
					break
				if s.kind != "land" and i > 360:
					break
			total += _report(p, s.id, track)
			b.queue_free()
			await frames(1)
	print("pose jerks found: %d" % total)
	finish()


## The tracked points this tick: world axes, relative to the Bird's position (m); the last, its position.
func _points(b: Bird) -> Array:
	var r := b.rig
	var o := b.global_position
	var g := r.global_transform
	var L := b.profile.body_length
	var head: Vector3 = r._head.global_position
	var out: Array = [
		head,
		head + g.basis * (r.head_basis * Vector3.FORWARD) * L * 0.12,
		g * (r.neck_joints[2] as Vector3) if r.neck_joints.size() > 2 else head,
		g * ((r.bone_ends.get("tail", [Vector3.ZERO, Vector3.ZERO]) as Array)[1] as Vector3),
		g * (r.wing_joints[0][3] as Vector3),
		g * (r.wing_joints[1][3] as Vector3),
		g * (r.leg_joints[0][3] as Vector3),
		g * (r.leg_joints[1][3] as Vector3),
		g * (Vector3.BACK * L),
		g * (Vector3.UP * L),
	]
	for k in out.size():
		out[k] = (out[k] as Vector3) - o
	out.append(o)
	return out


## Print the jerks in one run; returns how many.
func _report(p: BirdProfile, scenario: String, track: Array) -> int:
	var L := p.body_length
	var n := track.size()
	var found := 0
	for k in POINTS.size():
		var acc := PackedFloat32Array()
		acc.resize(n)
		for t in range(1, n - 1):
			var a: Vector3 = track[t - 1][0][k]
			var b: Vector3 = track[t][0][k]
			var c: Vector3 = track[t + 1][0][k]
			acc[t] = (c - 2.0 * b + a).length()
		var last_flag := -100
		for t in range(1, n - 1):
			if acc[t] < JERK_MIN * L:
				continue
			var around := PackedFloat32Array()
			for u in range(maxi(1, t - WINDOW), mini(n - 1, t + WINDOW + 1)):
				if absi(u - t) > 1:
					around.append(acc[u])
			around.sort()
			var med := around[around.size() / 2] if not around.is_empty() else 0.0
			if acc[t] < SPIKE * maxf(med, 0.002 * L):
				continue
			if t - last_flag <= 2:   # (one jerk shows on a few ticks)
				continue
			last_flag = t
			found += 1
			var from: String = track[t - 1][1]
			var to: String = track[t + 1][1]
			var state := from if from == to else "%s->%s" % [from, to]
			print("JERK %-8s %-11s t=%5.2fs  %-7s %.3f L (%.0fx the ticks around)  %s" % [p.id, scenario, t / 60.0, POINTS[k], acc[t] / L, acc[t] / maxf(med, 0.002 * L), state])
	return found
