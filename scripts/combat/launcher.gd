class_name Launcher
extends RefCounted
## A saddle-mounted launcher (Hedgerow Aces, docs/design/concept_briefs.html): bolted on facing forward, so
## you aim it by flying the bird, like a First World War fighter. Two weapons:
##   ROCKETS  6 rounds, 4 a second while fire is held; unguided, so you fly the gunsight onto the lead marker.
##   SEEKERS  3 rounds; hold a target inside the LOCK_CONE for LOCK_TIME to lock, then fire.
## Ammo is restocked, and lost feathers grown back, by sitting on a perch for RESTOCK_TIME (later: outposts only).
## Stepped by CombatWorld; reads the bird's public state only (state, model, global transform).

enum Weapon { ROCKETS, SEEKERS }

const AMMO := {Weapon.ROCKETS: 6, Weapon.SEEKERS: 4}
const COOLDOWN := {Weapon.ROCKETS: 0.25, Weapon.SEEKERS: 0.6}
const LOCK_CONE := 15.0       ## deg off the aim to start and build a lock
const LOCK_KEEP := 25.0       ## deg off the aim before a lock is dropped
const LOCK_TIME := 1.0        ## s inside the cone to lock
const LOCK_RANGE := Vector2(6.0, 40.0)   ## m
const TARGET_RANGE := 60.0    ## m, the furthest bird the HUD will bracket
const RESTOCK_TIME := 2.0     ## s perched to rearm

var bird: Bird
var controller: Object = null   ## has sample(launcher: Launcher, dt: float) -> CombatInput
var weapon := Weapon.ROCKETS
var capacity := AMMO.duplicate()   ## rounds when full: AMMO, or what the bird's mounts carry (set_mounts)
var ammo := AMMO.duplicate()
## Where round i of a weapon leaves from, world space: Callable(weapon: int, i: int) -> Vector3 (the saddle's
## pods: Tack.muzzle_world). Unset: muzzle().
var mount := Callable()
var lock_target: Bird = null
var lock := 0.0               ## 0..1 lock progress on lock_target
var cooldown := 0.0
var shots := 0
var _perched := 0.0
var _birds: Array = []


func _init(b: Bird, ctl: Object = null) -> void:
	bird = b
	controller = ctl


## Where the launcher points: along the flight path (the bird's nose follows it to within the angle of attack).
func aim() -> Vector3:
	return bird.model.flight_dir() if bird.state == Bird.State.FLYING else -bird.global_basis.z


func muzzle() -> Vector3:
	return bird.global_position + aim() * bird.profile.body_length * 0.6 + Vector3.UP * bird.profile.body_length * 0.1


## Arm from the bird's mounts: `rockets` / `seekers` rounds when full (0: none of that weapon), each fired
## from where `at` says.
func set_mounts(rockets: int, seekers: int, at: Callable) -> void:
	capacity = {Weapon.ROCKETS: rockets, Weapon.SEEKERS: seekers}
	ammo = capacity.duplicate()
	mount = at
	if int(capacity[weapon]) == 0 and int(capacity[Weapon.SEEKERS if weapon == Weapon.ROCKETS else Weapon.ROCKETS]) > 0:
		weapon = Weapon.SEEKERS if weapon == Weapon.ROCKETS else Weapon.ROCKETS


func locked() -> bool:
	return lock_target != null and lock >= 1.0


func step(dt: float, world: CombatWorld) -> void:
	_birds = world.birds
	cooldown = maxf(0.0, cooldown - dt)
	var inp: CombatInput = controller.sample(self, dt) if controller != null else CombatInput.new()
	var other := Weapon.SEEKERS if weapon == Weapon.ROCKETS else Weapon.ROCKETS
	if inp.weapon_next and int(capacity[other]) > 0:   # (a bird carrying one kind has nothing to switch to)
		weapon = other
		lock = 0.0
		lock_target = null
	_update_lock(dt)
	if bird.state == Bird.State.PERCHED:
		_perched += dt
		if _perched >= RESTOCK_TIME:
			ammo = capacity.duplicate()
			if not bird.lost_feathers.is_empty():
				bird.mend()
	else:
		_perched = 0.0
	var want := inp.fire_pressed or (weapon == Weapon.ROCKETS and inp.fire_held)
	if want and cooldown <= 0.0 and int(ammo[weapon]) > 0 and bird.state == Bird.State.FLYING:
		fire(world)


func fire(world: CombatWorld) -> Projectile:
	ammo[weapon] = int(ammo[weapon]) - 1
	cooldown = float(COOLDOWN[weapon])
	shots += 1
	var k := Projectile.Kind.ROCKET if weapon == Weapon.ROCKETS else Projectile.Kind.SEEKER
	var from: Vector3 = mount.call(weapon, int(ammo[weapon])) if mount.is_valid() else muzzle()   # (the round just gone)
	var p := Projectile.launch(k, from, bird.model.velocity, aim(), bird, lock_target if locked() else null)
	world.spawn(p)
	return p


## Off-aim angle (deg) and range to a bird.
func bearing(b: Bird) -> Vector2:
	var to := b.global_position - muzzle()
	return Vector2(rad_to_deg(aim().angle_to(to)), to.length())


func _update_lock(dt: float) -> void:
	if weapon != Weapon.SEEKERS:
		lock = 0.0
		lock_target = null
		return
	if lock_target != null and is_instance_valid(lock_target):
		var br := bearing(lock_target)
		if br.x <= LOCK_KEEP and br.y >= LOCK_RANGE.x and br.y <= LOCK_RANGE.y:
			if br.x <= LOCK_CONE:
				lock = minf(1.0, lock + dt / LOCK_TIME)
			return
	# Nothing held: start on the bird nearest the aim inside the cone.
	lock = maxf(0.0, lock - dt * 2.0)
	var best: Bird = null
	var best_a := LOCK_CONE
	for b in _birds:
		if b == bird or not is_instance_valid(b):
			continue
		var br := bearing(b)
		if br.x <= best_a and br.y >= LOCK_RANGE.x and br.y <= LOCK_RANGE.y:
			best = b
			best_a = br.x
	if best != lock_target:
		lock_target = best
		lock = 0.0


## The bird the HUD brackets: the locked or locking one, else the nearest within TARGET_RANGE in front.
func target() -> Bird:
	if lock_target != null and is_instance_valid(lock_target):
		return lock_target
	var best: Bird = null
	var best_score := INF
	for b in _birds:
		if b == bird or not is_instance_valid(b):
			continue
		var br := bearing(b)
		if br.y > TARGET_RANGE or br.x > 70.0:
			continue
		var score := br.y * (1.0 + br.x / 30.0)
		if score < best_score:
			best = b
			best_score = score
	return best


## Where to point the launcher so a rocket meets `t`: its future position after the rocket's flight time,
## raised by the rocket's drop under gravity over that time.
func lead_point(t: Bird) -> Vector3:
	var from := muzzle()
	var tp := t.global_position
	var tv := Projectile.velocity_of(t)
	var spd := bird.model.velocity.length() + 34.0   # a rocket's average speed over its first ~30 m
	var flight := from.distance_to(tp) / spd
	for i in 3:
		flight = from.distance_to(tp + tv * flight) / spd
	return tp + tv * flight + Vector3.UP * 0.5 * Projectile.G * flight * flight
