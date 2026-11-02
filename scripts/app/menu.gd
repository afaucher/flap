class_name Menu
extends Control
## The start menu (run with no arguments): Flight (the game: the arena and its birds, no rider, no weapons),
## Fight (the combat range, carrying rockets or seekers) and the Lab. A choice opens its scene with its options
## added to the command line's (Boot.extra). Keys: 1..5, or click.

## [label, scene, options]
const CHOICES := [
	["Flight", "res://scenes/game.tscn", ["--no-rider"]],
	["Fight: six rockets", "res://scenes/combat_range.tscn", []],
	["Fight: four seekers", "res://scenes/combat_range.tscn", ["--seekers"]],
	["Lab", "res://scenes/bird_lab.tscn", []],
	["Quit", "", []],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = "FLAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	box.add_child(title)
	for i in CHOICES.size():
		var b := Button.new()
		b.name = "Choice%d" % i
		b.text = "%d   %s" % [i + 1, CHOICES[i][0]]
		b.custom_minimum_size = Vector2(320, 48)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(choose.bind(i))
		box.add_child(b)
	# (centred: the box grows from the screen's middle once its size is known)
	box.position -= box.get_combined_minimum_size() * 0.5
	(box.get_child(1) as Button).grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode - KEY_1
		if k >= 0 and k < CHOICES.size():
			choose(k)


func choose(i: int) -> void:
	var c: Array = CHOICES[i]
	if c[1] == "":
		get_tree().quit()
		return
	Boot.extra = PackedStringArray(c[2])
	get_tree().change_scene_to_file(c[1])
