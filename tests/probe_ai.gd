extends TestCase
## Probe (not in -TestAll): trace AI birds' flights, one species after another (BIRDS), once a second.

const BIRDS := ["falcon"]
const SECONDS := 25


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	for bi in BIRDS.size():
		var pilot := AIPilot.new(layout, 1000 + bi)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BIRDS[bi]), layout, pilot)
		b.perch_at(layout.perches[(BirdProfile.IDS.find(BIRDS[bi]) * 53 + 5) % layout.perches.size()])
		print("=== ", BIRDS[bi], " ", b.profile.summary())
		b.bonked.connect(func(n: Vector3, s: float): print("   BONK n=%s into=%.1f at %s" % [n, s, b.global_position]))
		b.perched.connect(func(p: Perch): print("   PERCHED on %d" % p.id))
		var last_target := -2
		for f in 60 * SECONDS:
			await get_tree().physics_frame
			var tid := pilot.target.id if pilot.target else -1
			if tid != last_target:
				print("   target %d (%s) route %d pts %s" % [tid, pilot.target.position if pilot.target else "", pilot.route.size(), pilot.debug_reason])
				last_target = tid
			if f % 30 == 0:
				var t := b.telemetry()
				print("t=%d st=%d md=%d pos=(%.1f,%.1f,%.1f) v=%.1f path=%.0f bank=%.0f stick=(%.2f,%.2f) wp=%d/%d d=%.1f stam=%.2f burst=%.1f cand=%d" % [
					f / 60, b.state, pilot.mode, b.global_position.x, b.global_position.y, b.global_position.z, t.speed,
					rad_to_deg(t.path_angle), rad_to_deg(t.bank), t.stick.x, t.stick.y, pilot.wp, pilot.route.size(),
					b.global_position.distance_to(pilot.target.position) if pilot.target else -1.0, t.stamina, t.burst, t.candidate_status])
		b.queue_free()
		await frames(1)
	finish()
