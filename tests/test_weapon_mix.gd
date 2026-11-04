extends TestCase
## The enemy's weapon mix by difficulty (CombatSkill.weapons): the combat AI is far better with seekers than rockets
## (probe_weapon_skill), so --
##   - a side carries seekers in its skill's seeker_share: a recruit side fewest, an ace side most, never fewer at a
##     harder skill, for every mix of species;
##   - seekers go first to the birds built for them (crow, owl), then to the sparrow;
##   - the gun (the AI's weakest weapon against a bird that breaks) only on an easy side: gun_share of a recruit side,
##     none at pilot or ace, never more at a harder skill; to the rocket birds before the seeker birds;
##   - the energy fighters (hawk, falcon) carry rockets at every skill: boom and zoom is a rocket pass.

const MIXES := [["falcon", "owl", "crow"], ["crow", "sparrow", "owl"], ["sparrow", "hawk", "crow"], ["hawk", "falcon", "sparrow"], ["sparrow", "sparrow", "sparrow"]]


func setup() -> void:
	var S := Launcher.Weapon.SEEKERS
	for ids in MIXES:
		var counts := []
		var guns := []
		for skill in ["recruit", "pilot", "ace"]:
			var kit: Array = CombatSkill.preset(skill).weapons(ids)
			counts.append(kit.count(S))
			guns.append(kit.count(Launcher.Weapon.GUN))
			for i in ids.size():
				if CombatStyle.of(BirdProfile.by_id(ids[i])).prefers_height:
					eq(kit[i], Launcher.Weapon.ROCKETS, "%s at %s: the %s carries rockets" % [ids, skill, ids[i]])
			# (seekers to the birds built for them before the sparrow)
			for i in ids.size():
				if kit[i] == S and ids[i] == "sparrow":
					for j in ids.size():
						if ids[j] in ["crow", "owl"]:
							eq(kit[j], S, "%s at %s: the %s has seekers before the sparrow does" % [ids, skill, ids[j]])
		print("%s: seekers at recruit / pilot / ace: %s, guns %s" % [ids, counts, guns])
		check(guns[0] >= guns[1] and guns[1] >= guns[2] and guns[2] == 0, "%s: guns only on an easier side, none at ace (%s)" % [ids, guns])
		check(counts[0] <= counts[1] and counts[1] <= counts[2], "%s: never fewer seekers at a harder skill (%s)" % [ids, counts])
	eq(CombatSkill.preset("recruit").weapons(["crow", "sparrow", "owl"]).count(S), 1, "crow, sparrow, owl at recruit: one carries seekers")
	eq(CombatSkill.preset("pilot").weapons(["crow", "sparrow", "owl"]).count(S), 2, "... at pilot: two")
	eq(CombatSkill.preset("ace").weapons(["crow", "sparrow", "owl"]).count(S), 3, "... at ace: all three")
	eq(CombatSkill.preset("pilot").weapons(["falcon", "owl", "crow"]), [Launcher.Weapon.ROCKETS, S, S], "the range's default enemy at pilot: the mix it has always flown")
	eq(CombatSkill.preset("recruit").weapons(["falcon", "owl", "crow"]), [Launcher.Weapon.ROCKETS, S, Launcher.Weapon.GUN], "... at recruit: the owl seekers, the crow the gun")
	eq(CombatSkill.preset("recruit").weapons(["crow", "sparrow", "owl"]), [S, Launcher.Weapon.GUN, Launcher.Weapon.ROCKETS], "crow, sparrow, owl at recruit: the gun to the sparrow (a rocket bird) first")
	for ids in MIXES:
		eq(CombatSkill.preset("pilot").weapons(ids).count(Launcher.Weapon.GUN), 0, "%s at pilot: no gun" % [ids])
	finish()
