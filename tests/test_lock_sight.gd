extends TestCase
## A seeker lock needs a clear line of sight (Launcher.sees): with the birds held still and the launcher's lock stepped
## tick by tick --
##   - a target dead ahead with a trunk 3 m to one side of the line (left and right): it locks in LOCK_TIME;
##   - with the trunk on the line: no lock builds at all;
##   - locked, the target slips behind a trunk (to the left and to the right): a cut shorter than LOS_GRACE costs
##     nothing, and kept cut the lock drains away.


func setup() -> void:
	for side in [1.0, -1.0]:
		await _clear_beside(side)
	await _blocked_on_line()
	for side in [1.0, -1.0]:
		await _slips_behind(side)
	finish()


## Two birds at 20 m up, the shooter at the origin heading -z, the target 20 m ahead; one trunk at (x, -10).
func _scene(trunk_x: float) -> Dictionary:
	var layout := ArenaLayout.new()
	var t := ArenaLayout.TreeData.new()
	t.id = 0
	t.base = Vector2(trunk_x, -10.0)
	t.height = 40.0
	t.radius = 0.5
	layout.trees.append(t)
	ArenaLayout._add_to_hash(layout._tree_hash, t.base, t.id)
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var me: Dictionary = d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 20, 0), Vector3.FORWARD)
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 20, -20), Vector3.FORWARD)
	var l: Launcher = me.launcher
	l.weapon = Launcher.Weapon.SEEKERS
	await frames(2)   # (the world steps the launcher once: it knows its world)
	l.lock = 0.0
	l.lock_target = null
	_hold(me.bird, Vector3(0, 20, 0))
	_hold(them.bird, Vector3(0, 20, -20))
	return {"d": d, "l": l, "target": them.bird}


## Put a bird at `at`, heading -z, and keep it there (the launcher is stepped by hand, no physics in between).
func _hold(b: Bird, at: Vector3) -> void:
	b.fly_from(at, Vector3.FORWARD, b.profile.v_best)


func _step(l: Launcher, ticks: int) -> void:
	for i in ticks:
		l._update_lock(1.0 / 60.0)


func _clear_beside(side: float) -> void:
	var s: Dictionary = await _scene(side * 3.0)
	var l: Launcher = s.l
	_step(l, int(Launcher.LOCK_TIME * 60.0) + 2)
	check(l.locked() and l.lock_target == s.target, "a trunk 3 m to the %s of the line: it locks in %.1f s (lock %.2f)" % ["right" if side > 0 else "left", Launcher.LOCK_TIME, l.lock])
	_drop(s.d)
	await frames(2)


func _blocked_on_line() -> void:
	var s: Dictionary = await _scene(0.0)
	var l: Launcher = s.l
	_step(l, 120)
	check(not l.locked() and l.lock == 0.0, "a trunk on the line: no lock builds (lock %.2f after 2 s)" % l.lock)
	_drop(s.d)
	await frames(2)


func _slips_behind(side: float) -> void:
	var s: Dictionary = await _scene(side * 3.0)
	var l: Launcher = s.l
	_step(l, int(Launcher.LOCK_TIME * 60.0) + 2)
	check(l.locked(), "locked first (trunk to the %s)" % ("right" if side > 0 else "left"))
	_hold(s.target, Vector3(side * 6.0, 20, -20))   # (the line now runs through the trunk; still inside LOCK_KEEP)
	check(not l.sees(s.target), "the target behind the trunk is out of sight")
	_step(l, int(Launcher.LOS_GRACE * 60.0) - 5)
	check(l.locked(), "a cut shorter than %.2f s costs nothing (lock %.2f)" % [Launcher.LOS_GRACE, l.lock])
	_step(l, 60)
	check(not l.locked() and l.lock < 0.5, "kept behind the trunk, the lock drains away (lock %.2f after 1 s more)" % l.lock)
	_drop(s.d)
	await frames(2)


func _drop(d: Duel) -> void:
	d.cleanup()
	d.queue_free()
