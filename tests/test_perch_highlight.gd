extends TestCase
## The highlighted landing candidate (Bird.candidate) is the perch the bird's flight path will meet, not the one its
## nose points at. Each case flies a twin bird first, on its own, to find where the path really goes (the flight model
## flown, not a copy of the prediction), puts a branch across that path and a decoy branch nearer the bird where the
## path does not go, and then flies the bird itself past them:
##   gliding at best glide, neutral stick: the path, not the nose (which rides alpha above it), picks;
##   slow, neutral stick: the path sinks under the line the bird is moving along now, and the perch it sinks onto,
##     not the one on that line, is picked;
##   banked left and banked right: the perch round the turn, not the one straight ahead.
## Through each approach the candidate stays the path's perch, and the decoy is really out of the feet's reach of the
## path (above it, or off to the side).
## And a perch in the feet's reach right now is caught at once, where they reach it, though the path passes it closer
## further on.
## Off the path's way (left and right): a perch 55 deg off it (the next tree over) is never the candidate, one 15 deg off
## is; of a perch ahead and one beside the path that the path passes a little nearer, the one ahead; and the landing
## assist's held perch (Bird.candidate_lock) is kept 30 deg off, past the cone, over a perch dead ahead -- and let go
## of, that one is.

const DT := 1.0 / 60.0
var _id := 0


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var p := BirdProfile.crow()
	var start := Vector3(0.0, 30.0, 0.0)
	var glide := Vector3(0.0, -sin(p.glide_angle), -cos(p.glide_angle))
	# 1. Gliding at best glide, neutral stick: the decoy on the nose line, nearer.
	await _case("nose", p, start, glide, p.v_best, Vector2.ZERO, "nose")
	# 2. Slow, neutral stick: the decoy straight along its present motion.
	await _case("sink", p, start, Vector3.FORWARD, p.v_stall * 1.15, Vector2.ZERO, "line")
	# 3. Banked: the decoy straight ahead; the path curves away to the side the stick holds.
	await _case("bank right", p, start, glide, p.v_best, Vector2(0.8, 0.0), "line")
	await _case("bank left", p, start, glide, p.v_best, Vector2(-0.8, 0.0), "line")
	# 4. A branch in the feet's reach right now, which the path meets (closer) only further along: caught here, at once.
	await _in_reach_now(p, start)
	for side in [-1.0, 1.0]:
		await _off_way(p, start, glide, side)
	await _ahead_beats_beside(p, start, glide)
	await _held(p, start, glide)
	finish()


## A lone perch `deg` off the path's way, `dist` m out at the path's height (the bird glides on, neutral stick): is it
## ever the candidate (over the first 20 ticks)?
func _lone_pick(p: BirdProfile, start: Vector3, glide: Vector3, deg: float, dist: float) -> bool:
	var layout := ArenaLayout.new()
	var b := _bird(p, layout, Vector2.ZERO)
	b.fly_from(start, glide, p.v_best)
	var path := b.predicted_path()
	var way := (_along(path, dist) - start).normalized()
	var to := way.rotated(Vector3.UP, deg_to_rad(deg)) * dist
	var pr := _branch(layout, start + to - Vector3.UP * Perch.seat_at(Vector3.ZERO, p).y, Vector3.UP.cross(to).normalized())
	var picked := false
	for i in 20:
		await frames(1)
		picked = picked or b.candidate == pr
	b.queue_free()
	await frames(1)
	return picked


func _off_way(p: BirdProfile, start: Vector3, glide: Vector3, side: float) -> void:
	var what := "left" if side > 0.0 else "right"
	check(not await _lone_pick(p, start, glide, 55.0 * side, 6.0), "the next tree over, 55 deg to the %s: never the candidate" % what)
	check(await _lone_pick(p, start, glide, 15.0 * side, 6.0), "a perch 15 deg to the %s: the candidate" % what)


