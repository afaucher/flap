class_name AICombat
extends RefCounted
## An AI bird's weapons controller -> CombatInput, the player's authority and nothing more.
##
## With a `brain` (the combat AI, docs/design/combat_ai.md 4.5): fires only when the brain has weapons free on a
## target, the flight isn't dodging a tree, the bird isn't stunned, no teammate is in the line of fire, and fire
## control says the round would hit -- flown forward with the real Projectile code (FireControl) against the
## target as seen (CombatSense: delayed, its own velocity, never its inputs). Rockets: the predicted pass inside
## the fuse (times the skill's min_quality; a rocket that passes further off doesn't go off near it), and no trunk
## between. Seekers: locked, and the solution hits whether the
## target flies on or breaks either way at its corner rate (a sparrow that can beat it by breaking isn't shot at
## until the geometry is better). The last rounds wait for a better shot.
##
## Without one (the range's --demo shooter): a trigger finger only -- seekers fire once locked, rockets when the
## lead point is under 28 m away and within `rocket_tolerance` of the aim.

var prefer := Launcher.Weapon.SEEKERS
var rocket_tolerance := 5.0   ## deg off the lead point it will still fire at (no brain)
var brain: CombatBrain = null
var shots_held := 0           ## shots fire control declined (diagnostics)
var _every := 0


func sample(l: Launcher, dt: float) -> CombatInput:
	if brain != null:
		return _fight(l, dt)
	var other := Launcher.Weapon.ROCKETS if l.weapon == Launcher.Weapon.SEEKERS else Launcher.Weapon.SEEKERS
	var next: bool = (l.weapon != prefer and int(l.ammo[prefer]) > 0) or (int(l.ammo[l.weapon]) == 0 and int(l.ammo[other]) > 0)
	if l.weapon == Launcher.Weapon.SEEKERS:
		return CombatInput.new(l.locked(), false, next)
	var t := l.target()
	if t == null:
		return CombatInput.new(false, false, next)
	var lead := l.lead_point(t)
	var to := lead - l.muzzle()
	var ok := to.length() < 28.0 and rad_to_deg(l.aim().angle_to(to)) < rocket_tolerance
	return CombatInput.new(ok, false, next)


func _fight(l: Launcher, dt: float) -> CombatInput:
	brain.tick(dt)
	var i := brain.intent
	var b := l.bird
	if not i.fire or i.target == null or b.stun > 0.0 or b.state != Bird.State.FLYING or brain.pilot.avoiding > 0.0:
		return CombatInput.new()
	if l.cooldown > 0.0 or brain.ammo_left() == 0 or brain.world.friend_in_line(l) != null:
		return CombatInput.new()
	var t := brain.picture.track_of(i.target)
	if t == null or not t.visible:
		return CombatInput.new()
	var muzzle := l.muzzle()
	var d := muzzle.distance_to(t.pos)
	if d > 45.0 or l.aim().angle_to(t.pos - muzzle) > deg_to_rad(35.0):
		return CombatInput.new()
	_every += 1
	if _every % 2 != 0:   # (a solution every other tick is plenty)
		return CombatInput.new()
	var p0 := Perf.t()
	var ok := _would_hit(l, t)
	Perf.add("ai.combat.fire", p0)
	if not ok:
		shots_held += 1
		return CombatInput.new()
	return CombatInput.new(true)


func _would_hit(l: Launcher, t: CombatSense.Track) -> bool:
	var b := l.bird
	# The last rounds wait for a better shot.
	var left := brain.ammo_left()
	var quality := brain.skill.min_quality * (0.75 if left <= 1 else 1.0)
	var layout := brain.world.layout
	if l.weapon == Launcher.Weapon.ROCKETS:
		if layout != null and not layout.segment_clear(l.muzzle(), t.pos, 0.2):
			return false   # a trunk in the way
		return FireControl.miss(Projectile.Kind.ROCKET, l.muzzle(), b.model.velocity, l.aim(), t.pos, t.vel) < Projectile.fuse * quality
	if not l.locked() or l.lock_target != t.bird:
		return false
	var corner := CombatStyle.of(t.bird.profile).best_turn_rate(t.vel.length())   # (its best break at the speed it's seen at)
	for turn in [0.0, corner, -corner]:
		if FireControl.miss(Projectile.Kind.SEEKER, l.muzzle(), b.model.velocity, l.aim(), t.pos, t.vel, turn) > Projectile.fuse * quality:
			return false
	return true
