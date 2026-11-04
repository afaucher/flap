extends TestCase
## The start menu and what its choices open: the menu lists Flight, Fight and the Lab; Flight (its options in
## Boot.extra) is the game with no tack on any bird, and without them the riders are back. Fight opens its own
## screen (Esc back): your bird, your weapon, the mode and, for a match, the AI's skill, each shown with what it
## means; Start opens the range as chosen -- that species, one kind of round (six rockets or four seekers, nothing
## to switch to), the 3 v 3 match at that skill, or target practice with no match. Behind the menu, birds
## perched on an outpost's rail, their feet on it (each under its own hip, the legs not crossed), idling: each looks about and, within a few seconds, moves its
## tail, wings, plumage or neck.


const SHARDS := 2   ## (the menu and the game in one process, the range in another)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	if in_shard(0):
		await _menu_and_flight()
	if in_shard(1):
		await _fights()
	Boot.extra = PackedStringArray()
	finish()


func _menu_and_flight() -> void:
	var menu: Menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var labels := []
	for c in Menu.CHOICES:
		labels.append(c[0])
	for want in ["Flight", "Fight", "Lab"]:
		check(labels.has(want), "the menu offers " + want)
	eq(menu.find_children("Choice*", "Button", true, false).size(), Menu.CHOICES.size(), "a button per choice")
	await _backdrop(menu)
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
	(menu.find_child("Bird3", true, false) as Button).pressed.emit()        # falcon
	(menu.find_child("Weapon1", true, false) as Button).pressed.emit()      # seekers
	(menu.find_child("Skill2", true, false) as Button).pressed.emit()       # ace
	await frames(1)
	text = _text(menu)
	check(text.contains(Menu.WEAPONS[1][1]) and text.contains(Menu.SKILLS[2][2]) and text.contains("lose eight"), "what the seekers, the ace and the match's rules mean are on screen")
	var o := Menu.fight_options()
	check(Array(o) == ["--bird", BirdProfile.IDS[3], "--seekers", "--match", "--skill", "ace"], "and Start asks for just that (%s)" % str(o))
	var skill_row := menu.find_child("Skill0", true, false) as Button
	check(skill_row.is_visible_in_tree(), "a match offers the AI's skill")
	(menu.find_child("Mode1", true, false) as Button).pressed.emit()        # target practice
	await frames(1)
	check(not skill_row.is_visible_in_tree() and _text(menu).contains("racetrack"), "target practice doesn't, and shows its own rules")
	o = Menu.fight_options()
	check(not o.has("--match") and not o.has("--skill"), "and asks for no match (%s)" % str(o))
	(menu.find_child("Weapon0", true, false) as Button).pressed.emit()
	check(not Menu.fight_options().has("--seekers"), "rockets ask for no seekers")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	await frames(1)
	check(flight.is_visible_in_tree() and not start.is_visible_in_tree(), "Esc goes back")
	menu.queue_free()

	for no_tack in [true, false]:
		Boot.extra = PackedStringArray(Menu.CHOICES[0][2] if no_tack else [])
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
	# [bird, seekers, match, skill]
	for f in [["hawk", false, true, "ace"], ["sparrow", true, true, "recruit"], ["owl", false, false, "pilot"]]:
		Menu.fight_bird = f[0]
		Menu.fight_seekers = f[1]
		Menu.fight_match = f[2]
		Menu.fight_skill = f[3]
		Boot.extra = Menu.fight_options()
		var r: Node = load("res://scenes/combat_range.tscn").instantiate()
		add_child(r)
		if not r.is_loaded:
			await r.loaded
		await frames(3)
		var what := "%s, %s, %s" % [f[0], "seekers" if f[1] else "rockets", ("match at " + f[3]) if f[2] else "practice"]
		eq((r.bird as Bird).profile.id, f[0], what + ": you fly the bird picked")
		var l: Launcher = r.world.player
		var R := Launcher.Weapon.ROCKETS
		var S := Launcher.Weapon.SEEKERS
		var want := {R: 0, S: 4} if f[1] else {R: 6, S: 0}
		check(int(l.capacity[R]) == want[R] and int(l.capacity[S]) == want[S], "%s: you carry %s (%s)" % [what, "four seekers" if f[1] else "six rockets", str(l.capacity)])
		eq(l.weapon, S if f[1] else R, what + ": with that weapon selected")
		var w := l.weapon
		l.controller = _Switch.new()
		await frames(2)
		eq(l.weapon, w, what + ": and nothing to switch to")
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