## A perch ahead the path passes 2.5 m over, one beside the path 2 m off it (nearer the path, 14 deg off its way):
## the one ahead is picked.
func _ahead_beats_beside(p: BirdProfile, start: Vector3, glide: Vector3) -> void:
	var layout := ArenaLayout.new()
	var b := _bird(p, layout, Vector2.ZERO)
	b.fly_from(start, glide, p.v_best)
	var path := b.predicted_path()
	var at := _along(path, 7.0)
	var way := (at - start).normalized()
	var across := Vector3.UP.cross(way).normalized()
	var seat_h := Perch.seat_at(Vector3.ZERO, p).y
	var ahead := _branch(layout, at - Vector3.UP * (seat_h + 2.5), across)
	var beside := _branch(layout, at + across * 2.0 - Vector3.UP * seat_h, way)
	await frames(1)
	check(b.candidate == ahead, "a perch ahead the path passes 2.5 m over beats one 2 m beside it, 14 deg off its way (%s)" % ("beside" if b.candidate == beside else "none"))
	b.queue_free()
	await frames(1)


## The landing assist's held perch 30 deg off the path's way (outside CONE_DEG, inside LOCK_CONE_DEG), a perch dead
## ahead: held, it's the candidate; let go, the one ahead is.
func _held(p: BirdProfile, start: Vector3, glide: Vector3) -> void:
	var layout := ArenaLayout.new()
	var b := _bird(p, layout, Vector2.ZERO)
	b.fly_from(start, glide, p.v_best)
	var path := b.predicted_path()
	var seat_h := Perch.seat_at(Vector3.ZERO, p).y
	var at := _along(path, 6.0)
	var way := (at - start).normalized()
	var ahead := _branch(layout, at - Vector3.UP * seat_h, Vector3.UP.cross(way).normalized())
	var to := way.rotated(Vector3.UP, deg_to_rad(30.0)) * 6.0
	var held := _branch(layout, start + to - Vector3.UP * seat_h, Vector3.UP.cross(to).normalized())
	b.candidate_lock = held
	await frames(1)
	check(b.candidate == held, "the assist's held perch, 30 deg off, stays the candidate over one dead ahead")
	b.candidate_lock = null
	await frames(1)
	check(b.candidate == ahead, "let go, the one ahead is")
	b.queue_free()
	await frames(1)


## A branch from just ahead and below (in reach now) down to the slow bird's sinking path 6 m on: the path passes
## closest at the far end, out of reach; holding catch, the bird catches it at once, where the feet reach it now.
func _in_reach_now(p: BirdProfile, start: Vector3) -> void:
	var speed := p.grab_speed_max * 0.8
	var twin := _bird(p, ArenaLayout.new(), Vector2.ZERO)
	twin.fly_from(start, Vector3.FORWARD, speed)
	var path := PackedVector3Array([start])
	for i in 90:
		await frames(1)
		path.append(twin.global_position)
	twin.queue_free()
	var layout := ArenaLayout.new()
	var near_end := start + Vector3.FORWARD * 1.2 + Vector3.DOWN * 0.5
	var far_end := _along(path, 6.0) - Vector3.UP * Perch.seat_at(Vector3.ZERO, p).y
	var br := Perch.branch(0, near_end, far_end, Vector3.RIGHT, -1, 0.04)
	layout._add_perch(br)
	var v0 := Vector3.FORWARD * speed
	check(Perch.in_reach(p, start, v0, near_end), "in reach now: the branch's near end")
	var closest := br.closest_grip(path[0])
	var best_d := INF
	for q in path:
		if br.distance_to(q) < best_d:
			best_d = br.distance_to(q)
			closest = br.closest_grip(q)
	check(not Perch.in_reach(p, start, v0, closest), "the path passes closest further on, out of reach from here (%.1f m ahead)" % (closest - start).dot(Vector3.FORWARD))
	var c := _bird(p, layout, Vector2.ZERO)
	(c.controller as ScriptedInput).catch_hold = true
	c.fly_from(start, Vector3.FORWARD, speed)
	var caught := -1
	for i in 10:
		await frames(1)
		if c.state != Bird.State.FLYING:
			caught = i
			break
	check(caught >= 0 and caught <= 1 and c.perch == br, "in reach now: caught at once (tick %d)" % caught)
	check(c.perch_grip.distance_to(near_end) < 1.0, "where the feet reach it now, not further on (%.2f m from the near end)" % c.perch_grip.distance_to(near_end))
	c.queue_free()
	await frames(1)


