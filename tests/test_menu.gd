extends TestCase
## The start menu and what its choices open: the menu lists Flight, Fight, Race and the Lab. Flight opens its own screen
## (Esc back): your bird and how it flies (Novice | Realistic, with what each means); Start asks for the game with
## that bird and no tack on any bird (without Flight's options the riders are back). Fight opens its own screen:
## your bird, each pod's weapon, how it flies (the same choice as Flight's), the mode and, for a match, the AI's
## skill, each shown with what it means; Start opens the range as chosen -- that species, what each pod carries (the left
## pod's selected; Q switches to the right's when it differs), the 3 v 3 match at that skill, or target practice with no match.
## Race opens its own screen: your bird, the course, who races you (with what each means) and your best time on that
## course for that bird and way of flying (none, then the one kept); Start opens the game in race mode on that course
## with that bird, no tack, and AI racers of each other bird at that skill (none when racing alone); the pause menu's
## Start over puts you and them back on the course's start, the clock reset. Behind the menu, birds
## perched on an outpost's rail, their feet on it (each under its own hip, the legs not crossed), idling: each looks about and, within a few seconds, moves its
## tail, wings, plumage or neck.


const SHARDS := 3   ## (the menu and the game in one process, the range in another, the race screen and its game in a third)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	if in_shard(0):
		await _menu_and_flight()
	if in_shard(1):
		await _fights()
	if in_shard(2):
		await _race()
	Boot.extra = PackedStringArray()
	finish()


func _menu_and_flight() -> void:
	var menu: Menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var labels := []
	for c in Menu.CHOICES:
		labels.append(c[0])
	for want in ["Flight", "Fight", "Race", "Lab"]:
		check(labels.has(want), "the menu offers " + want)
	eq(menu.find_children("Choice*", "Button", true, false).size(), Menu.CHOICES.size(), "a button per choice")
	await _backdrop(menu)
	# The Flight screen.
	(menu.find_child("Choice0", true, false) as Button).pressed.emit()
	await frames(2)
	var fstart := menu.find_child("FlightStart", true, false) as Button
	var choice0 := menu.find_child("Choice0", true, false) as Button
	check(fstart.is_visible_in_tree() and not choice0.is_visible_in_tree(), "Flight opens its own screen")
	(menu.find_child("FlightBird4", true, false) as Button).pressed.emit()   # sparrow
	await frames(1)
	check(_text(menu).contains(BirdProfile.by_id(BirdProfile.IDS[4]).blurb), "picking the sparrow shows what it's like")
	check(_text(menu).contains(Menu.FLYING[0][2]), "Novice by default, and what it means is on screen")
	eq(Array(Menu.flight_options()), ["--no-rider", "--bird", BirdProfile.IDS[4], "--flying", "novice"], "Start asks for the game with that bird, no tack, novice")
	(menu.find_child("FlightFlying1", true, false) as Button).pressed.emit()   # realistic
	await frames(1)
	check(_text(menu).contains(Menu.FLYING[1][2]) and not _text(menu).contains(Menu.FLYING[0][2]), "Realistic shows what it means")
	check(Array(Menu.flight_options()).has("realistic"), "and Start asks for it")
	var esc0 := InputEventKey.new()
	esc0.keycode = KEY_ESCAPE
	esc0.pressed = true
	menu._unhandled_input(esc0)
	await frames(1)
	check(choice0.is_visible_in_tree() and not fstart.is_visible_in_tree(), "Esc goes back")
	# The Fight screen.
	(menu.find_child("Choice1", true, false) as Button).pressed.emit()
	await frames(2)
	var start := menu.find_child("Start", true, false) as Button
	var flight := menu.find_child("Choice0", true, false) as Button
	check(start.is_visible_in_tree() and not flight.is_visible_in_tree(), "Fight opens its own screen")
	eq(menu.find_children("Bird*", "Button", true, false).size(), BirdProfile.IDS.size(), "a button per bird")
	var text := _text(menu)
	for id in BirdProfile.IDS:
		var b := menu.find_child("Bird%d" % BirdProfile.IDS.find(id), true, false) as Button
		b.pressed.emit()
		await frames(1)
		check(_text(menu).contains(BirdProfile.by_id(id).blurb), "picking the %s shows what it's like" % id)
	check((menu.find_child("Flying1", true, false) as Button).button_pressed, "the Fight screen's Flying shows the Flight screen's choice (Realistic)")
	(menu.find_child("Flying0", true, false) as Button).pressed.emit()      # novice again
	(menu.find_child("Bird3", true, false) as Button).pressed.emit()        # falcon
	(menu.find_child("Left1", true, false) as Button).pressed.emit()        # seekers on both pods
	(menu.find_child("Right1", true, false) as Button).pressed.emit()
	(menu.find_child("Skill2", true, false) as Button).pressed.emit()       # ace
	await frames(1)
	text = _text(menu)
	check(text.contains(Menu.WEAPONS[1][2]) and text.contains(Menu.SKILLS[2][2]) and text.contains("lose eight"), "what the seekers, the ace and the match's rules mean are on screen")
	check(not text.contains("Q switches"), "one kind: nothing to switch")
	var o := Menu.fight_options()
	check(Array(o) == ["--bird", BirdProfile.IDS[3], "--loadout", "seekers", "--flying", "novice", "--match", "--skill", "ace"], "and Start asks for just that (%s)" % str(o))
	(menu.find_child("Right2", true, false) as Button).pressed.emit()       # a gun on the right
	await frames(1)
	text = _text(menu)
	check(text.contains(Menu.WEAPONS[2][2]) and text.contains(Menu.WEAPONS[1][2]) and text.contains("Q switches"), "two kinds: both described, and Q switches")
	check(Array(Menu.fight_options()).slice(2, 4) == ["--loadout", "seekers,gun"], "the pods asked for left then right (%s)" % str(Menu.fight_options()))
	(menu.find_child("Left0", true, false) as Button).pressed.emit()
	(menu.find_child("Right0", true, false) as Button).pressed.emit()
	var skill_row := menu.find_child("Skill0", true, false) as Button
	check(skill_row.is_visible_in_tree(), "a match offers the AI's skill")
	(menu.find_child("Mode1", true, false) as Button).pressed.emit()        # target practice
	await frames(1)
	check(not skill_row.is_visible_in_tree() and _text(menu).contains("racetrack"), "target practice doesn't, and shows its own rules")
	o = Menu.fight_options()
	check(not o.has("--match") and not o.has("--skill"), "and asks for no match (%s)" % str(o))
	check(Array(Menu.fight_options()).slice(2, 4) == ["--loadout", "rockets"], "rockets on both pods (%s)" % str(Menu.fight_options()))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	await frames(1)
	check(flight.is_visible_in_tree() and not start.is_visible_in_tree(), "Esc goes back")
	menu.queue_free()

	for no_tack in [true, false]:
		Boot.extra = Menu.flight_options() if no_tack else PackedStringArray()
		var game: Game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		if not game.is_loaded:
			await game.loaded
		await frames(3)
		var tacks := 0
		for b in game.ai_birds + [game.bird]:
			for c in (b as Bird).rig.get_children():
				tacks += int(c is Tack)
		if no_tack:
			eq(tacks, 0, "Flight: no rider or weapons on any bird")
			eq(game.bird.profile.id, Menu.flight_bird, "Flight: you fly the bird picked")
		else:
			check(tacks >= 1, "the game's riders are there without Flight's options (%d)" % tacks)
		game.queue_free()
		await frames(2)


