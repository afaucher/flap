extends TestCase
## The AI's flight exam (FlightExam; docs/design/flight_exam.md): each species, flown by the AI with the player's
## controls, against the objectives in small places that don't depend on a generated wood -- one shard a scene:
##   0 pine      every perch of a lone mature pine, from in front, both sides and behind (+3 m)
##   1 veteran   ... a veteran pine (broad, low crown)
##   2 pole      ... a pole-stage pine (slim, low perches)
##   3 oak       ... an oak (long level limbs, the lowest at ~5 m)
##   4 rails     an outpost's rail on a pine and on the clearing's big oak, from 8 sides, 3 and 10 m above
##   5 gates     the gate courses (FlightExam.COURSES: straight, climb, dive, tight and wide turns, a U-turn, a gate
##               behind, a slalom, an S-bend, up and down) at recruit, pilot and ace
##   6 heights   every pine perch from 10 m above (energy to lose) and 8 m below (a climb), in front and behind
##   7 grove     every perch of a pine among five others, in front and behind (threading the stand)
##   8 hop       from a perch on one pine to every perch of another 28 m off (take-off, flight, landing)
## Each species must land on (go through) at least its share (RATE, by scene) within the time, its median time under
## TIME; and the flock touches wood rarely (BONKS a try). The bounds sit well under what the AI does (the doc's table):
## a subtle change to the wood, a profile or the flight model moves a rate a few per cent, which they absorb; losing a
## way of flying (a side to land from, the bank the lift holds, the line-up, the energy on the final) costs tens.

const SHARDS := 9
const SECONDS := 45.0       ## s each try has
## Share each species must land on, by scene (default: "*"). The falcon's floor is lower where it's low and cluttered
## (an oak's 5 m limbs under the 10 m ones: its stall speed and turning circle leave it little room).
const RATE := {
	"*": {"crow": 0.95, "owl": 0.95, "hawk": 0.9, "falcon": 0.85, "sparrow": 0.95},
	"oak": {"falcon": 0.75},
	"gates": {"falcon": 0.9},
}
## Median s to land, by species (a scene can stretch it: TIME_SCALE).
const TIME := {"crow": 8.0, "owl": 8.0, "hawk": 12.0, "falcon": 16.0, "sparrow": 8.0}
const TIME_SCALE := {"rails": 2.0, "heights": 1.5, "hop": 1.6, "gates": 1.0}
const BONKS := 0.1          ## touches of wood a try, the flock's average, at most


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	if in_shard(0):
		await _tree("pine", [0.0, 90.0, 180.0, 270.0], [3.0])
	if in_shard(1):
		await _tree("veteran", [0.0, 90.0, 180.0, 270.0], [3.0])
	if in_shard(2):
		await _tree("pole", [0.0, 90.0, 180.0, 270.0], [3.0])
	if in_shard(3):
		await _tree("oak", [0.0, 90.0, 180.0, 270.0], [3.0])
	if in_shard(4):
		await _rails()
	if in_shard(5):
		await _gates()
	if in_shard(6):
		await _tree("pine", [0.0, 180.0], [10.0, -8.0], "heights")
	if in_shard(7):
		await _tree("pine", [0.0, 180.0], [3.0], "grove", true)
	if in_shard(8):
		await _hop()
	finish()


## Every perch of a lone tree of `form`, every species from each bearing and height.
func _tree(form: String, bearings: Array, ups: Array, scene := "", grove := false) -> void:
	var a := FlightExam.place()
	var t := FlightExam.add_tree(a, form)
	if grove:
		FlightExam.add_grove(a)
	var ex := FlightExam.new(self, a)
	var k := 0
	for id in BirdProfile.IDS:
		for q in FlightExam.perches_of(a, t.id):
			for be in bearings:
				for u in ups:
					k += 1
					ex.add_landing(id, q, be, u, 30.0, 100 + k)
	await ex.fly(SECONDS)
	_judge(scene if scene != "" else form, ex.attempts)
	ex.clear()
	await frames(2)


## The outpost rails: a pine's and the clearing's big oak's.
func _rails() -> void:
	var all: Array = []
	for form in ["pine", "big_oak"]:
		var a := FlightExam.place()
		var rail := FlightExam.add_outpost(a, FlightExam.add_tree(a, form))
		check(rail != null, "an outpost on the %s" % form)
		if rail == null:
			continue
		var ex := FlightExam.new(self, a)
		var k := 0
		for id in BirdProfile.IDS:
			for be in range(0, 360, 45):
				for u in [3.0, 10.0]:
					k += 1
					ex.add_landing(id, rail, float(be), u, 30.0, 100 + k)
		await ex.fly(SECONDS)
		all.append_array(ex.attempts)
		ex.clear()
		await frames(2)
	_judge("rails", all)


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
	print("%s: %d touches of wood in %d tries" % [scene, bonks, list.size()])
	check(bonks <= BONKS * list.size(), "%s: wood touched rarely (%d in %d tries)" % [scene, bonks, list.size()])
