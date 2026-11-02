extends TestCase
## Combat proof of concept (scripts/combat): rockets fly a short ballistic arc and burst at the end of their
## life; fuses arm only after ARM metres and fire at the closest approach; seekers steer toward a crossing
## target (left and right) no faster than their turn cap and drop a target outside their gimbal, while an
## unguided rocket at the same target misses; the launcher locks only inside its cone and range, spends ammo,
## switches weapon and rearms on a perch; with the tack, each round leaves from its own tube and the pods set
## what it carries; a hit stuns, shoves and counts, and enough hits down a bird; the
## range scene's demo shooter lands hits on an evading target.


class FakeModel:
	var velocity := Vector3.ZERO


class Dummy extends Node3D:
	var model := FakeModel.new()


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	_rockets()
	await _fuses()
	await _seekers()
	await _launcher()
	await _mounted()
	await _hits()
	await _range()
	finish()


func _rockets() -> void:
	var p := Projectile.launch(Projectile.Kind.ROCKET, Vector3(0, 30, 0), Vector3(10, 0, 0), Vector3(1, 0, 0), null)
	var ev := {}
	var at_half := 0.0
	for i in 120:
		ev = p.step(1.0 / 60.0, null, [])
		if i == 29:
			at_half = p.travelled
		if not ev.is_empty():
			break
	check(at_half > 15.0, "rocket covers %.1f m in half a second" % at_half)
	eq(String(ev.get("why", "")), "expired", "an unguided rocket ends at the end of its life")
	check(p.travelled > 30.0 and p.travelled < 60.0, "rocket range %.0f m (short-range weapon)" % p.travelled)
	check(p.pos.y < 30.0, "it drops under gravity")


func _fuses() -> void:
	var near := Dummy.new()
	add_child(near)
	near.global_position = Vector3(2.0, 30.0, 0.3)
	var p := Projectile.launch(Projectile.Kind.ROCKET, Vector3(0, 30, 0), Vector3.ZERO, Vector3(1, 0, 0), null)
	var fused := false
	while p.alive and p.travelled < Projectile.ARM:
		fused = fused or String(p.step(1.0 / 60.0, null, [near]).get("why", "")) == "fuse"
	check(not fused, "no burst before the fuse arms (a bird 2 m from the muzzle is safe)")
	var far := Dummy.new()
	add_child(far)
	far.global_position = Vector3(15.0, 29.1, 0.4)   # (the rocket has dropped ~0.95 m by 15 m)
	var q := Projectile.launch(Projectile.Kind.ROCKET, Vector3(0, 30, 0), Vector3.ZERO, Vector3(1, 0, 0), null)
	var ev := {}
	for i in 120:
		ev = q.step(1.0 / 60.0, null, [far])
		if not ev.is_empty():
			break
	eq(String(ev.get("why", "")), "fuse", "a rocket passing within the fuse radius bursts")
	check((ev.burst as Vector3).distance_to(far.global_position) <= Projectile.fuse + 1e-3, "it bursts at the closest approach")
	near.queue_free()
	far.queue_free()
	await frames(1)


func _seekers() -> void:
	for side in [-1.0, 1.0]:
		# A target crossing 20 m ahead at 10 m/s, to one side: the seeker catches it, the rocket doesn't.
		var results := {}
		for k in [Projectile.Kind.SEEKER, Projectile.Kind.ROCKET]:
			var d := Dummy.new()
			add_child(d)
			d.global_position = Vector3(20.0, 30.0, 0.0)
			d.model.velocity = Vector3(0.0, 0.0, 10.0 * side)
			var p := Projectile.launch(k, Vector3(0, 30, 0), Vector3(10, 0, 0), Vector3(1, 0, 0), null, d)
			var worst_turn := 0.0
			var ev := {}
			for i in 180:
				var before := p.vel.normalized()
				ev = p.step(1.0 / 60.0, null, [d])
				d.global_position += d.model.velocity / 60.0
				worst_turn = maxf(worst_turn, rad_to_deg(before.angle_to(p.vel.normalized())))
				if not ev.is_empty():
					break
			results[k] = String(ev.get("why", ""))
			if k == Projectile.Kind.SEEKER:
				check(worst_turn <= float(Projectile.SPEC[k].turn) / 60.0 + 0.5, "seeker turns at most its cap (%.2f deg/step)" % worst_turn)
			d.queue_free()
		eq(results[Projectile.Kind.SEEKER], "fuse", "seeker catches a target crossing to the %s" % ("right" if side > 0 else "left"))
		check(results[Projectile.Kind.ROCKET] != "fuse", "an unguided rocket misses the same crossing target")
	# Outside the gimbal (behind), the seeker lets go and flies straight.
	var behind := Dummy.new()
	add_child(behind)
	behind.global_position = Vector3(-10.0, 30.0, 0.0)
	var s := Projectile.launch(Projectile.Kind.SEEKER, Vector3(0, 30, 0), Vector3(10, 0, 0), Vector3(1, 0, 0), null, behind)
	s.step(1.0 / 60.0, null, [])
	check(s.target == null, "a target outside the seeker's gimbal is dropped")
	behind.queue_free()
	await frames(1)


func _pair(world: CombatWorld, layout: ArenaLayout, offset: Vector3) -> Array:
	var a := Bird.new()
	add_child(a)
	a.setup(BirdProfile.crow(), layout, null)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, null)
	a.fly_from(Vector3(0, 40, 0), Vector3(0, 0, 1), 9.0)
	b.fly_from(Vector3(0, 40, 0) + offset, Vector3(0, 0, 1), 9.0)
	var la := world.add_bird(a, null)
	world.add_bird(b, null)
	return [a, b, la]


