class_name CombatHud
extends Control
## The weapons layer of the HUD (docs/design/concept_briefs.html, "The HUD vocabulary"):
##   gunsight   a ring where the launcher points, 25 m out
##   lead       ROCKETS: a small diamond where to put the gunsight so a rocket meets the target
##   lock       SEEKERS: the lock cone around the gunsight, and a diamond on the target closing in as the lock
##              builds; solid when locked
##   bracket    on the target: range and closing speed
##   arrow      at the screen edge when the target is off-screen or behind
##   rack       bottom right: the rounds left of each weapon carried, the selected one bright
##   health     over the rack: your bird's feathers (Bird.health), a notch per feather it can lose; and a short bar
##              under the target's bracket
##   teams      enemies in ENEMY (the target's bracket; a small mark on the others), teammates a FRIEND caret above
##              them with no range, both as arrows at the screen's edge when off it; a FRIEND cross on the
##              gunsight while a teammate is in the line of fire (CombatWorld.friend_in_line)
##   warnings   round the aim ring, toward the threat: a red chevron for a lock building on you (solid once
##              locked), a red arrowhead for a round coming at you, pulsing faster as it closes, and "LOCK" /
##              "INCOMING" under the ring (CombatWorld.warnings_for: what any AI is told, too)
##   score      top right: your side's downed enemies (FRIEND) against theirs (ENEMY), when there are teams
##   tally      top right: shots, hits, downed (dev)
##   home       out of rounds or hurt: a marker on your base (where you rearm and mend), or an arrow at the edge
## Reads the launcher (and through it the birds) and the combat world's stats; draws in screen space.

const INK := Color(1.0, 0.93, 0.75)
const DIM := Color(1.0, 0.93, 0.75, 0.45)
const LOCKED := Color(1.0, 0.3, 0.25)
const ENEMY := Color(1.0, 0.62, 0.32)    ## warm: the other side
const FRIEND := Color(0.35, 0.92, 0.85)  ## cool: your side

var launcher: Launcher
var world: CombatWorld
var drew_lead := false     ## (tests) whether the last frame drew a lead mark
var note := ""             ## a line under the tally (the range shows target evasion on/off)
var home: Variant = null   ## your base's perch (world), for the way home
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	drew_lead = false
	if FlightHud.style != "dev":
		_draw_styled()
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or launcher == null or not is_instance_valid(launcher.bird):
		return
	var l := launcher
	var sight := l.muzzle() + l.aim() * 25.0
	var sight_ok := l.can_aim() and not cam.is_position_behind(sight)   # (perched: no aiming, so no sight, lead or lock)
	var sp := cam.unproject_position(sight)
	if sight_ok:
		draw_arc(sp, 12.0, 0, TAU, 32, INK, 2.0)
		draw_line(sp + Vector2(-24, 0), sp + Vector2(-15, 0), INK, 2.0)
		draw_line(sp + Vector2(15, 0), sp + Vector2(24, 0), INK, 2.0)
		draw_circle(sp, 1.8, INK)
	var t := l.target()
	if l.weapon == Launcher.Weapon.SEEKERS and sight_ok:
		var cone := _cone_px(cam, Launcher.LOCK_CONE)
		draw_arc(sp, cone, 0, TAU, 64, DIM, 1.5)
	if t != null:
		var tpos: Vector3 = t.global_position
		var br := l.bearing(t)
		var closing := -(Projectile.velocity_of(t) - l.bird.model.velocity).dot((tpos - l.muzzle()).normalized())
		if cam.is_position_behind(tpos) or not get_viewport_rect().has_point(cam.unproject_position(tpos)):
			_edge_arrow(cam, tpos, ENEMY)
		else:
			var tp := cam.unproject_position(tpos)
			var r := 18.0
			_bracket(tp, r, LOCKED if l.locked() else ENEMY)
			_bar(Rect2(tp.x - r, tp.y + r + 5, r * 2.0, 4), float(t.telemetry().health), 0)
			_text(tp + Vector2(r + 6, -r + 12), "%d m" % roundi(br.y), INK, 15)
			_text(tp + Vector2(r + 6, -r + 30), "%+.0f" % closing, DIM, 13)
			if not l.can_aim():
				pass
			elif l.weapon == Launcher.Weapon.ROCKETS:
				drew_lead = true
				var lead := l.lead_point(t)
				if not cam.is_position_behind(lead):
					var lp := cam.unproject_position(lead)
					draw_dashed_line(tp, lp, DIM, 1.0, 4.0)
					_diamond(lp, 7.0, INK, false)
			elif l.lock_target == t:
				_diamond(tp, lerpf(40.0, 9.0, l.lock), LOCKED if l.locked() else INK, l.locked())
	_teams(cam, l, t, sp if sight_ok else Vector2.INF)
	_warnings(cam, l)
	_rack(l)
	if home != null and l.bird.state != Bird.State.PERCHED and (_empty(l) or l.bird.health() < 1.0):
		_home_marker(cam, home, l.bird.global_position.distance_to(home))
	_text(Vector2(size.x - 210, size.y - 77), "HEALTH", INK, 13)
	_bar(Rect2(size.x - 130, size.y - 88, 106, 12), float(l.bird.telemetry().health), Bird.DOWN_FEATHERS)
	if world != null:
		_score(Vector2(size.x - 24, 78))
		var s := world.stats
		var acc := 100.0 * float(s.hits) / maxf(float(s.shots), 1.0)
		_text(Vector2(size.x - 24, 34), "shots %d   hits %d   downed %d   %d%%" % [s.shots, s.hits, s.kills, roundi(acc)], INK, 15, HORIZONTAL_ALIGNMENT_RIGHT)
		if note != "":
			_text(Vector2(size.x - 24, 54), note, DIM, 13, HORIZONTAL_ALIGNMENT_RIGHT)


