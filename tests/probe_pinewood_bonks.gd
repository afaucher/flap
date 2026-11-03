extends TestCase
## Diagnostic: the AI flock in the pine wood -- what each bump hits (trunk, crown limb, dead stub, oak limb,
## sapling twig, outpost), at what height, and what the pilot was doing (cruise or final, the target's own tree,
## avoiding, speed, bank). PROBE_ARENA=greybox7 / greybox3 flies a greybox seed instead, pinewood11 another pine
## wood seed; PROBE_TRACE=<species> prints its last moments before each bump, PROBE_WATCH=<species> its state each second.

const SIM_SECONDS := 90.0


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var which := OS.get_environment("PROBE_ARENA")
	var layout := ArenaLayout.generate(int(which.substr(7))) if which.begins_with("greybox") else Pinewood.generate(int(which.substr(8)) if which.length() > 8 else 7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var birds: Array[Bird] = []
	var pilots: Array[AIPilot] = []
	for i in BirdProfile.IDS.size():
		var pilot := AIPilot.new(layout, 1000 + i)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BirdProfile.IDS[i]), layout, pilot)
		b.arena = arena
		b.rig.visible = false
		b.perch_at(layout.perches[(i * 53 + 5) % layout.perches.size()])
		birds.append(b)
		pilots.append(pilot)
	Perf.on = true
	Perf._acc.clear()
	var last := {}
	var kinds := {}
	var prev := {}
	var prev_h := {}
	var hist := {}
	var turn := {}
	for f in int(SIM_SECONDS * 60.0):
		for i in birds.size():
			var b := birds[i]
			prev[b] = [b.model.speed, rad_to_deg(b.model.bank), pilots[i].avoiding, pilots[i].mode, pilots[i].wp, pilots[i].route.size()]
			var tg: Perch = pilots[i].target
			var extra := ""
			if tg != null:
				var tr = layout.trees[tg.tree_id]
				var axis := Vector2(tr.base.x, tr.base.y)
				extra = " d_perch %.2f d_trunk %.2f grip-trunk %.2f v %.1f cand %s state %d fwd.to_trunk %.2f" % [tg.distance_to(b.global_position), Vector2(b.global_position.x, b.global_position.z).distance_to(axis) - tr.radius,
					Vector2(tg.closest_grip(b.global_position).x, tg.closest_grip(b.global_position).z).distance_to(axis) - tr.radius, b.model.speed, str(b.candidate == tg), b.state,
					Vector2(b.model.flight_dir().x, b.model.flight_dir().z).normalized().dot((axis - Vector2(b.global_position.x, b.global_position.z)).normalized())]
			hist[b] = (hist.get(b, []) as Array).slice(-40) + ["  t-%s %s bank %.0f g %.0f y %.1f%s" % ["", pilots[i].debug_reason if pilots[i].avoiding >= 0.5 else "-", rad_to_deg(b.model.bank), rad_to_deg(b.model.path_angle), b.global_position.y, extra]]
		await get_tree().physics_frame
		if f % 60 == 0 and OS.get_environment("PROBE_WATCH") != "":
			for i in birds.size():
				var b := birds[i]
				var pl := pilots[i]
				if b.profile.id == OS.get_environment("PROBE_WATCH"):
					print("WATCH %3ds state %d mode %d y %.1f v %.1f tgt %s d %.1f wp %d/%d replans %d stam %.2f %s" % [f / 60, b.state, pl.mode, b.global_position.y, b.model.speed,
						str(pl.target.id) if pl.target != null else "-", pl.target.distance_to(b.global_position) if pl.target != null else -1.0, pl.wp, pl.route.size(), pl.replans, b.model.energy.stamina, pl.debug_reason if pl.avoiding > 0.0 else ""])
		for i in birds.size():
			var b := birds[i]
			var pl := pilots[i]
			# How the turn rate flown compares with g tan(bank) / v (what the avoidance predicts with).
			var hd := Vector2(b.model.flight_dir().x, b.model.flight_dir().z)
			if b.state == Bird.State.FLYING and prev_h.has(b) and absf(b.model.bank) > deg_to_rad(20.0) and b.model.speed > 3.0 and hd.length() > 0.5:
				var flown: float = -(prev_h[b] as Vector2).angle_to(hd) * 60.0
				var said := BirdProfile.G * tan(b.model.bank) / b.model.speed
				turn[b.profile.id] = (turn.get(b.profile.id, Vector2.ZERO) as Vector2) + Vector2(flown / said, 1.0)
			prev_h[b] = hd
			if b.bonks != int(last.get(b, 0)):
				last[b] = b.bonks
				var hit := _what(layout, b.global_position)
				var own: bool = pl.target != null and hit[1] == pl.target.tree_id
				var k: String = hit[0] + (" (target's tree)" if own else (" (tree it left)" if hit[1] == pl._last_tree else ""))
				kinds[k] = int(kinds.get(k, 0)) + 1
				var s: Array = prev[b]
				if OS.get_environment("PROBE_TRACE") == b.profile.id and pl.target != null:
					var tr = layout.trees[pl.target.tree_id]
					var o := Vector3(tr.base.x, 0.0, tr.base.y)
					print("  perch %d kind %d a %s b %s facing %s r %.2f; route %s; bird %s" % [pl.target.id, pl.target.kind, pl.target.a - o, pl.target.b - o, pl.target.facing, tr.radius, str(pl.route.map(func(q): return q - o)), b.global_position - o])
				if OS.get_environment("PROBE_TRACE") == b.profile.id:
					var h: Array = hist[b]
					for j in range(maxi(0, h.size() - 40), h.size(), 3):
						print(h[j])
				print("BONK %-7s at %4.1f m: %-26s %s wp %d/%d, d_perch %.1f, v %.1f, bank %.0f, avoiding %.2f" % [b.profile.id, b.global_position.y, k,
					["PERCHED", "CRUISE", "FINAL", "GROUNDED"][s[3]], s[4], s[5], pl.target.distance_to(b.global_position) if pl.target != null else -1.0, s[0], s[1], s[2]])
	var total := 0
	var bonks := 0
	for i in birds.size():
		total += pilots[i].perches_reached
		bonks += birds[i].bonks
		print("%s: %d perches, %d bonks" % [birds[i].profile.id, pilots[i].perches_reached, birds[i].bonks])
	print("FLOCK %d perches, %d bonks" % [total, bonks])
	for k in Perf._acc:
		print("PERF %s: %.0f us per tick (5 birds)" % [k, float(Perf._acc[k]) / (SIM_SECONDS * 60.0)])
	Perf.on = false
	print("BONKS ", kinds)
	for id in turn:
		print("TURN %s: flown / predicted %.2f" % [id, turn[id].x / turn[id].y])
	finish()


