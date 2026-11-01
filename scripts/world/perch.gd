class_name Perch
extends RefCounted
## A place a bird can hold on to (docs/design/flight_model.md, "Perches").
##
## A perch is a GRIP POINT (where the feet close, on top of the branch or trunk), a FACING (horizontal unit
## vector: where the bird looks once perched -- across the branch, or out over the clearing from a treetop --
## which is also the direction it drops off in on release and the side it is approached from) and the tree
## it belongs to. The catch volume is a sphere of the
## bird's grab_radius around the grip point; the catch also needs the bird slower than its grab_speed_max.

enum Kind { BRANCH, TREETOP }

var id := 0
var position := Vector3.ZERO
var facing := Vector3.FORWARD
var kind := Kind.BRANCH
var tree_id := -1
var thickness := 0.1        ## m, branch radius (visual)


func _init(i := 0, pos := Vector3.ZERO, face := Vector3.FORWARD, k := Kind.BRANCH, tree := -1) -> void:
	id = i
	position = pos
	facing = Vector3(face.x, 0.0, face.z).normalized() if Vector2(face.x, face.z).length() > 1e-4 else Vector3.FORWARD
	kind = k
	tree_id = tree


## Grab check result.
enum Catch { OUT_OF_RANGE, OK, TOO_FAST }


## Can a bird of `profile` at `pos` moving at `vel` catch this perch right now?
func catch_status(profile: BirdProfile, pos: Vector3, vel: Vector3) -> Catch:
	if pos.distance_to(position) > profile.grab_radius:
		return Catch.OUT_OF_RANGE
	return Catch.OK if vel.length() <= profile.grab_speed_max else Catch.TOO_FAST


## Where the bird's body sits while perched (a little above the grip point).
func seat(profile: BirdProfile) -> Vector3:
	return position + Vector3.UP * (profile.body_length * 0.35)


## Where a release starts: out along the facing, clear of the branch or trunk top under the bird.
func drop_off(profile: BirdProfile) -> Vector3:
	return seat(profile) + facing * (thickness + profile.body_length * 0.35 + 0.05)
