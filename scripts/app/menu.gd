class_name Menu
extends Control
## The start menu (run with no arguments): Flight (the game: the arena and its birds, no rider, no weapons),
## Fight and the Lab. A choice opens its scene with its options added to the command line's (Boot.extra).
## Keys: 1..4, or click.
## Fight opens a second screen first: your bird, your weapons (a pod each side: rockets, seekers or a gun), the mode (the 3 v 3
## match, or target practice on the range's racetrack target) and, for a match, the AI's skill (recruit | pilot |
## ace), with the rules of the mode chosen. Enter starts it, Esc goes back.
## Behind the pages, MenuBackdrop (birds perched on an outpost's rail, idling); the pages' look is MenuStyle's.
## `--shot <png>` saves the screen after `--shot-after` s (default 2) and quits (`--page fight`: on the Fight
## screen); `--no-backdrop` leaves the birds out.

## [label, scene, options] ("fight": the Fight screen)
const CHOICES := [
	["Flight", "res://scenes/game.tscn", ["--no-rider"]],
	["Fight", "fight", []],
	["Lab", "res://scenes/bird_lab.tscn", []],
	["Quit", "", []],
]
const RANGE := "res://scenes/combat_range.tscn"
const POD_KINDS := ["rockets", "seekers", "gun"]   ## (Saddle.POD_KINDS)
const WEAPONS := [   ## [label, what it does], in POD_KINDS order
	["Rockets", "Rockets (three a pod) fly straight and burst beside a bird: aim at the lead mark ahead of your target."],
	["Seekers", "Seekers (two a pod): hold an enemy in the sight for a second, 6 to 40 m off, to lock; then they steer themselves."],
	["Gun", "The gun (40 rounds a pod) fires while held: fast bullets, 40 m at most, aimed at the lead mark. Each hit takes a feather, and fewer in quick succession: it wears a bird down."],
]
const MODES := [   ## [label, rules]
	["3 v 3 match", "You and two AI wingmen (teal) against three AI birds (warm), out from the far outpost.\n" +
		"- A hit knocks out two or three flight feathers (a bullet, one). The hurt wing loses lift and drops; lose eight and you're down.\n" +
		"- A downed bird comes back at its base a few seconds later, mended and rearmed.\n" +
		"- Perch on your base's rail for two seconds to rearm and grow your feathers back. Nowhere else rearms.\n" +
		"- Bursts hurt anyone, teammates too: a teal cross over your sight means a friend is in the line of fire.\n" +
		"- The score, top right, counts the enemy birds each side has downed. There is no time limit."],
	["Target practice", "A target bird flies a racetrack over the clearing, with your crow wingman circling above it.\n" +
		"- Practise leading with rockets and locking with seekers: its straights are long enough to lock, its turns break it.\n" +
		"- It breaks away when it's locked or shot at (T: it flies straight). Eight feathers down it; it comes back a moment later.\n" +
		"- Perch on your base's rail for two seconds to rearm."],
]
const SKILLS := [   ## [CombatSkill preset, label, what it means]
	["recruit", "Recruit", "Slow to react, a narrow view, rough aim; it never checks behind it and breaks late."],
	["pilot", "Pilot", "Quick, checks six now and then, fires on a fair chance and knows the yo-yos."],
	["ace", "Ace", "Near-instant reactions, sees almost all round, fine aim; drags your seekers through the trunks."],
]
const CONTROLS := "Mouse: steer.  Space: flap.  Ctrl: catch a perch.
Left mouse / F: fire.  Q: switch weapon.  Esc: free the mouse."
const COL_W := 540.0     ## px: the choices' column
const RULES_W := 480.0   ## px: the rules'


static var fight_bird := "crow"   ## the Fight screen's choices (kept while the game runs)
static var fight_pods: Array = ["rockets", "rockets"]   ## left, right (POD_KINDS)
static var fight_match := true
static var fight_skill := "pilot"

var page := "main"   ## "main" | "fight"
var backdrop: MenuBackdrop
var _ui: Control   ## the pages
var _main: VBoxContainer
var _fight: VBoxContainer
var _blurb: Label
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
	if Boot.arg_value(Boot.args(), "--page") == "fight":
		page = "fight"
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
	_main = _page("FLAP", true)
	for i in CHOICES.size():
		var b := _button("%d   %s" % [i + 1, CHOICES[i][0]], 22, Vector2(320, 48))
		b.name = "Choice%d" % i
		b.pressed.connect(choose.bind(i))
		_main.add_child(b)
	_build_fight()
	_show(page)


