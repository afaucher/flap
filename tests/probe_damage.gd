extends TestCase
## Battle damage, measured: each species' wing area per flight feather (the share of its wing a primary,
## secondary, tertial carries), and in the range's demo (rockets, then seekers) the feathers each hit really takes
## and the hits a downing really needs.


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	for id in BirdProfile.IDS:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		var half := rig.profile.wing_area * 0.5
		var by := {}
		for f in rig.flight_feathers():
			if BirdRig.feather_side(f.key) == 1:
				var kind := floori((int(f.key) % 1000) / 100.0)
				if not by.has(kind):
					by[kind] = []
				by[kind].append(rig.feather_area(f.key) / half)
		var line := "%s:" % id
		for kind in by:
			var a: Array = by[kind]
			line += "  %s x%d %.1f..%.1f%%" % [["primary", "secondary", "tertial"][kind], a.size(), 100.0 * a.min(), 100.0 * a.max()]
		print(line)
		rig.queue_free()
	for seekers in [false, true]:
		var r: Node = load("res://scenes/combat_range.tscn").instantiate()
		add_child(r)
		await frames(2)
		r.demo = true
		r.evade = true
		r.start_seekers = seekers
		r.restart()
		var hits := 0
		var lost := 0
		var last_hits := 0
		var last_lost := 0
		var per_down := []
		var since := 0
		var dists := []
		r.world.burst.connect(func(at: Vector3, why: String):
			if why != "expired" and is_instance_valid(r.target):
				var d: float = (r.target as Bird).global_position.distance_to(at)
				if d <= CombatWorld.blast:
					dists.append(snappedf(d, 0.01)))
		for f in 60 * 80:
			await frames(1)
			var t: Bird = r.target
			var h: int = int(r.world.hits.get(t, 0))
			var n: int = t.lost_feathers.size()
			if h > last_hits and last_lost < Bird.DOWN_FEATHERS:   # (hits on a bird already down take nothing)
				hits += h - last_hits
				since += h - last_hits
				lost += maxi(n - last_lost, 0)
				if t.is_down():
					per_down.append(since)
					since = 0
			last_hits = h
			last_lost = n
		dists.sort()
		var ss := 0.0
		for d in dists:
			ss += clampf((1.0 - d / CombatWorld.blast - (1.0 - Projectile.fuse / CombatWorld.blast)) / (Projectile.fuse / CombatWorld.blast), 0.0, 1.0)
		print("burst distances (fuse %.1f, blast %.1f): %s; mean s %.2f" % [Projectile.fuse, CombatWorld.blast, str(dists), ss / maxf(dists.size(), 1)])
		print("%s: %d hits, %.2f feathers a hit (the 8th caps the last), downings after %s hits" % ["seekers" if seekers else "rockets", hits, float(lost) / maxf(hits, 1), str(per_down)])
		r.queue_free()
		await frames(2)
	finish()
