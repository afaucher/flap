class_name FlightHud
extends Control
## Basic flight HUD, drawn from the bird's telemetry snapshot only (set_state each frame):
##   SPEED tape (left): marks for stall (red), catch speed (cyan) and best glide (green).
##   PITCH ladder (right): the nose (W mark) and the flight path (circle) against a green IDEAL GLIDE line.
##   ROLL arc (top): the bank needle with red ticks at the bank limit.
##   ENERGY (bottom left): burst (short term) and stamina (medium term) bars.
##   STICK (bottom centre): where the virtual stick is.
##   Prompts (centre): catch / too fast / perched / stall.
##   F3 debug: angle of attack, CL, L/D, load factor and the wing areas (planform after tuck, and the
##   frontal "airbrake" area S_eff |sin alpha|) -- the wing-area readout planned for the full HUD.
## `style` (--hud) picks the layout (docs/images/hud_styles.jpg; classic is the default):
##   dev      all of the above on screen at once
##   classic  the bird's status in the top-left corner (name, burst, stamina; the combat HUD adds health and
##            rounds under it); the instruments (speed tape, pitch ladder, bank arc, stick) only with F3; key hints at the bottom left, fading after a few seconds (F1 brings them
##            back)
##   ring     everything wrapped round the edge of the aim ring (the seeker's lock circle round the point 25 m
##            down the flight path), nothing on the bird: burst and stamina along the top, (the combat HUD)
##            health on the right and rounds along the bottom
##   In both, speed is shown only where it matters, on the perch being caught: the perch is marked only while
##   catch is held (show_perch), with a speed gauge on it -- your speed against the most you can catch at,
##   green when you can, red when too fast. (Stall still has its prompt; the speed tape is under F3.)

const FG := Color(0.92, 0.95, 0.9, 0.9)
const DIM := Color(0.92, 0.95, 0.9, 0.35)
const GOOD := Color(0.35, 1.0, 0.45, 0.95)
const WARN := Color(1.0, 0.75, 0.25, 0.95)
const BAD := Color(1.0, 0.35, 0.3, 0.95)
const CYAN := Color(0.4, 0.9, 1.0, 0.95)

static var style := "classic"   ## "classic" (the game's) | "ring" | "dev" (every instrument on screen)
const STYLES := ["dev", "classic", "ring"]
const HINT_TIME := 8.0      ## s the key hints stay up (classic, ring)
const RING_DEG := 15.0      ## the aim ring: the seeker's lock cone (Launcher.LOCK_CONE), drawn this many deg out
static var ring_centre := Vector2.ZERO   ## this frame's aim ring on screen (the combat HUD draws on it too)
static var ring_r := 0.0
const OUTLINE := Color(0, 0, 0, 0.7)
var debug := false
var hints_left := HINT_TIME
var autopilot := false
var gamepad := false        ## label prompts for the gamepad (else keyboard + mouse)
var _band := -1
var t: Dictionary = {}
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	add_child(BuildVersion.make_label(true))   # (which build: for playtest reports, screenshots and recordings)


func set_state(state: Dictionary) -> void:
	t = state
	hints_left = maxf(0.0, hints_left - get_process_delta_time())
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F1:
		hints_left = HINT_TIME if hints_left <= 0.0 else 0.0


## Whether the scene should mark the candidate perch: always (dev), else only while catch is held.
static func show_perch(catch_armed: bool) -> bool:
	return style == "dev" or catch_armed


## classic: where the combat HUD's status rows go, under the flight HUD's in the top-left block.
static func status_anchor() -> Vector2:
	return Vector2(24, 104)


## The point on the aim ring at angle `a` (screen: 0 right, PI/2 down), `out` px outside it.
static func on_ring(a: float, out := 0.0) -> Vector2:
	return ring_centre + Vector2(cos(a), sin(a)) * (ring_r + out)


func _draw() -> void:
	if t.is_empty():
		return
	var sz := get_viewport_rect().size
	if style != "dev":
		_draw_styled(sz)
		return
	_speed_tape(Vector2(70, sz.y * 0.5))
	_pitch_ladder(Vector2(sz.x - 110, sz.y * 0.5))
	_roll_arc(Vector2(sz.x * 0.5, 120))
	_energy(Vector2(30, sz.y - 90))
	_stick(Vector2(sz.x * 0.5, sz.y - 70))
	_prompts(Vector2(sz.x * 0.5, sz.y * 0.5 + 120))
	_text(Vector2(20, 30), "%s   alt %.1f m%s" % [t.bird, t.altitude, "   [AUTOPILOT]" if autopilot else ""], FG, 18)
	if gamepad:
		_text(Vector2(20, 52), "left stick: bank / pitch   right stick: look   LT: flap   A (hold): catch   Back: bird   Start: respawn   Y: autopilot", DIM, 13)
	else:
		_text(Vector2(20, 52), "mouse: bank / pitch   space: flap   ctrl (hold): catch   1-5 bird   R respawn   P autopilot   F3 debug", DIM, 13)
	if debug:
		_debug(Vector2(sz.x - 330, 40))


