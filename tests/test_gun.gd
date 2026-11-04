extends TestCase
## The machine gun and per-side loadouts (Projectile GUN, Launcher, CombatWorld, Saddle): a bullet flies fast and
## far less far than a rocket, then just goes; it hits only by passing within the bird's own size (a crow's, not a
## sparrow's, at the same miss), left and right of the line; the gun's lead mark hits a crossing target where
## aiming at the target misses, crossing either way. In the world, a held trigger streams bullets at GUN_RATE from
## the gun pod's own muzzle (the left pod's or the right's, both ways round; two gun pods take turns), a tap fires a
## short burst, and the belt runs out (then fire is a dry click); the bullets land, each hit taking a feather with
## no stun and hurting no bird beside it, and fewer inside the recovery window (a third of one), so a stream chips
## a bird down instead of downing it at once -- and a rocket inside the window still takes one. Mixed loadouts
## carry each pod's rounds, Q switches between the two kinds and back, and not when both pods are alike; the
## gun's belt shows the rounds left on its own pod. The HUD shows the selected weapon first and draws the gun's
## lead mark. An AI bird given a gun (with a brain or a trigger finger only) flies and fights without error.


class FakeModel:
	var velocity := Vector3.ZERO


class Dummy extends Node3D:
	var model := FakeModel.new()


## Fire held for `hold` ticks (the first a press), then nothing; or a press every tick if `taps`.
class _Trigger:
	var hold := 0
	var next_at := -1   ## the tick to press weapon_next on (-1: never)
	var t := 0
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		var i := CombatInput.new(t == 0 and hold > 0, t < hold, t == next_at)
		t += 1
		return i


const STEP := 1.0 / 60.0


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	_flight()
	_reach()
	_lead()
	await _stream()
	await _tap_and_run_out()
	await _hits()
	_recovery()
	await _loadouts()
	await _belt()
	await _hud()
	await _ai()
	finish()


## A bullet's flight, stepped on its own: fast, about 40 m, quietly gone.
func _flight() -> void:
	var p := Projectile.launch(Projectile.Kind.GUN, Vector3(0, 30, 0), Vector3(10, 0, 0), Vector3(1, 0, 0), null)
	check(p.vel.length() > 100.0, "a bullet leaves at over 100 m/s on a 10 m/s carrier (%.0f)" % p.vel.length())
	var ev := {}
	var t := 0.0
	while p.alive:
		ev = p.step(STEP, null, [])
		t += STEP
	eq(String(ev.get("why", "")), "expired", "in open air it runs out")
	check(p.travelled > 35.0 and p.travelled < 50.0, "after about 40 m (%.1f m, %.2f s)" % [p.travelled, t])
	var r := Projectile.launch(Projectile.Kind.ROCKET, Vector3(0, 30, 0), Vector3(10, 0, 0), Vector3(1, 0, 0), null)
	var rt := 0.0
	while r.alive:
		r.step(STEP, null, [])
		rt += STEP
	check(t < rt * 0.6, "a far shorter flight than a rocket's (%.2f s v %.2f s)" % [t, rt])


## Only within the bird's own size: a crow 0.2 m off the line is hit, a sparrow there isn't, and 0.4 m off nothing
## is -- left and right.
func _reach() -> void:
	var crow := BirdProfile.crow()
	var sparrow := BirdProfile.by_id("sparrow")
	for side in [-1.0, 1.0]:
		for c in [[crow, 0.2, true], [sparrow, 0.2, false], [crow, 0.4, false]]:
			var t := _ProfiledDummy.new()
			t.profile = c[0]
			add_child(t)
			var tof := 20.0 / float(Projectile.SPEC[Projectile.Kind.GUN].launch)
			t.global_position = Vector3(20.0, 30.0 - 0.5 * Projectile.G * tof * tof, side * float(c[1]))   # (on the bullet's drop by 20 m)
			var p := Projectile.launch(Projectile.Kind.GUN, Vector3(0, 30, 0), Vector3.ZERO, Vector3(1, 0, 0), null)
			var ev := {}
			while p.alive:
				ev = p.step(STEP, null, [t])
			var hit: bool = String(ev.get("why", "")) == "hit"
			eq(hit, bool(c[2]), "a bullet %.1f m to the %s of a %s %s it" % [float(c[1]), "left" if side < 0 else "right", c[0].id, "hits" if c[2] else "misses"])
			if hit:
				check(ev.near == t and String(ev.surface) == "bird", "and names the bird it hit")
			t.queue_free()


