extends TestCase
## The combat AI's defence (docs/design/combat_ai.md, 4.6): rounds fired at a bird from fixed geometries -- rockets
## from the rear quarters and the beam, seekers from behind and the quarters, left and right -- once at a combat-AI
## bird and once at the same bird flying straight on. Defending must take fewer hits than flying straight, both
## sides.

const SECONDS := 2.6


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var shots := [
		# [kind, from (in the bird's frame: x right, z behind), lead the shot]
		[Projectile.Kind.ROCKET, Vector3(8.0, 1.0, 12.0), true],
		[Projectile.Kind.ROCKET, Vector3(14.0, 0.5, 2.0), true],
		[Projectile.Kind.ROCKET, Vector3(12.0, 1.0, 20.0), true],
		[Projectile.Kind.ROCKET, Vector3(24.0, 0.5, 4.0), true],
		[Projectile.Kind.SEEKER, Vector3(2.0, 1.0, 24.0), false],
		[Projectile.Kind.SEEKER, Vector3(14.0, 1.0, 18.0), false],
		[Projectile.Kind.SEEKER, Vector3(4.0, 1.0, 34.0), false],
		[Projectile.Kind.SEEKER, Vector3(26.0, 1.0, 22.0), false],
	]
	for id in ["crow", "sparrow"]:
		var straight := 0
		var defended := 0
		for s in shots:
			for side in [1.0, -1.0]:
				var from: Vector3 = s[1] * Vector3(side, 1.0, 1.0)
				var a: int = await _shot(id, s[0], from, s[2], false)
				var b: int = await _shot(id, s[0], from, s[2], true)
				straight += a
				defended += b
				print("%s, %s from %s: straight %d hits, defending %d" % [id, "rocket" if s[0] == Projectile.Kind.ROCKET else "seeker", from, a, b])
		print("%s: flying straight %d hits, defending %d (of %d rounds)" % [id, straight, defended, shots.size() * 2])
		check(defended < straight, "%s: defending takes fewer hits than flying straight on (%d vs %d)" % [id, defended, straight])
	finish()


## One round fired at the bird from `from` (its own frame); returns the hits it took.
func _shot(id: String, kind: int, from: Vector3, lead: bool, defend: bool) -> int:
	var layout := ArenaLayout.new()
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var pos := Vector3(0, 20, 0)
	var me: Dictionary
	if defend:
		me = d.add_ai(id, 0, pos, Vector3.FORWARD, CombatSkill.preset("ace"), 3)
		(me.launcher as Launcher).ammo[(me.launcher as Launcher).weapon] = 0   # (nothing to shoot back with: just defend)
	else:
		me = d.add_bird(id, 0, ScriptedInput.new(), null, pos, Vector3.FORWARD)
	var shooter: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 40, 60), Vector3.FORWARD)
	# Let the defender's brain see it's flying before the round comes (a few ticks).
	for f in 3:
		await get_tree().physics_frame
	var b: Bird = me.bird
	var at: Vector3 = b.global_position + Vector3(from.x, from.y, from.z)   # (it flies along -z: +z is behind)
	var aim: Vector3 = (FireControl.lead(at, Vector3.ZERO, b.global_position, b.model.velocity) if lead else b.global_position) - at
	var p := Projectile.launch(kind, at, Vector3.ZERO, aim, shooter.bird, b if kind == Projectile.Kind.SEEKER else null)
	d.world.spawn(p)
	for f in int(SECONDS * 60.0):
		await get_tree().physics_frame
	var hits := int(d.world.hits.get(b, 0))
	d.cleanup()
	d.queue_free()
	await frames(2)
	return hits