func _launcher() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	# Dead ahead at 20 m: a lock builds in about a second.
	var pr := _pair(world, layout, Vector3(0, 0, 20))
	var l: Launcher = pr[2]
	l.weapon = Launcher.Weapon.SEEKERS
	await frames(40)
	check(l.lock_target == pr[1] and not l.locked(), "locking on a bird in the cone, not yet locked after 2/3 s")
	await frames(40)
	check(l.locked(), "locked after a second in the cone")
	var before: int = l.ammo[Launcher.Weapon.SEEKERS]
	var p := l.fire(world)
	eq(int(l.ammo[Launcher.Weapon.SEEKERS]), before - 1, "firing spends a round")
	check(p.target == pr[1], "a locked seeker goes after the locked bird")
	for b in [pr[0], pr[1]]:
		world.remove_bird(b)
		b.queue_free()
	# 40 deg off the nose: no lock.
	var pr2 := _pair(world, layout, Vector3(14, 0, 17))
	var l2: Launcher = pr2[2]
	l2.weapon = Launcher.Weapon.SEEKERS
	await frames(70)
	check(l2.lock_target == null, "no lock on a bird 40 deg off the nose")
	# Switching weapon, and rearming on a perch.
	l2.controller = _Switch.new()
	await frames(1)
	eq(l2.weapon, Launcher.Weapon.ROCKETS, "weapon_next switches weapon")
	l2.controller = null
	l2.ammo[Launcher.Weapon.ROCKETS] = 0
	pr2[0].perch_at(layout.perches[0])
	await frames(int(Launcher.RESTOCK_TIME * 60) + 5)
	eq(int(l2.ammo[Launcher.Weapon.ROCKETS]), int(Launcher.AMMO[Launcher.Weapon.ROCKETS]), "sitting on a perch rearms")
	for b in [pr2[0], pr2[1]]:
		b.queue_free()
	world.queue_free()
	await frames(1)


## A crow with the tack and two rocket pods: six rockets, no seekers; each leaves from the tube it sat in, on
## the bird's back (not ahead of its beak), the pods taking turns; a perch rearms to what the pods hold.
func _mounted() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var pr := _pair(world, layout, Vector3(0, 0, 20))
	var a: Bird = pr[0]
	var l: Launcher = pr[2]
	var pods: Array[String] = ["rockets", "rockets"]
	var t := Tack.fit(a.rig, a, pods)
	l.set_mounts(t.capacity("rockets"), t.capacity("seekers"), func(w: int, i: int) -> Vector3: return t.muzzle_world("rockets" if w == Launcher.Weapon.ROCKETS else "seekers", i))
	await frames(2)
	eq(int(l.ammo[Launcher.Weapon.ROCKETS]), 6, "two rocket pods: six rockets")
	eq(int(l.ammo[Launcher.Weapon.SEEKERS]), 0, "two rocket pods: no seekers")
	var sides := []
	for shot in 2:
		var want := t.muzzle_world("rockets", int(l.ammo[Launcher.Weapon.ROCKETS]) - 1)
		var p := l.fire(world)
		check(p.pos.distance_to(want) < 1e-4, "rocket %d leaves from its tube's mouth" % shot)
		check(p.pos.distance_to(a.global_position) < a.profile.body_length * 0.4, "rocket %d leaves from the bird's back, not ahead of its beak" % shot)
		sides.append(signf((a.global_transform.affine_inverse() * p.pos).x))
	check(sides[0] != sides[1], "the pods take turns, one side then the other")
	l.ammo[Launcher.Weapon.ROCKETS] = 0
	a.perch_at(layout.perches[0])
	await frames(int(Launcher.RESTOCK_TIME * 60) + 5)
	eq(int(l.ammo[Launcher.Weapon.ROCKETS]), 6, "a perch rearms to what the pods hold")
	for b in [pr[0], pr[1]]:
		world.remove_bird(b)
		b.queue_free()
	world.queue_free()
	await frames(1)


class _Switch:
	var done := false
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		var first := not done
		done = true
		return CombatInput.new(false, false, first)


func _hits() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var pr := _pair(world, layout, Vector3(0, 0, 20))
	var victim: Bird = pr[1]
	var downs := [0]
	world.downed.connect(func(_b): downs[0] += 1)
	await frames(2)
	var v0 := victim.model.velocity
	world.hit(victim, victim.global_position + Vector3(0.5, 0, 0), 1.0, pr[0])
	check(victim.stun > 0.0, "a hit stuns")
	check((victim.model.velocity - v0).x < -1.0, "and shoves the bird away from the burst")
	eq(int(world.hits[victim]), 1, "and counts")
	for i in CombatWorld.DOWN_AFTER - 1:
		world.hit(victim, victim.global_position, 1.0, pr[0])
	eq(downs[0], 1, "%d hits down a bird" % CombatWorld.DOWN_AFTER)
	for b in [pr[0], pr[1]]:
		b.queue_free()
	world.queue_free()
	await frames(1)


func _range() -> void:
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	await frames(2)
	r.demo = true
	r.evade = true
	r.restart()
	await frames(60 * 18)
	var s: Dictionary = r.world.stats
	check(int(s.shots) >= 3 and int(s.hits) >= 1, "the demo shooter fires and lands hits on an evading target (%s)" % s)
	check(r.target_pilot.breaks >= 1, "the target breaks when threatened")
	r.queue_free()
	await frames(2)
