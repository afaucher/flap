class_name Loading
extends CanvasLayer
## The loading screen while a scene grows its wood (the game, the range): MenuStyle's brass-on-leather panel over a
## dark ground, what's loading, the step it's on, a brass bar filling and a tip. The heavy work goes on behind it:
## the layout generated on a worker thread (pure data: the screen keeps drawing meanwhile), the arena built in
## ArenaBuilder.steps() a frame apart, the birds spawned; then a frame or two drawn behind it (the shaders
## compile) and it fades.
##   var screen := Loading.new("The pine wood")
##   add_child(screen)
##   layout = await screen.generate(func() -> ArenaLayout: return Pinewood.generate(7), 0.25, 1.5)
##   await screen.run(arena.steps(layout), 0.85)
##   await screen.finish()

const TIPS := [
	"Hold Ctrl as you come in to catch a perch: the bar on it turns green when you're slow enough.",
	"A bird glides best with the mouse let go: the flight path settles onto its ideal glide.",
	"Perch on your base's rail for two seconds to rearm and grow lost feathers back.",
	"Seekers lock on a bird held in the sight for a second, 6 to 40 m off.",
	"Rockets fly straight: aim at the lead mark ahead of your target.",
	"Space flaps: a beat costs burst, and a tired bird flaps weaker.",
	"F6 changes the light: golden, afternoon, a misty morning, overcast.",
]

var what := ""         ## what's loading (the panel's heading)
var progress := 0.0    ## 0..1
var _step: Label
var _bar: ProgressBar
var _root: Control
var _task := -1        ## the worker thread's layout task while it runs


func _init(heading := "") -> void:
	what = heading
	layer = 100


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = MenuStyle.theme()
	add_child(_root)
	var bg := ColorRect.new()   # (a dark leather ground, lighter in the middle)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.024, 0.016)
	_root.add_child(bg)
	var glow := TextureRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.17, 0.11, 0.068), Color(0.035, 0.024, 0.016, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	glow.texture = gt
	_root.add_child(glow)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "FLAP"
	title.add_theme_font_override("font", MenuStyle.font(MenuStyle.TITLE_FONT, 700))
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", MenuStyle.ACCENT)
	box.add_child(title)
	var rule := ColorRect.new()
	rule.color = MenuStyle.EDGE
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	var head := Label.new()
	head.text = what
	head.add_theme_font_size_override("font_size", 22)
	box.add_child(head)
	_step = Label.new()
	_step.name = "Step"
	_step.add_theme_font_size_override("font_size", 16)
	_step.add_theme_color_override("font_color", MenuStyle.DIM)
	box.add_child(_step)
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size.y = 14
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.05, 0.035, 0.02)
	trough.border_color = MenuStyle.EDGE.darkened(0.35)
	trough.set_border_width_all(1)
	trough.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = MenuStyle.ACCENT
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", trough)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)
	var tip := Label.new()
	tip.text = TIPS[randi() % TIPS.size()]
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_override("font", MenuStyle.font(MenuStyle.NOTES_FONT))
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", MenuStyle.DIM)
	box.add_child(tip)
	_show("", 0.0)


func _show(step: String, p: float) -> void:
	progress = clampf(maxf(progress, p), 0.0, 1.0)
	if step != "" and _step != null:
		_step.text = step + "..."
	if _bar != null:
		_bar.value = progress


## The layout made by `make` (pure data: run on a worker thread while the screen draws), the bar filling toward
## `to` over about `expect` s meanwhile. Headless, it's simply made.
func generate(make: Callable, to: float, expect := 1.5, step := "Growing the wood") -> ArenaLayout:
	var from := progress
	_show(step, from)
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":   # (no screen to keep drawing: just make it; under the tests' fixed
		_show(step, to)                          # frame rate a wait would spin thousands of frames)
		return make.call()
	var got := [null]
	var id := WorkerThreadPool.add_task(func() -> void: got[0] = make.call(), true, "layout")
	_task = id
	var t0 := Time.get_ticks_msec()
	while not WorkerThreadPool.is_task_completed(id):
		var f := 1.0 - exp(-(Time.get_ticks_msec() - t0) / 1000.0 / maxf(expect, 0.1))   # (eases toward `to`, never reaching it)
		_show(step, lerpf(from, to, f * 0.95))
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	_task = -1
	_show(step, to)
	return got[0]


func _exit_tree() -> void:
	if _task >= 0:   # (quit while the layout was still growing: let the thread finish, not die mid-write)
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Run `steps` ([label, Callable, share] each, as ArenaBuilder.steps()) a frame apart, the bar going to `to`.
func run(steps: Array, to: float) -> void:
	var from := progress
	var total := 0.0
	for st in steps:
		total += float(st[2])
	var done := 0.0
	for st in steps:
		_show(String(st[0]), lerpf(from, to, done / maxf(total, 1e-6)))
		await get_tree().process_frame
		(st[1] as Callable).call()
		done += float(st[2])
	_show("", to)


## Done: a couple of frames drawn behind the screen (the scene's shaders compile), the bar full, a short fade.
func finish() -> void:
	_show("Taking off", 1.0)
	for i in 3:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	await tw.finished
	queue_free()
