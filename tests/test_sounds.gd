extends TestCase
## The game's sound (docs/design/audio_plan.md "As built"): the baked files are today's recipes and every cue has its
## takes; the recipes do what the plan asks of them (measured on the rendered samples: your lock's beeps and someone
## locking you are far apart in pitch; loops wrap without a jump; a burst hits at once; a rocket launch is over in
## 0.2 s, so four a second stay apart); the owl's wingbeat is next to silent beside the crow's; and GameAudio asks for
## the right cue at the right moment: launches with their motors, each kind of burst, hits with the species' alarm,
## the gun's shot (its own, no motor), its strikes on wood and the ground, a bullet zipping by when it passes you
## close (not your own, not far off), the lock's beeps rising and quickening then the locked tone (and nothing without a target), what the HUD warns you
## of (someone locking you; a seeker closing on you, the warble quickening), the dry click, the weapon switch, a clink per missing round on
## the base then the chime (and none off the base), the talons catching on a landing (not on a teleport), bonks
## louder the harder they hit, a glance's claw scrape (a bright scrape, louder the harder; no thud, no cry), and a
## wing strike's feathers on the bark (louder the more speed it cost; no cry).


class _Press:
	var fire := false
	var next := false
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		var c := CombatInput.new(fire, false, next)
		fire = false
		next = false
		return c


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	_baked()
	_recipes()
	_wingbeats()
	await _game_audio()
	finish()


func _baked() -> void:
	var stamp := FileAccess.get_file_as_string(SoundRecipes.STAMP_PATH).strip_edges()
	eq(stamp, SoundRecipes.source_md5(), "the sounds are baked from today's recipes (re-run tools/bake_sounds.gd)")
	var missing := []
	for name: String in SoundRecipes.SOUNDS:
		for f: String in SoundRecipes.files_of(name):
			if not ResourceLoader.exists(Sfx.DIR + f + ".wav"):
				missing.append(f)
	eq(missing, [], "every take is baked")
	var unknown := []
	for c: String in Sfx.CUES:
		if not SoundRecipes.SOUNDS.has(Sfx.sound_of(c)):
			unknown.append(c)
	eq(unknown, [], "every cue plays a baked sound")
	for name: String in SoundRecipes.SOUNDS:
		check(Sfx.CUES.has(name), "%s has a cue" % name)
	# A 3D one-shot is baked with its lead-in (SoundRecipes.LEAD_3D: an AudioStreamPlayer3D mixes at nothing until the
	# tick after it starts); a flat one and a loop without.
	var lead := SoundDsp.n_of(SoundRecipes.LEAD_3D)
	var unled := []
	var led_flat := []
	for name: String in SoundRecipes.SOUNDS:
		var f: String = SoundRecipes.files_of(name)[0]
		var w := SoundDsp.load_wav(Sfx.DIR + f + ".wav")
		var quiet := SoundDsp.peak(SoundDsp.cut(w, 0.0, SoundRecipes.LEAD_3D * 0.9)) < 1e-3
		if SoundRecipes.positional(name) and not SoundRecipes.is_loop(name):
			if not quiet or w.size() < SoundRecipes.render(name).size() + lead - 2:
				unled.append(name)
		elif quiet and SoundRecipes.render(name).size() == w.size() - lead:
			led_flat.append(name)
	eq(unled, [], "every 3D one-shot is baked with its lead-in")
	eq(led_flat, [], "no flat sound or loop is delayed")
	check(SoundRecipes.positional("gun_shot") and not SoundRecipes.positional("lock_beep"), "(the gun shot is 3D, the lock beep flat)")


## Zero crossings a second over the loud part: the pitch of a tone.
func _crossings(s: PackedFloat32Array) -> float:
	var th := SoundDsp.peak(s) * 0.3
	var a := 0
	while a < s.size() and absf(s[a]) < th:
		a += 1
	var b := s.size() - 1
	while b > a and absf(s[b]) < th:
		b -= 1
	var n := 0
	for i in range(a + 1, b):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n * 0.5 / maxf(float(b - a) / SoundDsp.RATE, 1e-4)


