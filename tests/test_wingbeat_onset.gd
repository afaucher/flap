extends TestCase
## Wingbeats start, stop and change without a jump, every species, in the bird lab's landings: where the bird
## starts flapping, stops, re-flaps, or the flare's braking beats take over at the catch, the drawn wing (its flap
## angle and hand lift, BirdRig.flap / hand_lift) moves no faster in a tick than the wingbeat itself moves it
## anywhere else in the run. (Once, starting a beat jumped the wing to wherever the beat's phase was: a crow's
## wings went from level to raised in one frame.)


func _init() -> void:
	timeout_sec = 150.0


func setup() -> void:
	var lab := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(lab)
	await frames(2)
	for p in BirdProfile.all():
		for sid in ["land_slow", "land_level"]:
			var b := Bird.new()
			add_child(b)
			b.setup(p, lab, null)
			b.arena = arena
			LabScenarios.start(LabScenarios.by_id(sid), b, lab)
			var wing: Array[Vector2] = []   # (flap, hand lift: both in radians)
			var src: Array[int] = []        # 0 none, 1 flapping, 2 the flare's beats
			var phase := PackedFloat32Array()
			for i in 400:
				await frames(1)
				var t := b.telemetry()
				wing.append(Vector2(b.rig.flap, deg_to_rad(b.rig.hand_lift)))
				src.append(2 if b.state == Bird.State.LANDING else (1 if bool(t.flapping) else 0))
				phase.append(float(t.flap_phase))
				if b.state == Bird.State.PERCHED:
					break
			var onset := [false]
			for i in range(1, wing.size()):
				onset.append(src[i] != src[i - 1] or (src[i] == 1 and phase[i] < phase[i - 1] - 0.2))
			var normal := 0.0
			var worst := 0.0
			var at := -1
			for i in range(1, wing.size()):
				var step := wing[i].distance_to(wing[i - 1])
				var near := false
				for j in range(maxi(0, i - 3), i + 1):
					near = near or onset[j]
				if near:
					if step > worst:
						worst = step
						at = i
				else:
					normal = maxf(normal, step)
			check(worst <= normal * 1.2 + 0.01, "%s %s: the wing changes beat without a jump (%.3f rad in a tick at %d, against %.3f in its beating)" % [p.id, sid, worst, at, normal])
			b.queue_free()
			await frames(1)
	finish()