class _ProfiledDummy extends Node3D:
	var model := FakeModel.new()
	var profile: BirdProfile


## The gun's lead mark, on a crossing target 20 m out, either way: bullets fired at it hit; at the target, they miss.
func _lead() -> void:
	var layout := ArenaLayout.lab()
	var shooter := Bird.new()
	add_child(shooter)
	shooter.setup(BirdProfile.crow(), layout, null)
	shooter.rig.visible = false
	shooter.fly_from(Vector3(0, 40, 0), Vector3(0, 0, -1), 9.0)
	var l := Launcher.new(shooter)
	l.set_mounts(0, 0, Callable(), 80)
	eq(l.weapon, Launcher.Weapon.GUN, "a launcher armed with only a gun has it selected")
	var target := Bird.new()
	add_child(target)
	target.setup(BirdProfile.crow(), layout, null)
	target.rig.visible = false
	for side in [-1.0, 1.0]:
		var at := l.muzzle() + Vector3(0, 0, -20)
		target.fly_from(at, Vector3(side, 0, 0), 9.0)
		var lead := l.lead_point(target)
		var results := []
		for aim_at in [lead, target.global_position]:
			var dm := _ProfiledDummy.new()
			dm.profile = target.profile
			add_child(dm)
			dm.global_position = target.global_position
			dm.model.velocity = target.model.velocity
			var p := Projectile.launch(Projectile.Kind.GUN, l.muzzle(), shooter.model.velocity, aim_at - l.muzzle(), null)
			var ev := {}
			while p.alive:
				dm.global_position += dm.model.velocity * STEP
				ev = p.step(STEP, null, [dm])
			results.append(String(ev.get("why", "")) == "hit")
			dm.queue_free()
		check(results[0], "crossing to the %s, a bullet at the gun's lead mark hits" % ("left" if side < 0 else "right"))
		check(not results[1], "crossing to the %s, one aimed at the target misses behind it" % ("left" if side < 0 else "right"))
	l.weapon = Launcher.Weapon.ROCKETS
	l.capacity[Launcher.Weapon.ROCKETS] = 6
	var rocket_lead := l.lead_point(target).distance_to(target.global_position)
	l.weapon = Launcher.Weapon.GUN
	check(l.lead_point(target).distance_to(target.global_position) < rocket_lead * 0.6, "the gun leads far less than a rocket")
	shooter.queue_free()
	target.queue_free()


## A crow with its tack and `pods`, flying, in `world` (its launcher armed from the tack).
func _armed(world: CombatWorld, layout: ArenaLayout, pods: Array, at := Vector3(0, 40, 0)) -> Array:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, null)
	b.fly_from(at, Vector3(0, 0, -1), 9.0)
	var typed: Array[String] = []
	typed.assign(pods)
	var t := Tack.fit(b.rig, b, typed)
	var l := world.add_bird(b, null)
	l.set_tack(t)
	return [b, l, t]


## Held for a second: GUN_RATE rounds, each from the gun pod's own muzzle, on its side -- the left pod's, or the
## right's; two gun pods take turns.
func _stream() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	for pods in [["gun", "rockets"], ["rockets", "gun"], ["gun", "gun"]]:
		var a := _armed(world, layout, pods)
		var b: Bird = a[0]
		var l: Launcher = a[1]
		var t: Tack = a[2]
		var what := ",".join(pods)
		var per := int(Saddle.POD_ROUNDS.gun)
		eq(l.carried(Launcher.Weapon.GUN), per * pods.count("gun"), what + ": the gun pods' rounds")
		eq(l.carried(Launcher.Weapon.ROCKETS), int(Saddle.POD_ROUNDS.rockets) * pods.count("rockets"), what + ": the rocket pods'")
		l.weapon = Launcher.Weapon.GUN
		var sides := []
		var off := 0
		var at_muzzle := true
		var on_spawn := func(p: Projectile) -> void:
			if p.shooter != b:
				return
			at_muzzle = at_muzzle and p.pos.distance_to(t.muzzle_world("gun", l.left(Launcher.Weapon.GUN))) < 1e-4
			var local := t.saddle.global_transform.affine_inverse() * p.pos
			sides.append(signf(local.x))
		world.launched.connect(on_spawn)
		var trig := _Trigger.new()
		trig.hold = 60
		l.controller = trig
		await frames(61)
		world.launched.disconnect(on_spawn)
		check(sides.size() >= int(Launcher.GUN_RATE) - 1 and sides.size() <= int(Launcher.GUN_RATE) + 1, "%s: a second's hold fires about %d rounds (%d)" % [what, int(Launcher.GUN_RATE), sides.size()])
		check(at_muzzle, what + ": each leaves from the gun's muzzle")
		if pods.count("gun") == 1:
			var want := -1.0 if pods[0] == "gun" else 1.0
			var own := true
			for s in sides:
				own = own and s == want
			check(own and not sides.is_empty(), "%s: every bullet from the %s side" % [what, "left" if want < 0 else "right"])
			for i in t.saddle.round_order.rockets.size():
				check(signf(t.saddle.round_muzzle("rockets", i).x) == -want, "%s: rocket %d from the other side" % [what, i])
		else:
			var turns := sides.size() > 1
			for i in range(1, sides.size()):
				turns = turns and sides[i] != sides[i - 1]
			check(turns, "%s: the two guns take turns" % what)
		world.remove_bird(b)
		b.queue_free()
	world.queue_free()
	await frames(1)


