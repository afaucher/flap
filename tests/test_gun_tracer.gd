extends TestCase
## The gun's tracers and muzzle flashes leave from its barrels as they're drawn: a crow on two gun pods, flying fast with
## the trigger held, each frame --
##  - every muzzle flash is drawn on a gun pod's mouth (as drawn this frame: Tack.muzzle_drawn), not left behind in the
##    air where it was fired (the bird flies 20 cm a frame on past it: the flash sat over its back, then its tail);
##  - no tracer's tail is drawn behind the mouth it left (it came out of the bird's back), and a bullet just fired has
##    its tail at the mouth (not cut short of it): from the barrel, on both pods.


class _Hold:
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		return CombatInput.new(false, true, false)


func _init() -> void:
	timeout_sec = 30.0


func setup() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var a := Bird.new()
	add_child(a)
	a.setup(BirdProfile.crow(), layout, null)
	a.fly_from(Vector3(0, 30, 0), Vector3(0, 0, -1), 13.0)
	var l := world.add_bird(a, null)
	var pods: Array[String] = ["gun", "gun"]
	var t := Tack.fit(a.rig, a, pods)
	l.set_tack(t)
	await frames(3)
	l.controller = _Hold.new()
	var flashes := 0
	var flash_off := 0.0
	var tails := 0
	var behind := 0.0
	var at_mouth := {}   # pod (0 / 1) -> young bullets whose tail is drawn at its mouth
	# (process_frame comes before the frame's _process calls: what's drawn is read a frame on, against the mouths read
	# at the same point the frame before -- the moment it was drawn for)
	await get_tree().process_frame
	var mouths := [t.muzzle_drawn("gun", 0), t.muzzle_drawn("gun", 1)]
	for f in 30:
		await get_tree().process_frame
		var drawn_at := mouths
		mouths = [t.muzzle_drawn("gun", 0), t.muzzle_drawn("gun", 1)]
		var m_now := drawn_at
		for p: Vector3 in world.fx.flashes_drawn:
			flashes += 1
			flash_off = maxf(flash_off, minf(p.distance_to(m_now[0]), p.distance_to(m_now[1])))
		for seg: Array in world.tracers_drawn:
			var tail: Vector3 = seg[0]
			var head: Vector3 = seg[1]
			var dir := (head - tail).normalized()
			var k := 0 if tail.distance_to(m_now[0]) < tail.distance_to(m_now[1]) else 1
			var m: Vector3 = m_now[k]
			if tail.distance_to(m) > 0.6:
				continue   # (an older bullet, well out)
			tails += 1
			behind = maxf(behind, -(tail - m).dot(dir))
			if tail.distance_to(m) < 0.015:
				at_mouth[k] = int(at_mouth.get(k, 0)) + 1
	l.controller = null
	check(flashes >= 5, "muzzle flashes drawn (%d)" % flashes)
	check(flash_off < 0.045, "every muzzle flash is on a gun's mouth as drawn (at most %.1f cm off it)" % (flash_off * 100.0))
	check(tails >= 5, "tracers drawn leaving the guns (%d)" % tails)
	check(behind < 0.015, "no tracer's tail is drawn behind its gun's mouth (at most %.1f cm behind)" % (behind * 100.0))
	check(at_mouth.has(0) and at_mouth.has(1), "a bullet just fired streaks from its gun's mouth, from each pod (%s)" % at_mouth)
	a.queue_free()
	world.queue_free()
	await frames(2)
	finish()
