class_name FlightExam
extends RefCounted
## The AI's flight exam (docs/design/flight_exam.md): small, controlled places -- one tree grown alone as the pine
## wood grows it, an outpost on it, a few gates on open ground -- and the objectives an AI bird must meet in them,
## flown by AIPilot (landings) or RacePilot (gates) with the player's controls only. Nothing here depends on a whole
## generated wood, so a change to how the wood is laid out doesn't move the exam; a change to how a tree grows does
## (on purpose: the AI must land on the trees the game has).
##
## A landing attempt: the bird starts flying at cruise `out` m from the perch, `bearing` deg round from the side the
## perch faces (0: in front, 180: behind its tree), `up` m above it, heading for it; AIPilot.go_to_perch. Landed on
## another perch, it's sent on again. It passes if it sits on the perch within the time.
##
## A gate attempt: a course of post gates on open ground (RaceCourse.from_gates), the bird starting in flight at cruise,
## flown by RacePilot (its line through the gates, its go-arounds). It passes if it takes every gate, in order, within
## the time (the way home isn't part of it: the landings are).

const FORMS := ["pine", "veteran", "pole", "oak", "big_oak"]
const SIZES := {   ## form -> [height m, trunk radius m]: the middle of the pine wood's range for that form (the big oak:
	"pine": [28.0, 0.28], "veteran": [21.0, 0.47], "pole": [13.0, 0.12], "oak": [19.5, 0.78],   ## the clearing's)
	"big_oak": [22.5, 0.9],
}


## The gate courses: name -> [[window centre, way through], ...], for a bird starting at GATE_START heading +Z at
## cruise. Post gates on open ground (no wood but their posts): the turns and heights a course asks for, alone.
const GATE_START := Vector3(0.0, 6.0, -40.0)
const COURSES := {
	"straight": [[Vector3(0, 6, -5), Vector3(0, 0, 1)]],
	"climb": [[Vector3(0, 12, -5), Vector3(0, 0, 1)]],
	"dive": [[Vector3(0, 2.3, -10), Vector3(0, 0, 1)]],
	"turn90_wide": [[Vector3(25, 6, -15), Vector3(1, 0, 0)]],
	"turn90_tight": [[Vector3(12, 6, -26), Vector3(1, 0, 0)]],
	"uturn": [[Vector3(16, 6, -40), Vector3(0, 0, -1)]],
	"behind": [[Vector3(0, 6, -65), Vector3(0, 0, -1)]],
	"slalom": [[Vector3(0, 6, -22), Vector3(0, 0, 1)], [Vector3(6, 6, -4), Vector3(0, 0, 1)], [Vector3(0, 6, 14), Vector3(0, 0, 1)]],
	"s_bend": [[Vector3(14, 6, -20), Vector3(1, 0, 0)], [Vector3(28, 6, -6), Vector3(0, 0, 1)], [Vector3(14, 6, 8), Vector3(-1, 0, 0)]],
	"up_down": [[Vector3(0, 11, -14), Vector3(0, 0, 1)], [Vector3(0, 3, 14), Vector3(0, 0, 1)], [Vector3(0, 9, 42), Vector3(0, 0, 1)]],
}


## The gates of course `name` (COURSES).
static func gates_of(name: String) -> Array[RaceCourse.Gate]:
	var out: Array[RaceCourse.Gate] = []
	for g in COURSES[name]:
		out.append(post_gate(g[0], g[1]))
	return out


## An empty place: flat ground, still air, the pine wood's style (its trees' collision), no edge posts.
static func place() -> ArenaLayout:
	var a := ArenaLayout.new()
	a.style = "pinewood"
	a.avenues = []
	return a


## A tree of `form` (FORMS) grown alone at `at` as the pine wood grows one (seeded `s`).
static func add_tree(a: ArenaLayout, form: String, at := Vector2.ZERO, s := 1) -> ArenaLayout.TreeData:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var size: Array = SIZES[form]
	var t: ArenaLayout.TreeData
	if form == "oak" or form == "big_oak":
		t = Pinewood._tree(a, ArenaLayout.Kind.BROADLEAF, at, size[0], size[1])
		Pinewood._grow_oak(a, t, rng, form == "big_oak")
	else:
		t = Pinewood._tree(a, ArenaLayout.Kind.PINE, at, size[0], size[1])
		t.form = "" if form == "pine" else form
		Pinewood._grow_pine(a, t, rng)
	return t