## A tap fires a GUN_BURST burst; held, the belt runs out; then fire clicks dry.
func _tap_and_run_out() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var a := _armed(world, layout, ["gun", "seekers"])
	var l: Launcher = a[1]
	l.weapon = Launcher.Weapon.GUN
	var tap := _Trigger.new()
	tap.hold = 1
	l.controller = tap
	await frames(40)
	eq(l.shots, Launcher.GUN_BURST, "a tap fires a short burst")
	var hold := _Trigger.new()
	hold.hold = int(60.0 * float(l.carried(Launcher.Weapon.GUN)) / Launcher.GUN_RATE) + 60
	l.controller = hold
	await frames(hold.hold + 2)
	eq(l.left(Launcher.Weapon.GUN), 0, "held, the belt runs out")
	eq(l.shots, l.carried(Launcher.Weapon.GUN), "having fired every round on it")
	eq(l.left(Launcher.Weapon.SEEKERS), 2, "and the other pod's seekers are untouched")
	var dry := l.dry_fires
	var again := _Trigger.new()
	again.hold = 1
	l.controller = again
	await frames(3)
	check(l.dry_fires == dry + 1 and l.shots == l.carried(Launcher.Weapon.GUN), "empty, fire clicks dry")
	world.remove_bird(a[0])
	a[0].queue_free()
	world.queue_free()
	await frames(1)


## In the world: a held stream at a crow 15 m ahead lands hits, each a feather outside the recovery window and a
## third of one inside it, with no stun; a crow a metre beside it isn't hurt.
func _hits() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var a := _armed(world, layout, ["gun", "gun"])
	var shooter: Bird = a[0]
	var l: Launcher = a[1]
	var target := Bird.new()
	add_child(target)
	target.setup(BirdProfile.crow(), layout, null)
	world.add_bird(target, null)
	var beside := Bird.new()
	add_child(beside)
	beside.setup(BirdProfile.crow(), layout, null)
	world.add_bird(beside, null)
	var place := func() -> void:   # (both held on the line of fire, 15 m out, flying with the shooter)
		var fd := shooter.model.flight_dir()
		var across := fd.cross(Vector3.UP).normalized()
		target.fly_from(shooter.global_position + fd * 15.0, fd, shooter.model.velocity.length())
		beside.fly_from(shooter.global_position + fd * 15.0 + across * 1.0, fd, shooter.model.velocity.length())
	place.call()
	var struck := []
	world.struck.connect(func(b: Bird, _at: Vector3, keys: Array) -> void: struck.append([b, keys.size()]))
	var trig := _Trigger.new()
	trig.hold = 60
	l.controller = trig
	var stun := 0.0
	for f in 75:
		await frames(1)
		stun = maxf(stun, target.stun)
		place.call()
	var hits := int(world.hits.get(target, 0))
	check(hits >= 3, "a second's stream at a crow 15 m ahead lands hits (%d of %d)" % [hits, l.shots])
	eq(target.lost_feathers.size(), 1 + floori((hits - 1) / 3.0 + 1e-6), "the first takes a feather, each after it inside the window a third of one (%d hits)" % hits)
	check(not target.is_down(), "a second's stream chips the bird, it doesn't down it")
	eq(stun, 0.0, "a bullet doesn't stun")
	eq(int(world.hits.get(beside, 0)), 0, "the crow a metre beside it isn't touched")
	eq(beside.lost_feathers.size(), 0, "nor loses a feather")
	var ok := true
	for s in struck:
		ok = ok and s[0] == target
	check(ok and struck.size() == hits, "every hit is reported (struck), on the bird hit")
	for b in [shooter, target, beside]:
		world.remove_bird(b)
		b.queue_free()
	world.queue_free()
	await frames(1)


