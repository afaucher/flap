class_name ChaseCamera
extends Camera3D
## Third-person chase camera: behind and a little above the bird's direction of flight (or where a sitting
## bird faces), rolling a third of the bank, widening its field of view with speed. Pulled in when a trunk is
## between it and the bird. Reads the bird's telemetry and interpolated transform only.
## `look_input` (the right stick, -1..1) orbits it around the bird -- up to LOOK_YAW to the side and
## LOOK_PITCH up or down -- and it springs back when the stick is let go. A sitting bird's look_pitch tilts it.
## zoom_by() (the mouse wheel, in flight) moves it in or out, ZOOM_RANGE times the chase distance, easing there.

const LOOK_YAW := 75.0
const LOOK_PITCH := 35.0
const ZOOM_RANGE := Vector2(0.45, 3.5)   ## the chase distance's scale, closest .. farthest
const ZOOM_STEP := 1.15                  ## per wheel click

var bird: Bird
var distance := 3.2
var height := 0.9
var roll_share := 0.35
var look_input := Vector2.ZERO
var _look := Vector3.FORWARD
var _roll := 0.0
var _orbit := Vector2.ZERO   ## smoothed look_input
var zoom := 1.0              ## where the wheel has set the distance (a scale of it)
var _zoom := 1.0             ## eased toward it


func _ready() -> void:
	# The camera moves every rendered frame (_process) toward the bird's already-interpolated transform, so it
	# must not be physics-interpolated itself (Godot warns when an interpolated camera moves outside physics).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func snap() -> void:
	if bird == null:
		return
	var t := bird.telemetry()
	_look = _look_dir(t)
	_orbit = Vector2.ZERO
	global_position = _desired(bird.global_position, _look)
	look_at(bird.global_position + _look * 3.0, Vector3.UP)


func _look_dir(t: Dictionary) -> Vector3:
	var flying: bool = t.state == Bird.State.FLYING
	var d: Vector3 = t.flight_dir if flying else t.facing
	# Don't stare straight down a vertical dive: keep some horizontal heading.
	var h := Vector3(d.x, 0.0, d.z)
	if h.length() < 0.3:
		h = Vector3(_look.x, 0.0, _look.z)
	var up := clampf(d.y, -0.6, 0.6) if flying else float(t.look_pitch) * 0.5   # (pull back: look up)
	return (h.normalized() * 0.8 + Vector3.UP * up).normalized()


## The look direction swung by the right stick: yaw about world up, then pitch about the camera's right.
func _orbited(look: Vector3) -> Vector3:
	var d := look.rotated(Vector3.UP, -deg_to_rad(LOOK_YAW) * _orbit.x)
	var right := d.cross(Vector3.UP)
	if right.length() > 1e-3:
		d = d.rotated(right.normalized(), -deg_to_rad(LOOK_PITCH) * _orbit.y)
	return d.normalized()


## The wheel: `clicks` out (+) or in (-).
func zoom_by(clicks: float) -> void:
	zoom = clampf(zoom * pow(ZOOM_STEP, clicks), ZOOM_RANGE.x, ZOOM_RANGE.y)


func _desired(target: Vector3, look: Vector3) -> Vector3:
	var scale := clampf(bird.profile.span / 1.0, 0.5, 1.4) * _zoom
	return target - look * distance * scale + Vector3.UP * height * scale


func _process(dt: float) -> void:
	if bird == null:
		return
	var p0 := Perf.t()
	_follow(dt)
	Perf.add("camera", p0)


func _follow(dt: float) -> void:
	_zoom = lerpf(_zoom, zoom, 1.0 - exp(-8.0 * dt))
	var t := bird.telemetry()
	var target := bird.get_global_transform_interpolated().origin
	var want_look := _look_dir(t)
	if _look.dot(want_look) < -0.98:   # (turned right round, a perch faced the other way: slerp has no axis between opposites)
		_look = _look.rotated(Vector3.UP, 0.3).normalized()
	_look = _look.slerp(want_look, 1.0 - exp(-4.0 * dt)).normalized()
	_orbit = _orbit.lerp(look_input, 1.0 - exp(-6.0 * dt))
	var look := _orbited(_look)
	var want := _desired(target, look)
	# Keep a trunk (or the ground) from coming between the camera and the bird.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(target, want, ArenaBuilder.WORLD_LAYER)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = target.lerp(hit.position, 0.85)
	global_position = global_position.lerp(want, 1.0 - exp(-8.0 * dt))
	_roll = lerpf(_roll, float(t.bank) * roll_share, 1.0 - exp(-5.0 * dt))
	var aim := target + look * 3.0
	if global_position.distance_to(aim) > 0.01:
		var fwd := (aim - global_position).normalized()
		var up := Vector3.UP.rotated(fwd, _roll)   # (+ about the view axis rolls the view right, with the bank)
		look_at(aim, up)
	var over: float = maxf(0.0, float(t.speed) - float(t.v_best))
	fov = lerpf(fov, clampf(68.0 + over * 0.9, 68.0, 95.0), 1.0 - exp(-3.0 * dt))
