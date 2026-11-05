class_name Launcher
extends RefCounted
## A saddle-mounted launcher (Hedgerow Aces, docs/design/concept_briefs.html): bolted on facing forward, so
## you aim it by flying the bird, like a First World War fighter. A pod each side (Saddle), each one of three kinds;
## what's carried is summed over the pods (two of a kind: AMMO), and Q / RB switches between the kinds carried:
##   ROCKETS  3 a pod, 4 a second while fire is held; unguided, so you fly the gunsight onto the lead marker.
##   GUN      GUN_POD rounds a pod, GUN_RATE a second while fire is held (a tap fires a GUN_BURST burst); fast, short-
##            lived bullets (Projectile GUN) that must hit the bird itself, each taking about a feather: it chips, rockets
##            and seekers down. Aimed like rockets, at the lead marker (a bullet's flight is far shorter); a little spread.
##   SEEKERS  2 a pod; hold a target inside the LOCK_CONE for LOCK_TIME to lock, then fire. The seeker head sees
##            along a straight line: wood cutting it (a trunk, a branch, an outpost's deck; not leaves) stops the lock
##            building, and past LOS_GRACE drains it -- so among the trunks a lock is hard to hold, and a bird can
##            break one by putting a trunk between itself and the shooter.
## Ammo is restocked, and lost feathers grown back, by sitting RESTOCK_TIME on the bird's base: its `rearm_perch`
## (the range sets an outpost's rail; unset, any perch does).
## Stepped by CombatWorld; reads the bird's public state only (state, model, global transform).

enum Weapon { ROCKETS, SEEKERS, GUN }

const KIND_NAMES := {Weapon.ROCKETS: "rockets", Weapon.SEEKERS: "seekers", Weapon.GUN: "gun"}   ## Saddle's pod kinds
const GUN_POD := 40           ## rounds in a gun pod's belt (Saddle.POD_ROUNDS)
const GUN_RATE := 10.0        ## rounds a second while fire is held
const GUN_BURST := 3          ## the fewest rounds a press fires (a tap is a short burst)
const GUN_SPREAD := 0.7       ## deg, each bullet's scatter off the aim (sd, each way)
const AMMO := {Weapon.ROCKETS: 6, Weapon.SEEKERS: 4, Weapon.GUN: 2 * GUN_POD}   ## two pods of the kind
const COOLDOWN := {Weapon.ROCKETS: 0.25, Weapon.SEEKERS: 0.6, Weapon.GUN: 1.0 / GUN_RATE}
## A launcher not armed from mounts (tests, the AI's CombatBrain.arm) carries six rockets and four seekers, no gun.
const UNMOUNTED := {Weapon.ROCKETS: 6, Weapon.SEEKERS: 4, Weapon.GUN: 0}
const LOCK_CONE := 15.0       ## deg off the aim to start and build a lock
const LOCK_KEEP := 25.0       ## deg off the aim before a lock is dropped
const LOCK_TIME := 1.0        ## s inside the cone to lock
const LOCK_RANGE := Vector2(6.0, 40.0)   ## m
const LOS_GRACE := 0.25       ## s the wood may cut the line before the lock drains (a branch flicking past)
const LOS_DRAIN := 1.5        ## lock lost per s while the wood cuts the line, past the grace
const TARGET_RANGE := 60.0    ## m, the furthest bird the HUD will bracket
const PICK_CONE := 20.0       ## deg off the aim: inside it the HUD's target is whatever is nearest the sight (a bird, a balloon)
const PICK_KEEP := 0.6        ## another takes the pick from the one held only nearer the sight than this share of its angle
const SIGHT_RANGE := 25.0     ## m out on the line of fire, where the HUD draws the gunsight
const RESTOCK_TIME := 2.0     ## s perched to rearm
const GUN_SPEED := 92.0       ## m/s over the carrier's, a bullet's average over its first ~30 m (for the lead)