func _recipes() -> void:
	var beep := _crossings(SoundRecipes.render("lock_beep"))
	var warn := _crossings(SoundRecipes.render("locked_warning"))
	check(beep > warn * 2.0, "your lock beeps (%d Hz) sit far above the warning that you're locked (%d Hz)" % [beep, warn])
	for name: String in ["lock_tone", "rocket_motor", "seeker_motor", "forest_wind", "insects"]:
		var s := SoundRecipes.render(name)
		var step := 0.0
		for i in range(1, s.size()):
			step = maxf(step, absf(s[i] - s[i - 1]))
		var wrap := absf(s[0] - s[s.size() - 1])
		check(wrap <= step * 1.01, "%s wraps without a jump (%.4f, steps up to %.4f)" % [name, wrap, step])
		var head := SoundDsp.rms(s, 0.0, 0.05)
		var tail := SoundDsp.rms(s, s.size() / float(SoundDsp.RATE) - 0.05)
		check(absf(linear_to_db(head) - linear_to_db(tail)) < 6.0, "%s is as loud across the wrap" % name)
	for take in 4:
		var b := SoundRecipes.render("burst", take)
		check(SoundDsp.rms(b, 0.0, 0.03) > SoundDsp.rms(b, 0.1, 0.4) * 3.0, "burst %d hits at once and dies away" % take)
	# The gun: ten shots a second stay ten -- each over well before the next 100 ms on, its crack at once -- with the
	# bolt's clatter after the crack (high clicks 15-55 ms on, then quiet); a bullet on wood brighter than one in the
	# ground; a bullet going by falls in pitch, over in 0.16 s.
	for take in SoundRecipes.files_of("gun_shot").size():
		var g := SoundRecipes.render("gun_shot", take)
		check(g.size() <= SoundDsp.n_of(0.1) and SoundDsp.rms(g, 0.06) < SoundDsp.rms(g, 0.0, 0.02) * 0.05,
				"gun shot %d is over before the next, ten a second (%.0f ms long)" % [take + 1, g.size() * 1000.0 / SoundDsp.RATE])
		check(SoundDsp.onset(g, 0.0, 12.0) < 0.002, "gun shot %d cracks at once" % (take + 1))
		var hi := SoundDsp.highpass(g, 3000.0, 2)
		var clatter := SoundDsp.rms(hi, 0.015, 0.055)
		check(clatter > SoundDsp.rms(hi, 0.06, 0.085) * 4.0 and clatter > SoundDsp.rms(g, 0.0, 0.01) * 0.04,
				"gun shot %d: the bolt clatters after the crack (%.4f, the crack %.4f)" % [take + 1, clatter, SoundDsp.rms(g, 0.0, 0.01)])
	var bright := func(name: String) -> float:
		var t := 0.0
		for take in SoundRecipes.files_of(name).size():
			var x := SoundRecipes.render(name, take)
			t += SoundDsp.rms(SoundDsp.highpass(x, 2000.0, 2)) / maxf(SoundDsp.rms(x), 1e-6)
		return t / SoundRecipes.files_of(name).size()
	var wood: float = bright.call("gun_strike_wood")
	var ground: float = bright.call("gun_strike_ground")
	check(wood > ground * 1.8, "a bullet on wood is brighter than one in the ground (%.2f, %.2f of it above 2 kHz)" % [wood, ground])
	for name: String in ["gun_strike_wood", "gun_strike_ground"]:
		var x := SoundRecipes.render(name)
		check(SoundDsp.rms(x, 0.0, 0.03) > SoundDsp.rms(x, 0.08) * 4.0, "%s hits at once and dies away" % name)
	for take in SoundRecipes.files_of("bullet_zip").size():
		var z := SoundRecipes.render("bullet_zip", take)
		var sec := z.size() / float(SoundDsp.RATE)
		var f0 := _crossings(SoundDsp.cut(z, 0.0, sec * 0.3))
		var f1 := _crossings(SoundDsp.cut(z, sec * 0.7))
		check(f1 < f0 * 0.85 and z.size() <= SoundDsp.n_of(0.16), "bullet zip %d falls in pitch as it passes (%d -> %d Hz), short" % [take + 1, f0, f1])
	var r := SoundRecipes.render("rocket_launch")
	check(SoundDsp.rms(r, 0.2) < SoundDsp.rms(r, 0.0, 0.2) * 0.15, "a rocket launch is over in 0.2 s")
	for take in 3:
		var low := SoundDsp.lowpass(SoundRecipes.render("bonk", take), 300.0, 2)
		var ring := SoundDsp.rms(low, 0.08, 0.25) / maxf(SoundDsp.rms(low, 0.0, 0.03), 1e-6)
		check(ring < 0.04, "bonk %d is a thud with no low ring after it (a held tone sounds like a honk): %.3f" % [take + 1, ring])
	var brightness := func(x: PackedFloat32Array) -> float:   # (over 2 kHz against under 300 Hz)
		return SoundDsp.rms(SoundDsp.highpass(x, 2000.0, 2)) / maxf(SoundDsp.rms(SoundDsp.lowpass(x, 300.0, 2)), 1e-6)
	var thud: float = brightness.call(SoundRecipes.render("bonk", 0))
	for take in SoundRecipes.files_of("claw_scrape").size():
		var c := SoundRecipes.render("claw_scrape", take)
		var sec := c.size() / float(SoundDsp.RATE)
		var k: float = brightness.call(c)
		check(sec > 0.12 and sec < 0.5 and k > 1.2 and k > thud * 4.0, "claw scrape %d is a scrape: %.2f s, bright (%.2f over 2 kHz to under 300 Hz; a bonk's thud %.2f)" % [take + 1, sec, k, thud])
	var lengths := {}
	for take in SoundRecipes.files_of("perch_catch").size():
		var c := SoundRecipes.render("perch_catch", take)
		lengths[c.size()] = true
		check(SoundDsp.onset(c, 0.0, 12.0) < 0.03, "perch catch %d starts on its scratch" % (take + 1))
		check(SoundDsp.rms(c, c.size() / float(SoundDsp.RATE) - 0.02) < SoundDsp.rms(c) * 0.2, "perch catch %d ends quiet" % (take + 1))
	check(lengths.size() >= 4, "the perch catch takes are different scratches of the recording")
	for sp: String in SoundRecipes.CALLS:
		for kind in ["call", "alarm"]:
			var name := "%s_%s" % [kind, sp]
			for take in SoundRecipes.files_of(name).size():
				var c := SoundRecipes.render(name, take)
				check(SoundDsp.onset(c, 0.0, 12.0) < 0.06, "%s %d starts on the call" % [name, take + 1])
				check(SoundDsp.rms(c, c.size() / float(SoundDsp.RATE) - 0.02) < SoundDsp.rms(c) * 0.25, "%s %d ends quiet" % [name, take + 1])
	var owl := SoundRecipes.render("call_owl")
	var hawk := SoundRecipes.render("call_hawk")
	check(owl.size() > SoundDsp.n_of(0.5) and hawk.size() > SoundDsp.n_of(0.5), "the owl's screech and the hawk's scream are long calls")


