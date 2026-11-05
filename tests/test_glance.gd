extends TestCase
## Touching wood: side hits glance, square ones bonk, wings strike, and the bird's reflexes soften what's coming.
##
## A wall of wood (a plank face at x = 0, facing +x; not in the layout, so no reflex sees it coming), a crow on its left
## and on its right:
##  - at 15 deg and best glide: a glance -- no bonk, no stun, most of its speed kept (the claws' drag only), pushed off
##    and steering away (further off than with glance_assist 0, which still glances); the near foot thrown onto the
##    wood, its drawn claws on the face (not in it), the far foot tucked;
##  - at 30 deg and 12 m/s (a bonk by speed into it before): still a glance by its angle, no stun, and it costs more of
##    the speed than the 15 deg one;
##  - at 60 deg: a bonk (stunned); square on, slow (1.5 m/s) and fast (8): the slow one's stun far shorter.
## The lab tree's trunk (in the layout: the reflexes see it), each side:
##  - a crow, a sparrow and a hawk brushing it at 15 deg: the tuck reflex pulls their wings in before the touch, no roll,
##    and they glance; the crow's drawn claws on the bark; tuck_reflex 0: no tuck;
##  - a crow at it square on: the flare reflex brakes -- it hits slower and is stunned less than with flare_reflex 0;
##  - a crow passing 12 cm clear (its spread wing would reach the bark): with the tuck reflex its wings pull in and it
##    strikes nothing but sinks for it; with tuck_reflex 0 its wing strikes and costs speed;
##  - a novice's crow (avoid_assist) brushing it: rolls away, touches nothing, and brakes for it.
## Landing on the lab branch (catch held): no reflex and no wing strike for the tree it lands in.

const WALL_X := 0.0


func _init() -> void:
	timeout_sec = 180.0


