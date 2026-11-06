extends TestCase
## Team play (docs/design/combat_ai.md, 4.8 and 8): 3 v 3 in the pine wood, pilot skill on both sides, the same mix
## (a crow, a sparrow, a hawk) each side, each team starting by its base. Two matches of SECONDS (one a shard, the AI
## birds seeded MATCHES), each:
##   - both teams land hits;
##   - the members spread their targets: two of a team rarely chase the same enemy unless it's after one of them;
##   - friendly fire stays rare (at most one hit in ten; a burst on an enemy can catch a teammate beside it).
## And (shard 2) a bird downed in the fight -- its feathers shot out, hit by hit -- comes back on its base and flies
## again. (A match is deterministic but chaotic: a change anywhere in the flying runs a different one, and whether
## anyone is downed in a given 90 s is luck -- six matches of 150 s downed 0-3 -- so downing isn't judged on one; it
## ran on until a bird was, up to 400 s, past the runner's 120 s.)

const SHARDS := 3
const SECONDS := 90.0
const MATCHES := [20, 40]
const MIX := ["crow", "sparrow", "hawk"]


func _init() -> void:
	timeout_sec = 240.0


func setup() -> void:
	for k in MATCHES.size():
		if in_shard(k):
			await _match(MATCHES[k])
	if in_shard(2):
		await _downed_comes_back()
	finish()


func _teams(ai_seed: int) -> Duel:
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
			d.add_ai(MIX[i], team, at, toward, CombatSkill.preset("pilot"), ai_seed + team * 10 + i)
	return d


func _match(ai_seed: int) -> void:
	var d: Duel = await _teams(ai_seed)
	var shared := 0.0        # member-seconds two teammates spent on the same enemy that wasn't after either
	var fighting := 0.0      # member-seconds spent engaging or attacking
	for f in int(SECONDS * 60.0):
		await d.step()
		for e in d.entries:
			var bird: Bird = e.bird
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
	var share := shared / maxf(fighting, 1e-3)
	print("3 v 3 (AI seed %d) for %.0f s: score %s, hits landed %s (friendly %d), two on one target %.0f%% of fighting time" % [ai_seed, SECONDS, out.score, landed, d.world.friendly_hits, share * 100.0])
	check(landed[0] >= 1 and landed[1] >= 1, "seed %d: both teams land hits (%s)" % [ai_seed, landed])
	check(share < 0.35, "seed %d: teammates spread their targets (two on one %.0f%% of the time)" % [ai_seed, share * 100.0])
	check(d.world.friendly_hits * 10 <= maxi(hits, 10), "seed %d: friendly fire stays rare: at most one hit in ten (%d of %d)" % [ai_seed, d.world.friendly_hits, hits])
	d.cleanup()
	d.queue_free()
	await frames(2)


## 20 s into a match, team 0's crow is shot down (bursts on it a little over the recovery window apart, as a salvo
## a pass could give, until it's down): it flutters down, comes back on its base mended and rearmed, and flies again.
func _downed_comes_back() -> void:
	var d: Duel = await _teams(MATCHES[0])
	for f in 20 * 60:
		await d.step()
	var me: Dictionary = d.entries[0]
	var b: Bird = me.bird
	var shooter: Bird = d.entries[3].bird
	var n := 0
	while not b.is_down() and n < 20:
		d.world.hit(b, b.global_position + Vector3.UP * 0.2, 1.0, shooter)
		n += 1
		for f in int((CombatWorld.recover + 0.1) * 60.0):
			await d.step()
	check(b.is_down(), "shot again and again, the crow goes down (%d hits)" % n)
	var back := false
	var flew := false
	for f in 60 * 40:
		await d.step()
		if not b.is_down() and b.state == Bird.State.PERCHED and b.perch == d.world.bases[0]:
			back = true
		if back and b.state == Bird.State.FLYING:
			flew = true
			break
	print("downed after %d hits; back on its base %s, flew again %s; health %.2f" % [n, back, flew, b.health()])
	check(back, "the downed crow comes back on its base")
	check(flew, "and flies again")
	d.cleanup()
	d.queue_free()
	await frames(2)
