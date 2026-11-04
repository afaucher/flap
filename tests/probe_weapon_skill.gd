extends TestCase
## Diagnostic: how well the combat AI uses each weapon, by skill. One shard per (skill, weapon): an attacker (a crow,
## then a sparrow) armed with that weapon only hunts a defending crow (pilot skill, unarmed) in the pine wood, 60 s
## from 25 m astern, in woods 1-4; a downed defender comes back on its base. Prints rounds fired, hits, downs.

const SHARDS := 6
const SKILLS := ["recruit", "pilot", "ace"]
const WEAPONS := [Launcher.Weapon.ROCKETS, Launcher.Weapon.SEEKERS]
const SECONDS := 60.0


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	for si in SKILLS.size():
		for wi in WEAPONS.size():
			if not in_shard(si * WEAPONS.size() + wi):
				continue
			for id in ["crow", "sparrow"]:
				for wood in [1, 2, 3, 4]:
					var r: Dictionary = await _hunt(SKILLS[si], WEAPONS[wi], id, wood)
					print("WEAPON %s %s %s wood %d: rounds %d, hits %d, downs %d" % [SKILLS[si], "rockets" if WEAPONS[wi] == Launcher.Weapon.ROCKETS else "seekers", id, wood, r.rounds, r.hits, r.downs])
	finish()


func _hunt(skill: String, weapon: int, id: String, wood: int) -> Dictionary:
	var layout := Pinewood.generate(wood)
	var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var b := CombatWorld.far_base(layout, a.position)
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: a, 1: b})
	await frames(1)
	var spot := _spot(layout)
	var them: Dictionary = d.add_ai("crow", 1, spot, Vector3.FORWARD, CombatSkill.preset("pilot"), 9)
	var tl: Launcher = them.launcher
	tl.capacity = {Launcher.Weapon.ROCKETS: 0, Launcher.Weapon.SEEKERS: 0}
	tl.ammo = tl.capacity.duplicate()
	var me: Dictionary = d.add_ai(id, 0, spot + Vector3(0, 1, 25), Vector3.FORWARD, CombatSkill.preset(skill), 5)
	var l: Launcher = me.launcher
	l.capacity = {Launcher.Weapon.ROCKETS: Launcher.AMMO[Launcher.Weapon.ROCKETS] if weapon == Launcher.Weapon.ROCKETS else 0, Launcher.Weapon.SEEKERS: Launcher.AMMO[Launcher.Weapon.SEEKERS] if weapon == Launcher.Weapon.SEEKERS else 0}
	l.ammo = l.capacity.duplicate()
	l.weapon = weapon
	(me.bird as Bird).rig.visible = false
	(them.bird as Bird).rig.visible = false
	var out: Dictionary = await d.run(SECONDS)
	var r := {"rounds": l.shots, "hits": int(d.world.hits.get(them.bird, 0)), "downs": int(out.birds[0].downs)}
	d.cleanup()
	d.queue_free()
	await frames(2)
	return r


## A point 14 m up among the trunks, clear of wood by 3 m, with room ahead (-z) and 25 m behind.
func _spot(layout: ArenaLayout) -> Vector3:
	for r in range(20, 70, 3):
		for k in 24:
			var ang := TAU * k / 24.0
			var p := Vector3(cos(ang) * r, 14.0, sin(ang) * r)
			if layout.clear_by(p, 3.0) and not layout.clear_by(p, 8.0) and layout.segment_clear(p + Vector3(0, 1, 25), p + Vector3(0, 0, -10), 1.5):
				return p
	return Vector3(30, 14, 30)