var bird: Bird
var controller: Object = null   ## has sample(launcher: Launcher, dt: float) -> CombatInput
var weapon := Weapon.ROCKETS
var capacity := UNMOUNTED.duplicate()   ## rounds when full: UNMOUNTED, or what the bird's mounts carry (set_mounts)
var ammo := UNMOUNTED.duplicate()
## Where round i of a weapon leaves from, world space: Callable(weapon: int, i: int) -> Vector3 (the saddle's
## pods: Tack.muzzle_world). Unset: muzzle().
var mount := Callable()
var mount_drawn := Callable()   ## (weapon, round) -> where that round's muzzle is drawn this frame (set_tack)
var lock_target: Bird = null
var lock := 0.0               ## 0..1 lock progress on lock_target
var cooldown := 0.0
var shots := 0
var dry_fires := 0             ## fire pressed with the weapon empty (GameAudio: the dry click)
var burst_left := 0            ## gun rounds still to come of the burst a press started
var rearm_perch := -1          ## the base's perch (Perch.id): the only place to rearm and mend (-1: any perch)
var _perched := 0.0
var _blocked := 0.0            ## s the wood has cut the line to lock_target
var _birds: Array = []
var _world: CombatWorld = null
var _rng := RandomNumberGenerator.new()   ## (the gun's scatter)
var _pick: Object = null      ## what target() picked last (it holds it against one a little nearer the sight)


func _init(b: Bird, ctl: Object = null) -> void:
	bird = b
	controller = ctl
	_rng.seed = 5


## The weapon for a Saddle pod kind ("rockets" | "seekers" | "gun"), or -1.
static func weapon_of(kind: String) -> int:
	for w in KIND_NAMES:
		if KIND_NAMES[w] == kind:
			return w
	return -1


## The projectile a weapon fires.
static func kind_of(w: int) -> int:
	return Projectile.Kind.GUN if w == Weapon.GUN else (Projectile.Kind.SEEKER if w == Weapon.SEEKERS else Projectile.Kind.ROCKET)


## Rounds of weapon `w` carried when full, and left now (0 for a kind not carried).
func carried(w: int) -> int:
	return int(capacity.get(w, 0))


func left(w: int) -> int:
	return int(ammo.get(w, 0))


## The weapons carried, in Weapon order.
func kinds() -> Array:
	var out := []
	for w in [Weapon.ROCKETS, Weapon.SEEKERS, Weapon.GUN]:
		if carried(w) > 0:
			out.append(w)
	return out


## What Q / RB switches to: the next kind carried after the selected one (itself if it's the only one).
func next_weapon() -> int:
	var ks := kinds()
	if ks.is_empty():
		return weapon
	var i := ks.find(weapon)
	return ks[(i + 1) % ks.size()]


## Where the launcher points: along the flight path (the bird's nose follows it to within the angle of attack).
func aim() -> Vector3:
	return bird.model.flight_dir() if bird.state == Bird.State.FLYING else -bird.global_basis.z


func muzzle() -> Vector3:
	return bird.global_position + aim() * bird.profile.body_length * 0.6 + Vector3.UP * bird.profile.body_length * 0.1


## Arm from the bird's mounts: `rockets` / `seekers` / `gun` rounds when full (0: none of that weapon), each fired
## from where `at` says. The selected weapon stays if it's carried, else the first carried.
func set_mounts(rockets: int, seekers: int, at: Callable, gun := 0) -> void:
	capacity = {Weapon.ROCKETS: rockets, Weapon.SEEKERS: seekers, Weapon.GUN: gun}
	ammo = capacity.duplicate()
	mount = at
	mount_drawn = Callable()
	if carried(weapon) == 0 and not kinds().is_empty():
		weapon = kinds()[0]


## Arm from a bird's tack: what its pods hold, each round from its own pod's muzzle (Tack.muzzle_world).
func set_tack(t: Tack) -> void:
	set_mounts(t.capacity("rockets"), t.capacity("seekers"), func(w: int, i: int) -> Vector3: return t.muzzle_world(KIND_NAMES[w], i), t.capacity("gun"))
	mount_drawn = func(w: int, i: int) -> Vector3: return t.muzzle_drawn(KIND_NAMES[w], i)


func locked() -> bool:
	return lock_target != null and lock >= 1.0


