extends TestCase
## Team play (docs/design/combat_ai.md, 4.8 and 8): 3 v 3 in the pine wood, pilot skill on both sides, the same mix
## (a crow, a sparrow, a hawk) each side, each team starting by its base:
##   - both teams land hits, and birds are downed (the match runs SECONDS, and on, up to MAX_SECONDS, until a bird
##     has been downed and come back: with CombatWorld.recover a salvo takes one pass, and downs come slower);
##   - a downed bird comes back on its base and flies again;
##   - the members spread their targets: two of a team rarely chase the same enemy unless it's after one of them;
##   - friendly fire stays rare (at most one hit in ten; a burst on an enemy can catch a teammate beside it).

const SECONDS := 90.0
const MAX_SECONDS := 400.0
const MIX := ["crow", "sparrow", "hawk"]


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var layout := Pinewood.generate(7)
	var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var b := CombatWorld.far_base(layout, a.position)
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: a, 1: b})
	await frames(1)
	for team in [0, 1]:
		var base: Perch = d.world.bases[team]
		var other: Perch = d.world.bases[1 - team]
		var toward := Vector3(other.position.x - base.position.x, 0.0, other.position.z - base.position.z).normalized()
		var across := Vector3(-toward.z, 0.0, toward.x)
		for i in MIX.size():
			var at := base.position + toward * 12.0 + across * (float(i) - 1.0) * 6.0 + Vector3.UP * (6.0 + 2.0 * i)
			d.add_ai(MIX[i], team, at, toward, CombatSkill.preset("pilot"), 20 + team * 10 + i)
	var shared := 0.0        # member-seconds two teammates spent on the same enemy that wasn't after either
	var fighting := 0.0      # member-seconds spent engaging or attacking
	var flew_again := {}     # Bird -> true once it flew after a respawn
	var was_down := {}
	var f := 0
	while f < int(SECONDS * 60.0) or (f < int(MAX_SECONDS * 60.0) and (was_down.is_empty() or flew_again.size() < was_down.size())):
		f += 1
		await d.step()
		for e in d.entries:
			var bird: Bird = e.bird
			if bird.is_down():
				was_down[bird] = true
			elif was_down.has(bird) and bird.state == Bird.State.FLYING:
				flew_again[bird] = true
			var br: CombatBrain = e.brain
			if not (br.intent.mode in ["engage", "attack"]) or br.intent.target == null:
				continue
			fighting += 1.0 / 60.0
			var t := br.picture.track_of(br.intent.target)
			if t != null and br.attacking(t, bird):
				continue
			if br.board.on_target(br.intent.target, bird) > 0:
				shared += 1.0 / 60.0
	var out := d.outcome()
	var hits := 0
	var landed := {0: 0, 1: 0}   # team -> hits it landed on the other (friendly fire stays nil, below)
	for e in out.birds:
		hits += int(e.hits_taken)
		landed[1 - int(e.team)] += int(e.hits_taken)
		print("  team %d %s: hits taken %d, shots %d, downed %d, bonks %d, modes %s" % [e.team, e.id, e.hits_taken, e.shots, e.downs, e.bonks, e.modes])
	var score: Dictionary = out.score
	var share := shared / maxf(fighting, 1e-3)
	print("3 v 3 for %.0f s: score %s, hits landed %s (friendly %d), downed birds back up %d of %d, two on one target %.0f%% of fighting time" % [f / 60.0, score, landed, d.world.friendly_hits, flew_again.size(), was_down.size(), share * 100.0])
	check(landed[0] >= 2 and landed[1] >= 2, "both teams land hits (%s)" % landed)
	check(int(score.get(0, 0)) + int(score.get(1, 0)) >= 1, "and down enemies (%s)" % score)
	check(was_down.size() >= 1 and flew_again.size() == was_down.size(), "every downed bird came back on its base and flew again (%d of %d)" % [flew_again.size(), was_down.size()])
	check(share < 0.35, "teammates spread their targets (two on one %.0f%% of the time)" % (share * 100.0))
	check(d.world.friendly_hits * 10 <= maxi(hits, 10), "friendly fire stays rare: at most one hit in ten (%d of %d)" % [d.world.friendly_hits, hits])
	d.cleanup()
	d.queue_free()
	await frames(2)
	finish()
