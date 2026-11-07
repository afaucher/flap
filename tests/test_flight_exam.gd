extends TestCase
## The AI's flight exam (FlightExam; docs/design/flight_exam.md): each species, flown by the AI with the player's
## controls, against the objectives in small places that don't depend on a generated wood -- one shard a scene:
##   0 pine      every perch of a lone mature pine, from in front, both sides and behind (+3 m)
##   1-2 veteran ... a veteran pine (broad, low crown): from in front and behind (1), from the sides (2)
##   3 pole      ... a pole-stage pine (slim, low perches)
##   4-5 oak     ... an oak's crown (its limbs from 6 m up): the crow, owl and sparrow (4), the hawk and falcon (5)
##   6, 7, 17 oak_low ... the oak's low limbs (~4.5 m, under the crown: little room under it to slow down and turn): the
##               crow, owl and sparrow (6) from 4 sides, the hawk (7) and the falcon (17) from 8
##   8-9 rails   an outpost's rail on a pine (8) and on the clearing's big oak (9), from 8 sides, 3 and 10 m above
##   10 gates    the gate courses (FlightExam.COURSES: straight, climb, dive, tight and wide turns, a U-turn, a gate
##               behind, a slalom, an S-bend, up and down) at recruit, pilot and ace
##   11 heights  every pine perch from 10 m above (energy to lose) and 8 m below (a climb), in front and behind
##   12, 16 grove  every perch of a pine among five others, in front and behind (threading the stand): split as the oak
##   13 hop      from a perch on one pine to every perch of another 28 m off (take-off, flight, landing)
##   14 close    every pine perch from 12 m out in front, at its height, heading at it: in on the line already, it flies
##               straight in (a turning circle to line up loops a wide turner round the tree)
##   15 oak_low_heights  the oak's low limbs from 10 m above and 6 m below, in front and behind: the hawk and falcon
## (A shard runs in one process, which the runner stops at 120 s: the oak and the grove are dear to fly among, so their
## birds are split by species, which keeps each species' whole sample in one judgement.)
## Each species must land on (go through) at least its share (RATE, by scene) within the time, its median time under
## TIME; the flock touches wood rarely (BONKS a try); and no species flies more than OVER_BANKED of its time banked past
## what its lift holds (FlightExam.OVER_BANK: a turn it can't hold sinks into a stall spiral), and nine finals in ten
## begin under FINAL_FAST x its cruise (high or fast, it loses the energy first: faster, it can't bleed to its catch). The bounds sit well under what the AI does (the doc's table):
## a subtle change to the wood, a profile or the flight model moves a rate a few per cent, which they absorb; losing a
## way of flying (a side to land from, the bank the lift holds, the line-up, the energy on the final) costs tens.

const SHARDS := 18
const SECONDS := 45.0       ## s each try has
const LOW_TIER := 6.0       ## m: an oak's limbs under this are its low tier (oak_low)
const EIGHT := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
const OAK_BIRDS := [["crow", "owl", "sparrow"], ["hawk", "falcon"]]   ## the oak's and grove's shards' species
## Share each species must land on, by scene (default: "*"). The falcon's and the hawk's floors are lower under the
## oak's crown (its low limbs ~4.5 m up: their stall speeds and turning circles leave them little room there).
const RATE := {
	"*": {"crow": 0.95, "owl": 0.95, "hawk": 0.9, "falcon": 0.85, "sparrow": 0.95},
	"oak_low": {"hawk": 0.95, "falcon": 0.85},
	"pole": {"falcon": 0.9},
	"oak_low_heights": {"hawk": 0.85, "falcon": 0.8},
	"gates": {"falcon": 0.9},
}
## Median s to land, by species (a scene can stretch it: TIME_SCALE).
const TIME := {"crow": 8.0, "owl": 8.0, "hawk": 12.0, "falcon": 16.0, "sparrow": 8.0}
const TIME_SCALE := {"rails": 2.0, "heights": 1.5, "hop": 1.6, "gates": 1.0, "oak_low": 3.0, "oak_low_heights": 3.0, "close": 0.5}   # (oak_low: the falcon gets there late if at all, its median unbounded)
const FINAL_FAST := 1.35    ## x cruise (v_best) nine finals in ten begin under (~1.1-1.26 now; diving the height away, 1.4-1.6)
const OVER_BANKED := 0.03   ## share of its flying time a species may spend banked past what the lift holds (~1.5% at
                            ## most now, in the gates' tight turns; banking to the limit whatever the speed, the falcon's 8-17%)
