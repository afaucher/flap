extends TestCase
## Diagnostic: the cost of ArenaLayout.first_touch (a bird's brace look-ahead) and its parts in the pine wood, at
## random points and headings 2-12 m up, 0.16 s of flight at 9 m/s. Headless.


func setup() -> void:
	var layout := Pinewood.generate(7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := 4000
	var tests := []
	for i in n:
		var r := layout.reach(Vector2.ZERO) * 0.7 * sqrt(rng.randf())
		var a := rng.randf() * TAU
		var h := rng.randf() * TAU
		var p := Vector3(cos(a) * r, rng.randf_range(2.0, 12.0), sin(a) * r)
		var v := Vector3(cos(h), 0.0, sin(h)) * 9.0
		var pts := PackedVector3Array()
		for k in 5:
			pts.append(p + v * (0.16 * k / 4.0))
		tests.append(pts)
	var t0 := Time.get_ticks_usec()
	var hits := 0
	for pts in tests:
		if not layout.first_touch(pts, 0.1).is_empty():
			hits += 1
	var us := float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	var near := 0
	for pts: PackedVector3Array in tests:
		near += layout.trees_near_segment(pts[0], pts[4], 0.5).size()
	var us_near := float(Time.get_ticks_usec() - t0) / n
	print("first_touch %.1f us a call (%d of %d touch); trees_near_segment alone %.1f us, %.1f trees" % [us, hits, n, us_near, float(near) / n])
	finish()