func setup() -> void:
	var p := BirdProfile.crow()
	for side in [-1.0, 1.0]:
		var nm := "wall on its left" if side < 0.0 else "wall on its right"
		var g := await _fly(side, 15.0, p.v_best, 1.0, true)
		print("%s, 15 deg at %.1f m/s: glances %d bonks %d, stunned %s, speed %.2f -> %.2f, off the wall %.2f m at 0.6 s; claws: near foot %.1f cm off the face (deepest %.1f cm in) over %d frames, far foot %.1f cm off" % [
			nm, p.v_best, g.glances, g.bonks, g.stunned, g.before, g.after, g.off, g.near_cm, g.deep_cm, g.frames, g.far_cm])
		eq(g.glances, 1, "%s, 15 deg: one glance" % nm)
		eq(g.bonks, 0, "%s, 15 deg: no bonk" % nm)
		check(not g.stunned, "%s, 15 deg: never stunned" % nm)
		check(g.after > g.before * 0.85, "%s, 15 deg: keeps most of its speed (%.2f of %.2f)" % [nm, g.after, g.before])
		check(g.off > 0.3, "%s, 15 deg: off the wall and away (%.2f m out at 0.6 s)" % [nm, g.off])
		check(g.frames >= 3, "%s: the near foot reaches the wood (%d frames on it)" % [nm, g.frames])
		check(g.near_cm < 1.5, "%s: its drawn claws on the wood's face (%.1f cm off it)" % [nm, g.near_cm])
		check(g.deep_cm < 1.0, "%s: and not in it (%.1f cm in)" % [nm, g.deep_cm])
		check(g.far_cm > 4.0, "%s: the far foot stays tucked (%.1f cm off the wood)" % [nm, g.far_cm])
		var bare := await _fly(side, 15.0, p.v_best, 0.0, false)
		eq(bare.glances, 1, "%s, glance_assist 0: still a glance" % nm)
		check(g.off > bare.off + 0.1, "%s: the glance's steer takes it further off the wall (%.2f m v %.2f with it off)" % [nm, g.off, bare.off])
		var hard := await _fly(side, 30.0, 12.0, 1.0, false)
		print("%s, 30 deg at 12 m/s: glances %d bonks %d, stunned %s, speed %.2f -> %.2f" % [nm, hard.glances, hard.bonks, hard.stunned, hard.before, hard.after])
		check(hard.glances == 1 and hard.bonks == 0 and not hard.stunned, "%s, 30 deg at 12 m/s: a glance by its angle, no stun" % nm)
		check(hard.after / hard.before < g.after / g.before - 0.1, "%s: the harder side hit costs more of the speed (%.2f kept v %.2f)" % [nm, hard.after / hard.before, g.after / g.before])
		var steep := await _fly(side, 60.0, p.v_best, 1.0, false)
		eq(steep.glances, 0, "%s, 60 deg: no glance" % nm)
		check(steep.bonks == 1 and steep.stunned, "%s, 60 deg: a bonk, stunned" % nm)
		var soft := await _fly(side, 90.0, 1.5, 1.0, false)
		var fast := await _fly(side, 90.0, 8.0, 1.0, false)
		print("%s, square on: 1.5 m/s stun %.2f s, 8 m/s stun %.2f s" % [nm, soft.stun, fast.stun])
		check(soft.bonks == 1 and fast.bonks == 1, "%s, square on: bonks" % nm)
		check(soft.stun < 0.15 and fast.stun > 0.3, "%s: a soft bonk stuns briefly (%.2f s), a hard one long (%.2f s)" % [nm, soft.stun, fast.stun])

	for side in [-1.0, 1.0]:
		var sn := "left" if side < 0.0 else "right"
		for id in ["crow", "sparrow", "hawk"]:
			var nm := "%s, the trunk on its %s" % [id, sn]
			var tr := await _trunk(id, {"kind": "hit", "deg": 15.0, "side": side, "speed": 1.0}, {}, id == "crow")
			print("%s, 15 deg: tucks %d, fold %.2f and bank %.0f deg at the touch; glances %d bonks %d; claws %.1f cm off the bark (deepest %.1f in) over %d frames" % [
				nm, tr.tucks, tr.fold, tr.bank, tr.glances, tr.bonks, tr.near_cm, tr.deep_cm, tr.frames])
			check(tr.tucks >= 1 and tr.fold > 0.5, "%s: the tuck reflex pulls its wings in before the touch (fold %.2f)" % [nm, tr.fold])
			check(absf(tr.bank) < 5.0, "%s: no roll (%.0f deg)" % [nm, tr.bank])
			check(tr.glances == 1 and tr.bonks == 0, "%s: a glance (%d), no bonk (%d)" % [nm, tr.glances, tr.bonks])
			if id == "crow":
				check(tr.frames >= 2, "%s: the near foot on the bark (%d frames: a thin trunk curves out of its reach in a few cm of flight)" % [nm, tr.frames])
				check(tr.near_cm < 1.5, "%s: its drawn claws on the bark (%.1f cm off it)" % [nm, tr.near_cm])
				check(tr.deep_cm < 1.0, "%s: and not in it (%.1f cm in)" % [nm, tr.deep_cm])
				var off := await _trunk(id, {"kind": "hit", "deg": 15.0, "side": side, "speed": 1.0}, {"tuck_reflex": 0.0}, false)
				check(off.tucks == 0 and off.fold < 0.05, "%s, tuck_reflex 0: no tuck (fold %.2f)" % [nm, off.fold])
		var nm := "crow, the trunk on its %s" % sn
		var head := await _trunk("crow", {"kind": "hit", "deg": 90.0, "side": side, "speed": 1.0}, {}, false)
		var head0 := await _trunk("crow", {"kind": "hit", "deg": 90.0, "side": side, "speed": 1.0}, {"flare_reflex": 0.0}, false)
		print("%s, square on: flares %d, %.2f m/s at the touch, stun %.2f s; flare_reflex 0: flares %d, %.2f m/s, stun %.2f s" % [nm, head.flares, head.speed, head.stun, head0.flares, head0.speed, head0.stun])
		check(head.flares >= 1 and head.bonks == 1, "%s, square on: the flare reflex fires, and it bonks" % nm)
		check(head.speed < head0.speed - 1.0, "%s: it hits slower braked (%.2f v %.2f m/s)" % [nm, head.speed, head0.speed])
		check(head.stun < head0.stun - 0.02, "%s: and is stunned less (%.2f v %.2f s)" % [nm, head.stun, head0.stun])
		check(head0.flares == 0, "%s, flare_reflex 0: no flare" % nm)
		var clip := await _trunk("crow", {"kind": "hit", "gap": 0.12, "side": side, "speed": 1.0}, {}, false)
		var clip0 := await _trunk("crow", {"kind": "hit", "gap": 0.12, "side": side, "speed": 1.0}, {"tuck_reflex": 0.0}, false)
		print("%s, passing 12 cm clear: tucks %d, wing strikes %d, %.2f m/s after, %.2f m lowest; tuck_reflex 0: strikes %d, %.2f m/s after, %.2f m lowest" % [nm, clip.tucks, clip.wing_strikes, clip.after, clip.low, clip0.wing_strikes, clip0.after, clip0.low])
		check(clip.glances + clip.bonks + clip0.glances + clip0.bonks == 0, "%s, passing 12 cm clear: its body touches nothing" % nm)
		check(clip.tucks >= 1 and clip.wing_strikes == 0, "%s: the tuck reflex pulls its wings in past the bark (%d strikes)" % [nm, clip.wing_strikes])
		check(clip.low < clip0.low - 0.01, "%s: and it sinks for it (%.2f v %.2f m)" % [nm, clip.low, clip0.low])
		check(clip0.wing_strikes >= 1 and clip0.after < clip.after - 0.5, "%s, tuck_reflex 0: its wing strikes the bark and costs speed (%.2f v %.2f m/s)" % [nm, clip0.after, clip.after])
		var nov := await _trunk("crow", {"kind": "hit", "deg": 15.0, "side": side, "speed": 1.0}, {"avoid_assist": FlightAssist.AVOID}, false)
		print("%s, novice (avoid %.1f): avoids %d, glances %d bonks %d, most flare %.2f" % [nm, FlightAssist.AVOID, nov.avoids, nov.glances, nov.bonks, nov.flare_max])
		check(nov.avoids >= 1 and nov.glances + nov.bonks == 0, "%s, novice: rolls away and touches nothing" % nm)
		check(nov.flare_max >= Bird.AVOID_DRAG * FlightAssist.AVOID * 0.9, "%s, novice: and brakes for it (flare %.2f)" % [nm, nov.flare_max])

	# Landing on the lab branch, catch held: no reflex, no wing strike for the tree it lands in.
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	var lb := Bird.new()
	add_child(lb)
	lb.setup(BirdProfile.crow(), layout, null)
	lb.arena = arena
	lb.rig.visible = false
	LabScenarios.start(LabScenarios.by_id("land_level"), lb, layout)
	for f in 300:
		await get_tree().physics_frame
		if lb.state == Bird.State.PERCHED:
			break
	eq(lb.state, Bird.State.PERCHED, "the lab landing still lands")
	check(lb.tucks + lb.flares + lb.braces == 0, "and no reflex fires for the branch it lands on")
	eq(lb.wing_strikes, 0, "nor do its wings strike the tree it lands in")
	lb.queue_free()
	arena.queue_free()
	await frames(2)
	finish()


