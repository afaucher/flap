class_name RaceHud
extends Control
## The race's HUD, drawn from RaceRun.state() only (set_state each frame) and the camera: the clock top centre with
## the gate count under it; the last split against your best's at that gate (green ahead, red behind) for a few
## seconds; top right your best time and the average of your last three; a bracket on the next gate with its distance
## (every gate taken: on the start rail, to land on), a fainter one on the gate after, and an arrow at the screen's
## edge when the next is off screen; at the finish, your time and whether it's a best.

const FG := Color(0.95, 0.95, 0.9, 0.95)
const DIM := Color(0.95, 0.95, 0.9, 0.5)
const AHEAD := Color(0.4, 1.0, 0.5, 0.95)
const BEHIND := Color(1.0, 0.45, 0.35, 0.95)
const MARK := Color(1.0, 0.6, 0.2, 0.95)
const SPLIT_SHOWN := 3.0   ## s

var s: Dictionary = {}
var best: Dictionary = {}   ## {time, splits} (empty: none yet)
var average: Array = [INF, 0]   ## RaceRecord.average: [mean s, of how many finishes]
var bird_pos := Vector3.ZERO
var new_best := false
var _split_t := 0.0
var _seen_splits := 0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func set_state(state: Dictionary, pos: Vector3) -> void:
	s = state
	bird_pos = pos
	var n: int = (s.get("splits", []) as Array).size()
	if n != _seen_splits:
		_seen_splits = n
		_split_t = SPLIT_SHOWN if n > 0 else 0.0
	_split_t = maxf(0.0, _split_t - get_process_delta_time())
	queue_redraw()


static func clock_text(t: float) -> String:
	if t == INF:
		return "-:--.-"
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func _draw() -> void:
	if s.is_empty():
		return
	var sz := size
	var top := Vector2(sz.x * 0.5, 54)
	var phase: int = s.phase
	var shown: float = s.time if phase == RaceRun.Phase.FINISHED else s.clock
	_text(top - Vector2(200, 0), clock_text(shown), FG, 40, 400)
	var under := "Gate %d/%d" % [s.next + 1, s.count]
	if phase == RaceRun.Phase.FINISHED:
		under = "Finished"
	elif s.get("home", false):
		under = "Land on the rail"
	_text(top + Vector2(-200, 46), under, FG if s.get("home", false) and phase != RaceRun.Phase.FINISHED else DIM, 20, 400)
	if phase == RaceRun.Phase.READY:
		_text(top + Vector2(-300, 104), "Drop off the rail to start the clock", FG, 22, 600)
	if not best.is_empty():
		_text(Vector2(sz.x - 330, 30), "Best  " + clock_text(best.time), FG, 22, 300, HORIZONTAL_ALIGNMENT_RIGHT)
	if int(average[1]) > 0:
		_text(Vector2(sz.x - 330, 60), "Avg of last %d  %s" % [int(average[1]), clock_text(float(average[0]))], DIM, 20, 300, HORIZONTAL_ALIGNMENT_RIGHT)
	var splits: Array = s.splits
	if _split_t > 0.0 and not splits.is_empty():
		var i := splits.size() - 1
		var t: float = splits[i]
		var line := "Gate %d  %s" % [i + 1, clock_text(t)]
		var col := FG
		if not best.is_empty() and i < (best.splits as Array).size():
			var d: float = t - float(best.splits[i])
			line += "  %+.1f" % d
			col = AHEAD if d <= 0.0 else BEHIND
		_text(top + Vector2(-200, 74), line, col, 22, 400)
	if phase == RaceRun.Phase.FINISHED:
		_text(Vector2(0, sz.y * 0.4), ("New best!  " if new_best else "") + clock_text(s.time), AHEAD if new_best else FG, 44, sz.x)
		return
	if s.has("after_centre") and s.after_centre != null:
		_bracket(s.after_centre, 12.0, Color(MARK, 0.35), false)
	if s.has("next_centre"):
		_bracket(s.next_centre, 18.0, MARK, true)


## A bracket round the gate at `p` on screen (with its distance), or an arrow at the edge pointing to it.
func _bracket(p: Vector3, r: float, col: Color, label: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sz := size
	var behind := cam.is_position_behind(p)
	var sp := cam.unproject_position(p)
	var inset := Rect2(Vector2(40, 40), sz - Vector2(80, 80))
	if not behind and inset.has_point(sp):
		for k in 4:   # (four corners)
			var c := sp + Vector2(r if k % 2 == 0 else -r, r if k < 2 else -r)
			var hx := Vector2(-signf(c.x - sp.x) * r * 0.5, 0)
			var hy := Vector2(0, -signf(c.y - sp.y) * r * 0.5)
			draw_line(c, c + hx, col, 2.0)
			draw_line(c, c + hy, col, 2.0)
		if label:
			_text(sp + Vector2(-40, r + 4), "%.0f m" % bird_pos.distance_to(p), col, 16, 80)
		return
	if not label:
		return
	var centre := sz * 0.5
	var dir := (sp - centre)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var t := minf((inset.size.x * 0.5) / maxf(absf(dir.x), 1e-3), (inset.size.y * 0.5) / maxf(absf(dir.y), 1e-3))
	var at := centre + dir * t
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([at + dir * 16.0, at - dir * 8.0 + side * 12.0, at - dir * 8.0 - side * 12.0]), col)


func _text(pos: Vector2, txt: String, c: Color, fs: int, w: float, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	for o in [Vector2(1, 1), Vector2(-1, 1)]:
		draw_string(_font, pos + o + Vector2(0, fs), txt, align, w, fs, Color(0, 0, 0, 0.7))
	draw_string(_font, pos + Vector2(0, fs), txt, align, w, fs, c)
