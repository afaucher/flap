class_name LabFight
extends RefCounted
## The bird lab's combat scenes (LabScenarios, kind "fight"): the real fight -- a CombatWorld, the war tack, real
## rounds from real pods -- round the lab bird, to look at frame by frame. The other bird is the lab bird's species,
## so the two glide alike and stay lined up. They fly toward +Z at FLY_Y, clear of the lab tree.
##   gun     the lab bird, a gun pod each side, GUN_BEHIND m behind a bird gliding on: a long burst at FIRE_AT s --
##           tracers from the muzzles as drawn, the flashes, chips knocked out of the target.
##   rocket  the lab bird is the target: a bird ROCKET_BEHIND m behind fires a rocket up its path at FIRE_AT s; the
##           burst beside it knocks out flight feathers, which flutter down.
##   seeker  the lab bird, seekers, behind a bird SEEKER_OFF m off its line: it holds it in the cone to lock
##           (Launcher.LOCK_TIME) and fires once locked; the seeker steers onto it.
##   downed  the lab bird is the target with DOWN_FEATHERS - 1 feathers gone: the rocket's burst downs it, and it
##           flutters down out of the fight (CombatWorld.down_flutter, on here: Bird.start_tumble) and comes down on the
##           ground.
##   rearm   the lab bird on the branch as its base, its pods empty and REARM_LOST feathers gone: after
##           Launcher.RESTOCK_TIME on it, rearmed and mended.

const FLY_Y := 12.0          ## m, over the lab tree (7 m)
const FLY_X := 4.0           ## m, beside it
const START_Z := -14.0
const FIRE_AT := 0.6         ## s
const GUN_BEHIND := 9.0
const GUN_HOLD := 1.2        ## s of fire held
const ROCKET_BEHIND := 9.0
const DOWNED_BEHIND := 6.0
const SEEKER_BEHIND := 16.0
const SEEKER_OFF := 2.0
const REARM_LOST := 4

var what := ""
var world: CombatWorld
var subject: Bird            ## the lab bird
var other: Bird = null       ## the shooter or the target
var shooter: Launcher        ## whoever fires (rearm: the lab bird's)
var target: Bird = null
var tacks := {}              ## Bird -> Tack
var trigger: Trigger
var lost0 := 0               ## the target's feathers gone at the start


## Build the scene round `bird` (just set up by LabScenarios.start, hands off) under `parent`.
static func start(s: Dictionary, bird: Bird, layout: ArenaLayout, parent: Node, arena: ArenaBuilder) -> LabFight:
	var f := LabFight.new()
	f.what = s.fight
	f.subject = bird
	f.world = CombatWorld.new()
	f.world.name = "LabCombat"
	f.world.layout = layout
	f.world.down_flutter = true
	parent.add_child(f.world)
	var p := bird.profile
	var dir := Vector3(0.0, -sin(p.glide_angle), cos(p.glide_angle))
	var at := Vector3(FLY_X, FLY_Y, START_Z)
	f.trigger = Trigger.new()
	match f.what:
		"gun", "seeker":
			bird.fly_from(at, dir, p.v_best)
			f.shooter = f._join(bird, ["gun", "gun"] if f.what == "gun" else ["seekers", "seekers"], 0)
			var off := Vector3.RIGHT * SEEKER_OFF if f.what == "seeker" else Vector3.ZERO
			f.other = f._spawn(p, layout, parent, arena, at + dir * (GUN_BEHIND if f.what == "gun" else SEEKER_BEHIND) + off, dir)
			f._join(f.other, [], 1)
			f.target = f.other
			f.trigger.at = FIRE_AT
			f.trigger.hold = GUN_HOLD if f.what == "gun" else 0.0
			f.trigger.on_lock = f.what == "seeker"
		"rocket", "downed":
			var behind := ROCKET_BEHIND if f.what == "rocket" else DOWNED_BEHIND
			bird.fly_from(at + dir * behind, dir, p.v_best)
			f._join(bird, [], 1)
			f.other = f._spawn(p, layout, parent, arena, at, dir)
			f.shooter = f._join(f.other, ["rockets", "rockets"], 0)
			f.target = bird
			f.trigger.at = FIRE_AT * (0.4 if f.what == "downed" else 1.0)
			if f.what == "downed":
				bird.lose_feathers(bird.global_position + bird.global_basis.x * 0.2, Bird.DOWN_FEATHERS - 1)
		"rearm":
			var perch: Perch = layout.perches[0]
			bird.perch_at(perch)
			bird.perch_grip = LabScenarios.aim_point(perch)
			bird.global_position = Perch.seat_at(bird.perch_grip, p)
			bird.model.position = bird.global_position
			f.shooter = f._join(bird, ["rockets", "rockets"], 0)
			f.shooter.rearm_perch = perch.id
			for w in f.shooter.ammo:
				f.shooter.ammo[w] = 0
			bird.lose_feathers(bird.global_position + bird.global_basis.x * 0.2, REARM_LOST)
			f.target = bird
			f.trigger.at = INF
	f.shooter.controller = f.trigger
	if f.target != null:
		f.lost0 = f.target.lost_feathers.size()
	return f


## Into the fight on `team`, armed with `pods` (empty: none) when its species carries the tack.
func _join(b: Bird, pods: Array, team: int) -> Launcher:
	var l := world.add_bird(b, null, team)
	if Tack.RIDDEN.has(b.profile.id):
		var t := Tack.fit(b.rig, b, pods if not pods.is_empty() else ["rockets", "rockets"])
		tacks[b] = t
		if not pods.is_empty():
			l.set_tack(t)
	if pods.is_empty():
		for w in l.capacity:
			l.capacity[w] = 0
			l.ammo[w] = 0
	return l


func _spawn(p: BirdProfile, layout: ArenaLayout, parent: Node, arena: ArenaBuilder, at: Vector3, dir: Vector3) -> Bird:
	var b := Bird.new()
	b.name = "LabOther"
	parent.add_child(b)
	b.setup(p, layout, ScriptedInput.new())
	b.arena = arena
	b.fly_from(at, dir, p.v_best)
	return b


func tack_of(b: Bird) -> Tack:
	return tacks.get(b, null)


## Feathers the target has lost since the start.
func knocked_out() -> int:
	return target.lost_feathers.size() - lost0 if target != null else 0


## A line for the lab's readout.
func status() -> String:
	var l := shooter
	var w := l.weapon
	var line := "%s  %d/%d left  shots %d" % [Launcher.KIND_NAMES[w], l.left(w), l.carried(w), l.shots]
	if w == Launcher.Weapon.SEEKERS:
		line += "  lock %.0f%%" % (100.0 * l.lock)
	if target != null:
		line += "   target: %d feathers out (%d gone)%s" % [knocked_out(), target.lost_feathers.size(), "  DOWN" if target.is_down() else ""]
	if what == "rearm":
		line += "   on base %s" % ("yes" if l.on_base() else "no")
	return line


func free_all() -> void:
	if other != null and is_instance_valid(other):
		other.queue_free()
	if world != null and is_instance_valid(world):
		world.queue_free()


## The shooter's trigger: from `at` s, a press (and `hold` s held); `on_lock`: the press waits for the lock.
class Trigger:
	var at := 0.0
	var hold := 0.0
	var on_lock := false
	var clock := 0.0
	var fired := false

	func sample(l: Launcher, dt: float) -> CombatInput:
		clock += dt
		if clock < at:
			return CombatInput.new()
		if on_lock and not l.locked():
			return CombatInput.new()
		var press := not fired
		fired = true
		return CombatInput.new(press, clock < at + hold)
