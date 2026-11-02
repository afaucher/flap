extends TestCase
## The rig is posed once per rendered frame (Bird._process), for the simulated moment the frame draws the bird
## (Bird.drawn_lag), and the engine doesn't interpolate it again: the whole rig -- feathers, lofted surfaces, skinned
## legs -- moves every frame with the interpolated body. Physics ticks alone don't pose it (a frame catching up runs
## several ticks but draws once: posing on each multiplied the rig's cost by the catch-up ticks, so one slow frame made
## the next slower -- 20 birds: 290 ms frames, 8 ticks each), and the time it is posed for keeps up with the simulation.
## It is posed from the first frame a bird is drawn. The comparison mode (--rig-tick: posed on the frame's first tick) still poses once a frame. Either way the tack is
## posed with the rig it rides on, not later in the frame.


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
	b.fly_from(Vector3(0, 30, 0), Vector3.FORWARD, 12.0)
	# Posed from the first frame it's drawn, for the tick it was placed on (skipping it, the rig ran a tick behind its
	# state from then on -- a wingbeat out of step with the take-off it was posed for).
	var n_spawn := b.rig.poses
	b._process(0.0)
	check(b.rig.poses == n_spawn + 1, "posed on the first frame it's drawn (%d poses)" % (b.rig.poses - n_spawn))
	await frames(5)
	check(not b.rig.is_physics_interpolated(), "posed for the drawn moment, the rig isn't interpolated again by the engine")
	var n0 := b.rig.poses
	var posed0 := b._posed_t
	var sim0 := b._sim_t
	for k in 3:   # (three ticks inside one rendered frame, as a frame catching up runs them)
		b._physics_process(dt)
	check(b.rig.poses == n0, "ticks alone don't pose the rig (%d poses in 3 ticks)" % (b.rig.poses - n0))
	var n1 := b.rig.poses
	await frames(10)
	var posed := b.rig.poses - n1
	check(posed >= 9 and posed <= 11, "every frame poses it once (%d in 10 frames)" % posed)
	var gap := absf((b._posed_t - posed0) - (b._sim_t - sim0))
	check(gap <= dt * 1.01, "for the simulated time that passed (posed %.3f s of %.3f s)" % [b._posed_t - posed0, b._sim_t - sim0])
	check(b._sim_t - b._posed_t >= -1e-6 and b._sim_t - b._posed_t <= dt * 1.01, "at most a tick behind the simulation, never ahead (%.4f s)" % (b._sim_t - b._posed_t))
	_tack_rides(b)

	# --rig-tick: on the frame's first tick, once a frame however many ticks it runs.
	Bird.rig_in_process = false
	var c := Bird.new()
	add_child(c)
	c.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
	Bird.rig_in_process = true
	c.fly_from(Vector3(5, 30, 0), Vector3.FORWARD, 12.0)
	await frames(5)
	check(c.rig.is_physics_interpolated(), "--rig-tick: the rig interpolated tick to tick")
	var m0 := c.rig.poses
	for k in 3:
		c._physics_process(dt)
	check(c.rig.poses - m0 <= 1, "--rig-tick: three ticks in one frame pose the rig once (%d)" % (c.rig.poses - m0))
	var m1 := c.rig.poses
	await frames(10)
	check(c.rig.poses - m1 >= 9, "--rig-tick: and every frame poses it (%d in 10 frames)" % (c.rig.poses - m1))
	_tack_rides(c)
	finish()


## The tack is posed when the rig is: right after a pose, the saddle swells with the rig's fluff and breath as of that
## pose (posed later in the frame, the rider lagged the bird under them, or ran at another rate).
func _tack_rides(b: Bird) -> void:
	var tack := Tack.fit(b.rig, b)
	for k in 3:
		b.rig.animate(b.telemetry(), 0.11)
		var want := b.rig.fluff * (1.0 + 0.012 * b.rig.breath)
		check(absf(tack.saddle.scale.x - want) < 1e-5, "%s: the saddle posed with the rig (scale %.5f, the rig's %.5f)" % ["process" if not b.rig.is_physics_interpolated() else "tick", tack.saddle.scale.x, want])
	tack.queue_free()