func step(dt: float, world: CombatWorld) -> void:
	_birds = world.birds
	_world = world
	cooldown = maxf(0.0, cooldown - dt)
	var inp: CombatInput = controller.sample(self, dt) if controller != null else CombatInput.new()
	if inp.weapon_next and next_weapon() != weapon:   # (a bird carrying one kind has nothing to switch to)
		weapon = next_weapon()
		lock = 0.0
		lock_target = null
		burst_left = 0
	_update_lock(dt)
	if on_base():
		_perched += dt
		if _perched >= RESTOCK_TIME:
			ammo = capacity.duplicate()
			if not bird.lost_feathers.is_empty():
				bird.mend()
	else:
		_perched = 0.0
	var gun := weapon == Weapon.GUN
	if gun and inp.fire_pressed:
		burst_left = maxi(burst_left, GUN_BURST)
	var want := inp.fire_pressed or (weapon != Weapon.SEEKERS and inp.fire_held) or (gun and burst_left > 0)
	if want and cooldown <= 1e-6 and left(weapon) > 0 and bird.state == Bird.State.FLYING:   # (1e-6: the gun's 1/10 s is 6 ticks)
		fire(world)
	elif inp.fire_pressed and left(weapon) == 0:
		dry_fires += 1
	if gun and (left(weapon) == 0 or bird.state != Bird.State.FLYING):
		burst_left = 0


## Sitting on the base's perch, where the rack refills and feathers grow back.
func on_base() -> bool:
	return bird.state == Bird.State.PERCHED and (rearm_perch < 0 or (bird.perch != null and bird.perch.id == rearm_perch))


## All rounds in and every feather on.
func full() -> bool:
	return ammo == capacity and bird.lost_feathers.is_empty()


func fire(world: CombatWorld) -> Projectile:
	ammo[weapon] = int(ammo[weapon]) - 1
	cooldown = float(COOLDOWN[weapon])
	shots += 1
	var k := kind_of(weapon)
	var from: Vector3 = mount.call(weapon, int(ammo[weapon])) if mount.is_valid() else muzzle()   # (the round just gone)
	var dir := aim()
	if k == Projectile.Kind.GUN:
		burst_left = maxi(burst_left - 1, 0)
		var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := side.cross(dir).normalized()
		var sd := deg_to_rad(GUN_SPREAD)
		dir = (dir + side * tan(_rng.randfn(0.0, sd)) + up * tan(_rng.randfn(0.0, sd))).normalized()
	var p := Projectile.launch(k, from, bird.model.velocity, dir, bird, lock_target if locked() else null)
	if k == Projectile.Kind.GUN and mount_drawn.is_valid():
		var w := weapon
		var i := int(ammo[weapon])
		p.gun_mouth = func() -> Vector3: return mount_drawn.call(w, i)
	world.spawn(p)
	return p


## Off-aim angle (deg) and range to a bird.
func bearing(b: Object) -> Vector2:
	var to := aim_at(b) - muzzle()
	return Vector2(rad_to_deg(aim().angle_to(to)), to.length())


## Can the bird aim (and so fire, and build a lock)? Only in flight: the launcher points along the flight path.
func can_aim() -> bool:
	return bird.state == Bird.State.FLYING


func _update_lock(dt: float) -> void:
	if weapon != Weapon.SEEKERS or not can_aim():
		lock = 0.0
		lock_target = null
		return
	if lock_target != null and is_instance_valid(lock_target):
		var br := bearing(lock_target)
		if br.x <= LOCK_KEEP and br.y >= LOCK_RANGE.x and br.y <= LOCK_RANGE.y:
			if sees(lock_target):
				_blocked = 0.0
				if br.x <= LOCK_CONE:
					lock = minf(1.0, lock + dt / LOCK_TIME)
			else:
				_blocked += dt
				if _blocked > LOS_GRACE:
					lock = maxf(0.0, lock - dt * LOS_DRAIN)
			return
	# Nothing held: start on the bird nearest the aim inside the cone, in sight.
	lock = maxf(0.0, lock - dt * 2.0)
	var best: Bird = null
	var best_a := LOCK_CONE
	for b in _birds:
		if not is_instance_valid(b) or not is_enemy(b):   # (never a lock on a teammate)
			continue
		var br := bearing(b)
		if br.x <= best_a and br.y >= LOCK_RANGE.x and br.y <= LOCK_RANGE.y and sees(b):
			best = b
			best_a = br.x
	if best != lock_target:
		lock_target = best
		lock = 0.0
		_blocked = 0.0