## A grove round a tree at `at`: GROVE's neighbours (form, bearing deg, metres out) -- a pine stand's spacing, so
## an approach to the middle tree threads between trunks and crowns.
const GROVE := [["pine", 20.0, 10.0], ["pole", 95.0, 8.0], ["veteran", 160.0, 11.0], ["pine", 230.0, 9.5], ["pole", 300.0, 8.5]]


static func add_grove(a: ArenaLayout, at := Vector2.ZERO, s := 1) -> void:
	for k in GROVE.size():
		var g: Array = GROVE[k]
		add_tree(a, g[0], at + Vector2.from_angle(deg_to_rad(float(g[1]))) * float(g[2]), s + 10 + k)


## An outpost on `t` (facing its most open side, as the pine wood places them); its rail perch, or null.
static func add_outpost(a: ArenaLayout, t: ArenaLayout.TreeData, s := 1) -> Perch:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	if not Pinewood._outpost(a, t, rng):
		return null
	return a.perches[a.outposts[-1].rail_perch_id]


## The perches on tree `tree_id` (its branches' and its top).
static func perches_of(a: ArenaLayout, tree_id: int) -> Array[Perch]:
	var out: Array[Perch] = []
	for p in a.perches:
		if p.tree_id == tree_id:
			out.append(p)
	return out


## Where an attempt starts: [position, heading] `out` m from the perch, `bearing` deg round from its facing (+: to
## its right seen from the front), `up` m above it (at least 3 m off the ground), heading for it.
static func start_for(p: Perch, bearing: float, out := 30.0, up := 3.0) -> Array:
	var dir := p.facing.rotated(Vector3.UP, deg_to_rad(-bearing))
	var pos := p.position + dir * out
	pos.y = maxf(p.position.y + up, 3.0)
	var to := p.position - pos
	return [pos, Vector3(to.x, 0.0, to.z).normalized()]


## One landing attempt's bird and what came of it.
class Attempt:
	var id := ""                ## species
	var perch: Perch
	var bearing := 0.0
	var up := 0.0
	var bird: Bird
	var pilot: AIPilot
	var landed := INF           ## s to sit on the perch (INF: didn't)
	var elsewhere := 0          ## times it sat on another perch first
	var grounded := 0           ## times it came down on the ground
	var approaches := 0         ## routes planned (the first, and each go-around)
	var bonks := 0
	var no_route := 0           ## times the planner found no way to the perch
	var asked := -INF           ## s it was last sent on (sent again at most once a second)
	var from: Perch = null      ## a hop's: the perch it starts on
	var name := ""              ## a gate attempt's course
	var race: RaceRun = null    ## (gate attempts)
	var racer: RacePilot = null
	var prev := Vector3.ZERO
	var flown := 0              ## ticks flying
	var over_bank := 0          ## ... of them banked past what the lift holds (AIPilot.held_bank, OVER_BANK more)
	var turned := 0.0           ## deg its heading turned through in all (a loop: 360)
	var finals: Array[float] = []   ## its speed over its cruise (v_best) as each final began
	var _was_final := false
	var _heading := Vector3.ZERO

	func ok() -> bool:
		return landed < INF

	func describe() -> String:
		if race != null:
			return "%-7s %-12s %s  %d of %d gates, %d misses, %d go-arounds, %d bonks, %d ground" % [id, name, ("%5.1f s" % landed) if ok() else " FAIL ",
				race.next, race.course.gates.size(), race.misses, racer.go_arounds, bonks, grounded]
		return "%-7s perch %2d (%4.1f m) from %4.0f deg, %+.0f m: %s  %d plans, %d bonks, %d elsewhere, %d ground, %d no route" % [id, perch.id,
			perch.position.y, bearing, up, ("%5.1f s" % landed) if ok() else " FAIL ", approaches, bonks, elsewhere, grounded, no_route]


var host: Node                  ## where the birds go (the test)
var layout: ArenaLayout
var arena: ArenaBuilder
var attempts: Array[Attempt] = []
var trace: Attempt = null       ## printed every TRACE_EVERY ticks while it flies (probes)
const TRACE_EVERY := 6
const OVER_BANK := deg_to_rad(5.0)   ## rad past the lift's held bank a tick counts as over-banked (the roll overshoots a little)