## LabScenarios scenario `s` (kind "hit") off the lab tree's trunk, `id`, with `opts` set on the bird (tuck_reflex,
## flare_reflex, avoid_assist). At the touch: bank (deg), the wings' fold, the speed; how many of each reflex began,
## glances, bonks, wing strikes; the most stun and flare; the speed 0.5 s after the trunk and the lowest height; with
## `rig`, the near foot's drawn claws against the bark (the trunk's cylinder) while on it.
func _trunk(id: String, s: Dictionary, opts: Dictionary, rig: bool) -> Dictionary:
	var layout := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	var tree: ArenaLayout.TreeData = layout.trees[0]
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, null)
	b.arena = arena
	b.rig.visible = rig
	LabScenarios.start(s, b, layout)   # (placed before its first tick: at the origin it's in the trunk)
	for k in opts:
		b.set(k, opts[k])
	var side: float = s.side
	var out := {"bank": 0.0, "fold": 0.0, "speed": 0.0, "stun": 0.0, "flare_max": 0.0, "after": 0.0, "low": INF,
		"near_cm": 0.0, "deep_cm": 0.0, "frames": 0}
	var near_i := 0 if side < 0.0 else 1
	if rig:
		b.rig.posed.connect(func(_dt: float) -> void:
			var gl: Dictionary = b.telemetry().glance
			if gl.is_empty() or (b.rig.toe_tips[near_i] as Array).is_empty() or b.rig.rake_w[near_i] < 0.99:
				return
			var age: float = gl.age
			if age < 0.0 or age > Bird.GLANCE_RAKE - 0.02:
				return
			var xf := b.rig.global_transform
			var near := INF
			var deep := 0.0
			for tip: Vector3 in b.rig.toe_tips[near_i]:
				var w := xf * tip
				var d := Vector2(w.x - tree.base.x, w.z - tree.base.y).length() - tree.radius
				near = minf(near, d)
				deep = maxf(deep, -d)
			out.frames += 1
			out.near_cm = maxf(out.near_cm, maxf(near, 0.0) * 100.0)
			out.deep_cm = maxf(out.deep_cm, deep * 100.0))
	var touched := false
	var trace := OS.get_environment("GLANCE_DEBUG") != ""
	for f in 90:
		var bank := b.model.bank
		var fold := b.model.fold
		var spd := b.model.speed
		await get_tree().physics_frame
		if trace:
			print("  %s f %d z %.2f y %.2f bank %.0f fold %.2f flare %.2f v %.2f reflex %s strikes %d" % [id, f, b.global_position.z, b.global_position.y, rad_to_deg(b.model.bank), b.model.fold, b.model.flare, b.model.speed, b.reflex, b.wing_strikes])
		out.stun = maxf(out.stun, b.stun)
		out.flare_max = maxf(out.flare_max, b.model.flare)
		out.low = minf(out.low, b.global_position.y)
		if not touched and (b.glances > 0 or b.bonks > 0):
			touched = true
			out.bank = rad_to_deg(bank)
			out.fold = fold
			out.speed = spd
		if b.global_position.z > tree.base.y + 0.5 * b.profile.v_best and out.after == 0.0:
			out.after = b.model.speed
	for k in ["tucks", "flares", "avoids", "braces", "glances", "bonks", "wing_strikes"]:
		out[k] = b.get(k)
	b.queue_free()
	arena.queue_free()
	await frames(2)
	return out