const BONKS := {"*": 0.1, "oak_low": 0.25, "oak_low_heights": 0.25}   ## touches of wood a try, the shard's birds' average, at most (under the oak's
                                              ## crown the hawk and falcon brush its limbs: ~0.14 a try)


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(0):
		await _tree("pine", [0.0, 90.0, 180.0, 270.0], [3.0])
	if in_shard(1):
		await _tree("veteran", [0.0, 180.0], [3.0])
	if in_shard(2):
		await _tree("veteran", [90.0, 270.0], [3.0])
	if in_shard(3):
		await _tree("pole", [0.0, 90.0, 180.0, 270.0], [3.0])
	for j in 2:
		if in_shard(4 + j):
			await _tree("oak", [0.0, 90.0, 180.0, 270.0], [3.0], "oak", false, 1, OAK_BIRDS[j])
	if in_shard(6):
		await _tree("oak", [0.0, 90.0, 180.0, 270.0], [3.0], "oak_low", false, -1, OAK_BIRDS[0])
	for j in 2:   # (the hawk and the falcon from 8 sides each, a shard each: their shares there are the closest judged)
		if in_shard([7, 17][j]):
			await _tree("oak", EIGHT, [3.0], "oak_low", false, -1, [OAK_BIRDS[1][j]])
	if in_shard(8):
		await _rail("pine")
	if in_shard(9):
		await _rail("big_oak")
	if in_shard(10):
		await _gates()
	if in_shard(11):
		await _tree("pine", [0.0, 180.0], [10.0, -8.0], "heights")
	for j in 2:
		if in_shard([12, 16][j]):
			await _tree("pine", [0.0, 180.0], [3.0], "grove", true, 0, OAK_BIRDS[j])
	if in_shard(13):
		await _hop()
	if in_shard(14):
		await _tree("pine", [0.0], [0.0], "close", false, 0, BirdProfile.IDS, 12.0)
	if in_shard(15):
		await _tree("oak", [0.0, 180.0], [10.0, -6.0], "oak_low_heights", false, -1, OAK_BIRDS[1])
	finish()


## Every perch of a lone tree of `form` (`tier` 1: those from LOW_TIER up, -1: those under it, 0: all), each of `birds`
## from each bearing and height.
func _tree(form: String, bearings: Array, ups: Array, scene := "", grove := false, tier := 0, birds: Array = BirdProfile.IDS, out := 30.0) -> void:
	var a := FlightExam.place()
	var t := FlightExam.add_tree(a, form)
	if grove:
		FlightExam.add_grove(a)
	var ex := FlightExam.new(self, a)
	var k := 0
	for id in birds:
		for q in FlightExam.perches_of(a, t.id):
			if tier != 0 and (q.position.y >= LOW_TIER) != (tier > 0):
				continue
			for be in bearings:
				for u in ups:
					k += 1
					ex.add_landing(id, q, be, u, out, 100 + k)
	check(k > 0, "%s: perches to land on" % (scene if scene != "" else form))
	await ex.fly(SECONDS)
	_judge(scene if scene != "" else form, ex.attempts)
	ex.clear()
	await frames(2)


## An outpost's rail on a tree of `form` (a pine's, the clearing's big oak's), from 8 sides, 3 and 10 m above.
func _rail(form: String) -> void:
	var a := FlightExam.place()
	var rail := FlightExam.add_outpost(a, FlightExam.add_tree(a, form))
	check(rail != null, "an outpost on the %s" % form)
	if rail == null:
		return
	var ex := FlightExam.new(self, a)
	var k := 0
	for id in BirdProfile.IDS:
		for be in range(0, 360, 45):
			for u in [3.0, 10.0]:
				k += 1
				ex.add_landing(id, rail, float(be), u, 30.0, 100 + k)
	await ex.fly(SECONDS)
	_judge("rails", ex.attempts)
	ex.clear()
	await frames(2)


