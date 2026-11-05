class_name RaceTrial
extends Node3D
## Headless race harness (as Duel is for fights): an arena with collision, a course with its posts in, and birds
## racing it -- AI racers (RacePilot) or any controller -- each with its own RaceRun. Birds don't collide with each
## other, so many can race at once. Add it to the tree, setup(), add birds, await run().

var layout: ArenaLayout
var course: RaceCourse
var arena: ArenaBuilder
var entries: Array = []   ## {bird, run, pilot (or null), skill, prev, track (where it was, every TRACK_EVERY ticks)}
const TRACK_EVERY := 6
var _tick := 0


## `c` already generated on `l` (its posts are put in here, before the arena is built).
func setup(l: ArenaLayout, c: RaceCourse) -> void:
	layout = l
	course = c
	c.apply(l)
	arena = ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(l)


## An AI racer of species `id` at `skill` on the start perch.
func add_ai(id: String, skill: String, seed := 1) -> Dictionary:
	var run := RaceRun.new(course)
	var pilot := RacePilot.new(layout, course, run, CombatSkill.preset(skill), seed)
	var e := add_bird(id, pilot, run)
	e.skill = skill
	return e


## A bird with controller `ctrl` (on the start perch unless placed after), its run `run` (or a new one).
func add_bird(id: String, ctrl: Object, run: RaceRun = null) -> Dictionary:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, ctrl)
	b.arena = arena
	b.rig.visible = false
	b.perch_at(course.start)
	var e := {"bird": b, "run": run if run != null else RaceRun.new(course), "pilot": ctrl as RacePilot, "skill": "", "prev": b.global_position, "track": [],
		"course_bonks": -1}
	entries.append(e)
	return e


## Run until every bird has finished (or given up), at most `seconds` of simulated time.
func run(seconds: float) -> void:
	for f in int(seconds * 60.0):
		await step()
		if entries.all(func(e): return e.run.finished() or (e.pilot != null and e.pilot.dnf)):
			break


## One physics tick: each bird's last move fed to its run.
func step() -> void:
	await get_tree().physics_frame
	_tick += 1
	for e in entries:
		var b: Bird = e.bird
		e.run.step(e.prev, b.global_position, 1.0 / 60.0, RaceRun.perch_of(b))
		e.prev = b.global_position
		if e.course_bonks < 0 and e.run.next >= course.gates.size():   # (the bonks on the course, before the landing home)
			e.course_bonks = b.bonks
		if _tick % TRACK_EVERY == 0 and not e.run.finished():
			e.track.append(b.global_position)


## Per bird: {id, skill, time (INF: didn't finish), gates, splits, misses, go_arounds, bonks, course_bonks (before the
## last gate: the landing home's left out), glances, wing_strikes, dnf}.
func results() -> Array:
	var out := []
	for e in entries:
		var b: Bird = e.bird
		var r: RaceRun = e.run
		out.append({"id": b.profile.id, "skill": e.skill, "time": r.time, "gates": r.next, "splits": r.splits.duplicate(),
			"misses": r.misses, "missed_at": r.missed_at.duplicate(), "go_arounds": e.pilot.go_arounds if e.pilot != null else 0,
			"bonks": b.bonks, "course_bonks": e.course_bonks if e.course_bonks >= 0 else b.bonks, "glances": b.glances, "wing_strikes": b.wing_strikes, "dnf": e.pilot.dnf if e.pilot != null else false})
	return out
