extends TestCase
## The combat AI's defence (docs/design/combat_ai.md, 4.6). In this flight model no level break beats a locked seeker
## (probe_seeker_break), and a rocket from inside ~15 m arrives before a bird can roll, so the defence works before the
## round is in the air: deny the lock, jink while an enemy sits in firing position, drag a seeker past a trunk.
##   - Pursued: a pilot-skill combat-AI attacker starts behind the defender (astern, on either quarter, close and
##     at the edge of lock range) and hunts it, with seekers (a crow) and with rockets (a sparrow). Once the defender
##     is a combat-AI bird (defending only: it has no rounds), once the same bird flying straight on. Defending must
##     take at most half the hits, from the left and from the right, and the attacker must hold a seeker lock for far
##     less of the time.
##   - Tree drag: a seeker fired from behind with a trunk ahead and to one side; the defender (a sparrow, ace skill)
##     flies close past the trunk and hooks in behind it, and the seeker bursts on the wood. Flying straight on, it's
##     hit.

const SECONDS := 10.0


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var starts := [Vector3(0.0, 0.0, 18.0), Vector3(10.0, 1.0, 20.0), Vector3(-10.0, 1.0, 20.0), Vector3(6.0, 2.0, 32.0), Vector3(-6.0, 2.0, 32.0)]
	for attacker in ["crow", "sparrow"]:
		for id in ["crow", "sparrow"]:
			var straight := {"hits": 0, "locked": 0.0, "shots": 0}
			var defended := {"hits": 0, "locked": 0.0, "shots": 0}
			var by_side := {1.0: [0, 0], -1.0: [0, 0]}
			for s in starts:
				var a: Dictionary = await _pursued(id, attacker, s, false)
				var b: Dictionary = await _pursued(id, attacker, s, true)
				for k in straight:
					straight[k] += a[k]
					defended[k] += b[k]
				if s.x != 0.0:
					by_side[signf(s.x)][0] += a.hits
					by_side[signf(s.x)][1] += b.hits
				print("%s pursued by a %s from %s: straight %d hits (%d shots, locked %.1f s), defending %d (%d shots, locked %.1f s)" % [id, attacker, s, a.hits, a.shots, a.locked, b.hits, b.shots, b.locked])
			var seekers := _weapon(attacker) == Launcher.Weapon.SEEKERS
			var what := "%s pursued by a %s (%s)" % [id, attacker, "seekers" if seekers else "rockets"]
			print("%s: flying straight %d hits, defending %d" % [what, straight.hits, defended.hits])
			check(defended.hits * 2 <= straight.hits, "%s: defending takes at most half the hits of flying straight (%d vs %d)" % [what, defended.hits, straight.hits])
			for side in [1.0, -1.0]:
				check(by_side[side][1] < by_side[side][0], "%s, from the %s: defending beats flying straight (%d vs %d)" % [what, "right" if side > 0 else "left", by_side[side][1], by_side[side][0]])
			if seekers:
				check(defended.locked * 2.0 < straight.locked, "%s: denies the lock (locked %.1f s vs %.1f s)" % [what, defended.locked, straight.locked])
	# Tree drag: the sparrow (the turn fighter, at home among the trunks) both ways. A crow's ~4 m turn can't hook in
	# behind a trunk in the second between the incoming warning (25 m out) and the seeker: printed, not checked.
	for id in ["sparrow", "crow"]:
		for side in [1.0, -1.0]:
			var a: Dictionary = await _tree_drag(id, side, false)
			var b: Dictionary = await _tree_drag(id, side, true)
			var what := "%s, a seeker from behind, a trunk ahead on the %s" % [id, "right" if side > 0 else "left"]
			print("%s: straight %s, defending %s" % [what, a, b])
			if id == "sparrow":
				check(a.hits > 0, "%s: flying straight on, it's hit" % what)
				check(b.hits == 0 and b.on == "trunk", "%s: dragged past the trunk, the seeker bursts on the wood (%s)" % [what, b.on])
	finish()


func _weapon(id: String) -> int:
	return CombatStyle.of(BirdProfile.by_id(id)).weapon


## A combat-AI attacker of species `attacker` starting at `from` (the defender's frame: x right, z behind) hunts the
## defender for SECONDS. Returns {hits (the defender took), shots (the attacker fired), locked (s it held a lock)}.
func _pursued(id: String, attacker: String, from: Vector3, defend: bool) -> Dictionary:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	var pos := Vector3(0, 22, 0)
	var me: Dictionary
	if defend:
		me = d.add_ai(id, 0, pos, Vector3.FORWARD, CombatSkill.preset("pilot"), 3)
		var l: Launcher = me.launcher
		l.capacity[l.weapon] = 0   # (nothing to shoot back with: it only defends)
		l.ammo[l.weapon] = 0
	else:
		me = d.add_bird(id, 0, ScriptedInput.new(), null, pos, Vector3.FORWARD)
	var them: Dictionary = d.add_ai(attacker, 1, pos + from, Vector3.FORWARD, CombatSkill.preset("pilot"), 9)
	var b: Bird = me.bird
	var tl: Launcher = them.launcher
	var locked := 0.0
	for f in int(SECONDS * 60.0):
		await get_tree().physics_frame
		if tl.locked() and tl.lock_target == b:
			locked += 1.0 / 60.0
		if b.is_down():
			break
	var out := {"hits": int(d.world.hits.get(b, 0)), "shots": tl.shots, "locked": locked}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return out


## A seeker locked on the defender from 32 m behind, a trunk 7 m ahead and 2 m to the `side`. Returns {hits, on
## (what the seeker burst on)}.
func _tree_drag(id: String, side: float, defend: bool) -> Dictionary:
	var layout := ArenaLayout.new()
	var t := ArenaLayout.TreeData.new()
	t.id = 0
	t.base = Vector2(side * 2.0, -7.0)
	t.height = 40.0
	t.radius = 0.5
	layout.trees.append(t)
	ArenaLayout._add_to_hash(layout._tree_hash, t.base, t.id)
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var pos := Vector3(0, 20, 0)
	var me: Dictionary
	if defend:
		me = d.add_ai(id, 0, pos, Vector3.FORWARD, CombatSkill.preset("ace"), 3)
		var l: Launcher = me.launcher
		l.capacity[l.weapon] = 0
		l.ammo[l.weapon] = 0
	else:
		me = d.add_bird(id, 0, ScriptedInput.new(), null, pos, Vector3.FORWARD)
	var shooter: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 60, 300), Vector3.FORWARD)   # (out of sight: only its round matters)
	var b: Bird = me.bird
	var on := ["-"]
	d.world.burst.connect(func(_at, why, _kind, surface): on[0] = surface if why != "expired" else "air")
	for f in 3:
		await get_tree().physics_frame
	var at := b.global_position + Vector3(0.0, 1.0, 32.0)
	d.world.spawn(Projectile.launch(Projectile.Kind.SEEKER, at, b.model.velocity, b.global_position - at, shooter.bird, b))
	for f in 150:
		await get_tree().physics_frame
	var out := {"hits": int(d.world.hits.get(b, 0)), "on": on[0]}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return out
