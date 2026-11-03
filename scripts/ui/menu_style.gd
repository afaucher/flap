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
