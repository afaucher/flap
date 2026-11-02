class_name Tack
extends Node3D
## A bird's war tack: the Saddle (with its harness and launcher) and its Rider, fitted to one BirdRig and
## riding on it (a child of the rig, so rig space). Reads only the rig's pose and, when it has one, the Bird's
## state and velocity: visual only, like the rig.
##   var tack := Tack.fit(bird.rig, bird, ["rockets", "seekers"])   # or Tack.fit(rig) in a gallery, setting `sitting` / `wind`
##   tack.set_ammo(rockets, seekers)
##   tack.muzzle_world("rockets", i)   # where round i leaves from

const RIDER_HEIGHT := 0.075   ## m: a 1.75 m man at 1:23
## Species that can carry it. Not the owl: its big head sits right over its shoulders, where the launcher goes
## (it needs a different mount); not the sparrow: a 7.5 cm rider outweighs it.
const RIDDEN: Array[String] = ["crow", "falcon", "hawk"]
const STAND_PITCH := Vector2(38.0, 52.0)   ## deg the back tilts from level, perched: kneel up .. stand

var rig: BirdRig
var bird: Bird
var saddle: Saddle
var rider: Rider
var sitting := false          ## without a Bird: perched (the rider stands)
var wind := Vector3.ZERO      ## without a Bird: the airflow over it, rig space


static func fit(r: BirdRig, b: Bird = null, pods: Array = [], tilt := Saddle.DEFAULT_TILT) -> Tack:
	var t := Tack.new()
	t.name = "Tack"
	t.rig = r
	t.bird = b
	t.saddle = Saddle.new()
	t.saddle.name = "Saddle"
	t.saddle.build(r, RIDER_HEIGHT, pods, tilt)
	t.add_child(t.saddle)
	t.rider = Rider.new()
	t.rider.name = "Rider"
	t.rider.build(t.saddle, RIDER_HEIGHT)
	t.add_child(t.rider)
	r.add_child(t)
	t.update(0.0)
	return t


func set_ammo(rockets: int, seekers: int) -> void:
	saddle.set_ammo(rockets, seekers)


## Rounds the mounts hold of `kind` ("rockets" / "seekers").
func capacity(kind: String) -> int:
	return saddle.capacity(kind)


## Where round `i` of `kind` (in firing order) leaves from, world space.
func muzzle_world(kind: String, i: int) -> Vector3:
	return saddle.global_transform * saddle.round_muzzle(kind, i)


func _process(dt: float) -> void:
	update(dt)


## Ride along: the saddle swells with the plumage (the trunk's fluff and breath scale), the rider kneels in
## flight and stands on the footrest when the bird sits (or, landing, as it pitches up).
func update(dt: float) -> void:
	var sc := rig.fluff * (1.0 + 0.012 * rig.breath)
	saddle.scale = Vector3.ONE * sc
	# At rest the rider sits up; on a steep back (a falcon perches nearly upright) they stand on the footrest.
	var rest := 1.0 if sitting else 0.0
	var air := wind
	if bird != null:
		var s := bird.state
		rest = 1.0 if s == Bird.State.PERCHED or s == Bird.State.GROUNDED else (0.5 if s == Bird.State.LANDING else 0.0)
		air = -(rig.global_transform.basis.inverse() * bird.model.velocity)
	var tilt := rad_to_deg(rig.world_up.angle_to(saddle.seat_normal))
	var stand := rest * smoothstep(STAND_PITCH.x, STAND_PITCH.y, tilt)
	rider.pose(dt, stand, rest, rig.world_up, rig.look_dir, air, sc)