## A crow flown level at `deg` toward the wall on `side` (-1 its left) at `speed`; glance_assist `assist`. With `rig`,
## its drawn feet are measured against the wall's face while a glance shows. Returns what happened.
func _fly(side: float, deg: float, speed: float, assist: float, rig: bool) -> Dictionary:
	var world := Node3D.new()
	add_child(world)
	var wall := StaticBody3D.new()
	wall.collision_layer = ArenaBuilder.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 20.0, 40.0)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(WALL_X - 0.5, 5.0, 0.0)
	world.add_child(wall)
	var b := Bird.new()
	world.add_child(b)
	b.setup(BirdProfile.crow(), ArenaLayout.new(), ScriptedInput.new())
	b.perch_assist = 0.0
	b.glance_assist = assist
	b.rig.visible = rig
	# (heading -z the wall at x 0 is on its left; heading +z, on its right)
	var a := deg_to_rad(deg)
	var dir := Vector3(-sin(a), 0.0, -cos(a) if side < 0.0 else cos(a))
	var r := BirdProfile.crow().body_length * 0.28
	var start_d := 0.6 if deg < 45.0 else speed * 0.08   # (square on: a few ticks out, before it sinks)
	b.fly_from(Vector3(WALL_X + r + start_d * sin(a), 5.0, 0.0), dir, speed)
	var out := {"glances": 0, "bonks": 0, "stunned": false, "before": 0.0, "after": 0.0, "off": 0.0, "stun": 0.0,
		"near_cm": 0.0, "deep_cm": 0.0, "frames": 0, "far_cm": INF}
	var hit_t := -1.0
	var t := 0.0
	var last_speed := speed
	var near_i := 0 if side < 0.0 else 1   # (the wall on its left: the left foot)
	if rig:   # (measured as each pose is drawn, in the rig's frame of that pose)
		b.rig.posed.connect(func(_dt: float) -> void:
			var gl: Dictionary = b.telemetry().glance
			if gl.is_empty() or (b.rig.toe_tips[near_i] as Array).is_empty():
				return
			var xf := b.rig.global_transform
			var near := INF
			var deep := 0.0
			for tip: Vector3 in b.rig.toe_tips[near_i]:
				var x := (xf * tip).x - WALL_X
				near = minf(near, x)
				deep = maxf(deep, -x)
			for tip: Vector3 in b.rig.toe_tips[1 - near_i]:
				out.far_cm = minf(out.far_cm, ((xf * tip).x - WALL_X) * 100.0)
			var age: float = gl.age
			if age > 0.05 and age < Bird.GLANCE_RAKE - 0.02 and b.rig.rake_w[near_i] > 0.99:
				out.frames += 1
				out.near_cm = maxf(out.near_cm, maxf(near, 0.0) * 100.0)
				out.deep_cm = maxf(out.deep_cm, deep * 100.0))
	while t < 1.5:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if b.stun > 0.0:
			out.stunned = true
			out.stun = maxf(out.stun, b.stun)
		if hit_t < 0.0 and (b.glances > 0 or b.bonks > 0):
			hit_t = t
			out.before = last_speed
		last_speed = b.model.speed
		if hit_t > 0.0 and t - hit_t < 0.05:
			out.after = b.model.speed
		if hit_t > 0.0 and t - hit_t >= 0.6 and out.off == 0.0:
			out.off = b.global_position.x - WALL_X - r
	out.glances = b.glances
	out.bonks = b.bonks
	world.queue_free()
	await frames(2)
	return out
