extends TestCase
## The enemy's weapon mix by difficulty (CombatSkill.weapons): the combat AI is far better with seekers than rockets
## (probe_weapon_skill), so --
##   - a side carries seekers in its skill's seeker_share: a recruit side fewest, an ace side most, never fewer at a
##     harder skill, for every mix of species;
##   - seekers go first to the birds built for them (crow, owl), then to the sparrow;
##   - the energy fighters (hawk, falcon) carry rockets at every skill: boom and zoom is a rocket pass.

const MIXES := [["falcon", "owl", "crow"], ["crow", "sparrow", "owl"], ["sparrow", "hawk", "crow"], ["hawk", "falcon", "sparrow"], ["sparrow", "sparrow", "sparrow"]]


func setup() -> void:
	var S := Launcher.Weapon.SEEKERS
	for ids in MIXES:
		var counts := []
		for skill in ["recruit", "pilot", "ace"]:
			var kit: Array = CombatSkill.preset(skill).weapons(ids)
			counts.append(kit.count(S))
			for i in ids.size():
				if CombatStyle.of(BirdProfile.by_id(ids[i])).prefers_height:
					eq(kit[i], Launcher.Weapon.ROCKETS, "%s at %s: the %s carries rockets" % [ids, skill, ids[i]])
			# (seekers to the birds built for them before the sparrow)
			for i in ids.size():
				if kit[i] == S and ids[i] == "sparrow":
					for j in ids.size():
						if ids[j] in ["crow", "owl"]:
							eq(kit[j], S, "%s at %s: the %s has seekers before the sparrow does" % [ids, skill, ids[j]])
		print("%s: seekers at recruit / pilot / ace: %s" % [ids, counts])
		check(counts[0] <= counts[1] and counts[1] <= counts[2], "%s: never fewer seekers at a harder skill (%s)" % [ids, counts])
	eq(CombatSkill.preset("recruit").weapons(["crow", "sparrow", "owl"]).count(S), 1, "crow, sparrow, owl at recruit: one carries seekers")
	eq(CombatSkill.preset("pilot").weapons(["crow", "sparrow", "owl"]).count(S), 2, "... at pilot: two")
	eq(CombatSkill.preset("ace").weapons(["crow", "sparrow", "owl"]).count(S), 3, "... at ace: all three")
	eq(CombatSkill.preset("pilot").weapons(["falcon", "owl", "crow"]), [Launcher.Weapon.ROCKETS, S, S], "the range's default enemy at pilot: the mix it has always flown")
	finish()