## The exam in `l`, its birds under `h`. Courses (add_course) go in before build(); birds after.
func _init(h: Node, l: ArenaLayout) -> void:
	host = h
	layout = l


## Build the place (solid wood only). Before adding birds.
func build() -> void:
	if arena != null:
		return
	arena = ArenaBuilder.new()
	arena.looks = false
	host.add_child(arena)
	arena.build(layout)


## A post gate on open ground: its window centred on `centre`, the way through `normal` (horizontal).
static func post_gate(centre: Vector3, normal: Vector3) -> RaceCourse.Gate:
	var g := RaceCourse.Gate.new()
	g.kind = "post"
	g.centre = centre
	g.face(Vector3(normal.x, 0.0, normal.z).normalized(), ArenaLayout.GROUND_Y)
	return g


## A course through `gates` for birds starting at `from` heading `dir` (its posts put in the place: before build()).
func add_course(gates: Array[RaceCourse.Gate], from: Vector3, dir: Vector3) -> RaceCourse:
	var st := Perch.branch(-1, from, from, dir, -1, 0.05)   # (where the line starts; not a perch in the place)
	var c := RaceCourse.from_gates(layout, st, gates)
	c.apply(layout)
	return c


## A bird of species `id` flying course `c` (from its start, at cruise) at `skill`, seeded `s`.
func add_race(id: String, c: RaceCourse, nm: String, skill := "pilot", s := 1) -> Attempt:
	build()
	var at := Attempt.new()
	at.id = id
	at.name = nm
	at.race = RaceRun.new(c)
	at.racer = RacePilot.new(layout, c, at.race, CombatSkill.preset(skill), s)
	at.pilot = at.racer.guide
	at.bird = Bird.new()
	host.add_child(at.bird)
	at.bird.setup(BirdProfile.by_id(id), layout, at.racer)
	at.bird.arena = arena
	at.bird.rig.visible = false
	at.bird.fly_from(c.start.position, c.start.facing, at.bird.profile.v_best)
	at.prev = c.start.position
	attempts.append(at)
	return at


## A bird of species `id` sent to land on `p` from `bearing` / `up` (start_for), seeded `s`.
func add_landing(id: String, p: Perch, bearing: float, up := 3.0, out := 30.0, s := 1) -> Attempt:
	build()
	var at := Attempt.new()
	at.id = id
	at.perch = p
	at.bearing = bearing
	at.up = up
	at.pilot = AIPilot.new(layout, s)
	at.bird = Bird.new()
	host.add_child(at.bird)
	at.bird.setup(BirdProfile.by_id(id), layout, at.pilot)
	at.bird.arena = arena
	at.bird.rig.visible = false
	var st := start_for(p, bearing, out, up)
	at.bird.fly_from(st[0], st[1], at.bird.profile.v_best)
	at.pilot._fit(at.bird)
	at.pilot.go_to_perch(at.bird, p)
	attempts.append(at)
	return at


## A bird of species `id` sitting on `from` (another tree's perch), sent to land on `p`: it takes off, flies across and
## lands, as an AI bird hops from perch to perch. Seeded `s`.
func add_hop(id: String, from: Perch, p: Perch, s := 1) -> Attempt:
	build()
	var at := Attempt.new()
	at.id = id
	at.perch = p
	at.bearing = rad_to_deg(Vector2(from.position.x - p.position.x, from.position.z - p.position.z).angle())
	at.up = from.position.y - p.position.y
	at.pilot = AIPilot.new(layout, s)
	at.bird = Bird.new()
	host.add_child(at.bird)
	at.bird.setup(BirdProfile.by_id(id), layout, at.pilot)
	at.bird.arena = arena
	at.bird.rig.visible = false
	at.bird.perch_at(from)
	at.from = from
	attempts.append(at)
	return at