func _backdrop(menu: Menu) -> void:
	var bd := menu.backdrop
	check(bd != null and bd.rigs.size() >= 3, "birds behind the menu")
	if bd == null:
		return
	var rest := []   # each bird's perched controls, its head's way, and how far each moved from them
	for r in bd.rigs:
		for i in 2:
			var foot := r.global_transform * (r.leg_joints[i][3] as Vector3)
			check(absf(foot.y - bd.rail_top) < 0.03, "%s's %s foot on the rail (%.3f m off)" % [r.profile.id, ["left", "right"][i], foot.y - bd.rail_top])
			var hip := r.leg_joints[i][0] as Vector3   # (each foot under its own hip: the legs not crossed, whichever way the bird faces)
			var out: float = (r.leg_joints[i][3] as Vector3).x * float(BirdRig.SIDES[i])
			check(out > 0.0 and hip.x * float(BirdRig.SIDES[i]) > 0.0, "%s's %s foot on its own side (%.3f m out)" % [r.profile.id, ["left", "right"][i], out])
		rest.append({"c": [r.fold, r.tail_pitch, r.fluff, r.neck_ext], "head": r.head_basis.get_rotation_quaternion(), "moved": 0.0, "turned": 0.0})
	for f in 7 * 60:
		await frames(1)
		for k in bd.rigs.size():
			var r := bd.rigs[k]
			var c: Array = rest[k].c
			var now := [r.fold, r.tail_pitch, r.fluff, r.neck_ext]
			for j in 4:
				rest[k].moved = maxf(rest[k].moved, absf(float(now[j]) - float(c[j])))
			rest[k].turned = maxf(rest[k].turned, rest[k].head.angle_to(r.head_basis.get_rotation_quaternion()))
	for k in bd.rigs.size():
		var id := bd.rigs[k].profile.id
		check(rest[k].moved > 0.05, "the %s idles in 7 s (tail, wings, plumage or neck: %.2f)" % [id, rest[k].moved])
		check(rest[k].turned > deg_to_rad(15.0), "the %s looks about (%.0f deg)" % [id, rad_to_deg(rest[k].turned)])


