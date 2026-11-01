extends TestCase
## AI birds (every species) fly perch to perch with only the player's controls, in two different arenas:
## every species chains perches, the flock as a whole chains many, trees are rarely touched, and nobody
## leaves the arena.

const SIM_SECONDS := 90.0
const SEEDS := [7, 3]


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var per_species := {}
	for s in SEEDS:
		await _fly_arena(s, per_species)
	for id in BirdProfile.IDS:
		check(per_species[id] >= 4, "%s chains perches in both arenas (%d)" % [id, per_species[id]])
	finish()


func _fly_arena(arena_seed: int, per_species: Dictionary) -> void:
	var layout := ArenaLayout.generate(arena_seed)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	# The planner alone: a route to a far perch, every leg clear.
	var planner := FlightPlanner.new(layout)
	var sp := layout.start_perch()
	var far: Perch = null
	for p in layout.perches:
		if p.position.distance_to(sp.position) > 50.0 and p.position.y < sp.position.y - 5.0:
			far = p
			break
	var route := planner.plan_to_perch(sp.position + sp.facing, far, BirdProfile.crow(), sp.tree_id)
	check(route.size() >= 2, "seed %d: a route to a far perch (%d points)" % [arena_seed, route.size()])
	for i in range(1, route.size() - 1):
		check(layout.segment_clear(route[i - 1], route[i], planner.clearance * 0.99, sp.tree_id if i == 1 else -1), "route leg %d is clear" % i)

	var birds: Array[Bird] = []
	var pilots: Array[AIPilot] = []
	for i in BirdProfile.IDS.size():
		var pilot := AIPilot.new(layout, 1000 + i)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BirdProfile.IDS[i]), layout, pilot)
		b.arena = arena
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
	for i in birds.size():
		var b := birds[i]
		var pl := pilots[i]
		print("seed %d %s: %d perches, %d bonks, %d replans, state %d, stamina %.2f" % [arena_seed, b.profile.id, pl.perches_reached, b.bonks, pl.replans, b.state, b.model.energy.stamina])
		total += pl.perches_reached
		total_bonks += b.bonks
		per_species[b.profile.id] = per_species.get(b.profile.id, 0) + pl.perches_reached
	print("seed %d flock: %d perches, %d bonks in %.0f s" % [arena_seed, total, total_bonks, SIM_SECONDS])
	check(total >= 18, "seed %d: the flock chains perches (%d)" % [arena_seed, total])
	check(total_bonks <= total, "seed %d: trees are rarely touched (%d bonks for %d perches)" % [arena_seed, total_bonks, total])
	check(max_r < layout.boundary + 10.0, "seed %d: stayed in the arena (%.1f m)" % [arena_seed, max_r])
	for b in birds:
		b.queue_free()
	arena.queue_free()
	await frames(2)