## The recovery window, applied directly: a feather a bullet outside it, a third of one inside (a feather every
## third hit), a feather again once it's passed; a rocket inside a bullet's window still takes one, not two or three.
func _recovery() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, null)
	b.fly_from(Vector3(0, 40, 0), Vector3(0, 0, -1), 9.0)
	world.add_bird(b, null)
	var at := b.global_position + Vector3(0.1, 0, 0)
	var lost := []
	for i in 7:
		world.hit(b, at, 1.0, null, Projectile.Kind.GUN)
		lost.append(b.lost_feathers.size())
	eq(lost, [1, 1, 1, 2, 2, 2, 3], "seven bullets in quick succession: a feather, then one every third")
	world._clock += CombatWorld.recover + 0.05
	world.hit(b, at, 1.0, null, Projectile.Kind.GUN)
	eq(b.lost_feathers.size(), 4, "once the window has passed, a bullet takes a whole feather again")
	world.hit(b, at, 1.0, null, Projectile.Kind.ROCKET)
	eq(b.lost_feathers.size(), 5, "a rocket inside a bullet's window takes one feather")
	world._clock += CombatWorld.recover + 0.05
	var before := b.lost_feathers.size()
	world.hit(b, at, 1.0, null, Projectile.Kind.ROCKET)
	check(b.lost_feathers.size() - before >= 2, "outside it, a rocket takes its two or three")
	world.remove_bird(b)
	b.queue_free()
	world.queue_free()


## Q switches between the two kinds carried and back; with both pods alike it stays.
func _loadouts() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	for c in [[["gun", "rockets"], Launcher.Weapon.GUN, Launcher.Weapon.ROCKETS], [["seekers", "gun"], Launcher.Weapon.SEEKERS, Launcher.Weapon.GUN], [["gun", "gun"], Launcher.Weapon.GUN, Launcher.Weapon.GUN], [["rockets", "rockets"], Launcher.Weapon.ROCKETS, Launcher.Weapon.ROCKETS]]:
		var a := _armed(world, layout, c[0])
		var l: Launcher = a[1]
		var what := ",".join(c[0])
		l.weapon = c[1]
		var seen := [l.weapon]
		for k in 2:
			var trig := _Trigger.new()
			trig.next_at = 0
			l.controller = trig
			await frames(2)
			seen.append(l.weapon)
		eq(seen, [c[1], c[2], c[1]], "%s: Q switches %s" % [what, "to the other kind and back" if c[1] != c[2] else "nothing (one kind)"])
		world.remove_bird(a[0])
		a[0].queue_free()
	world.queue_free()
	await frames(1)


## The gun's belt shows its pod's rounds: all its cartridges full, about half at half, none empty; two guns share
## the rounds left between them.
func _belt() -> void:
	var rig := BirdRig.new()
	add_child(rig)
	rig.build(BirdProfile.crow())
	for pods in [["gun", "rockets"], ["rockets", "gun"], ["gun", "gun"]]:
		var typed: Array[String] = []
		typed.assign(pods)
		var t := Tack.fit(rig, null, typed)
		var n: int = t.capacity("gun")
		var shown := func() -> Array:
			var out := [0, 0]
			for i in 2:
				for c in (t.saddle.belts[i] as Array):
					out[i] += int((c as MeshInstance3D).visible)
			return out
		var what := ",".join(pods)
		var gi: int = pods.find("gun")
		t.set_ammo(0, 0, n)
		var full: Array = shown.call()
		check(full[gi] == Saddle.BELT_SHOWN, "%s: a full gun shows its whole belt (%s)" % [what, str(full)])
		if pods.count("gun") == 1:
			eq(full[1 - gi], 0, what + ": the other pod has no belt")
		t.set_ammo(0, 0, n / 2)
		var half: Array = shown.call()
		check(absi(int(half[gi]) - Saddle.BELT_SHOWN / 2) <= 1, "%s: half its rounds, about half its belt (%s)" % [what, str(half)])
		t.set_ammo(0, 0, 0)
		eq(shown.call(), [0, 0], what + ": empty, no cartridges")
		if pods.count("gun") == 2:
			t.set_ammo(0, 0, 2)
			eq(shown.call(), [1, 1], what + ": the last two rounds, one on each gun")
		t.free()
	rig.queue_free()
	await frames(1)


