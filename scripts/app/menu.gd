class_name Menu
extends Control
## The start menu (run with no arguments): Flight (the game: the arena and its birds, no rider, no weapons),
## Fight, Race and the Lab. A choice opens its scene with its options added to the command line's (Boot.extra).
## Keys: 1..6, or click.
## Flight opens a screen first: your bird and how it flies (Novice: the landing assist and more power and stamina,
## FlightAssist; Realistic: none). Fight opens one too: your bird, what each pod carries (rockets, seekers or the
## machine gun, left and right; two kinds, and Q switches), how it flies, the mode (the 3 v 3 match, or target
## practice on the range's racetrack target) and, for a match, the AI's skill (recruit | pilot | ace), with the
## rules of the mode chosen. Race opens one: your bird, how it flies, the course (Technical | Long, Level | High and low: COURSES) and who races you
## (no one, or AI racers at recruit | pilot | ace, one of each other bird), with your best time on that course, and
## the race's rules (the game's --race, RaceCourse). Enter starts any of them, Esc goes back. Settings: which way the mouse and the gamepad's stick
## climb and every control (SettingsPanel, the pause menu's too). The pages are built by MenuStyle's helpers.
## Behind the pages, MenuBackdrop (birds perched on an outpost's rail, idling); the pages' look is MenuStyle's.
## `--shot <png>` saves the screen after `--shot-after` s (default 2) and quits (`--page fight|flight|race|settings`:
## on that screen); `--no-backdrop` leaves the birds out.

## [label, scene, options] ("fight": the Fight screen)
const CHOICES := [
	["Flight", "flight", []],
	["Fight", "fight", []],
	["Race", "race", []],
	["Lab", "res://scenes/bird_lab.tscn", []],
	["Settings", "settings", []],
	["Quit", "", []],
]
const RANGE := "res://scenes/combat_range.tscn"
const GAME := "res://scenes/game.tscn"
const WEAPONS := [   ## [--loadout kind, label, what it does] (each pod carries one)
	["rockets", "Rockets", "Three a pod. They fly straight and burst beside a bird: aim at the lead mark ahead of your target."],
	["seekers", "Seekers", "Two a pod. Hold an enemy in the sight for a second, 6 to 40 m off, to lock; then they steer themselves."],
	["gun", "Machine gun", "A belt of rounds in bursts. Each hit chips a feather: lead the mark and keep it there."],
]
const FLYING := [   ## [--flying, label, what it means]
	["novice", "Novice", "Hold Ctrl near a perch and the bird lines itself up and lands for you. More flapping power and stamina."],
	["realistic", "Realistic", "No help: the bird flies as its wings and muscles allow, and every landing is yours to judge."],
]
const MODES := [   ## [label, rules]
	["3 v 3 match", "You and two AI wingmen (teal) against three AI birds (warm), out from the far outpost.\n" +
		"- A hit knocks out two or three flight feathers. The hurt wing loses lift and drops; lose eight and you're down.\n" +
		"- A downed bird comes back at its base a few seconds later, mended and rearmed.\n" +
		"- Perch on your base's rail for two seconds to rearm and grow your feathers back. Nowhere else rearms.\n" +
		"- Bursts hurt anyone, teammates too: a teal cross over your sight means a friend is in the line of fire.\n" +
		"- The score, top right, counts the enemy birds each side has downed. There is no time limit."],
	["Target practice", "A target bird flies a racetrack over the clearing, with your crow wingman circling above it.\n" +
		"- Practise leading with rockets and locking with seekers: its straights are long enough to lock, its turns break it.\n" +
		"- It breaks away when it's locked or shot at (T: it flies straight). Eight feathers down it; it comes back a moment later.\n" +
		"- Balloons ride on cables round the clearing: bullets hole them and they sink, a rocket sets one alight. Each is winched up again.
" +
		"- Perch on your base's rail for two seconds to rearm."],
]
const SKILLS := [   ## [CombatSkill preset, label, what it means]
	["recruit", "Recruit", "Slow to react, a narrow view, rough aim; it never checks behind it and breaks late."],
	["pilot", "Pilot", "Quick, checks six now and then, fires on a fair chance and knows the yo-yos."],
	["ace", "Ace", "Near-instant reactions, sees almost all round, fine aim; drags your seekers through the trunks."],
]
const CONTROLS := "Mouse: steer.  Space: flap.  Ctrl: catch a perch.
Left mouse / F: fire.  Q: switch weapon."
const FLIGHT_CONTROLS := "Mouse: steer.  Space: flap.  Ctrl: catch a perch (hold it to see where you'll land)."
const COURSE_SHAPES := [   ## [RaceCourse shape, label, what it means]
	["technical", "Technical", "Twelve gates close together, tight turns between the trunks. Made for the agile birds: the hawk and falcon will struggle."],
	["long", "Long", "Seven gates far apart. Between them, find your own way through the wood."],
]
const COURSE_HEIGHTS := [   ## [RaceCourse heights, label, what it means]
	["level", "Level", "The gates at much the same height."],
	["high-low", "High and low", "Gates low by the ground and high under the crowns: dive and climb."],
]
const COURSES := {   ## RaceCourse style -> the seed of its course on the game's arena (ARENA_SEED): a full one, home kept
	"technical-level": 8, "technical-high-low": 19, "long-level": 13, "long-high-low": 12,
}
const ARENA_SEED := 7          ## the game's arena with no --seed (the best times are kept per arena too)
const RIVALS := [   ## [--race-ai, label, what it means] ("": racing alone)
	["", "None", "Just you and the clock."],
	["recruit", "Recruits", "One of each other bird. They wander off the line and often miss a gate and go round."],
	["pilot", "Pilots", "One of each other bird. They hold the line well; a miss costs them a loop."],
	["ace", "Aces", "One of each other bird, flying the line as cleanly as it can be flown."],
]
const RACE_RULES := "- Start on the outpost's rail. The clock runs from when you leave it until you land back on it
  with every gate taken. Land on it sooner and the run starts over.
