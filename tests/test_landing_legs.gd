extends TestCase
## The legs through a landing, every species, every lab approach (measured on the drawn joints):
## - while the leg is tucked the ankle stays on the belly side of the leg (below the knee-foot line, in the body's
##   frame): once, with the body pitched up for the flare, the tucked leg flipped up into the owl's body and out of
##   its back;
## - touchdown doesn't snap: the ankle and the body's place (the rig's stance offset) move no more in the perching
##   tick than in the ticks before it -- the body once jumped to its stance and the feet snapped the last few
##   centimetres onto the grip.
## (Other leg jerks remain -- grips near the knee, fast fly-bys: tests/probe_pose_jerks.gd finds them.)


func _init() -> void:
	timeout_sec = 200.0


func setup() -> void:
	var lab := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(lab)
	await frames(2)
	for p in BirdProfile.all():
		var L := p.body_length
		var worst_up := -INF
		for s in LabScenarios.LIST:
			if s.get("kind", "") != "land" or not s.get("bleed", true):
				continue
			var b := Bird.new()
			add_child(b)
			b.setup(p, lab, null)
			b.arena = arena
			LabScenarios.start(s, b, lab)
			var ankles: Array[Vector3] = []
			var places: Array[Vector3] = []
			var touch := -1
			for i in 400:
				await frames(1)
				var r := b.rig
				var lj: Array = r.leg_joints[1]
				var knee: Vector3 = lj[1]
				var ankle: Vector3 = lj[2]
				var foot: Vector3 = lj[3]
				ankles.append(ankle)
				places.append(r.position)
				if r.leg_reach[1] < 0.05 and b.state != Bird.State.PERCHED:
					var d := (foot - knee)
					var f := clampf((ankle - knee).dot(d) / maxf(d.length_squared(), 1e-8), 0.0, 1.0)
					worst_up = maxf(worst_up, ankle.y - (knee + d * f).y)
				if touch < 0 and b.state == Bird.State.PERCHED:
					touch = i
				if touch >= 0 and i > touch + 3:
					break
			if touch > 6:
				var before := 0.0
				var before_p := 0.0
				for k in range(touch - 5, touch):
					before = maxf(before, ankles[k].distance_to(ankles[k - 1]))
					before_p = maxf(before_p, places[k].distance_to(places[k - 1]))
				var at := ankles[touch].distance_to(ankles[touch - 1])
				var at_p := places[touch].distance_to(places[touch - 1])
				check(at <= before * 1.5 + L * 0.01, "%s %s: the feet don't snap at touchdown (ankle %.3f m that tick, %.3f before)" % [p.id, s.id, at, before])
				check(at_p <= before_p * 1.5 + L * 0.02, "%s %s: the body doesn't jump to its stance at touchdown (%.3f m that tick, %.3f before)" % [p.id, s.id, at_p, before_p])
			b.queue_free()
			await frames(1)
		check(worst_up < 0.0, "%s landing: tucked, the ankle stays on the belly side of the leg (%.3f m)" % [p.id, worst_up])
	finish()