## Screen radius (px) of a cone of `deg` around the view centre, for the lock cone.
func _cone_px(cam: Camera3D, deg: float) -> float:
	var f := (size.y * 0.5) / tan(deg_to_rad(cam.fov) * 0.5)
	return f * tan(deg_to_rad(deg))


func _bracket(c: Vector2, r: float, col: Color, wd := 2.0) -> void:
	var k := r * 0.45
	for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_line(c + Vector2(q.x * r, q.y * (r - k)), c + q * r, col, wd)
		draw_line(c + q * r, c + Vector2(q.x * (r - k), q.y * r), col, wd)


func _diamond(c: Vector2, r: float, col: Color, fill: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	if fill:
		draw_colored_polygon(pts.slice(0, 4), Color(col, 0.35))
	draw_polyline(pts, col, 2.0)


## Where the warnings go: [[screen point, "lock" | "locked" | "round", strength 0..1]], each on a circle round
## the aim ring (the screen's middle in the dev HUD) in the direction the threat is, seen from the camera.
func warning_marks(cam: Camera3D, l: Launcher) -> Array:
	if world == null or l == null or not is_instance_valid(l.bird):
		return []
	var w := world.warnings_for(l.bird)
	var c := FlightHud.ring_centre if FlightHud.style != "dev" and FlightHud.ring_r > 0.0 else size * 0.5
	var r := (FlightHud.ring_r if FlightHud.style != "dev" and FlightHud.ring_r > 0.0 else minf(size.x, size.y) * 0.3) + 34.0
	var out := []
	for k in w.locks:
		out.append([c + _screen_dir(cam, k.from) * r, "locked" if k.locked else "lock", float(k.lock)])
	for q in w.rounds:
		out.append([c + _screen_dir(cam, q.pos) * r, "round", clampf(1.0 - float(q.tgo) / 1.5, 0.0, 1.0)])
	return out


## The direction of `at` on screen from the view's middle (behind the camera too), unit.
static func _screen_dir(cam: Camera3D, at: Vector3) -> Vector2:
	var local := cam.global_transform.affine_inverse() * at
	var d := Vector2(local.x, -local.y)
	return d.normalized() if d.length() > 1e-4 else Vector2(0, 1)


func _warnings(cam: Camera3D, l: Launcher) -> void:
	var marks := warning_marks(cam, l)
	if marks.is_empty():
		return
	var clock := Time.get_ticks_msec() / 1000.0
	var words := {}
	for m in marks:
		var p: Vector2 = m[0]
		var kind: String = m[1]
		var k: float = m[2]
		var c := FlightHud.ring_centre if FlightHud.style != "dev" and FlightHud.ring_r > 0.0 else size * 0.5
		var dir := (c - p).normalized()   # (pointing in, toward you)
		var n := Vector2(-dir.y, dir.x)
		if kind == "round":
			var pulse := 0.55 + 0.45 * sin(clock * lerpf(8.0, 30.0, k))
			var s := lerpf(15.0, 24.0, k)
			var tri := func(sz: float) -> PackedVector2Array:
				return PackedVector2Array([p + dir * sz, p - dir * sz * 0.6 + n * sz * 0.8, p - dir * sz * 0.6 - n * sz * 0.8])
			draw_colored_polygon(tri.call(s + 4.0), Color(1, 0.93, 0.85, 0.85))   # (a light rim: it reads on dark bark and on sky)
			draw_colored_polygon(tri.call(s), Color(LOCKED.r, LOCKED.g, LOCKED.b, 0.6 + 0.4 * pulse))
			words["INCOMING"] = true
		else:
			var locked := kind == "locked"
			var pts := PackedVector2Array([p - dir * 9.0 + n * 16.0, p + dir * 7.0, p - dir * 9.0 - n * 16.0])
			draw_polyline(pts, Color(1, 0.93, 0.85, 0.85), 9.0)
			draw_polyline(pts, Color(LOCKED, 1.0 if locked else 0.6 + 0.4 * sin(clock * 10.0)), 5.0)
			words["LOCKED" if locked else "LOCK"] = true
	var c2 := FlightHud.ring_centre if FlightHud.style != "dev" and FlightHud.ring_r > 0.0 else size * 0.5
	var r2 := (FlightHud.ring_r if FlightHud.style != "dev" and FlightHud.ring_r > 0.0 else minf(size.x, size.y) * 0.3) + 64.0
	var label := "INCOMING" if words.has("INCOMING") else ("LOCKED" if words.has("LOCKED") else "LOCK")
	_text(c2 + Vector2(0, r2) - Vector2(_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, 0), label, LOCKED, 20)


## Friend and foe on the other birds (`t`, the bracketed target, has its own mark): a FRIEND caret over each
## teammate, a small ENEMY mark on each other enemy, an arrow at the edge for those off screen; and the FRIEND
## cross over the gunsight `sp` while a teammate is in the line of fire.
func _teams(cam: Camera3D, l: Launcher, t: Bird, sp: Vector2) -> void:
	if world == null:
		return
	for b in world.birds:
		if not is_instance_valid(b) or b == l.bird or b == t:
			continue
		var friend := world.friends(b, l.bird)
		var col := FRIEND if friend else ENEMY
		var at: Vector3 = (b as Bird).global_position
		if cam.is_position_behind(at) or not get_viewport_rect().has_point(cam.unproject_position(at)):
			_edge_arrow(cam, at, col, 0.7)
			continue
		var p := cam.unproject_position(at)
		if friend:
			var c := p + Vector2(0, -22)
			var pts := PackedVector2Array([c + Vector2(-11, -8), c, c + Vector2(11, -8)])
			draw_polyline(pts, Color(0, 0, 0, 0.6), 6.0)
			draw_polyline(pts, col, 3.0)
		else:
			_bracket(p, 11.0, Color(0, 0, 0, 0.5), 4.0)
			_bracket(p, 10.0, Color(col, 0.8), 2.0)
	if sp != Vector2.INF and world.friend_in_line(l) != null:
		for pass_i in 2:
			var c: Color = Color(0, 0, 0, 0.6) if pass_i == 0 else FRIEND
			var wd := 6.0 if pass_i == 0 else 3.0
			draw_line(sp + Vector2(-16, -16), sp + Vector2(16, 16), c, wd)
			draw_line(sp + Vector2(-16, 16), sp + Vector2(16, -16), c, wd)


func _edge_arrow(cam: Camera3D, world_pos: Vector3, col := INK, scale_by := 1.0) -> Vector2:
	var local := cam.global_transform.affine_inverse() * world_pos
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 1e-3:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	var p := c + dir * r
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([p + dir * 14.0 * scale_by, p + n * 9.0 * scale_by, p - n * 9.0 * scale_by]), col)
	return p