## The gate courses, each species at each skill.
func _gates() -> void:
	var a := FlightExam.place()
	var ex := FlightExam.new(self, a)
	var courses := {}
	var k := 0
	for nm in FlightExam.COURSES:
		var off := Vector3(200.0 * k, 0.0, 0.0)   # (each on its own ground)
		k += 1
		var gs := FlightExam.gates_of(nm)
		for g in gs:
			g.centre += off
			g.face(g.normal, ArenaLayout.GROUND_Y)
		courses[nm] = ex.add_course(gs, FlightExam.GATE_START + off, Vector3(0, 0, 1))
	a.half_extent = 200.0 * k + 100.0
	a.boundary = a.half_extent
	ex.build()
	await frames(2)
	k = 0
	for id in BirdProfile.IDS:
		for sk in ["recruit", "pilot", "ace"]:
			for nm in courses:
				k += 1
				ex.add_race(id, courses[nm], "%s %s" % [nm, sk.substr(0, 3)], sk, 200 + k)
	await ex.fly(SECONDS)
	_judge("gates", ex.attempts)
	ex.clear()
	await frames(2)


## From two perches each of a pine 28 m off to every perch of another.
func _hop() -> void:
	var a := FlightExam.place()
	var t := FlightExam.add_tree(a, "pine")
	var from := FlightExam.perches_of(a, FlightExam.add_tree(a, "pine", Vector2(-28.0, 0.0), 6).id)
	var ex := FlightExam.new(self, a)
	var k := 0
	for id in BirdProfile.IDS:
		for q in FlightExam.perches_of(a, t.id):
			for j in 2:
				k += 1
				ex.add_hop(id, from[(q.id * 3 + j * 5) % from.size()], q, 100 + k)
	await ex.fly(SECONDS)
	_judge("hop", ex.attempts)
	ex.clear()
	await frames(2)


## Each species' rate and median time against the scene's bounds; the flock's touches of wood.
func _judge(scene: String, list: Array) -> void:
	var bonks := 0
	for at in list:
		bonks += at.bonks
	for id in BirdProfile.IDS:
		var r := FlightExam.rate(list, id)
		if r.y == 0:
			continue   # (not flown in this shard)
		var times: Array = []
		for at in list:
			if at.id == id and at.ok():
				times.append(at.landed)
		times.sort()
		var median: float = times[times.size() / 2] if not times.is_empty() else INF
		var need: float = (RATE.get(scene, {}) as Dictionary).get(id, RATE["*"][id])
		var limit: float = TIME[id] * float(TIME_SCALE.get(scene, 1.0))
		print("%s %-7s %3d / %3d  (need %.0f%%)  median %4.1f s (under %.0f)" % [scene, id, r.x, r.y, need * 100.0, median, limit])
		for at in list:
			if at.id == id and not at.ok():
				print("    " + at.describe())
		check(r.y > 0 and float(r.x) / r.y >= need, "%s: the %s makes %d of %d (needs %.0f%%)" % [scene, id, r.x, r.y, need * 100.0])
		check(median <= limit, "%s: the %s's median %.1f s (under %.0f s)" % [scene, id, median, limit])
		var flown := 0
		var over := 0
		for at in list:
			if at.id == id:
				flown += at.flown
				over += at.over_bank
		var share := float(over) / maxi(flown, 1)
		print("    %s over-banked %.1f%% of its time" % [id, share * 100.0])
		check(share <= OVER_BANKED, "%s: the %s turns within its lift (over-banked %.1f%% of the time)" % [scene, id, share * 100.0])
		var fv: Array = []
		for at in list:
			if at.id == id:
				fv.append_array(at.finals)
		fv.sort()
		var p90: float = fv[mini(fv.size() - 1, int(fv.size() * 0.9))] if not fv.is_empty() else 0.0
		print("    %s: nine finals in ten begin under %.2f x its cruise" % [id, p90])
		check(p90 <= FINAL_FAST, "%s: the %s begins its finals at its speed (nine in ten under %.2f x cruise)" % [scene, id, p90])
	print("%s: %d touches of wood in %d tries" % [scene, bonks, list.size()])
	check(bonks <= float(BONKS.get(scene, BONKS["*"])) * list.size(), "%s: wood touched rarely (%d in %d tries)" % [scene, bonks, list.size()])