func _text(pos: Vector2, s: String, c: Color, fs := 16, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	if style != "dev":   # (an outline, so it reads on the bright haze and sky)
		draw_string_outline(_font, pos, s, align, w, fs, 4, OUTLINE)
	draw_string(_font, pos, s, align, w, fs, c)


## classic / ring: the status where the style puts it, the instruments only with F3. (The perch you'd land on is
## marked in the world: ArenaBuilder.show_candidate.)
func _draw_styled(sz: Vector2) -> void:
	_place_ring(sz)
	if style == "classic":
		_text(Vector2(24, 34), "%s%s" % [t.bird, "   [AUTOPILOT]" if autopilot else ""], FG, 20)
		_text(Vector2(24, 54), "alt %.0f m" % t.altitude, DIM, 14)
		_bars(Vector2(24, 66), 200.0)
	else:
		_text(Vector2(24, 34), "%s   alt %.0f m%s" % [t.bird, t.altitude, "   [AUTOPILOT]" if autopilot else ""], DIM, 15)
		_ring_energy()
	_prompts(Vector2(sz.x * 0.5, sz.y - 120), 17)
	if hints_left > 0.0:
		var a := clampf(hints_left, 0.0, 1.0)
		var line := "left stick: bank / pitch   right stick: look   LT: flap   A (hold): catch   Back: bird   Start: respawn   Y: autopilot" if gamepad else "mouse: bank / pitch   space: flap   ctrl (hold): catch   1-5 bird   R respawn   P autopilot   F1 keys   F3 instruments"
		_text(Vector2(24, sz.y - 24), line, Color(DIM, DIM.a * a * 2.0), 13)
	if debug:
		_speed_tape(Vector2(70, sz.y * 0.5))
		_pitch_ladder(Vector2(sz.x - 110, sz.y * 0.5))
		_roll_arc(Vector2(sz.x * 0.5, 120))
		_stick(Vector2(sz.x * 0.5, sz.y - 190))
		_debug(Vector2(sz.x - 330, 40))


## Burst and stamina as two bars at `o`, `w` wide (thin, without labels, under the screen's middle).
func _bars(o: Vector2, w: float, thin := false) -> void:
	var hgt := 5.0 if thin else 10.0
	var gap := 9.0 if thin else 16.0
	var burst_f: float = float(t.burst) / float(t.burst_max)
	var cap_f: float = float(t.burst_cap) / float(t.burst_max)
	draw_rect(Rect2(o.x - 1, o.y - 1, w + 2, hgt + 2), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(o.x + w * cap_f, o.y, w * (1.0 - cap_f), hgt), Color(0.3, 0.1, 0.1, 0.5))
	draw_rect(Rect2(o.x, o.y, w * burst_f, hgt), Color(1.0, 0.8, 0.3, 0.9))
	draw_rect(Rect2(o.x - 1, o.y + gap - 1, w + 2, hgt + 2), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(o.x, o.y + gap, w * float(t.stamina), hgt), Color(0.35, 0.65, 1.0, 0.9))
	if not thin:
		_text(Vector2(o.x + w + 8, o.y + hgt), "burst", FG, 12)
		_text(Vector2(o.x + w + 8, o.y + gap + hgt), "stamina", FG, 12)


## The aim ring this frame: round the point 25 m down the flight path (perched: where the bird faces), its
## radius the seeker's lock cone; off screen or behind, the screen's middle.
func _place_ring(sz: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	ring_centre = sz * 0.5
	ring_r = 160.0
	if cam == null:
		return
	var dir: Vector3 = t.flight_dir if int(t.state) == Bird.State.FLYING else t.facing
	var at: Vector3 = (t.position as Vector3) + dir * 25.0
	if not cam.is_position_behind(at):
		ring_centre = cam.unproject_position(at)
	ring_r = (sz.y * 0.5) / tan(deg_to_rad(cam.fov) * 0.5) * tan(deg_to_rad(RING_DEG))


## An arc on the aim ring from `a0` to `a1` (rad), filled to `f` of it in `col` over a dark track.
func _ring_arc(a0: float, a1: float, f: float, col: Color, out := 0.0, wd := 4.0) -> void:
	var r := ring_r + out
	draw_arc(ring_centre, r, a0, a1, 24, OUTLINE, wd + 3.0)
	draw_arc(ring_centre, r, a0, a1, 24, Color(0, 0, 0, 0.35), wd)
	if f > 0.001:
		draw_arc(ring_centre, r, a0, lerpf(a0, a1, clampf(f, 0.0, 1.0)), 24, col, wd)


## Burst (inner) and stamina (outer) along the ring's top, left to right.
func _ring_energy() -> void:
	var a0 := -PI * 0.5 - 0.4
	var a1 := -PI * 0.5 + 0.4
	_ring_arc(a0, a1, float(t.burst) / float(t.burst_max), Color(1.0, 0.8, 0.3, 0.9), 0.0, 4.0)
	_ring_arc(a0, a1, float(t.stamina), Color(0.35, 0.65, 1.0, 0.9), 8.0, 3.0)


func _speed_tape(c: Vector2) -> void:
	var h := 260.0
	var vmax: float = t.v_best * 2.5
	var top := c.y - h * 0.5
	draw_rect(Rect2(c.x - 8, top, 16, h), Color(0, 0, 0, 0.25))
	var speed: float = t.speed
	var f := clampf(speed / vmax, 0.0, 1.0)
	var col := GOOD
	if speed < t.v_stall * 1.05:
		col = BAD
	elif speed > t.v_best * 1.6:
		col = WARN
	draw_rect(Rect2(c.x - 8, top + h * (1.0 - f), 16, h * f), Color(col, 0.6))
	for mark in [[t.v_stall, BAD, "stall"], [t.grab_speed, CYAN, "catch"], [t.v_best, GOOD, "glide"]]:
		var y: float = top + h * (1.0 - clampf(mark[0] / vmax, 0.0, 1.0))
		draw_line(Vector2(c.x - 14, y), Vector2(c.x + 14, y), mark[1], 2.0)
		_text(Vector2(c.x + 18, y + 5), mark[2], mark[1], 11)
	_text(Vector2(c.x - 40, top - 12), "%.1f m/s" % speed, FG, 18)
	_band = SpeedBands.band(speed, SpeedBands.cuts(t.v_stall, t.grab_speed, t.v_best), _band)
	if int(t.state) == Bird.State.FLYING:
		_text(Vector2(c.x - 40, top + h + 22), SpeedBands.NAMES[_band], col, 14)
	if float(t.ground_effect) > 0.15:
		_text(Vector2(c.x - 40, top + h + 40), "ground effect", CYAN, 12)


func _pitch_ladder(c: Vector2) -> void:
	var h := 300.0
	var span := deg_to_rad(40.0)   # +-40 deg visible
	var px := h * 0.5 / span
	draw_rect(Rect2(c.x - 50, c.y - h * 0.5, 100, h), Color(0, 0, 0, 0.2))
	for d in range(-40, 41, 10):
		var y := c.y - deg_to_rad(d) * px
		var w := 18.0 if d != 0 else 40.0
		draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), DIM, 1.0)
		if d != 0:
			_text(Vector2(c.x + 26, y + 4), "%d" % d, DIM, 10)
	var gy: float = c.y + float(t.glide_angle) * px
	draw_line(Vector2(c.x - 46, gy), Vector2(c.x + 46, gy), GOOD, 3.0)
	_text(Vector2(c.x - 50, gy + 16), "ideal %.1f" % -rad_to_deg(t.glide_angle), GOOD, 11)
	var path_y := c.y - clampf(float(t.path_angle), -span, span) * px
	var near_ideal: bool = absf(float(t.path_angle) + float(t.glide_angle)) < deg_to_rad(1.5)
	draw_arc(Vector2(c.x, path_y), 8.0, 0, TAU, 20, GOOD if near_ideal else FG, 2.0)
	draw_line(Vector2(c.x - 18, path_y), Vector2(c.x - 8, path_y), FG, 2.0)
	draw_line(Vector2(c.x + 8, path_y), Vector2(c.x + 18, path_y), FG, 2.0)
	var nose_y := c.y - clampf(float(t.nose_pitch), -span, span) * px
	var wpts := PackedVector2Array([Vector2(c.x - 26, nose_y), Vector2(c.x - 13, nose_y + 7), Vector2(c.x, nose_y), Vector2(c.x + 13, nose_y + 7), Vector2(c.x + 26, nose_y)])
	draw_polyline(wpts, WARN, 2.0)
	_text(Vector2(c.x - 50, c.y - h * 0.5 - 10), "path %.1f  nose %.1f" % [rad_to_deg(t.path_angle), rad_to_deg(t.nose_pitch)], FG, 13)