func _empty(l: Launcher) -> bool:
	return int(l.ammo[Launcher.Weapon.ROCKETS]) + int(l.ammo[Launcher.Weapon.SEEKERS]) == 0


## The way home: a house mark on the base, or an arrow at the screen's edge toward it, with the distance.
func _home_marker(cam: Camera3D, at: Vector3, dist: float) -> void:
	var label := "BASE %d m" % roundi(dist)
	if cam.is_position_behind(at) or not get_viewport_rect().has_point(cam.unproject_position(at)):
		var p := _edge_arrow(cam, at)
		_text(p + Vector2(-30, 28), label, INK, 13)
		return
	var c := cam.unproject_position(at)
	draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-9, 10), c + Vector2(9, 10), c + Vector2(9, 0), c + Vector2(0, -9), c + Vector2(-9, 0)]), INK, 2.0)
	_text(c + Vector2(14, 6), label, INK, 13)


## classic / ring: the same marks, outlined; your health and rounds in the top-left block (classic) or on the
## aim ring (ring: health on its right, rounds along its bottom).
func _draw_styled() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or launcher == null or not is_instance_valid(launcher.bird):
		return
	var l := launcher
	var sight := l.muzzle() + l.aim() * 25.0
	var sight_ok := l.can_aim() and not cam.is_position_behind(sight)   # (perched: no aiming, so no sight, lead or lock)
	var sp := cam.unproject_position(sight)
	if sight_ok:
		for pass_i in 2:
			var col: Color = Color(0, 0, 0, 0.6) if pass_i == 0 else INK
			var wd := 4.0 if pass_i == 0 else 2.0
			draw_arc(sp, 12.0, 0, TAU, 32, col, wd)
			draw_line(sp + Vector2(-24, 0), sp + Vector2(-15, 0), col, wd)
			draw_line(sp + Vector2(15, 0), sp + Vector2(24, 0), col, wd)
	var t := l.target()
	if l.weapon == Launcher.Weapon.SEEKERS and sight_ok:
		var rc := FlightHud.ring_centre if FlightHud.style == "ring" else sp   # (one circle: the ring is the lock cone)
		draw_arc(rc, _cone_px(cam, Launcher.LOCK_CONE), 0, TAU, 64, Color(DIM, 0.3), 1.5)
	if t != null:
		var tpos: Vector3 = t.global_position
		var br := l.bearing(t)
		if cam.is_position_behind(tpos) or not get_viewport_rect().has_point(cam.unproject_position(tpos)):
			_edge_arrow(cam, tpos, ENEMY)
		else:
			var tp := cam.unproject_position(tpos)
			var r := 20.0
			_bracket(tp, r + 1.0, Color(0, 0, 0, 0.6), 5.0)
			_bracket(tp, r, LOCKED if l.locked() else ENEMY, 2.5)
			_text(tp + Vector2(r + 6, -r + 12), "%d m" % roundi(br.y), INK, 15)
			_bar(Rect2(tp.x - r, tp.y + r + 6, r * 2.0, 5), float(t.telemetry().health), 0)
			if not l.can_aim():
				pass
			elif l.weapon == Launcher.Weapon.ROCKETS:
				drew_lead = true
				var lead := l.lead_point(t)
				if not cam.is_position_behind(lead):
					var lp := cam.unproject_position(lead)
					draw_dashed_line(tp, lp, DIM, 1.0, 4.0)
					_diamond(lp, 7.0, INK, false)
			elif l.lock_target == t:
				_diamond(tp, lerpf(40.0, 9.0, l.lock), LOCKED if l.locked() else INK, l.locked())
	_teams(cam, l, t, sp if sight_ok else Vector2.INF)
	_warnings(cam, l)
	# Your health and rounds.
	var kind := Launcher.Weapon.ROCKETS if int(l.capacity[Launcher.Weapon.ROCKETS]) > 0 else Launcher.Weapon.SEEKERS
	var n := int(l.capacity[kind])
	var health := float(l.bird.telemetry().health)
	if FlightHud.style == "ring":
		_ring_health(health)
		_ring_rounds(n, int(l.ammo[kind]))
	else:
		var o := FlightHud.status_anchor()
		var w := 200.0
		_bar(Rect2(o.x, o.y, w, 12), health, Bird.DOWN_FEATHERS)
		_text(Vector2(o.x + w + 8, o.y + 11), "health", INK, 12)
		var pip := Vector2(12, 16)
		var y := o.y + 22
		for k in n:
			var rr := Rect2(o.x + k * (pip.x + 5), y, pip.x, pip.y)
			draw_rect(rr.grow(1.0), Color(0, 0, 0, 0.5))
			draw_rect(rr, INK if k < int(l.ammo[kind]) else Color(0, 0, 0, 0.0))
			draw_rect(rr, DIM, false, 1.0)
		_text(Vector2(o.x + n * (pip.x + 5) + 6, y + pip.y - 2), "rockets" if kind == Launcher.Weapon.ROCKETS else "seekers", INK, 12)
	if home != null and l.bird.state != Bird.State.PERCHED and (_empty(l) or l.bird.health() < 1.0):
		_home_marker(cam, home, l.bird.global_position.distance_to(home))
	if world != null:
		_score(Vector2(size.x - 24, 38))


