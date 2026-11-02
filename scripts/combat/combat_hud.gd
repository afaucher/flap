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
##   tally      top right: shots, hits, downed
## Reads the launcher (and through it the birds) and the combat world's stats; draws in screen space.

const INK := Color(1.0, 0.93, 0.75)
const DIM := Color(1.0, 0.93, 0.75, 0.45)
const LOCKED := Color(1.0, 0.45, 0.3)

var launcher: Launcher
var world: CombatWorld
var note := ""             ## a line under the tally (the range shows target evasion on/off)
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or launcher == null or not is_instance_valid(launcher.bird):
		return
	var l := launcher
	var sight := l.muzzle() + l.aim() * 25.0
	var sight_ok := not cam.is_position_behind(sight)
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
			_edge_arrow(cam, tpos)
		else:
			var tp := cam.unproject_position(tpos)
			var r := 18.0
			_bracket(tp, r, LOCKED if l.locked() else INK)
			_bar(Rect2(tp.x - r, tp.y + r + 5, r * 2.0, 4), float(t.telemetry().health), 0)
			_text(tp + Vector2(r + 6, -r + 12), "%d m" % roundi(br.y), INK, 15)
			_text(tp + Vector2(r + 6, -r + 30), "%+.0f" % closing, DIM, 13)
			if l.weapon == Launcher.Weapon.ROCKETS:
				var lead := l.lead_point(t)
				if not cam.is_position_behind(lead):
					var lp := cam.unproject_position(lead)
					draw_dashed_line(tp, lp, DIM, 1.0, 4.0)
					_diamond(lp, 7.0, INK, false)
			elif l.lock_target == t:
				_diamond(tp, lerpf(40.0, 9.0, l.lock), LOCKED if l.locked() else INK, l.locked())
	_rack(l)
	_text(Vector2(size.x - 210, size.y - 77), "HEALTH", INK, 13)
	_bar(Rect2(size.x - 130, size.y - 88, 106, 12), float(l.bird.telemetry().health), Bird.DOWN_FEATHERS)
	if world != null:
		var s := world.stats
		var acc := 100.0 * float(s.hits) / maxf(float(s.shots), 1.0)
		_text(Vector2(size.x - 24, 34), "shots %d   hits %d   downed %d   %d%%" % [s.shots, s.hits, s.kills, roundi(acc)], INK, 15, HORIZONTAL_ALIGNMENT_RIGHT)
		if note != "":
			_text(Vector2(size.x - 24, 54), note, DIM, 13, HORIZONTAL_ALIGNMENT_RIGHT)


## Screen radius (px) of a cone of `deg` around the view centre, for the lock cone.
func _cone_px(cam: Camera3D, deg: float) -> float:
	var f := (size.y * 0.5) / tan(deg_to_rad(cam.fov) * 0.5)
	return f * tan(deg_to_rad(deg))


func _bracket(c: Vector2, r: float, col: Color) -> void:
	var k := r * 0.45
	for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_line(c + Vector2(q.x * r, q.y * (r - k)), c + q * r, col, 2.0)
		draw_line(c + q * r, c + Vector2(q.x * (r - k), q.y * r), col, 2.0)


func _diamond(c: Vector2, r: float, col: Color, fill: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	if fill:
		draw_colored_polygon(pts.slice(0, 4), Color(col, 0.35))
	draw_polyline(pts, col, 2.0)


func _edge_arrow(cam: Camera3D, world_pos: Vector3) -> void:
	var local := cam.global_transform.affine_inverse() * world_pos
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 1e-3:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	var p := c + dir * r
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([p + dir * 14.0, p + n * 9.0, p - n * 9.0]), INK)


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
	draw_string(_font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