func _fights() -> void:
	# [bird, pods (left, right), match, skill]
	for f in [["hawk", ["rockets", "rockets"], true, "ace"], ["sparrow", ["seekers", "seekers"], true, "recruit"], ["owl", ["gun", "seekers"], false, "pilot"], ["crow", ["rockets", "gun"], false, "pilot"]]:
		Menu.fight_bird = f[0]
		Menu.fight_pods = (f[1] as Array).duplicate()
		Menu.fight_match = f[2]
		Menu.fight_skill = f[3]
		Boot.extra = Menu.fight_options()
		var r: Node = load("res://scenes/combat_range.tscn").instantiate()
		add_child(r)
		if not r.is_loaded:
			await r.loaded
		await frames(3)
		var pods: Array = f[1]
		var what := "%s, %s, %s" % [f[0], ",".join(pods), ("match at " + f[3]) if f[2] else "practice"]
		eq((r.bird as Bird).profile.id, f[0], what + ": you fly the bird picked")
		var l: Launcher = r.world.player
		var want := {}
		for w in Launcher.KIND_NAMES:
			want[w] = 0
			for p in pods:
				if p == Launcher.KIND_NAMES[w]:
					want[w] += int(Saddle.POD_ROUNDS[p])
			eq(l.carried(w), int(want[w]), "%s: you carry %d %s" % [what, int(want[w]), Launcher.KIND_NAMES[w]])
		eq(l.weapon, Launcher.weapon_of(pods[0]), what + ": with the left pod's weapon selected")
		var w0 := l.weapon
		l.controller = _Switch.new()
		await frames(2)
		if pods[0] == pods[1]:
			eq(l.weapon, w0, what + ": and nothing to switch to")
		else:
			eq(l.weapon, Launcher.weapon_of(pods[1]), what + ": and Q switches to the right pod's")
		if f[2]:
			check(r.target == null and r.match_birds.size() == 5, "%s: the 3 v 3 match (%d AI birds)" % [what, r.match_birds.size()])
			var skills := {}
			for b in r.match_birds:
				skills[((b as Bird).controller as CombatPilot).brain.skill.name] = true
			eq(skills.keys(), [f[3]], what + ": every AI bird flies at that skill")
		else:
			check(r.target != null and r.match_birds.is_empty(), what + ": the racetrack target, no match")
		r.queue_free()
		await frames(2)