## The HUD: the rack lists the selected weapon first; with the gun selected, flying at a bird, it draws the lead mark.
func _hud() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var a := _armed(world, layout, ["rockets", "gun"])
	var me: Bird = a[0]
	var l: Launcher = a[1]
	var e := Bird.new()
	add_child(e)
	e.setup(BirdProfile.crow(), layout, null)
	world.add_bird(e, null)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var hud := CombatHud.new()
	add_child(hud)
	hud.world = world
	hud.launcher = l
	l.weapon = Launcher.Weapon.GUN
	var rows := hud.rack_rows(l)
	check(rows.size() == 2 and rows[0].name == "gun" and int(rows[0].left) == l.carried(Launcher.Weapon.GUN) and rows[1].name == "rockets", "the rack: the gun first, then the rockets (%s)" % str(rows))
	l.weapon = Launcher.Weapon.ROCKETS
	eq(String(hud.rack_rows(l)[0].name), "rockets", "switched, the rockets first")
	l.weapon = Launcher.Weapon.GUN
	var drew := false
	for f in 30:
		e.fly_from(me.global_position + me.model.flight_dir() * 15.0 + Vector3(1.5, 0, 0), Vector3(1, 0, 0), 9.0)
		cam.look_at_from_position(me.global_position - me.model.flight_dir() * 3.0 + Vector3.UP * 0.5, me.global_position + me.model.flight_dir() * 10.0)
		await frames(1)
		drew = drew or hud.drew_lead
	check(drew, "the gun selected, the HUD draws its lead mark")
	for n in [hud, cam, me, e]:
		if n is Bird:
			world.remove_bird(n)
		n.queue_free()
	world.queue_free()
	await frames(1)


## An AI bird given a gun: the combat AI (it doesn't use the gun yet, but flies and fights on) and a trigger finger
## only (it fires bursts at a bird ahead).
func _ai() -> void:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	var me: Dictionary = d.add_ai("crow", 0, Vector3(0, 20, 0), Vector3.FORWARD)
	d.add_ai("hawk", 1, Vector3(0, 22, -30), Vector3.BACK)
	var ml: Launcher = me.launcher
	ml.set_mounts(0, 0, Callable(), 2 * Launcher.GUN_POD)
	ml.weapon = Launcher.Weapon.GUN
	var out := await d.run(6.0)
	check(out.birds.size() == 2 and is_instance_valid(me.bird), "the combat AI given a gun fights a 6 s duel (%s)" % str(out.birds))
	check(ml.left(Launcher.Weapon.GUN) <= ml.carried(Launcher.Weapon.GUN), "its belt stays within what it carries")
	d.cleanup()
	d.queue_free()
	await frames(1)
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var shooter := Bird.new()
	add_child(shooter)
	shooter.setup(BirdProfile.crow(), layout, null)
	shooter.fly_from(Vector3(0, 40, 0), Vector3(0, 0, -1), 9.0)
	var finger := AICombat.new()
	finger.prefer = Launcher.Weapon.GUN
	var l := world.add_bird(shooter, finger)
	l.set_mounts(3, 0, Callable(), Launcher.GUN_POD)
	var t := Bird.new()
	add_child(t)
	t.setup(BirdProfile.crow(), layout, null)
	world.add_bird(t, null)
	for f in 40:
		t.fly_from(shooter.global_position + shooter.model.flight_dir() * 15.0, shooter.model.flight_dir(), 9.0)
		await frames(1)
	eq(l.weapon, Launcher.Weapon.GUN, "a trigger finger preferring the gun switches to it")
	check(l.shots >= Launcher.GUN_BURST, "and fires bursts at a bird ahead (%d rounds)" % l.shots)
	for b in [shooter, t]:
		world.remove_bird(b)
		b.queue_free()
	world.queue_free()
	await frames(1)
