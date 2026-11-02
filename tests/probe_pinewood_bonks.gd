extends TestCase
## Diagnostic: the AI flock in the pine wood -- what each bump hits (trunk, crown limb, dead stub, oak limb,
## sapling twig, outpost) and at what height.

const SIM_SECONDS := 90.0


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var layout := Pinewood.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var birds: Array[Bird] = []
	for i in BirdProfile.IDS.size():
		var pilot := AIPilot.new(layout, 1000 + i)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BirdProfile.IDS[i]), layout, pilot)
		b.arena = arena
		b.rig.visible = false
		b.perch_at(layout.perches[(i * 53 + 5) % layout.perches.size()])
		birds.append(b)
	var last := {}
	var kinds := {}
	for f in int(SIM_SECONDS * 60.0):
		await get_tree().physics_frame
		for b in birds:
			if b.bonks != int(last.get(b, 0)):
				last[b] = b.bonks
				var k := _what(layout, b.global_position)
				kinds[k] = int(kinds.get(k, 0)) + 1
				print("BONK %s at %.1f m: %s" % [b.profile.id, b.global_position.y, k])
	print("BONKS ", kinds)
	finish()


func _what(a: ArenaLayout, p: Vector3) -> String:
	var best := INF
	var what := "nothing near"
	for t in a.trees_near_segment(p, p, 3.0):
		var axis := Geometry3D.get_closest_point_to_segment(p, Vector3(t.base.x, 0.0, t.base.y), t.top())
		var d: float = p.distance_to(axis) - t.radius
		if d < best:
			best = d
			what = ["trunk", "pine trunk", "oak trunk", "sapling trunk"][t.kind]
		for br in t.branches:
			var q := Geometry3D.get_closest_point_to_segment(p, br.root, br.tip)
			var db: float = p.distance_to(q) - br.radius
			if db < best:
				best = db
				what = "dead stub" if br.dead else ("oak limb" if t.kind == ArenaLayout.Kind.BROADLEAF else ("sapling twig" if t.kind == ArenaLayout.Kind.SAPLING else "crown limb"))
	for o in a.outposts:
		for seg in a.deck_lines(o):
			var q := Geometry3D.get_closest_point_to_segment(p, seg[0], seg[1])
			var dd := p.distance_to(q) - float(seg[2])
			if dd < best:
				best = dd
				what = "outpost"
	if p.y < 0.5:
		what = "ground (or %s)" % what
	return what
