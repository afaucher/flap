class_name RacePilot
extends RefCounted
## An AI racer: flies a RaceRun's course gate by gate through AIPilot.steer (its guidance, avoidance and ground
## guard), producing a FlightInput and nothing else -- the player's authority exactly. Its skill (CombatSkill's
## presets: recruit, pilot, ace) takes away from a perfect pilot as in a fight:
##   reaction     s between replans of where it aims (it flies the old aim meanwhile)
##   aim_error    noise on that aim (deg off at the gate's distance)
##   bank_frac    share of the bank limit it uses
## and how it reads the course:
##   recruit  aims at the next gate's centre (no line: an angled gate it meets crooked, and may miss)
##   pilot    lines up on the gate's axis first (a lead-in point out in front that shrinks as it closes)
##   ace      lines up too, and goes through on the side toward the gate after (the inside line), at the height
##            between
## Missed a gate (through its plane beside the window, or past it): it goes round, out in front again, and back in.

const LEAD := 6.0           ## m: the carrot runs at least this far ahead along the gate's axis (2 turning circles)
const THROUGH := 4.0        ## m past the gate it aims through at the last
const INSIDE := 0.4         ## ace: share of the window's half width it cuts toward the next gate
const STUCK := 30.0         ## s without a gate: it gives up (dnf)

var course: RaceCourse
var run: RaceRun
var skill: CombatSkill
var guide: AIPilot
var rng := RandomNumberGenerator.new()
var dnf := false
var go_arounds := 0
var _aim := Vector3.ZERO
var _replan := 0.0
var _around := false
var _side := 1.0
var _clock := 0.0
var _last_gate_t := 0.0
var _last_next := -1


func _init(l: ArenaLayout, c: RaceCourse, r: RaceRun, s: CombatSkill = null, seed := 1) -> void:
	course = c
	run = r
	skill = s if s != null else CombatSkill.preset("pilot")
	guide = AIPilot.new(l, seed)
	rng.seed = seed * 31 + 7


func sample(bird: Bird, dt: float) -> FlightInput:
	if guide.turn_radius < 0.0:
		guide._fit(bird)
	_clock += dt
	if run.finished() or dnf:
		return guide._hold_glide(bird, dt) if bird.state == Bird.State.FLYING else FlightInput.new()
	match bird.state:
		Bird.State.PERCHED:
			return _start(bird)
		Bird.State.GROUNDED:
			return guide._grounded(bird)
		Bird.State.LANDING:
			return FlightInput.new()
	if run.next != _last_next:
		_last_next = run.next
		_last_gate_t = _clock
		_around = false
		_replan = 0.0
	if _clock - _last_gate_t > STUCK:
		dnf = true
	var g: RaceCourse.Gate = course.gates[run.next]
	_replan -= dt
	if _replan <= 0.0:
		_replan = skill.reaction
		_aim = _plan(bird, g)
	var opts := {"bank_frac": skill.bank_frac, "gamma": _gamma(bird, g)}
	var low := g.centre.y - g.half_h - bird.layout.ground(g.centre.x, g.centre.z)
	if low < 4.0 and bird.global_position.distance_to(g.centre) < 30.0:
		opts.floor = clampf(low - 0.2, 0.8, 4.0)   # (a low gate: the ground guard lets it down to the window)
	return guide.steer(bird, _aim, dt, opts)


## On the start perch: turn to face the first gate, then go.
func _start(bird: Bird) -> FlightInput:
	var to := course.gates[0].centre - bird.global_position
	var err := AIPilot._signed_heading(bird.facing, to)
	if absf(err) > deg_to_rad(12.0):
		return FlightInput.new(Vector2(clampf(err * 1.5, -1.0, 1.0), 0.0))
	guide._last_tree = bird.perch.tree_id if bird.perch != null else -1
	guide._takeoff_pos = bird.global_position
	_last_gate_t = _clock
	return FlightInput.new(Vector2.ZERO, true, false)


## Where to aim for gate `g` now: a carrot on the gate's axis a couple of turning circles ahead of where the bird is
## along it (so from off to one side it closes on the axis, then turns along it), moving through the gate to THROUGH
## past it at the last; the recruit just aims at the gate. Past the gate without going through: round again, out to
## the side it's on and back in front.
func _plan(bird: Bird, g: RaceCourse.Gate) -> Vector3:
	var pos := bird.global_position
	var n := g.normal
	var r := g.right()
	var along := (pos - g.centre).dot(n)   # (< 0: in front of it)
	var lat := (pos - g.centre).dot(r)
	var ld := maxf(LEAD, guide.turn_radius * 2.0)
	if along > 0.3 and not _around:
		_around = true
		go_arounds += 1
		_side = 1.0 if lat >= 0.0 else -1.0
	if _around:
		if along < -ld:
			_around = false
		else:
			return g.centre - n * (ld + 2.0) + r * _side * guide.turn_radius * 2.0 + Vector3.UP * 1.0
	var target := g.centre
	if skill.name == "ace" and run.next + 1 < course.gates.size():
		var nxt := course.gates[run.next + 1].centre
		var side := signf((nxt - g.centre).dot(r))
		var up := clampf((nxt.y - g.centre.y) / 10.0, -1.0, 1.0)
		target += r * side * g.half_w * INSIDE + Vector3.UP * up * g.half_h * INSIDE
	var aim := target + n * (THROUGH if -along < maxf(THROUGH, bird.model.speed * 0.5) else 0.0)
	if skill.name != "recruit":
		aim = target + n * minf(along + ld, THROUGH)
	if skill.aim_error_deg > 0.0:
		var off := tan(deg_to_rad(skill.aim_error_deg)) * pos.distance_to(aim)
		aim += Vector3(rng.randfn(0.0, off), rng.randfn(0.0, off) * 0.5, rng.randfn(0.0, off))
	return aim


## The path angle to hold for gate `g`: down (or up) to the window's height a little before it, and no steeper than
## reaches that height over the guidance's look-ahead (so the predicted path doesn't run on into the ground).
func _gamma(bird: Bird, g: RaceCourse.Gate) -> float:
	var pos := bird.global_position
	var along := (pos - g.centre).dot(g.normal)
	var run_in := maxf(maxf(-along - 2.0, bird.model.speed * 1.4), 1.0)
	return clampf(atan2(_aim.y - pos.y, run_in), deg_to_rad(-35.0), deg_to_rad(25.0))
