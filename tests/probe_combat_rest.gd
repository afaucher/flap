extends TestCase
## Diagnostic: test_combat_team's 3 v 3, watched -- each bird every PROBE_EVERY s (default 5): its mode, flight state,
## the perch it's on against the one it means to be on, how far from its base, the flight AI's mode and target, its
## stamina and health; at the end, the time each spent in each mode. For changes to AIPilot's landings: a base it
## can't land on shows as "rest" or "rearm" flown, not perched.
##   .\probe.ps1 -Headless probe_combat_rest [--seconds 150] [--every 5]

func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(Boot.arg_value(args, "--seconds")) if Boot.arg_value(args, "--seconds") != "" else 150.0
	var every := float(Boot.arg_value(args, "--every")) if Boot.arg_value(args, "--every") != "" else 5.0
	var layout := Pinewood.generate(7)
	var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var b := CombatWorld.far_base(layout, a.position)
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: a, 1: b})
	await frames(1)
	var mix := ["crow", "sparrow", "hawk"]
	for team in [0, 1]:
		var base: Perch = d.world.bases[team]
		var other: Perch = d.world.bases[1 - team]
		var toward := Vector3(other.position.x - base.position.x, 0.0, other.position.z - base.position.z).normalized()
		var across := Vector3(-toward.z, 0.0, toward.x)
		for i in mix.size():
			var at := base.position + toward * 12.0 + across * (float(i) - 1.0) * 6.0 + Vector3.UP * (6.0 + 2.0 * i)
			d.add_ai(mix[i], team, at, toward, CombatSkill.preset("pilot"), 20 + team * 10 + i)
	print("COMBAT bases: 0 perch %d at %s, 1 perch %d at %s" % [a.id, str(a.position.round()), b.id, str(b.position.round())])
	for f in int(seconds * 60.0):
		await d.step()
		if f % int(every * 60.0) != 0:
			continue
		for e in d.entries:
			var bird: Bird = e.bird
			var br: CombatBrain = e.brain
			var pl: AIPilot = br.pilot
			var base: Perch = d.world.bases[int(e.team)]
			print("COMBAT t=%5.0f %d %-7s %-7s st=%d on=%s want=%s base=%4.0fm ai=%d tgt=%s avoid=%.1f stam=%.2f hp=%.2f bonks=%d" % [f / 60.0, e.team,
				bird.profile.id, br.intent.mode, bird.state, str(bird.perch.id) if bird.perch != null and bird.state == Bird.State.PERCHED else "-",
				str(br.intent.perch.id) if br.intent.perch != null else "-", bird.global_position.distance_to(base.position), pl.mode,
				str(pl.target.id) if pl.target != null else "-", pl.avoiding, bird.model.energy.stamina, bird.health(), bird.bonks])
	for e in d.outcome().birds:
		print("COMBAT team %d %s: downed %d, bonks %d, modes %s" % [e.team, e.id, e.downs, e.bonks, e.modes])
	finish()
