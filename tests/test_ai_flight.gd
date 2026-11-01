extends TestCase
## AI birds (every species) fly perch to perch with only the player's controls. A fleet benchmark for now:
## the flock as a whole chains many perches, most species do it repeatedly, trees are rarely touched, and
## nobody leaves the arena. (Known weak: the hawk and falcon in the low understory; see the design doc.)

const SIM_SECONDS := 90.0


func _init() -> void:
	timeout_sec = 200.0


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	# The planner alone: a route around a trunk, every leg clear.
	var planner := FlightPlanner.new(layout)
	var sp := layout.start_perch()
	var far: Perch = null
	for p in layout.perches:
		if p.position.distance_to(sp.position) > 50.0 and p.position.y < sp.position.y - 5.0:
			far = p
			break
	var route := planner.plan_to_perch(sp.position + sp.facing, far, BirdProfile.crow(), sp.tree_id)
	check(route.size() >= 2, "a route to a far perch (%d points)" % route.size())
	for i in range(1, route.size() - 1):
		check(layout.segment_clear(route[i - 1], route[i], planner.clearance * 0.99, sp.tree_id if i == 1 else -1), "route leg %d is clear" % i)

	var birds: Array[Bird] = []
	var pilots: Array[AIPilot] = []
	for i in BirdProfile.IDS.size():
		var pilot := AIPilot.new(layout, 1000 + i)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BirdProfile.IDS[i]), layout, pilot)
		b.perch_at(layout.perches[(i * 53 + 5) % layout.perches.size()])
		birds.append(b)
		pilots.append(pilot)
	var max_r := 0.0
	for f in int(SIM_SECONDS * 60.0):
		await get_tree().physics_frame
		for b in birds:
			max_r = maxf(max_r, Vector2(b.global_position.x, b.global_position.z).length())
	var total := 0
	var total_bonks := 0
	var repeat_species := 0
	for i in birds.size():
		var b := birds[i]
		var pl := pilots[i]
		print("%s: %d perches, %d bonks, %d replans, state %d, stamina %.2f" % [b.profile.id, pl.perches_reached, b.bonks, pl.replans, b.state, b.model.energy.stamina])
		total += pl.perches_reached
		total_bonks += b.bonks
		if pl.perches_reached >= 2:
			repeat_species += 1
	print("flock: %d perches, %d bonks in %.0f s" % [total, total_bonks, SIM_SECONDS])
	check(total >= 12, "the flock chains perches (%d)" % total)
	check(repeat_species >= 3, "most species perch repeatedly (%d of 5)" % repeat_species)
	check(total_bonks <= total + 5, "trees are rarely touched (%d bonks for %d perches)" % [total_bonks, total])
	check(max_r < layout.boundary + 10.0, "stayed in the arena (%.1f m)" % max_r)
	finish()