- Fly through each gate in the course's direction, coming from the gate before it; backwards doesn't count.
- Take them in order: the bright gate is next. Skip one and none after it count until you go back for it."
const COL_W := 540.0     ## px: the choices' column
const RULES_W := 480.0   ## px: the rules'


static var fight_bird := "crow"   ## the Fight screen's choices (kept while the game runs)
static var fight_pods := ["rockets", "rockets"]   ## left, right
static var fight_match := true
static var fight_skill := "pilot"
static var flight_bird := "crow"   ## the Flight screen's
static var race_bird := "crow"     ## the Race screen's
static var race_shape := "technical"   ## (COURSE_SHAPES' first column)
static var race_heights := "level"     ## (COURSE_HEIGHTS')
static var race_rivals := ""       ## (RIVALS' first column)
static var novice := true          ## both screens' Flying choice (Novice from the menu; the command line's default is realistic)

var page := "main"   ## "main" | "flight" | "fight" | "race" | "settings"
var backdrop: MenuBackdrop
var _ui: Control   ## the pages
var _main: VBoxContainer
var _flight: VBoxContainer
var _fight: VBoxContainer
var _settings: VBoxContainer
var _race: VBoxContainer
var _race_blurb: Label
var _rivals_note: Label
var _best: Label
var _course_note: Label
var _blurb: Label
var _flight_blurb: Label
var _flying_notes: Array[Label] = []   ## (one on each screen)
var _weapon_note: Label
var _rules: Label
var _skill_box: VBoxContainer
var _skill_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Antialias.apply(self, Boot.args())
	if not Boot.args().has("--no-backdrop"):
		backdrop = MenuBackdrop.new()
		add_child(backdrop)
	if Boot.arg_value(Boot.args(), "--page") in ["fight", "flight", "race", "settings"]:
		page = Boot.arg_value(Boot.args(), "--page")
	_build()
	var shot := Boot.arg_value(Boot.args(), "--shot")
	if shot != "":
		var after := Boot.arg_value(Boot.args(), "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot)
		get_tree().quit()


func _build() -> void:
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = MenuStyle.theme()
	add_child(_ui)
	_main = MenuStyle.page(_ui, "FLAP", true)
	for i in CHOICES.size():
		var b := MenuStyle.button("%d   %s" % [i + 1, CHOICES[i][0]], 22, Vector2(320, 48))
		b.name = "Choice%d" % i
		b.pressed.connect(choose.bind(i))
		_main.add_child(b)
	_build_flight()
	_build_fight()
	_build_race()
	_build_settings()
	_show(page)


func _build_flight() -> void:
	_flight = MenuStyle.page(_ui, "FLIGHT", false)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	_flight.add_child(cols)
	var pick := MenuStyle.column(COL_W)
	var side := MenuStyle.column(RULES_W)
	cols.add_child(pick)
	cols.add_child(side)
	pick.add_child(MenuStyle.heading("Your bird"))
	pick.add_child(MenuStyle.row(BirdProfile.IDS.map(func(id: String) -> String: return BirdProfile.by_id(id).display_name),
		BirdProfile.IDS.find(flight_bird), func(i: int) -> void:
			flight_bird = BirdProfile.IDS[i]
			_refresh(), "FlightBird"))
	_flight_blurb = MenuStyle.note(COL_W)
	pick.add_child(_flight_blurb)
	_flying_row(pick, "FlightFlying")
	side.add_child(MenuStyle.heading("Controls"))
	var controls := MenuStyle.note(RULES_W)
	controls.text = FLIGHT_CONTROLS
	side.add_child(controls)
	_flight.add_child(_go(start_flight, "FlightStart"))


func _build_fight() -> void:
	_fight = MenuStyle.page(_ui, "FIGHT", false)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	_fight.add_child(cols)
	var pick := MenuStyle.column(COL_W)   # the choices, left; the rules, right
	var rules := MenuStyle.column(RULES_W)
	cols.add_child(pick)
	cols.add_child(rules)
	pick.add_child(MenuStyle.heading("Your bird"))
	pick.add_child(MenuStyle.row(BirdProfile.IDS.map(func(id: String) -> String: return BirdProfile.by_id(id).display_name),
		BirdProfile.IDS.find(fight_bird), func(i: int) -> void:
			fight_bird = BirdProfile.IDS[i]
			_refresh(), "Bird"))
	_blurb = MenuStyle.note(COL_W)
	pick.add_child(_blurb)
	for p in 2:
		pick.add_child(MenuStyle.heading(["Left pod", "Right pod"][p]))
		pick.add_child(MenuStyle.row(WEAPONS.map(func(w: Array) -> String: return w[1]),
			WEAPONS.map(func(w: Array) -> String: return w[0]).find(fight_pods[p]), func(i: int) -> void:
				fight_pods[p] = WEAPONS[i][0]
				_refresh(), ["Left", "Right"][p]))
	_weapon_note = MenuStyle.note(COL_W)
	pick.add_child(_weapon_note)
	pick.add_child(MenuStyle.heading("Mode"))
	pick.add_child(MenuStyle.row(MODES.map(func(m: Array) -> String: return m[0]), 0 if fight_match else 1, func(i: int) -> void:
		fight_match = i == 0
		_refresh(), "Mode"))
	_skill_box = MenuStyle.column(COL_W)
	_skill_box.add_child(MenuStyle.heading("Their skill (and your wingmen's)"))
	_skill_box.add_child(MenuStyle.row(SKILLS.map(func(k: Array) -> String: return k[1]),
		SKILLS.map(func(k: Array) -> String: return k[0]).find(fight_skill), func(i: int) -> void:
			fight_skill = SKILLS[i][0]
			_refresh(), "Skill"))
	_skill_note = MenuStyle.note(COL_W)
	_skill_box.add_child(_skill_note)
	pick.add_child(_skill_box)
	_flying_row(rules, "Flying")
	rules.add_child(MenuStyle.heading("Rules"))
	_rules = MenuStyle.note(RULES_W)
	rules.add_child(_rules)
	rules.add_child(MenuStyle.heading("Controls"))
	var controls := MenuStyle.note(RULES_W)
	controls.text = CONTROLS
	rules.add_child(controls)
	_fight.add_child(_go(start_fight, "Start"))


func _build_race() -> void:
	_race = MenuStyle.page(_ui, "RACE", false)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	_race.add_child(cols)
	var pick := MenuStyle.column(COL_W)
	var side := MenuStyle.column(RULES_W)
	cols.add_child(pick)
	cols.add_child(side)
	pick.add_child(MenuStyle.heading("Your bird"))
	pick.add_child(MenuStyle.row(BirdProfile.IDS.map(func(id: String) -> String: return BirdProfile.by_id(id).display_name),
		BirdProfile.IDS.find(race_bird), func(i: int) -> void:
			race_bird = BirdProfile.IDS[i]
			_refresh(), "RaceBird"))
	_race_blurb = MenuStyle.note(COL_W)
	pick.add_child(_race_blurb)
	pick.add_child(MenuStyle.heading("Course"))
	pick.add_child(MenuStyle.row(COURSE_SHAPES.map(func(c: Array) -> String: return c[1]),
		COURSE_SHAPES.map(func(c: Array) -> String: return c[0]).find(race_shape), func(i: int) -> void:
			race_shape = COURSE_SHAPES[i][0]
			_refresh(), "Shape"))
	pick.add_child(MenuStyle.row(COURSE_HEIGHTS.map(func(c: Array) -> String: return c[1]),
		COURSE_HEIGHTS.map(func(c: Array) -> String: return c[0]).find(race_heights), func(i: int) -> void:
			race_heights = COURSE_HEIGHTS[i][0]
			_refresh(), "Heights"))
	_course_note = MenuStyle.note(COL_W)
	pick.add_child(_course_note)
	_best = MenuStyle.note(COL_W)
	pick.add_child(_best)
	pick.add_child(MenuStyle.heading("Racing against"))
	pick.add_child(MenuStyle.row(RIVALS.map(func(r: Array) -> String: return r[1]),
		RIVALS.map(func(r: Array) -> String: return r[0]).find(race_rivals), func(i: int) -> void:
			race_rivals = RIVALS[i][0]
			_refresh(), "Rivals"))
	_rivals_note = MenuStyle.note(COL_W)
	pick.add_child(_rivals_note)
	_flying_row(pick, "RaceFlying")
	side.add_child(MenuStyle.heading("Rules"))
	var rules := MenuStyle.note(RULES_W)
	rules.text = RACE_RULES
	side.add_child(rules)
	_race.add_child(_go(start_race, "RaceStart"))


func _build_settings() -> void:
	_settings = MenuStyle.page(_ui, "SETTINGS", false)
	_settings.add_child(SettingsPanel.new())
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := MenuStyle.button("Back  (Esc)", 20, Vector2(200, 48))
	back.name = "SettingsBack"
	back.pressed.connect(_show.bind("main"))
	go.add_child(back)
	_settings.add_child(go)


## The Flying choice (Novice | Realistic) and what it means, into `box`; its buttons are named <prefix><i>.
func _flying_row(box: VBoxContainer, prefix: String) -> void:
	box.add_child(MenuStyle.heading("Flying"))
	box.add_child(MenuStyle.row(FLYING.map(func(f: Array) -> String: return f[1]), 0 if novice else 1, func(i: int) -> void:
		novice = i == 0
		_refresh(), prefix))
	var note := MenuStyle.note(box.custom_minimum_size.x)
	_flying_notes.append(note)
	box.add_child(note)


## Back, and Start (named `start_name`) calling `start`.
func _go(start: Callable, start_name: String) -> HBoxContainer:
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	go.add_theme_constant_override("separation", 16)
	var back := MenuStyle.button("Back  (Esc)", 20, Vector2(200, 48))
	back.name = start_name + "Back"
	back.pressed.connect(_show.bind("main"))
	var b := MenuStyle.button("Start  (Enter)", 20, Vector2(240, 48))
	b.name = start_name
	b.pressed.connect(start)
	go.add_child(back)
	go.add_child(b)
	return go


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var key := (e as InputEventKey).keycode
	if page != "main":
		if key == KEY_ESCAPE:
			_show("main")
		elif page == "settings":
			pass
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			if page == "fight":
				start_fight()
			elif page == "race":
				start_race()
			else:
				start_flight()
		return
	var k := key - KEY_1
	if k >= 0 and k < CHOICES.size():
		choose(k)


func choose(i: int) -> void:
	var c: Array = CHOICES[i]
	if c[1] == "":
		get_tree().quit()
	elif c[1] in ["fight", "flight", "race", "settings"]:
		_show(c[1])
	else:
		Boot.extra = PackedStringArray(c[2])
		get_tree().change_scene_to_file(c[1])


## The range's options for the Fight screen's choices (the pods as one kind when both carry the same).
static func fight_options() -> PackedStringArray:
	var pods: String = fight_pods[0] if fight_pods[0] == fight_pods[1] else "%s,%s" % fight_pods
	var o := PackedStringArray(["--bird", fight_bird, "--loadout", pods, "--flying", "novice" if novice else "realistic"])
	if fight_match:
		o.append_array(["--match", "--skill", fight_skill])
	return o


## The game's options for the Flight screen's: no rider or weapons.
static func flight_options() -> PackedStringArray:
	return PackedStringArray(["--no-rider", "--bird", flight_bird, "--flying", "novice" if novice else "realistic"])


## The game's options for the Race screen's: race mode on the course picked, no rider or weapons, the AI racers if any.
## The Race screen's course: its RaceCourse style.
static func race_style() -> String:
	return race_shape + "-" + race_heights


static func race_options() -> PackedStringArray:
	var o := PackedStringArray(["--race", "--no-rider", "--bird", race_bird, "--course", str(COURSES[race_style()]), "--course-style", race_style(),
		"--flying", "novice" if novice else "realistic"])
	if race_rivals != "":
		o.append_array(["--race-ai", race_rivals])
	return o


func start_race() -> void:
	Boot.extra = race_options()
	get_tree().change_scene_to_file(GAME)


func start_flight() -> void:
	Boot.extra = flight_options()
	get_tree().change_scene_to_file(GAME)


func start_fight() -> void:
	Boot.extra = fight_options()
	get_tree().change_scene_to_file(RANGE)


func _show(p: String) -> void:
	page = p
	_main.get_meta("page").visible = p == "main"
	_flight.get_meta("page").visible = p == "flight"
	_fight.get_meta("page").visible = p == "fight"
	_settings.get_meta("page").visible = p == "settings"
	_race.get_meta("page").visible = p == "race"
	_refresh()
	if p == "main":
		(_main.find_child("Choice0", true, false) as Button).grab_focus()
	elif p == "flight":
		(_flight.find_child("FlightStart", true, false) as Button).grab_focus()
	elif p == "race":
		(_race.find_child("RaceStart", true, false) as Button).grab_focus()
	elif p == "settings":
		(_settings.find_child("SettingsBack", true, false) as Button).grab_focus()
	else:
		(_fight.find_child("Start", true, false) as Button).grab_focus()


func _refresh() -> void:
	_blurb.text = BirdProfile.by_id(fight_bird).blurb
	_flight_blurb.text = BirdProfile.by_id(flight_bird).blurb
	_race_blurb.text = BirdProfile.by_id(race_bird).blurb
	var best := RaceRecord.best(RaceRecord.key(COURSES[race_style()], ARENA_SEED, race_bird, "novice" if novice else "realistic", race_style()))
	for c in COURSE_SHAPES:
		if c[0] == race_shape:
			_course_note.text = c[2]
	for c in COURSE_HEIGHTS:
		if c[0] == race_heights:
			_course_note.text += " " + c[2]
	_best.text = ("Your best here: " + RaceHud.clock_text(float(best.time))) if not best.is_empty() else "No time set here yet."
	for r in RIVALS:
		if r[0] == race_rivals:
			_rivals_note.text = r[2]
	var notes := []
	for w in WEAPONS:
		if fight_pods.has(w[0]):
			notes.append("%s: %s" % [w[1], w[2]])
	if fight_pods[0] != fight_pods[1]:
		notes.append("Two kinds: Q switches between them.")
	_weapon_note.text = "\n".join(notes)
	for n in _flying_notes:
		n.text = FLYING[0 if novice else 1][2]
	for prefix in ["Flying", "FlightFlying", "RaceFlying"]:   # (both screens' rows show the one choice)
		for i in 2:
			var b := find_child("%s%d" % [prefix, i], true, false) as Button
			if b != null:
				b.set_pressed_no_signal(i == (0 if novice else 1))
	_rules.text = MODES[0 if fight_match else 1][1]
	_skill_box.visible = fight_match
	for k in SKILLS:
		if k[0] == fight_skill:
			_skill_note.text = k[2]
