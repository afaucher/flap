extends TestCase
## The game's sound (docs/design/audio_plan.md "As built"): the baked files are today's recipes and every cue has its
## takes; the recipes do what the plan asks of them (measured on the rendered samples: your lock's beeps and someone
## locking you are far apart in pitch; loops wrap without a jump; a burst hits at once; a rocket launch is over in
## 0.2 s, so four a second stay apart); the owl's wingbeat is next to silent beside the crow's; and GameAudio asks for
## the right cue at the right moment: launches with their motors, each kind of burst, hits with the species' alarm,
## the lock's beeps rising and quickening then the locked tone (and nothing without a target), what the HUD warns you
## of (someone locking you; a seeker closing on you, the warble quickening), the dry click, the weapon switch, a clink per missing round on
## the base then the chime (and none off the base), the talons catching on a landing (not on a teleport), and bonks
## louder the harder they hit.


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
	var r := SoundRecipes.render("rocket_launch")
	check(SoundDsp.rms(r, 0.2) < SoundDsp.rms(r, 0.0, 0.2) * 0.15, "a rocket launch is over in 0.2 s")
	var lengths := {}
	for take in SoundRecipes.files_of("perch_catch").size():
		var c := SoundRecipes.render("perch_catch", take)
		lengths[c.size()] = true
		check(SoundDsp.onset(c, 0.0, 12.0) < 0.03, "perch catch %d starts on its scratch" % (take + 1))
		check(SoundDsp.rms(c, c.size() / float(SoundDsp.RATE) - 0.02) < SoundDsp.rms(c) * 0.2, "perch catch %d ends quiet" % (take + 1))
	check(lengths.size() >= 4, "the perch catch takes are different scratches of the recording")
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

	for x in [a, b]:
		x.queue_free()
	world.queue_free()
	ga.queue_free()
	await frames(2)