## A wingbeat's thump over the wind, for one species.
func _beat(species: String) -> float:
	var a := FlightAudio.new()
	var t := {"state": Bird.State.FLYING, "speed": 8.0, "v_best": 8.0, "v_stall": 5.0, "grab_speed": 6.0,
		"stalled": false, "flap_count": 1, "species": species}
	a.set_state(t)
	a.render(4096)
	var quiet := _energy(a.render(1024))
	t.flap_count = 2
	a.set_state(t)
	var beat := _energy(a.render(1024))
	a.free()
	return maxf(beat - quiet, 0.0)


func _energy(b: PackedVector2Array) -> float:
	var e := 0.0
	for v in b:
		e += v.x * v.x
	return e / b.size()


func _wingbeats() -> void:
	var crow := _beat("crow")
	var owl := _beat("owl")
	var sparrow := _beat("sparrow")
	check(crow > 0.0 and sparrow > 0.0, "a crow's and a sparrow's wingbeats are heard")
	check(owl < crow * 0.05, "an owl's wingbeat is next to silent (%.6f vs a crow's %.6f)" % [owl, crow])


func _events_of(ga: GameAudio, name: String, since: int) -> Array:
	return ga.events.slice(since).filter(func(e: Dictionary) -> bool: return e.cue == name)