## Can the seeker head see `b`: is the straight line from the muzzle to it clear of wood (trunks, branches, decks)?
func sees(b: Bird) -> bool:
	var layout := _world.layout if _world != null else null
	return layout == null or layout.segment_clear(muzzle(), b.global_position, 0.0)


## Is `b` an enemy of this launcher's bird (another team)? Every other bird is, outside a CombatWorld.
func is_enemy(b: Bird) -> bool:
	return b != bird and (_world == null or not _world.friends(bird, b))


## The bird the AI shoots at (AICombat): the locked or locking one, else the nearest enemy within TARGET_RANGE in front.
func target_bird() -> Bird:
	if lock_target != null and is_instance_valid(lock_target):
		return lock_target
	var best: Bird = null
	var best_score := INF
	for b in _birds:
		if not is_instance_valid(b) or not is_enemy(b):
			continue
		var br := bearing(b)
		if br.y > TARGET_RANGE or br.x > 70.0:
			continue
		var score := br.y * (1.0 + br.x / 30.0)
		if score < best_score:
			best = b
			best_score = score
	return best


## What the HUD brackets and leads: the locked or locking bird; else, of the enemies and the balloons still up within
## TARGET_RANGE, the one nearest the sight inside PICK_CONE (held against another until that one is nearer the sight by
## PICK_KEEP); else the nearest enemy in front (target_bird).
func target() -> Object:
	if lock_target != null and is_instance_valid(lock_target):
		_pick = lock_target
		return lock_target
	var held := INF
	if _pick != null and _pickable(_pick):
		var br := bearing(_pick)
		if br.x <= PICK_CONE and br.y <= TARGET_RANGE:
			held = br.x
	var best: Object = _pick if held < INF else null
	var best_a := held * PICK_KEEP if held < INF else PICK_CONE
	for o in _birds + (_world.balloons if _world != null else []):
		if o == _pick or not _pickable(o):
			continue
		var br := bearing(o)
		if br.y <= TARGET_RANGE and br.x <= best_a:
			best = o
			best_a = br.x
	if best == null:
		best = target_bird()
	_pick = best
	return best


func _pickable(o: Object) -> bool:
	if not is_instance_valid(o):
		return false
	if o is TargetBalloon:
		return not (o as TargetBalloon).is_down()
	return o is Bird and is_enemy(o)


## Where on `o` the launcher aims: a bird's body, a balloon's envelope.
static func aim_at(o: Object) -> Vector3:
	return (o as TargetBalloon).centre() if o is TargetBalloon else (o as Node3D).global_position


## How whole `o` is, 0 .. 1: a bird's health, a balloon's gas above what holds it up (none once it's alight).
static func health_of(o: Object) -> float:
	if o is TargetBalloon:
		var bl := o as TargetBalloon
		return 0.0 if bl.burn_r >= 0.0 else clampf((bl.gas - TargetBalloon.DOWN_GAS) / (1.0 - TargetBalloon.DOWN_GAS), 0.0, 1.0)
	return float((o as Bird).telemetry().health)


## Where to point the launcher so a round of the selected weapon (a rocket, or a bullet) meets `t`: its future
## position after the round's flight time, raised by the round's drop under gravity over that time.
func lead_point(t: Object) -> Vector3:
	var from := muzzle()
	var tp := aim_at(t)
	var tv := Projectile.velocity_of(t)
	var spd := bird.model.velocity.length() + (GUN_SPEED if weapon == Weapon.GUN else 34.0)   # (a rocket averages 34 m/s over its first ~30 m)
	var flight := from.distance_to(tp) / spd
	for i in 3:
		flight = from.distance_to(tp + tv * flight) / spd
	return tp + tv * flight + Vector3.UP * 0.5 * Projectile.G * flight * flight


## Where the gunsight (SIGHT_RANGE out on the line of fire) has to be for the selected weapon's round to meet `t`: the
## sight's point for the aim through lead_point (the launcher points along the flight path, so a round leaves along the
## aim, the bird's speed and the kick together). Fly the sight onto it and the round meets `t` at whatever range: unlike
## lead_point itself, which the sight covers truly only at SIGHT_RANGE (the camera sits above the line of fire, so nearer
## than that a mark under the sight is above where the rounds go, further off below).
func lead_sight(t: Object) -> Vector3:
	var from := muzzle()
	return from + (lead_point(t) - from).normalized() * SIGHT_RANGE
