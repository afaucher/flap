class_name ChaseCamera
extends Camera3D
## Third-person chase camera: behind and a little above the bird's direction of flight, rolling a third of
## the bank, widening its field of view with speed. Pulled in when a trunk is between it and the bird.
## Reads the bird's telemetry and interpolated transform only.

var bird: Bird
var distance := 3.2
var height := 0.9
var roll_share := 0.35
var _look := Vector3.FORWARD
var _roll := 0.0


func snap() -> void:
	if bird == null:
		return
	var t := bird.telemetry()
	_look = _look_dir(t)
	global_position = _desired(bird.global_position, _look)
	look_at(bird.global_position + _look * 3.0, Vector3.UP)


func _look_dir(t: Dictionary) -> Vector3:
	var d: Vector3 = t.flight_dir if t.state == Bird.State.FLYING else t.facing
	# Don't stare straight down a vertical dive: keep some horizontal heading.
	var h := Vector3(d.x, 0.0, d.z)
	if h.length() < 0.3:
		h = Vector3(_look.x, 0.0, _look.z)
	return (h.normalized() * 0.8 + Vector3.UP * clampf(d.y, -0.6, 0.6)).normalized()


func _desired(target: Vector3, look: Vector3) -> Vector3:
	var scale := clampf(bird.profile.span / 1.0, 0.5, 1.4)
	return target - look * distance * scale + Vector3.UP * height * scale


func _process(dt: float) -> void:
	if bird == null:
		return
	var t := bird.telemetry()
	var target := bird.get_global_transform_interpolated().origin
	_look = _look.slerp(_look_dir(t), 1.0 - exp(-4.0 * dt)).normalized()
	var want := _desired(target, _look)
	# Keep a trunk from coming between the camera and the bird.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(target, want, ArenaBuilder.WORLD_LAYER)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		want = target.lerp(hit.position, 0.85)
	global_position = global_position.lerp(want, 1.0 - exp(-8.0 * dt))
	_roll = lerpf(_roll, float(t.bank) * roll_share, 1.0 - exp(-5.0 * dt))
	var aim := target + _look * 3.0
	if global_position.distance_to(aim) > 0.01:
		var fwd := (aim - global_position).normalized()
		var up := Vector3.UP.rotated(fwd, _roll)   # (+ about the view axis rolls the view right, with the bank)
		look_at(aim, up)
	var over: float = maxf(0.0, float(t.speed) - float(t.v_best))
	fov = lerpf(fov, clampf(68.0 + over * 0.9, 68.0, 95.0), 1.0 - exp(-3.0 * dt))