## Fly every attempt until each has landed or `seconds` have passed (all at once: they don't meet).
func fly(seconds: float) -> void:
	var was := {}
	for f in int(seconds * 60.0):
		await host.get_tree().physics_frame
		var left := false
		for at in attempts:
			if at.ok():
				continue
			var b := at.bird
			var st := b.state
			if at == trace and f % TRACE_EVERY == 0:
				_trace(at, (f + 1) / 60.0)
			_measure(at)
			if at.race != null:
				at.race.step(at.prev, b.global_position, 1.0 / 60.0, RaceRun.perch_of(b))
				at.prev = b.global_position
				if st != was.get(at, -1) and st == Bird.State.GROUNDED:
					at.grounded += 1
				was[at] = st
				if at.race.next >= at.race.course.gates.size():
					at.landed = (f + 1) / 60.0
					at.bonks = b.bonks
				elif not at.racer.dnf:
					left = true
				continue
			if st == Bird.State.PERCHED and b.perch == at.perch:
				at.landed = (f + 1) / 60.0
				at.approaches = at.pilot.replans
				at.bonks = b.bonks
				continue
			left = true
			if st != was.get(at, Bird.State.PERCHED if at.from != null else -1):
				if st == Bird.State.PERCHED:
					at.elsewhere += 1
				elif st == Bird.State.GROUNDED:
					at.grounded += 1
			was[at] = st
			var now := (f + 1) / 60.0
			var lost := at.pilot.target != at.perch and now - at.asked >= 1.0
			if lost and ((st == Bird.State.PERCHED and at.pilot.mode == AIPilot.Mode.PERCHED) or st == Bird.State.FLYING):
				# (Sat somewhere else, or gave it up: the exam sends it on again.)
				at.asked = now
				at.pilot.go_to_perch(b, at.perch)
				if at.pilot.target == null:
					at.no_route += 1
		if not left:
			break
	for at in attempts:
		if not at.ok():
			at.approaches = at.pilot.replans
			at.bonks = at.bird.bonks


## How it flew this tick: over-banked (a turn the lift can't hold sinks into a stall spiral), and how far it turned.
func _measure(at: Attempt) -> void:
	var b := at.bird
	if b.state != Bird.State.FLYING:
		at._heading = Vector3.ZERO
		return
	var m := b.model
	at.flown += 1
	var final := at.pilot != null and at.race == null and at.pilot.mode == AIPilot.Mode.FINAL
	if final and not at._was_final:
		at.finals.append(m.speed / b.profile.v_best)
	at._was_final = final
	if absf(m.bank) > AIPilot.held_bank(b.profile, m.speed) + OVER_BANK:
		at.over_bank += 1
	var fd := m.flight_dir()
	var h := Vector3(fd.x, 0.0, fd.z)
	if h.length() < 0.2:
		return
	h = h.normalized()
	if at._heading != Vector3.ZERO:
		at.turned += rad_to_deg(at._heading.angle_to(h))
	at._heading = h


func _trace(at: Attempt, t: float) -> void:
	var b := at.bird
	var m := b.model
	var pl := at.pilot
	var tgt := at.perch if at.perch != null else null
	var d := tgt.distance_to(b.global_position) if tgt != null else -1.0
	var grip := tgt.closest_grip(b.global_position) if tgt != null else Vector3.ZERO
	var rel := b.global_position - grip
	print("TRACE %5.2f %s pos %s d %5.1f dy %+5.1f v %4.1f (stall %.1f grab %.1f) path %+4.0f bank %+4.0f %s wp %d/%d avoid %.1f cand %s %s stam %.2f" % [t,
		["flying", "landing", "perched", "grounded"][b.state], str(b.global_position.snapped(Vector3.ONE * 0.1)), d, rel.y,
		m.speed, b.profile.v_stall, b.profile.grab_speed_max, rad_to_deg(m.path_angle), rad_to_deg(m.bank), ["PERCHED", "CRUISE", "FINAL", "GROUNDED"][pl.mode],
		pl.wp, pl.route.size(), pl.avoiding, "T" if b.candidate == tgt and tgt != null else ("-" if b.candidate == null else str(b.candidate.id)),
		["out", "ok", "fast"][b.candidate_status], m.energy.stamina])


## Take the birds and the arena away.
func clear() -> void:
	for at in attempts:
		at.bird.queue_free()
	attempts.clear()
	if arena != null:
		arena.queue_free()


## Landed / tried, for species `id` ("" every one) among `list` (default: all).
static func rate(list: Array, id := "") -> Vector2i:
	var n := 0
	var ok := 0
	for at in list:
		if id == "" or at.id == id:
			n += 1
			ok += 1 if at.ok() else 0
	return Vector2i(ok, n)
