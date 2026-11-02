extends TestCase
## AI birds (every species) fly perch to perch with only the player's controls, in two different greybox arenas
## and in the pine wood (the game's own): every species chains perches, the flock as a whole chains many, trees
## are rarely touched, and nobody leaves the arena.

const SIM_SECONDS := 90.0
const SEEDS := [7, 3]


func _init() -> void:
	timeout_sec = 450.0


func setup() -> void:
	await _plans_fit_the_bird()
	await _nowhere_to_go()
	var per_species := {}
	for s in SEEDS:
		await _fly_arena(s, per_species)
	var in_pinewood := {}
	await _fly_arena(7, in_pinewood, true)
	for id in BirdProfile.IDS:
		check(per_species[id] >= 4, "%s chains perches in both arenas (%d)" % [id, per_species[id]])
	finish()


## Plans are fitted to the bird: a wide-turning hawk keeps a wider berth from trunks and skips the lowest perches
## (unfitted, hawk and falcon once reached no perches at all; the flock counts below are too noisy to notice).
func _plans_fit_the_bird() -> void:
	var layout := ArenaLayout.generate(7)
	var fit := {}
	for id in ["hawk", "sparrow"]:
		var pilot := AIPilot.new(layout, 1)
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(id), layout, pilot)
		pilot._fit(b)
		fit[id] = pilot
		b.queue_free()
	check(fit.hawk.planner.clearance > fit.sparrow.planner.clearance + 0.3, "a wide-turning hawk plans a wider berth (%.2f vs %.2f m)" % [fit.hawk.planner.clearance, fit.sparrow.planner.clearance])
	check(fit.hawk.min_perch_height > ArenaLayout.TIERS[0].h.y, "a wide-turning hawk skips the lowest perches (%.1f m)" % fit.hawk.min_perch_height)
	await frames(1)


## An AI bird with no perch anywhere keeps flying without errors (no target was once a crash).
func _nowhere_to_go() -> void:
	var empty := ArenaLayout.new()
	var pilot := AIPilot.new(empty, 5)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), empty, pilot)
	b.fly_from(Vector3(0, 20, 0), Vector3(1, 0, 0), b.profile.v_best)
	for i in 120:
		await get_tree().physics_frame
	check(pilot.target == null, "nowhere to go: no target")
	check(b.state == Bird.State.FLYING or b.state == Bird.State.GROUNDED, "nowhere to go: still flying (state %d)" % b.state)
	# Giving up on a target (too many replans) clears it but leaves the old route behind; with nothing else
	# reachable the next tick must still not touch the missing target.
	pilot.route.assign([b.global_position, b.global_position + Vector3(20, 0, 0)])
	pilot.wp = 1
	for i in 30:
		await get_tree().physics_frame
	check(pilot.target == null, "nowhere to go after giving up: still no target, no crash")
	b.queue_free()
	await frames(1)


func _fly_arena(arena_seed: int, per_species: Dictionary, pinewood := false) -> void:
	var layout := Pinewood.generate(arena_seed) if pinewood else ArenaLayout.generate(arena_seed)
	var nm := ("pine wood %d" if pinewood else "seed %d") % arena_seed
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
	check(route.size() >= 2, "%s: a route to a far perch (%d points)" % [nm, route.size()])
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
		b.rig.visible = false   # (nothing renders here; skip the feather maths)
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
		print("%s %s: %d perches, %d bonks, %d replans, state %d, stamina %.2f" % [nm, b.profile.id, pl.perches_reached, b.bonks, pl.replans, b.state, b.model.energy.stamina])
		total += pl.perches_reached
		total_bonks += b.bonks
		per_species[b.profile.id] = per_species.get(b.profile.id, 0) + pl.perches_reached
	print("%s flock: %d perches, %d bonks in %.0f s" % [nm, total, total_bonks, SIM_SECONDS])
	check(total >= 18, "%s: the flock chains perches (%d)" % [nm, total])
	check(total_bonks <= total, "%s: trees are rarely touched (%d bonks for %d perches)" % [nm, total_bonks, total])
	check(max_r < layout.boundary + 10.0, "%s: stayed in the arena (%.1f m)" % [nm, max_r])
	for b in birds:
		b.queue_free()
	arena.queue_free()
	await frames(2)