func _build_fight() -> void:
	_fight = _page("FIGHT", false)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	_fight.add_child(cols)
	var pick := _column(COL_W)   # the choices, left; the rules, right
	var rules := _column(RULES_W)
	cols.add_child(pick)
	cols.add_child(rules)
	pick.add_child(_heading("Your bird"))
	pick.add_child(_row(BirdProfile.IDS.map(func(id: String) -> String: return BirdProfile.by_id(id).display_name),
		BirdProfile.IDS.find(fight_bird), func(i: int) -> void:
			fight_bird = BirdProfile.IDS[i]
			_refresh(), "Bird"))
	_blurb = _note(COL_W)
	pick.add_child(_blurb)
	for side in 2:
		pick.add_child(_heading(["Left pod", "Right pod"][side]))
		pick.add_child(_row(WEAPONS.map(func(w: Array) -> String: return w[0]), POD_KINDS.find(fight_pods[side]), func(i: int) -> void:
			fight_pods[side] = POD_KINDS[i]
			_refresh(), ["Left", "Right"][side]))
	_weapon_note = _note(COL_W)
	pick.add_child(_weapon_note)
	pick.add_child(_heading("Mode"))
	pick.add_child(_row(MODES.map(func(m: Array) -> String: return m[0]), 0 if fight_match else 1, func(i: int) -> void:
		fight_match = i == 0
		_refresh(), "Mode"))
	_skill_box = _column(COL_W)
	_skill_box.add_child(_heading("Their skill (and your wingmen's)"))
	_skill_box.add_child(_row(SKILLS.map(func(k: Array) -> String: return k[1]),
		SKILLS.map(func(k: Array) -> String: return k[0]).find(fight_skill), func(i: int) -> void:
			fight_skill = SKILLS[i][0]
			_refresh(), "Skill"))
	_skill_note = _note(COL_W)
	_skill_box.add_child(_skill_note)
	pick.add_child(_skill_box)
	rules.add_child(_heading("Rules"))
	_rules = _note(RULES_W)
	rules.add_child(_rules)
	rules.add_child(_heading("Controls"))
	var controls := _note(RULES_W)
	controls.text = CONTROLS
	rules.add_child(controls)
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	go.add_theme_constant_override("separation", 16)
	var back := _button("Back  (Esc)", 20, Vector2(200, 48))
	back.name = "Back"
	back.pressed.connect(_show.bind("main"))
	var start := _button("Start  (Enter)", 20, Vector2(240, 48))
	start.name = "Start"
	start.pressed.connect(start_fight)
	go.add_child(back)
	go.add_child(start)
	_fight.add_child(go)
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var key := (e as InputEventKey).keycode
	if page == "fight":
		if key == KEY_ESCAPE:
			_show("main")
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			start_fight()
		return
	var k := key - KEY_1
	if k >= 0 and k < CHOICES.size():
		choose(k)


func choose(i: int) -> void:
	var c: Array = CHOICES[i]
	if c[1] == "":
		get_tree().quit()
	elif c[1] == "fight":
		_show("fight")
	else:
		Boot.extra = PackedStringArray(c[2])
		get_tree().change_scene_to_file(c[1])


## The range's options for the Fight screen's choices.
static func fight_options() -> PackedStringArray:
	var o := PackedStringArray(["--bird", fight_bird, "--loadout", "%s,%s" % fight_pods])
	if fight_match:
		o.append_array(["--match", "--skill", fight_skill])
	return o


func start_fight() -> void:
	Boot.extra = fight_options()
	get_tree().change_scene_to_file(RANGE)


func _show(p: String) -> void:
	page = p
	_main.get_meta("page").visible = p == "main"
	_fight.get_meta("page").visible = p == "fight"
	if p == "main":
		(_main.find_child("Choice0", true, false) as Button).grab_focus()
	else:
		(_fight.find_child("Start", true, false) as Button).grab_focus()


func _refresh() -> void:
	_blurb.text = BirdProfile.by_id(fight_bird).blurb
	var notes := []
	for kind in POD_KINDS:
		if fight_pods.has(kind):
			notes.append(WEAPONS[POD_KINDS.find(kind)][1])
	_weapon_note.text = "\n".join(notes) + ("" if fight_pods[0] == fight_pods[1] else "\nQ switches between them.")
	_rules.text = MODES[0 if fight_match else 1][1]
	_skill_box.visible = fight_match
	for k in SKILLS:
		if k[0] == fight_skill:
			_skill_note.text = k[2]


## A page: a panel (MenuStyle's) holding a column under its title, centred on the screen, or `left` of it (the
## main page, clear of the birds).
func _page(title_text: String, left: bool) -> VBoxContainer:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var at: Container = CenterContainer.new() if not left else MarginContainer.new()
	at.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	at.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if left:
		at.add_theme_constant_override("margin_left", 110)
		at.add_theme_constant_override("margin_top", 120)
	holder.add_child(at)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	at.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.set_meta("page", holder)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if not left else HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", MenuStyle.font(MenuStyle.TITLE_FONT, 700))
	title.add_theme_font_size_override("font_size", 64 if left else 52)
	title.add_theme_color_override("font_color", MenuStyle.ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	var rule := ColorRect.new()   # a brass line under the title
	rule.color = MenuStyle.EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	if left:
		var sub := Label.new()
		sub.text = "Hedgerow air corps"
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", MenuStyle.DIM)
		box.add_child(sub)
	return box


## A row of toggle buttons, one pressed at a time; `pick(i)` on a press. Its buttons are named <prefix><i>.
func _row(labels: Array, on: int, pick: Callable, prefix: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := _button(String(labels[i]), 18, Vector2(100, 40))
		b.name = "%s%d" % [prefix, i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == on
		b.pressed.connect(pick.bind(i))
		row.add_child(b)
	return row


static func _button(text: String, font: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	return b


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_font_override("font", MenuStyle.font(MenuStyle.BODY_FONT, 600))
	l.add_theme_color_override("font_color", MenuStyle.DIM)
	return l


static func _column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", 10)
	return c


func _note(width: float) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_font_override("font", MenuStyle.font(MenuStyle.NOTES_FONT))
	return l