## [what, tree id] nearest to p.
func _what(a: ArenaLayout, p: Vector3) -> Array:
	var best := INF
	var what := "nothing near"
	var tid := -1
	for t in a.trees_near_segment(p, p, 3.0):
		var axis := Geometry3D.get_closest_point_to_segment(p, Vector3(t.base.x, 0.0, t.base.y), t.top())
		var d: float = p.distance_to(axis) - t.radius
		if d < best:
			best = d
			tid = t.id
			what = ["trunk", "pine trunk", "oak trunk", "sapling trunk"][t.kind]
		for br in t.branches:
			var q := Geometry3D.get_closest_point_to_segment(p, br.root, br.tip)
			var db: float = p.distance_to(q) - br.radius
			if db < best:
				best = db
				tid = t.id
				what = "dead stub" if br.dead else ("oak limb" if t.kind == ArenaLayout.Kind.BROADLEAF else ("sapling twig" if t.kind == ArenaLayout.Kind.SAPLING else ("branch" if t.kind == ArenaLayout.Kind.GENERIC else "crown limb")))
	for o in a.outposts:
		for seg in a.deck_lines(o):
			var q := Geometry3D.get_closest_point_to_segment(p, seg[0], seg[1])
			var dd := p.distance_to(q) - float(seg[2])
			if dd < best:
				best = dd
				tid = o.tree_id
				what = "outpost"
	if p.y < 0.5:
		what = "ground (or %s)" % what
	return [what, tid]
