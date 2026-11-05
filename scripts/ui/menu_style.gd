class_name MenuStyle
extends RefCounted
## The menu's look: instrument plates, dark leather panels edged in brass, cream text, the selected choice a lit
## brass plate (the brass HUD concept's). Chosen over a briefing card (cream paper, typewriter) and smoked glass
## (docs/images/menu_styles.jpg). The fonts are the system's for now (SystemFont, falling back to Godot's own);
## the look gets a bundled font when one is picked.

const PANEL := Color(0.13, 0.09, 0.06, 0.9)
const EDGE := Color(0.76, 0.6, 0.3)
const INK := Color(1.0, 0.93, 0.75)          ## = CombatHud.INK
const DIM := Color(0.86, 0.74, 0.5)          ## headings, the subtitle
const ACCENT := Color(0.82, 0.66, 0.32)      ## the title, the selected choice
const ON_ACCENT := Color(0.14, 0.09, 0.04)   ## text on the accent
const TITLE_FONT := ["Palatino Linotype", "Georgia", "serif"]
const BODY_FONT := ["Bahnschrift", "Segoe UI", "sans-serif"]
const NOTES_FONT := ["Segoe UI", "sans-serif"]
const RADIUS := 6


static func font(names: Array, weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


## The Theme for the pages: buttons a plate, lit on hover, the accent when pressed (a toggle's choice); the
## pages' PanelContainers leather edged in brass.
static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = font(BODY_FONT)
	th.set_color("font_color", "Label", INK)
	var plate := _box(PANEL.lerp(Color.BLACK, 0.15), EDGE, 2)
	var hover := _box(PANEL.lerp(ACCENT, 0.22), ACCENT, 2)
	var on := _box(ACCENT, ACCENT.lerp(Color.WHITE, 0.25), 2)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = INK
	focus.set_corner_radius_all(RADIUS + 2)
	focus.set_expand_margin_all(3)
	th.set_stylebox("normal", "Button", plate)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", on)
	th.set_stylebox("hover_pressed", "Button", on)
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("disabled", "Button", plate)
	for k in ["font_color", "font_focus_color", "font_disabled_color", "font_hover_color"]:
		th.set_color(k, "Button", INK)
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		th.set_color(k, "Button", ON_ACCENT)
	var panel := _box(PANEL, EDGE, 3)
	panel.set_content_margin_all(36)
	panel.shadow_color = Color(0, 0, 0, 0.55)
	panel.shadow_size = 14
	th.set_stylebox("panel", "PanelContainer", panel)
	return th


static func _box(fill: Color, edge: Color, w: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(w)
	b.set_corner_radius_all(RADIUS)
	b.set_content_margin_all(10)
	b.anti_aliasing = true
	return b


# --- The pages' parts (the start menu's, the pause menu's) ---

## A page in `parent`: a panel holding a column under its title, centred on the screen, or `left` of it (the
## main page, clear of the birds).
static func page(parent: Control, title_text: String, left: bool) -> VBoxContainer:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
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
	title.add_theme_font_override("font", font(TITLE_FONT, 700))
	title.add_theme_font_size_override("font_size", 64 if left else 52)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	var rule := ColorRect.new()   # a brass line under the title
	rule.color = EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	if left:
		var sub := Label.new()
		sub.text = "Hedgerow air corps"
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", DIM)
		box.add_child(sub)
	return box


## A row of toggle buttons, one pressed at a time; `pick(i)` on a press. Its buttons are named <prefix><i>.
static func row(labels: Array, on: int, pick: Callable, prefix: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := button(String(labels[i]), 18, Vector2(100, 40))
		b.name = "%s%d" % [prefix, i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == on
		b.pressed.connect(pick.bind(i))
		r.add_child(b)
	return r


static func button(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_font_override("font", font(BODY_FONT, 600))
	l.add_theme_color_override("font_color", DIM)
	return l


static func column(width: float) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = width
	c.add_theme_constant_override("separation", 10)
	return c


static func note(width: float) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_font_override("font", font(NOTES_FONT))
	return l


## One cell of the controls table (a heading cell `dim`).
static func cell(text: String, dim: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	if dim:
		l.add_theme_font_override("font", font(BODY_FONT, 600))
		l.add_theme_color_override("font_color", DIM)
	else:
		l.add_theme_font_override("font", font(NOTES_FONT))
	return l