func _roll_arc(c: Vector2) -> void:
	var r := 80.0
	draw_arc(c, r, PI + 0.2, TAU - 0.2, 40, DIM, 2.0)
	for d in [-60, -30, 0, 30, 60]:
		var a := -PI * 0.5 + deg_to_rad(d)
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 6), c + Vector2(cos(a), sin(a)) * (r + 6), DIM, 1.0)
	for s in [-1.0, 1.0]:
		var a: float = -PI * 0.5 + s * float(t.max_bank)
		draw_line(c + Vector2(cos(a), sin(a)) * (r - 10), c + Vector2(cos(a), sin(a)) * (r + 10), BAD, 3.0)
	var bank: float = t.bank
	var at_limit := absf(bank) > float(t.max_bank) - deg_to_rad(1.0)
	var a := -PI * 0.5 + bank
	draw_line(c, c + Vector2(cos(a), sin(a)) * r, WARN if at_limit else FG, 3.0)
	_text(Vector2(c.x - 30, c.y + 22), "bank %.0f" % rad_to_deg(bank), FG, 14)


func _energy(o: Vector2) -> void:
	var w := 200.0
	var burst_f: float = float(t.burst) / float(t.burst_max)
	var cap_f: float = float(t.burst_cap) / float(t.burst_max)
	draw_rect(Rect2(o.x, o.y, w, 12), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(o.x + w * cap_f, o.y, w * (1.0 - cap_f), 12), Color(0.3, 0.1, 0.1, 0.5))   # lost to fatigue
	draw_rect(Rect2(o.x, o.y, w * burst_f, 12), Color(1.0, 0.8, 0.3, 0.85))
	_text(Vector2(o.x + w + 8, o.y + 11), "burst", FG, 12)
	draw_rect(Rect2(o.x, o.y + 22, w, 12), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(o.x, o.y + 22, w * float(t.stamina), 12), Color(0.35, 0.65, 1.0, 0.85))
	_text(Vector2(o.x + w + 8, o.y + 33), "stamina", FG, 12)