func _race() -> void:
	RaceRecord.path = "user://test_menu_race_best_%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceRecord.path))
	var menu: Menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var i := Menu.CHOICES.map(func(c: Array) -> String: return c[0]).find("Race")
	(menu.find_child("Choice%d" % i, true, false) as Button).pressed.emit()
	await frames(2)
	var start := menu.find_child("RaceStart", true, false) as Button
	var choice0 := menu.find_child("Choice0", true, false) as Button
	check(start.is_visible_in_tree() and not choice0.is_visible_in_tree(), "Race opens its own screen")
	check(not (menu.find_child("Start", true, false) as Button).is_visible_in_tree() and not (menu.find_child("FlightStart", true, false) as Button).is_visible_in_tree(), "and only its own")
	eq(menu.find_children("Course*", "Button", true, false).size(), Menu.COURSES.size(), "a button per course")
	(menu.find_child("RaceBird2", true, false) as Button).pressed.emit()   # owl
	(menu.find_child("Course1", true, false) as Button).pressed.emit()     # the second course
	await frames(1)
	var text := _text(menu)
	check(text.contains(BirdProfile.by_id(BirdProfile.IDS[2]).blurb), "picking the owl shows what it's like")
	check(text.contains(Menu.RIVALS[0][2]), "racing alone by default, and what it means is on screen")
	check(text.contains("No time set"), "no best time yet")
	check(text.contains(Menu.RACE_RULES), "the race's rules are on screen")
	check(not text.contains("Space: flap"), "no controls on it")
	eq(Array(Menu.race_options()), ["--race", "--no-rider", "--bird", BirdProfile.IDS[2], "--course", str(Menu.COURSES[1]), "--flying", "novice"],
		"Start asks for a race on that course with that bird, no tack, no rivals")
	for k in Menu.RIVALS.size():
		(menu.find_child("Rivals%d" % k, true, false) as Button).pressed.emit()
		await frames(1)
		check(_text(menu).contains(Menu.RIVALS[k][2]), "%s: what it means is on screen" % Menu.RIVALS[k][1])
		var o := Array(Menu.race_options())
		check(o.has("--race-ai") == (k > 0) and (k == 0 or o[o.find("--race-ai") + 1] == Menu.RIVALS[k][0]), "%s: and Start asks for them (%s)" % [Menu.RIVALS[k][1], str(o)])
	(menu.find_child("Rivals2", true, false) as Button).pressed.emit()     # pilots
	RaceRecord.offer(RaceRecord.key(Menu.COURSES[1], Menu.ARENA_SEED, BirdProfile.IDS[2], "novice"), 31.25, [])
	(menu.find_child("Course0", true, false) as Button).pressed.emit()     # (a time on another course isn't shown)
	await frames(1)
	check(_text(menu).contains("No time set"), "a best on another course isn't this one's")
	(menu.find_child("Course1", true, false) as Button).pressed.emit()
	await frames(1)
	check(_text(menu).contains("0:31.2") or _text(menu).contains("0:31.3"), "the best kept on this course is shown")
	(menu.find_child("RaceFlying1", true, false) as Button).pressed.emit() # realistic: a best of its own
	await frames(1)
	check(_text(menu).contains("No time set"), "a novice best isn't a realistic one")
	check((menu.find_child("Flying1", true, false) as Button).button_pressed and (menu.find_child("FlightFlying1", true, false) as Button).button_pressed, "the other screens' Flying follow it")
	(menu.find_child("RaceFlying0", true, false) as Button).pressed.emit()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	await frames(1)
	check(choice0.is_visible_in_tree() and not start.is_visible_in_tree(), "Esc goes back")
	menu.queue_free()

	for rivals in ["pilot", ""]:
		Menu.race_rivals = rivals
		Boot.extra = Menu.race_options()
		var game: Game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		if not game.is_loaded:
			await game.loaded
		await frames(3)
		var what := "race (%s)" % (rivals if rivals != "" else "alone")
		check(game.race and game.course != null and game.course.gates.size() == game.course.gate_count, what + ": the game opens in race mode on a full course")
		if game.course != null:
			eq(game.course.seed, Menu.COURSES[1], what + ": the course picked")
			var over := AABB(game.course.start.position + Vector3(-0.4, 0.1, -0.4), Vector3(0.8, 1.2, 0.8))   # (where a bird sits on the rail, and over its head)
			var in_way := 0
			for mi in game.race_view.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).is_visible_in_tree() and ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).intersects(over):
					in_way += 1
			eq(in_way, 0, what + ": nothing of the course drawn over the start rail, in a bird's way")
			check(game.bird.perch == game.course.start, what + ": you on its start")
		eq(game.bird.profile.id, BirdProfile.IDS[2], what + ": you fly the bird picked")
		if game.course != null and rivals != "":   # (the pause menu's Start over: everyone back on the start, the clocks reset)
			var away: Perch = game.layout.perches[0] if game.layout.perches[0] != game.course.start else game.layout.perches[1]
			game.bird.perch_at(away)
			game.race_run.phase = RaceRun.Phase.RUNNING
			game.racers[0].bird.perch_at(away)
			game.start_over()   # (checked at once: the racers leave the rail on their next tick)
			check(game.bird.perch == game.course.start and game.race_run.phase == RaceRun.Phase.READY, what + ": Start over puts you back on the start, the clock reset")
			check(game.racers[0].bird.perch == game.course.start, what + ": and the racers")
		eq(game.ai_birds.size(), 0, what + ": no perch-to-perch AI birds")
		var tacks := 0
		for c in game.bird.rig.get_children():
			tacks += int(c is Tack)
		eq(tacks, 0, what + ": no rider or weapons")
		if rivals == "":
			eq(game.racers.size(), 0, what + ": no one else on the course")
		else:
			var ids := {}
			for r in game.racers:
				ids[r.id] = true
				eq(((r.pilot as RacePilot).skill as CombatSkill).name, rivals, what + ": the %s races at that skill" % r.id)
			eq(ids.size(), BirdProfile.IDS.size() - 1, what + ": one of each other bird")
			check(not ids.has(BirdProfile.IDS[2]), what + ": and not yours")
		game.queue_free()
		await frames(2)
	Menu.race_rivals = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceRecord.path))
	RaceRecord.path = "user://race_best.cfg"


## All the text on the menu's visible labels.
static func _text(menu: Node) -> String:
	var out := ""
	for l in menu.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out += (l as Label).text + "\n"
	return out


class _Switch:
	var done := false
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		var first := not done
		done = true
		return CombatInput.new(false, false, first)
