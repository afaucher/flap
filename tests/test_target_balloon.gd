extends TestCase
## TargetBalloon, by what it draws and how it moves: a Caquot at the riders' scale (the drawn envelope's length and
## girth); whole, it rides high on its cable and stays there; bullets hole it (the shader gets each hole) and it
## sinks, sooner the more holes, going soft (the drawn tail droops, the nose cups in) until it lies on the ground;
## a burst sets it alight and it falls, burning, and lies there a wreck. A shot that misses it doesn't touch it.

const DT := 1.0 / 60.0


func setup() -> void:
	# The drawn envelope, whole.
	var b := _balloon(0)
	var env := _envelope(b)
	var lo := Vector3.ONE * 1e9
	var hi := -Vector3.ONE * 1e9
	for p in env:
		lo = lo.min(p)
		hi = hi.max(p)
	near(hi.z - lo.z, TargetBalloon.LENGTH, 0.03, "the drawn envelope is a Caquot's 28 m at 1:20.6 (%.2f m)" % (hi.z - lo.z))
	near((hi.x - lo.x) * 0.5, TargetBalloon.RADIUS, 0.01, "and its girth a Caquot's (%.3f m)" % ((hi.x - lo.x) * 0.5))
	# Whole, it rides high and stays there.
	_run(b, 20.0)
	var h := b.centre().y - b.global_position.y
	check(b.stage() == TargetBalloon.Stage.UP and h > b.cable * 0.85, "whole, it rides at the top of its cable (%.1f m of %.0f)" % [h, b.cable])
	# A shot past it misses; one through it holes it, in and out, and the shader has the holes.
	var c := b.centre()
	check(b.hit_point(c + Vector3(3, 2, 0), c + Vector3(-3, 2, 0)) == null, "a shot 2 m over it misses")
	var at = b.hit_point(c + Vector3(0, 0, 0) + b.body.global_basis.x * 3.0, c - b.body.global_basis.x * 3.0)
	check(at != null, "a shot through its flank hits")
	b.bullet_hit(at, -b.body.global_basis.x)
	b.step(DT)
	check(b.holes.size() == 2 and b.stage() == TargetBalloon.Stage.HOLED, "holed in and out (%d holes)" % b.holes.size())
	check(int(b._mat.get_shader_parameter("hole_n")) == 2, "and the envelope's drawn with both")
	b.queue_free()
	# Holed, it sinks: sooner with more holes, going soft as it does, and settles on the ground.
	var times := []
	for n in [4, 12]:
		var s := _balloon(n)
		var tail_0 := _tail_drop(s)
		var nose_0 := _nose(s)
		_shoot(s, n)
		var t := 0.0
		var lowest := 1e9
		var soft_tail := 0.0
		var soft_nose := 0.0
		var rising := false
		var down_at := -1.0
		while s.stage() != TargetBalloon.Stage.DOWN or s.landed < 0.0:
			var before := s.centre().y
			s.step(DT)
			t += DT
			if down_at < 0.0 and s.is_down():
				down_at = t
			if s.centre().y > before + 0.05:
				rising = true
			if s.stage() == TargetBalloon.Stage.SINKING and soft_tail == 0.0 and s.gas < 0.5:
				soft_tail = _tail_drop(s)
				soft_nose = _nose(s)
			if t > 120.0:
				break
		check(not rising, "%d holes: it never rises as it loses gas" % n)
		check(soft_tail > tail_0 + 0.1, "%d holes: soft, its tail droops (%.2f m below the nose, whole %.2f)" % [n, soft_tail, tail_0])
		check(soft_nose > nose_0 + 0.04, "%d holes: and its nose cups in (%.2f m back, whole %.2f)" % [n, soft_nose, nose_0])
		var on_ground := s.centre().y - s.global_position.y
		check(s.landed >= 0.0 and on_ground < 0.4, "%d holes: it comes down on the ground (%.2f m up, after %.0f s)" % [n, on_ground, t])
		check(s.is_down() and s.hit_point(s.centre() + Vector3(1, 0, 0), s.centre() - Vector3(1, 0, 0)) == null, "%d holes: down, it's out of the shooting" % n)
		times.append(down_at)
		s.queue_free()
	check(times[1] < times[0] * 0.5, "the more holes, the sooner it's brought down (%.1f s with 4, %.1f s with 12)" % [times[0], times[1]])
	# A burst sets it alight: it burns, falls burning, and lies a wreck on the ground.
	var f := _balloon(1)
	_run(f, 2.0)
	f.burst_near(f.centre() + f.body.global_basis.x * 0.8)
	f.step(DT)
	check(f.stage() == TargetBalloon.Stage.BURNING and f.fire() >= 0.0 and f.is_down(), "a burst beside it sets it alight (%s)" % TargetBalloon.Stage.keys()[f.stage()])
	f.bullet_hit(f.centre(), Vector3.FORWARD)
	check(f.holes.is_empty(), "alight, a bullet adds nothing")
	var fell := false
	var top := f.centre().y
	var t := 0.0
	while f.stage() != TargetBalloon.Stage.WRECK and t < 30.0:
		f.step(DT)
		t += DT
		fell = fell or f.stage() == TargetBalloon.Stage.FALLING
	check(fell, "it falls as it burns")
	var low := f.centre().y - f.global_position.y
	check(f.stage() == TargetBalloon.Stage.WRECK and low < 0.4 and t < 8.0, "and lies a wreck on the ground (%.2f m up, %.1f s after it caught, from %.1f m)" % [low, t, top - f.global_position.y])
	check(f.burnt() > 0.9, "burnt out (%.0f%%)" % (f.burnt() * 100.0))
	f.queue_free()
	finish()


func _balloon(sd: int) -> TargetBalloon:
	var b := TargetBalloon.new(sd)
	b.auto = false
	add_child(b)
	b.position = Vector3(sd * 10.0, 0.0, 0.0)
	b.step(DT)
	return b


func _run(b: TargetBalloon, secs: float) -> void:
	for i in int(secs / DT):
		b.step(DT)


## The drawn envelope's vertices (body space): the first (NU + 1) x (NA + 1) of its mesh.
func _envelope(b: TargetBalloon) -> PackedVector3Array:
	var all: PackedVector3Array = b._env.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return all.slice(0, (TargetBalloon.NU + 1) * (TargetBalloon.NA + 1))


## How far the drawn tail's tip sits below the nose's (body space).
func _tail_drop(b: TargetBalloon) -> float:
	var env := _envelope(b)
	return env[0].y - env[env.size() - 1].y


## How far back the drawn nose's tip is from where a taut one's is.
func _nose(b: TargetBalloon) -> float:
	return _envelope(b)[0].z + TargetBalloon.LENGTH * 0.5


## `n` bullets through its flank.
func _shoot(b: TargetBalloon, n: int) -> void:
	for i in n:
		var u := 0.2 + 0.5 * float(i) / maxf(1.0, n - 1.0)
		var p := b.body.global_transform * Vector3(TargetBalloon._r(u), 0.0, (u - 0.5) * TargetBalloon.LENGTH)
		b.bullet_hit(p, -b.body.global_basis.x)