func _stick(c: Vector2) -> void:
	var r := 32.0
	draw_rect(Rect2(c.x - r, c.y - r, r * 2, r * 2), Color(0, 0, 0, 0.25))
	draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), DIM, 1.0)
	draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), DIM, 1.0)
	var s: Vector2 = t.stick
	# Pull (+y) draws below centre, like a joystick seen from above.
	var stall_y := c.y + r * FlightModel.STALL_STICK
	draw_line(Vector2(c.x - 8, stall_y), Vector2(c.x + 8, stall_y), BAD, 1.0)
	draw_circle(c + s * r, 4.0, WARN)


func _prompts(c: Vector2, fs := 22) -> void:
	var msg := ""
	var col := FG
	match int(t.state):
		Bird.State.PERCHED:
			msg = "PERCHED  -  %s take off  |  %s let go  |  stick to look around" % [_key("flap"), _key("catch")]
		Bird.State.GROUNDED:
			msg = "ON THE GROUND  -  %s to jump up and fly" % _key("flap")
		Bird.State.LANDING:
			msg = "CAUGHT"
			col = GOOD
		_:
			match int(t.candidate_status):
				Perch.Catch.OK:
					msg = "%s: CATCH" % _key("catch")
					col = GOOD
				Perch.Catch.OUT_OF_RANGE:
					if float(t.candidate_distance) < 8.0:
						msg = "perch ahead  -  hold %s to catch" % _key("catch") if not t.catch_armed else "catch armed"
						col = CYAN if t.catch_armed else DIM
				Perch.Catch.TOO_FAST:
					msg = "TOO FAST - pull up to slow down"
					col = BAD
			if msg == "":
				if t.stalled:
					msg = "STALL - push forward"
					col = BAD
				elif t.stunned:
					msg = "BONK"
					col = WARN
				elif float(t.stamina) < 0.15:
					msg = "EXHAUSTED - find a perch"
					col = WARN
	if msg != "":
		_text(Vector2(c.x - 300, c.y), msg, col, fs, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _debug(o: Vector2) -> void:
	var lines := [
		"alpha %.1f deg (stall %.1f)%s" % [rad_to_deg(t.alpha), rad_to_deg(t.alpha_stall), "  STALLED" if t.stalled else ""],
		"CL %.2f  CD %.3f  L/D %.1f" % [t.cl, t.cd, t.ld],
		"load %.2f g   fold %.2f   flare %.2f" % [t.load, t.fold, t.flare],
		"wing area %.3f m2 -> %.3f effective" % [t.wing_area, t.wing_area_eff],
		"frontal (airbrake) area %.3f m2" % t.frontal_area,
		"burst %.1f / %.1f   stamina %.0f%%" % [t.burst, t.burst_cap, float(t.stamina) * 100.0],
		"bonks %d" % t.bonks,
	]
	draw_rect(Rect2(o.x - 10, o.y - 18, 330, 22 * lines.size() + 10), Color(0, 0, 0, 0.35))
	for i in lines.size():
		_text(o + Vector2(0, i * 22), lines[i], FG, 14)


func _key(action: String) -> String:
	match action:
		"flap": return "LT" if gamepad else "SPACE"
		"catch": return "A" if gamepad else "CTRL"
	return action.to_upper()