## The score at `p` (right aligned): your side's downed enemies, in FRIEND, against the other side's, in ENEMY.
func _score(p: Vector2) -> void:
	if world == null or launcher == null or world.score.size() < 2:
		return
	var mine := int(world.teams.get(launcher.bird, -1))
	var ours := int(world.score.get(mine, 0))
	var theirs := 0
	for team in world.score:
		if team != mine:
			theirs += int(world.score[team])
	var right := "%d" % theirs
	var wr := _font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var wc := _font.get_string_size(" : ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_text(p, right, ENEMY, 26, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(p - Vector2(wr, 0), " : ", INK, 26, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(p - Vector2(wr + wc, 0), "%d" % ours, FRIEND, 26, HORIZONTAL_ALIGNMENT_RIGHT)


## Health on the aim ring's right: a segment per feather the bird can lose, the remaining ones lit from the
## bottom up, red when low.
func _ring_health(h: float) -> void:
	var c := FlightHud.ring_centre
	var r := FlightHud.ring_r
	var n := Bird.DOWN_FEATHERS
	var a_bot := 0.6
	var a_top := -0.6
	var step := (a_top - a_bot) / n
	var lit := roundi(h * n)
	draw_arc(c, r, a_top, a_bot, 32, Color(0, 0, 0, 0.7), 7.0)
	for k in n:
		var s0 := a_bot + step * k + step * 0.08
		var s1 := a_bot + step * (k + 1) - step * 0.08
		var col: Color = (LOCKED if h <= 0.375 else INK) if k < lit else Color(0, 0, 0, 0.35)
		draw_arc(c, r, minf(s0, s1), maxf(s0, s1), 6, col, 4.0)


## Rounds along the aim ring's bottom: a tick each, lit while loaded.
func _ring_rounds(n: int, left: int) -> void:
	var c := FlightHud.ring_centre
	var r := FlightHud.ring_r
	for k in n:
		var a := PI * 0.5 + (k - (n - 1) * 0.5) * 0.1
		var p0 := c + Vector2(cos(a), sin(a)) * (r - 6.0)
		var p1 := c + Vector2(cos(a), sin(a)) * (r + 8.0)
		draw_line(p0, p1, Color(0, 0, 0, 0.7), 7.0)
		draw_line(p0, p1, INK if k < left else Color(DIM, 0.25), 4.0)


## A health bar: filled to `h` (0..1), red when low; `notches` marks between the feathers it counts.
func _bar(r: Rect2, h: float, notches: int) -> void:
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(r.position, Vector2(r.size.x * h, r.size.y)), LOCKED if h <= 0.375 else INK)
	for k in range(1, notches):
		var x := r.position.x + r.size.x * k / notches
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.5), 1.0)
	draw_rect(r, DIM, false, 1.0)


func _rack(l: Launcher) -> void:
	var base := Vector2(size.x - 210, size.y - 64)
	var rows := []
	for row in [[Launcher.Weapon.ROCKETS, "ROCKETS"], [Launcher.Weapon.SEEKERS, "SEEKERS"]]:
		if int(l.capacity[row[0]]) > 0:
			rows.append(row)
	for i in rows.size():
		var w: int = rows[i][0]
		var sel := l.weapon == w
		var y := base.y + i * 24
		_text(Vector2(base.x, y + 13), rows[i][1], INK if sel else DIM, 13)
		var n := int(l.capacity[w])
		for k in n:
			var r := Rect2(base.x + 80 + k * 18, y + 1, 12, 14)
			if k < int(l.ammo[w]):
				draw_rect(r, INK if sel else DIM)
			else:
				draw_rect(r, DIM, false, 1.0)


func _text(p: Vector2, s: String, c: Color, fs := 15, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		p.x -= w
	if FlightHud.style != "dev":
		draw_string_outline(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
