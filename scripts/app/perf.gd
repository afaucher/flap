class_name Perf
extends Node
## Frame profiler: where each rendered frame's time goes (`.\perf.ps1`; game `--perf <seconds>`).
## Code marks sections with `var t0 := Perf.t()` ... `Perf.add("name", t0)`; the times add up per rendered frame
## (a frame may run 0, 1 or 2 physics ticks: their sections land in the frame that ran them). Off (`Perf.on`
## false), a mark costs a clock read and a bool test.
## The recorder (this node, added by the game) closes each frame last in _process and records, per frame:
##   - wall time since the last frame (what the eye sees: steady, or hitching), physics ticks run;
##   - each section's microseconds;
##   - the engine's own process / physics step times, the render thread's CPU and the GPU time, draw calls.
## After a warm-up it records `seconds`, writes `<out>.csv` (one row per frame) and `<out>.txt` (a summary: per
## section mean / p95 / max and its share of the frame; frame pacing -- hitches, ticks per frame; the worst frames
## with what was busiest in each), then quits.

static var on := false
static var _acc := {}
static var _ticks := 0

var seconds := 10.0
var warmup := 3.0
var out := "user://perf"
var _t_last := 0
var _t_start := 0
var _rows: Array = []
var _sections := {}   ## every section name seen
var _vp: RID


static func t() -> int:
	return Time.get_ticks_usec()


static func add(name: String, t0: int) -> void:
	if on:
		_acc[name] = int(_acc.get(name, 0)) + Time.get_ticks_usec() - t0


func _ready() -> void:
	on = true
	process_priority = 100000          # (last of the frame's _process calls)
	process_physics_priority = -100000  # (first of each physics tick: counts it)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	_t_last = Time.get_ticks_usec()
	_t_start = _t_last


func _physics_process(_dt: float) -> void:
	_ticks += 1


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_us := now - _t_last
	_t_last = now
	var row := {
		"t": (now - _t_start) / 1e6,
		"frame_ms": frame_us / 1000.0,
		"ticks": _ticks,
		"engine_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"engine_physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu(),
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_vp),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
	for k in _acc:
		row[k] = int(_acc[k]) / 1000.0
		_sections[k] = true
	_acc.clear()
	_ticks = 0
	var t: float = row.t
	if t >= warmup:
		_rows.append(row)
	if t >= warmup + seconds:
		_write()
		get_tree().quit()


func _write() -> void:
	var cols := ["t", "frame_ms", "ticks", "engine_process_ms", "engine_physics_ms", "render_cpu_ms", "gpu_ms", "draw_calls"]
	var secs: Array = _sections.keys()
	secs.sort()
	cols.append_array(secs)
	var csv := FileAccess.open(out + ".csv", FileAccess.WRITE)
	csv.store_line(",".join(cols))
	for r: Dictionary in _rows:
		var vals := PackedStringArray()
		for c in cols:
			vals.append("%.3f" % float(r.get(c, 0.0)))
		csv.store_line(",".join(vals))
	csv.close()
	var n := _rows.size()
	var lines := PackedStringArray()
	var frames := _col("frame_ms")
	var med := _pct(frames, 0.5)
	lines.append("Flap frame profile: %d frames over %.1f s (after %.0f s warm-up), %s" % [n, seconds, warmup, Engine.get_version_info().string])
	lines.append("display %d Hz, physics %d Hz, vsync %s, max_fps %d" % [int(DisplayServer.screen_get_refresh_rate()), Engine.physics_ticks_per_second, DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	lines.append("")
	lines.append("Frame pacing (wall time between frames, ms): mean %.2f  median %.2f  p95 %.2f  p99 %.2f  max %.2f" % [_mean(frames), med, _pct(frames, 0.95), _pct(frames, 0.99), _pct(frames, 1.0)])
	var hitch := 0
	for f in frames:
		if f > med * 1.5:
			hitch += 1
	lines.append("  hitches (frames over 1.5 x the median): %d (%.1f %%)" % [hitch, 100.0 * hitch / maxf(n, 1)])
	var tk := {}
	for r: Dictionary in _rows:
		tk[int(r.ticks)] = int(tk.get(int(r.ticks), 0)) + 1
	var tks := PackedStringArray()
	var keys := tk.keys()
	keys.sort()
	for k in keys:
		tks.append("%d tick%s: %d" % [k, "" if k == 1 else "s", tk[k]])
	lines.append("  physics ticks per rendered frame: " + ", ".join(tks) + "   (anything but 1 shows as uneven motion for whatever moves only on ticks)")
	lines.append("")
	var total_ticks := 0
	for r: Dictionary in _rows:
		total_ticks += int(r.ticks)
	var per_tick := float(n) / maxf(total_ticks, 1)   # (a section's mean per frame x this = its mean per physics tick)
	lines.append("%-26s %8s %8s %8s %8s %9s" % ["per frame (ms)", "mean", "p95", "max", "share", "per tick"])
	var engine_cols := ["engine_process_ms", "engine_physics_ms", "render_cpu_ms", "gpu_ms"]
	for c in engine_cols:
		var v := _col(c)
		lines.append("%-26s %8.3f %8.3f %8.3f %7.0f%%" % [c, _mean(v), _pct(v, 0.95), _pct(v, 1.0), 100.0 * _mean(v) / maxf(_mean(frames), 1e-6)])
	lines.append("  scripts, by section (summed over the frame's ticks):")
	var by_mean: Array = []
	for s in secs:
		by_mean.append([_mean(_col(s)), s])
	by_mean.sort_custom(func(a, b): return a[0] > b[0])
	for e in by_mean:
		var v := _col(e[1])
		lines.append("  %-24s %8.3f %8.3f %8.3f %7.0f%% %9.3f" % [e[1], _mean(v), _pct(v, 0.95), _pct(v, 1.0), 100.0 * _mean(v) / maxf(_mean(frames), 1e-6), _mean(v) * per_tick])
	lines.append("")
	lines.append("Worst 12 frames:")
	var order: Array = range(n)
	order.sort_custom(func(a, b): return float(_rows[a].frame_ms) > float(_rows[b].frame_ms))
	for i in mini(12, n):
		var r: Dictionary = _rows[order[i]]
		var top: Array = []
		for s in secs:
			top.append([float(r.get(s, 0.0)), s])
		top.sort_custom(func(a, b): return a[0] > b[0])
		var tops := PackedStringArray()
		for e in top.slice(0, 3):
			tops.append("%s %.2f" % [e[1], e[0]])
		lines.append("  t %6.2f s  frame %6.2f ms  ticks %d  process %.2f  physics %.2f  render cpu %.2f  gpu %.2f | %s" % [r.t, r.frame_ms, r.ticks, r.engine_process_ms, r.engine_physics_ms, r.render_cpu_ms, r.gpu_ms, ", ".join(tops)])
	var txt := FileAccess.open(out + ".txt", FileAccess.WRITE)
	txt.store_string("\n".join(lines) + "\n")
	txt.close()
	print("\n".join(lines))


func _col(c: String) -> PackedFloat64Array:
	var v := PackedFloat64Array()
	for r: Dictionary in _rows:
		v.append(float(r.get(c, 0.0)))
	return v


static func _mean(v: PackedFloat64Array) -> float:
	var s := 0.0
	for x in v:
		s += x
	return s / maxf(v.size(), 1)


static func _pct(v: PackedFloat64Array, p: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[clampi(int(round(p * (s.size() - 1))), 0, s.size() - 1)]