func _game_audio() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	add_child(world)
	var ga := GameAudio.new()
	ga.forest = false
	add_child(ga)
	ga.watch_world(world)
	var a := Bird.new()
	var b := Bird.new()
	for x in [a, b]:
		add_child(x)
		x.setup(BirdProfile.crow(), layout, null)
		ga.watch(x)
	a.fly_from(Vector3(0, 40, 0), Vector3(0, 0, 1), 9.0)
	b.fly_from(Vector3(0, 40, 20), Vector3(0, 0, 1), 9.0)
	var la := world.add_bird(a, null, 0)
	world.add_bird(b, null, 1)
	world.player = la
	ga.player = a
	var ctl := _Press.new()
	la.controller = ctl
	await frames(2)

	# Bursts, by what they hit.
	var n := ga.events.size()
	world.burst.emit(Vector3(3, 0.1, 3), "impact", Projectile.Kind.ROCKET, "ground")
	world.burst.emit(Vector3(3, 6.0, 3), "impact", Projectile.Kind.ROCKET, "trunk")
	world.burst.emit(Vector3(3, 30, 3), "fuse", Projectile.Kind.SEEKER, "bird")
	world.burst.emit(Vector3(3, 30, 3), "expired", Projectile.Kind.ROCKET, "air")
	eq(ga.events.slice(n).map(func(e: Dictionary) -> String: return e.cue), ["burst_ground", "burst_wood", "burst", "fizzle"],
			"a burst sounds like what it hit: the ground, a trunk, a bird, or nothing")
	# The gun's bullets: on the ground and on a trunk, the gun's own strikes (not a rocket's burst); on a bird, only the
	# hit's feathers (struck).
	n = ga.events.size()
	world.burst.emit(Vector3(3, 0.1, 3), "impact", Projectile.Kind.GUN, "ground")
	world.burst.emit(Vector3(3, 6.0, 3), "impact", Projectile.Kind.GUN, "trunk")
	world.burst.emit(Vector3(3, 30, 3), "hit", Projectile.Kind.GUN, "bird")
	eq(ga.events.slice(n).map(func(e: Dictionary) -> String: return e.cue), ["gun_strike_ground", "gun_strike_wood"],
			"a bullet strikes the ground or a trunk with the gun's own sounds; on a bird, nothing of its own")
	# Shots: each its own gun shot, no rocket launch, no motor. b's bullet passing 0.8 m off you zips by once, where it
	# passed (beside you); one 5 m off doesn't, nor does your own going by as close.
	n = ga.events.size()
	var me := a.global_position
	world.spawn(Projectile.launch(Projectile.Kind.GUN, me + Vector3(0.8, 0, -12), Vector3.ZERO, Vector3(0, 0, 1), b))
	world.spawn(Projectile.launch(Projectile.Kind.GUN, me + Vector3(5.0, 0, -12), Vector3.ZERO, Vector3(0, 0, 1), b))
	world.spawn(Projectile.launch(Projectile.Kind.GUN, me + Vector3(-0.8, 0, -12), Vector3.ZERO, Vector3(0, 0, 1), a))
	await frames(30)
	eq(_events_of(ga, "gun_shot", n).size(), 3, "a gun shot for each bullet fired")
	eq(_events_of(ga, "rocket_launch", n).size() + _events_of(ga, "rocket_motor", n).size(), 0, "the gun has no rocket's launch or motor")
	var zips := _events_of(ga, "bullet_zip", n)
	eq(zips.size(), 1, "a bullet passing close zips by, once; one far off or your own, nothing")
	if zips.size() == 1:
		var zp: Vector3 = zips[0].pos
		check(zp.x > me.x + 0.5 and zp.x < me.x + 1.1, "the zip is where it passed (%.2f m to your side)" % (zp.x - me.x))
	# A hit: feathers and the species' alarm.
	n = ga.events.size()
	world.hit(b, b.global_position + Vector3(0.5, 0, 0), 1.0, a)
	check(_events_of(ga, "feather_puff", n).size() == 1 and _events_of(ga, "alarm_crow", n).size() == 1,
			"a hit puffs feathers and the crow cries")

	# The lock: beeps rising and quickening as it builds, then the locked tone and no more beeps.
	n = ga.events.size()
	la.weapon = Launcher.Weapon.SEEKERS
	await frames(int(Launcher.LOCK_TIME * 60) + 20)
	check(la.locked(), "(locked)")
	var beeps := _events_of(ga, "lock_beep", n)
	check(beeps.size() >= 4, "%d beeps while the lock builds" % beeps.size())
	if beeps.size() >= 4:
		check(float(beeps[-1].pitch) > float(beeps[0].pitch) + 0.2, "the beeps rise as the lock grows")
		var gap0: float = beeps[1].t - beeps[0].t
		var gap1: float = beeps[-1].t - beeps[-2].t
		check(gap1 < gap0 * 0.6, "and quicken (%.2f s -> %.2f s apart)" % [gap0, gap1])
	var tones := _events_of(ga, "lock_tone", n)
	eq(tones.size(), 1, "locked: the steady tone, once")
	if tones.size() == 1 and not beeps.is_empty():
		check(float(beeps[-1].t) <= float(tones[0].t), "no beeps once locked")
	# Nothing to lock (the target gone behind you): no beeps.
	b.fly_from(a.global_position - Vector3(0, 0, 15), Vector3(0, 0, 1), 9.0)
	await frames(10)
	n = ga.events.size()
	await frames(60)
	eq(_events_of(ga, "lock_beep", n).size() + _events_of(ga, "lock_tone", n).size(), 0, "no target, no lock sounds")

	# Someone locking you: b behind you, a seeker on its rack. And a seeker coming for you.
	var lb: Launcher = world.launchers[1]
	n = ga.events.size()
	lb.weapon = Launcher.Weapon.SEEKERS
	await frames(int(Launcher.LOCK_TIME * 60) + 40)
	check(lb.lock_target == a, "(b locks you)")
	check(_events_of(ga, "locked_warning", n).size() >= 2, "being locked pulses a warning")
	n = ga.events.size()
	world.spawn(Projectile.launch(Projectile.Kind.SEEKER, a.global_position - Vector3(0, 0, 28), Vector3.ZERO, Vector3(0, 0, 1), b, a))
	await frames(60)
	check(_events_of(ga, "seeker_launch", n).size() == 1 and _events_of(ga, "seeker_motor", n).size() == 1,
			"a seeker launches with its motor")
	var warbles := _events_of(ga, "incoming", n)
	check(warbles.size() >= 3, "a seeker coming for you warbles (%d)" % warbles.size())
	if warbles.size() >= 3:
		check(warbles[-1].t - warbles[-2].t < warbles[1].t - warbles[0].t, "faster as it closes")
	lb.weapon = Launcher.Weapon.ROCKETS
	await frames(int(Projectile.SPEC[Projectile.Kind.SEEKER].life * 60) + 5)

	# The dry click and the weapon switch.
	n = ga.events.size()
	la.weapon = Launcher.Weapon.ROCKETS
	la.ammo[Launcher.Weapon.ROCKETS] = 0
	await frames(2)
	ctl.fire = true
	await frames(2)
	eq(_events_of(ga, "empty_click", n).size(), 1, "fire with nothing loaded: one dry click")
	n = ga.events.size()
	ctl.next = true
	await frames(2)
	eq(_events_of(ga, "weapon_switch", n).size(), 1, "switching weapons clacks")

	# The base: a clink a missing round, then the chime; another perch, nothing.
	for on_base in [false, true]:
		a.fly_from(Vector3(0, 40, 0), Vector3(0, 0, 1), 9.0)
		await frames(2)
		la.rearm_perch = layout.perches[1].id
		la.ammo[Launcher.Weapon.ROCKETS] = 2
		la.ammo[Launcher.Weapon.SEEKERS] = int(la.capacity[Launcher.Weapon.SEEKERS])
		n = ga.events.size()
		a.perch_at(layout.perches[1] if on_base else layout.perches[0])
		await frames(int(Launcher.RESTOCK_TIME * 60) + 10)
		var ticks := _events_of(ga, "rearm_tick", n).size()
		var chimes := _events_of(ga, "rearmed", n).size()
		if on_base:
			eq(ticks, int(la.capacity[Launcher.Weapon.ROCKETS]) - 2, "on the base: a clink for each missing round")
			eq(chimes, 1, "then the chime")
		else:
			check(ticks == 0 and chimes == 0, "off the base: no clinks, no chime")
		eq(_events_of(ga, "perch_catch", n).size(), 0, "set down on a perch (a start, a respawn): no catch")
	n = ga.events.size()
	a.perched.emit(layout.perches[1])   # (as Bird._land does when a landing ends)
	eq(_events_of(ga, "perch_catch", n).size(), 1, "landing on a perch: the talons catch")

	# Bonks: louder the harder; a hard one makes the bird cry.
	n = ga.events.size()
	b.bonked.emit(Vector3.UP, 2.0)
	await frames(int(GameAudio.CALL_GAP * 60) + 2)
	b.bonked.emit(Vector3.UP, 9.0)
	var bonks := _events_of(ga, "bonk", n)
	eq(bonks.size(), 2, "two bonks")
	if bonks.size() == 2:
		check(float(bonks[1].db) > float(bonks[0].db) + 6.0, "a hard bonk is louder than a soft one")
	eq(_events_of(ga, "alarm_crow", n).size(), 1, "only the hard one makes the crow cry")

	# A glance: the claws scrape on the wood, louder the harder it brushed; no thud, no cry.
	await frames(int(GameAudio.CALL_GAP * 60) + 2)
	n = ga.events.size()
	b.glanced.emit(Vector3.RIGHT, 0.5, 5.0)
	await frames(10)
	b.glanced.emit(Vector3.RIGHT, 2.8, 9.0)
	var scrapes := _events_of(ga, "claw_scrape", n)
	eq(scrapes.size(), 2, "two glances: two claw scrapes")
	if scrapes.size() == 2:
		check(float(scrapes[1].db) > float(scrapes[0].db) + 4.0, "a hard glance scrapes louder than a light one")
	eq(_events_of(ga, "bonk", n).size(), 0, "a glance is no bonk's thud")
	eq(_events_of(ga, "alarm_crow", n).size(), 0, "and the bird doesn't cry at a glance")

	# A wing strike: the feathers on the bark, louder the more speed it cost; no cry.
	await frames(10)
	n = ga.events.size()
	b.wing_struck.emit(-1, b.global_position, 0.3)
	await frames(10)
	b.wing_struck.emit(1, b.global_position, 2.5)
	var strikes := _events_of(ga, "wing_strike", n)
	eq(strikes.size(), 2, "two wing strikes: two feather-on-bark sounds")
	if strikes.size() == 2:
		check(float(strikes[1].db) > float(strikes[0].db) + 4.0, "a wing strike that costs more speed sounds louder")
	eq(_events_of(ga, "alarm_crow", n).size(), 0, "and the bird doesn't cry at a wing strike")

	for x in [a, b]:
		x.queue_free()
	world.queue_free()
	ga.queue_free()
	await frames(2)
