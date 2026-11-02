extends TestCase
## Combat proof of concept (scripts/combat): rockets fly a short ballistic arc and burst at the end of their
## life; fuses arm only after ARM metres and fire at the closest approach; seekers steer toward a crossing
## target (left and right) no faster than their turn cap and drop a target outside their gimbal, while an
## unguided rocket at the same target misses; the launcher locks only inside its cone and range, spends ammo,
## switches weapon and rearms on a perch; with the tack, each round leaves from its own tube and the pods set
## what it carries; a hit stuns, shoves and knocks out the flight feathers nearest it (on the side it came from,
## left and right; the rig leaves them out), 2 or 3 of them within a fuse's reach (2.5 on average), 1 beyond; a wing that lost
## feathers lifts less and drops (the bird rolls toward it, either side); eight feathers down a bird, once, and a
## perch or a respawn mends it; the range scene's demo shooter lands hits on an evading target.


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
	_feather_counts()
	_wing_loss_flight()
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
	(pr2[0] as Bird).lose_feathers((pr2[0] as Bird).global_position, 3)
	pr2[0].perch_at(layout.perches[0])
	await frames(int(Launcher.RESTOCK_TIME * 60) + 5)
	eq(int(l2.ammo[Launcher.Weapon.ROCKETS]), int(Launcher.AMMO[Launcher.Weapon.ROCKETS]), "sitting on a perch rearms")
	eq((pr2[0] as Bird).health(), 1.0, "and grows the lost feathers back")
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
	victim.mend()
	# Each side: a burst off one wing takes that wing's feathers, which the rig then leaves out, and only that wing
	# loses area.
	for s in [-1.0, 1.0]:
		var at: Vector3 = victim.global_position + victim.rig.global_basis.x.normalized() * s * 0.3
		var keys := victim.lose_feathers(at, 3)
		eq(keys.size(), 3, "a hit knocks out the feathers it's asked to")
		var sides := {}
		for key in keys:
			sides[BirdRig.feather_side(key)] = true
		check(sides.keys() == [int(s)], "a burst off the %s wing takes that wing's feathers (%s)" % ["right" if s > 0 else "left", str(sides.keys())])
		var wl := victim.model.wing_loss
		var mine := wl.y if s > 0 else wl.x
		var other := wl.x if s > 0 else wl.y
		check(mine > 0.03 and mine < 0.4 and other == 0.0, "only that wing loses area (%.3f, the other %.3f)" % [mine, other])
		await frames(2)
		# (the flight feathers as drawn: a lost one shrunk to nothing at its root)
		var gone := 0
		var drawn := 0
		var flight := victim.rig.flight_feathers()
		for n in victim.rig.feather_keys.size():
			var key := victim.rig.feather_keys[n]
			if key < 3000 and not BirdRig.FLIGHT_KINDS.has(floori((key % 1000) / 100.0)):
				continue
			var small := victim.rig.feather_xforms[n].basis.z.length() < 1e-3
			if keys.has(key):
				gone += int(small)
			else:
				drawn += int(not small)
		eq(gone, keys.size(), "the rig leaves the lost feathers out")
		eq(drawn, flight.size() - keys.size(), "and draws all the other flight feathers")
		victim.mend()
		eq(victim.model.wing_loss, Vector2.ZERO, "mending gives the wing its area back")
	# Down: the eighth feather, and only once.
	var n_hits := 0
	while not victim.is_down() and n_hits < 20:
		world.hit(victim, victim.global_position, 1.0, pr[0])
		n_hits += 1
	eq(victim.lost_feathers.size(), Bird.DOWN_FEATHERS, "a bird loses at most %d feathers" % Bird.DOWN_FEATHERS)
	eq(downs[0], 1, "losing the %dth downs it (%d point-blank hits)" % [Bird.DOWN_FEATHERS, n_hits])
	eq(float(victim.telemetry().health), 0.0, "health reads 0 when down")
	world.hit(victim, victim.global_position, 1.0, pr[0])
	eq(downs[0], 1, "a downed bird isn't downed again")
	victim.mend()
	eq(float(victim.telemetry().health), 1.0, "mended, it reads 1")
	for b in [pr[0], pr[1]]:
		b.queue_free()
	world.queue_free()
	await frames(1)


## Feathers per hit: 2 or 3 within the fuse's reach, 2.5 on average; 1 in the blast's outer ring.
func _feather_counts() -> void:
	var world := CombatWorld.new()
	world._rng.seed = 3
	var total := 0
	var lo := 99
	var hi := 0
	var N := 4000
	for i in N:
		var d := Projectile.fuse * (i + 0.5) / N
		var n := world.feathers_for(1.0 - d / CombatWorld.blast)
		total += n
		lo = mini(lo, n)
		hi = maxi(hi, n)
	var avg := float(total) / N
	check(absf(avg - CombatWorld.FEATHERS_PER_HIT) < 0.1, "a hit averages %.1f feathers (%.2f)" % [CombatWorld.FEATHERS_PER_HIT, avg])
	check(lo == 2 and hi == 3, "2 or 3 feathers a hit within the fuse's reach (%d..%d)" % [lo, hi])
	var outer := 0
	for i in 100:
		outer = maxi(outer, world.feathers_for(1.0 - lerpf(Projectile.fuse + 0.01, CombatWorld.blast, i / 99.0) / CombatWorld.blast))
	eq(outer, 1, "1 from the blast's outer ring")
	world.free()


## A wing that lost area: both wings, less lift (the bird sinks faster); one wing, the bird rolls toward it.
func _wing_loss_flight() -> void:
	var y := {}
	var bank := {}
	for case in ["whole", "both", "left", "right"]:
		var m := FlightModel.new(BirdProfile.crow())
		m.position = Vector3(0, 50, 0)
		m.velocity = Vector3(0, 0, -m.profile.v_best)
		m.alpha = m.profile.alpha_best
		m.wing_loss = {"whole": Vector2.ZERO, "both": Vector2(0.25, 0.25), "left": Vector2(0.25, 0.0), "right": Vector2(0.0, 0.25)}[case]
		var inp := FlightInput.new()
		for i in 60:
			m.step(1.0 / 60.0, inp)
		y[case] = m.position.y
		bank[case] = rad_to_deg(m.bank)
	check(float(y.both) < float(y.whole) - 0.2, "with less wing the bird sinks faster (%.2f m lower in 1 s)" % (float(y.whole) - float(y.both)))
	check(absf(float(bank.whole)) < 0.5, "whole, it holds level (%.1f deg)" % bank.whole)
	check(float(bank.right) > 5.0 and float(bank.left) < -5.0, "a damaged wing drops: right %.1f deg, left %.1f deg (+ right down)" % [bank.right, bank.left])


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
