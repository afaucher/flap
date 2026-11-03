extends TestCase
## Diagnostic: the duel matrix (docs/design/combat_ai.md, 8): every species against every species (MATRIX=crow,hawk,...;
## default all five), at MATRIX_SKILL=pilot (or MATRIX_SKILLS=ace,recruit: the first species at the first skill, the
## second at the second), from two starts (a head-on pass and a beam crossing), each run both ways round (sides
## swapped). MATRIX_SECONDS per duel (60). Prints each duel's hits and downs and a table of win shares: a duel goes to
## the bird that knocked out more feathers (hits, a down counting as three), a draw half each.

const STARTS := {
	"head-on": [Vector3(-30, 22, 0), Vector3.RIGHT, Vector3(30, 22, 4), Vector3.LEFT],
	"beam": [Vector3(-25, 22, 0), Vector3.RIGHT, Vector3(0, 24, -25), Vector3.BACK],
}


func _init() -> void:
	timeout_sec = 7200.0


func setup() -> void:
	var ids := Array(OS.get_environment("MATRIX").split(",", false)) if OS.get_environment("MATRIX") != "" else Array(BirdProfile.IDS)
	var secs := float(OS.get_environment("MATRIX_SECONDS")) if OS.get_environment("MATRIX_SECONDS") != "" else 60.0
	var skills := Array(OS.get_environment("MATRIX_SKILLS").split(",", false)) if OS.get_environment("MATRIX_SKILLS") != "" else []
	var one := OS.get_environment("MATRIX_SKILL") if OS.get_environment("MATRIX_SKILL") != "" else "pilot"
	if skills.size() < 2:
		skills = [one, one]
	var layout := Pinewood.generate(7)
	var a0 := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var bases := {0: a0, 1: CombatWorld.far_base(layout, a0.position)}
	var wins := {}       # "a v b" -> [a's share, duels]
	for i in ids.size():
		for j in range(i, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var share := 0.0
			var n := 0
			for start in STARTS:
				for swap in [false, true]:
					var r: Dictionary = await _duel(layout, bases, a, b, skills, STARTS[start], swap, secs, 31 + n)
					share += r.a_share
					n += 1
					print("  %s (%s) v %s (%s), %s%s: %s %d hits %d downs, %s %d hits %d downs, %.2f ms/tick" % [a, skills[0], b, skills[1], start, " swapped" if swap else "", a, r.a_hits, r.a_downs, b, r.b_hits, r.b_downs, r.ms])
			wins["%s v %s" % [a, b]] = [share / n, n]
	print("Win share of the first named (%s v %s), %d duels each:" % [skills[0], skills[1], STARTS.size() * 2])
	for k in wins:
		print("  %-18s %.0f%%" % [k, wins[k][0] * 100.0])
	finish()


## One duel; returns {a_hits (feathers... hits it landed), a_downs (it downed b), b_hits, b_downs, a_share, ms}.
func _duel(layout: ArenaLayout, bases: Dictionary, a: String, b: String, skills: Array, start: Array, swap: bool, secs: float, seed: int) -> Dictionary:
	var d := Duel.new()
	add_child(d)
	d.setup(layout, bases)
	await frames(1)
	var sa: Array = [start[2], start[3]] if swap else [start[0], start[1]]
	var sb: Array = [start[0], start[1]] if swap else [start[2], start[3]]
	var ea: Dictionary = d.add_ai(a, 0, sa[0], sa[1], CombatSkill.preset(skills[0]), seed)
	var eb: Dictionary = d.add_ai(b, 1, sb[0], sb[1], CombatSkill.preset(skills[1]), seed + 100)
	var out: Dictionary = await d.run(secs)
	var a_hits := int(d.world.hits.get(eb.bird, 0))
	var b_hits := int(d.world.hits.get(ea.bird, 0))
	var a_downs := int(d.world.score.get(0, 0))
	var b_downs := int(d.world.score.get(1, 0))
	var pa := a_hits + 3 * a_downs
	var pb := b_hits + 3 * b_downs
	var share := 0.5 if pa == pb else (1.0 if pa > pb else 0.0)
	d.cleanup()
	d.queue_free()
	await frames(2)
	return {"a_hits": a_hits, "b_hits": b_hits, "a_downs": a_downs, "b_downs": b_downs, "a_share": share, "ms": out.ms_per_tick}