## Fly the case: `decoy` "nose" (on the nose's line) or "line" (on the straight line of the present motion).
func _case(label: String, p: BirdProfile, start: Vector3, dir: Vector3, speed: float, stick: Vector2, decoy_on: String) -> void:
	# Where the path really goes: a twin flown in empty air with the same stick.
	var empty := ArenaLayout.new()
	var twin := _bird(p, empty, stick)
	twin.fly_from(start, dir, speed)
	var nose := -twin.global_basis.z
	var path := PackedVector3Array([start])
	for i in 90:
		await frames(1)
		path.append(twin.global_position)
	twin.queue_free()
	var seat_h := Perch.seat_at(Vector3.ZERO, p).y
	# The path's perch: 8 m along it, a branch across it with the seat on the path.
	var at := _along(path, 8.0)
	var fwd := (_along(path, 8.1) - at).normalized()
	var across := Vector3.UP.cross(fwd).normalized()
	var grip := at - Vector3.UP * seat_h
	# The decoy: 6 m out (nearer), on the nose's line or the straight line of the present motion.
	var line := nose if decoy_on == "nose" else dir.normalized()
	var dgrip := start + line * 6.0 - Vector3.UP * seat_h
	var layout := ArenaLayout.new()
	var target := _branch(layout, grip, across)
	var decoy := _branch(layout, dgrip, Vector3.UP.cross(line).normalized())
	check(decoy.distance_to(start) < target.distance_to(start), "%s: the decoy is the nearer perch" % label)
	# The decoy really is off the path: no point of the path has it in the feet's reach.
	var reachable := false
	for i in path.size() - 1:
		var v := (path[i + 1] - path[i]) / DT
		if Perch.in_reach(p, path[i], v, decoy.closest_grip(path[i])):
			reachable = true
	check(not reachable, "%s: the path never has the decoy in reach" % label)
	# The bird itself, past them: the candidate is the path's perch all the way in.
	var b := _bird(p, layout, stick)
	b.fly_from(start, dir, speed)
	var ticks := 0
	var right := 0
	var wrong := ""
	for i in 90:
		await frames(1)
		if target.distance_to(b.global_position) < p.grab_radius * 0.5 or (target.position - b.global_position).dot(b.model.flight_dir()) < 0.0:
			break   # (there, or past it)
		if target.distance_to(b.global_position) > Bird.APPROACH_RADIUS - 0.5:
			continue   # (not yet near enough to be a candidate)
		ticks += 1
		if b.candidate == target:
			right += 1
		elif wrong == "":
			wrong = ("decoy" if b.candidate == decoy else "none") + " at tick %d, %.2f m from the target, status %d" % [ticks, target.distance_to(b.global_position), b.candidate_status]
	check(ticks > 20, "%s: a real approach (%d ticks)" % [label, ticks])
	check(right == ticks, "%s: the path's perch is the candidate all the way in (%d of %d ticks; else %s)" % [label, right, ticks, wrong])
	b.queue_free()
	await frames(1)


## The point `s` metres along the polyline.
func _along(path: PackedVector3Array, s: float) -> Vector3:
	var left := s
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if seg >= left:
			return path[i].lerp(path[i + 1], left / maxf(seg, 1e-6))
		left -= seg
	return path[path.size() - 1]


func _branch(layout: ArenaLayout, mid: Vector3, axis: Vector3) -> Perch:
	var half := Vector3(axis.x, 0.0, axis.z).normalized() * 0.5
	var pr := Perch.branch(_id, mid - half, mid + half, Vector3.FORWARD, -1, 0.04)
	pr.id = layout.perches.size()
	_id += 1
	layout._add_perch(pr)
	return pr


func _bird(p: BirdProfile, layout: ArenaLayout, stick: Vector2) -> Bird:
	var ctl := ScriptedInput.new()
	ctl.stick = stick
	var b := Bird.new()
	add_child(b)
	b.setup(p, layout, ctl)
	b.perch_assist = 0.0
	b.rig.visible = false
	return b
