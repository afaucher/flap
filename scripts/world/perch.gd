class_name Perch
extends RefCounted
## A place a bird can hold on to (docs/design/flight_model.md, "Perches").
##
## A perch is a GRIP SET, not a point: a BRANCH perch is the line along the top of the branch where feet can
## close (from just clear of the trunk to just short of the tip); a TREETOP perch is a disc on top of the
## trunk. A bird catches the grip point closest to it -- wherever along the branch it arrives -- and sits
## there facing ACROSS the branch toward the side it came from (on a treetop: the way it was flying).
##
## The catch needs the closest grip point within the bird's grab_radius and the bird slower than its
## grab_speed_max. `position` is a representative point (the line's middle, the disc's centre) for spatial
## lookups, AI aiming and spawning; `facing` the default facing there (across the branch / toward the arena
## centre), which is also the side the AI approaches from.

enum Kind { BRANCH, TREETOP }
enum Catch { OUT_OF_RANGE, OK, TOO_FAST }

var id := 0
var kind := Kind.BRANCH
var tree_id := -1
var a := Vector3.ZERO           ## grip line start (BRANCH; the trunk end) or disc centre (TREETOP)
var b := Vector3.ZERO           ## grip line end (BRANCH; the tip end) or disc centre (TREETOP)
var disc := 0.0                 ## TREETOP: grip disc radius
var position := Vector3.ZERO
var facing := Vector3.FORWARD
var thickness := 0.1            ## m, branch radius (visual, drop-off clearance)
var fallback := false           ## an edge post's top: the AI rests there only when nothing else is in reach


## A branch perch: the grip line a..b along the top of the branch.
static func branch(i: int, from: Vector3, to: Vector3, face: Vector3, tree: int, radius: float) -> Perch:
	var p := Perch.new()
	p.id = i
	p.kind = Kind.BRANCH
	p.a = from
	p.b = to
	p.position = (from + to) * 0.5
	p.facing = _flat(face)
	p.tree_id = tree
	p.thickness = radius
	return p


## A treetop perch: a grip disc of `radius` centred on `centre`.
static func treetop(i: int, centre: Vector3, radius: float, face: Vector3, tree: int) -> Perch:
	var p := Perch.new()
	p.id = i
	p.kind = Kind.TREETOP
	p.a = centre
	p.b = centre
	p.disc = radius
	p.position = centre
	p.facing = _flat(face)
	p.tree_id = tree
	p.thickness = radius
	return p


static func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 1e-4 else Vector3.FORWARD


## The grip point nearest to `p`.
func closest_grip(p: Vector3) -> Vector3:
	if kind == Kind.TREETOP:
		var off := Vector3(p.x - a.x, 0.0, p.z - a.z)
		if off.length() > disc:
			off = off.normalized() * disc
		return a + off
	return Geometry3D.get_closest_point_to_segment(p, a, b)


func distance_to(p: Vector3) -> float:
	return p.distance_to(closest_grip(p))


## The grip point nearest the bird's line of flight: where the path from `pos` along `dir` (out to `ahead`
## metres) passes closest to the branch -- the spot straight ahead the bird is flying at, not the nearest
## spot to its body. This is where it lands.
func aim_grip(pos: Vector3, dir: Vector3, ahead: float) -> Vector3:
	var end := pos + dir.normalized() * ahead
	if kind == Kind.TREETOP:
		return closest_grip(Geometry3D.get_closest_point_to_segment(a, pos, end))
	var pts := Geometry3D.get_closest_points_between_segments(pos, end, a, b)
	return pts[1]


## Where an approach should aim: the outer part of a branch (most room around it), a treetop's centre.
func approach_anchor() -> Vector3:
	return a.lerp(b, 0.75) if kind == Kind.BRANCH else position


## Half the grip line's length (0 for a treetop): how far the grip points reach from `position`.
func reach() -> float:
	return a.distance_to(b) * 0.5 if kind == Kind.BRANCH else disc


## Which way a bird sits after arriving moving along `travel`: across the branch toward the side it came
## from (feet wrap round the branch), or on a treetop simply the way it was flying.
func facing_for(travel: Vector3) -> Vector3:
	var t := _flat(travel)
	if kind == Kind.TREETOP or travel.length() < 1e-3:
		return t if travel.length() >= 1e-3 else facing
	var axis := _flat(b - a)
	var across := Vector3.UP.cross(axis).normalized()
	var d := t.dot(across)
	if absf(d) < 0.05:
		return facing
	return across * signf(d)


## The catch envelope: can the feet reach `grip` from `pos`, moving at `vel`? It follows the relative motion
## instead of being a sphere round the bird: the feet swing forward and down, so the reach is long ahead
## (longer the faster the bird is coming in -- it starts its flare earlier), narrow to the sides, deep below,
## shallow above, and nothing behind. Hovering (nearly still), it is a small sphere.
static func in_reach(profile: BirdProfile, pos: Vector3, vel: Vector3, grip: Vector3) -> bool:
	var r := grip - pos
	var reach := profile.grab_radius
	var speed := vel.length()
	if speed < 0.5:
		return r.length() <= reach * 0.6
	var d := vel / speed
	var along := r.dot(d)
	var ahead := reach * (1.0 + 0.4 * clampf(speed / profile.grab_speed_max, 0.0, 1.0))
	if along < -reach * 0.15 or along > ahead:
		return false
	# Off the flight line: split into up/down (in the vertical plane of the path) and sideways.
	var off := r - d * along
	var up_axis := (Vector3.UP - d * d.y)
	up_axis = up_axis.normalized() if up_axis.length() > 1e-3 else Vector3.UP
	var above := off.dot(up_axis)          # + = the grip is above the flight line
	var side := (off - up_axis * above).length()
	var side_reach := reach * 0.55 * (1.0 - 0.4 * clampf(along / ahead, 0.0, 1.0))
	if side > side_reach + maxf(0.0, -above) * 0.3:   # (a perch below the line can be a little further to the side)
		return false
	# The feet reach forward and down from the flight line, barely up. Relative to the path, not to the world:
	# a bird swooping up carries itself to a perch above it.
	return above >= -reach * 0.9 and above <= reach * 0.35


## Can a bird of `profile` at `pos` moving at `vel` catch this perch at `grip` (default: the nearest grip
## point) right now? In the catch envelope (in_reach) and slow enough.
func catch_status(profile: BirdProfile, pos: Vector3, vel: Vector3, grip = null) -> Catch:
	var g: Vector3 = grip if grip != null else closest_grip(pos)
	if not in_reach(profile, pos, vel, g):
		return Catch.OUT_OF_RANGE
	return Catch.OK if vel.length() <= profile.grab_speed_max else Catch.TOO_FAST


## Where a bird's body sits when gripping `grip`.
static func seat_at(grip: Vector3, profile: BirdProfile) -> Vector3:
	return grip + Vector3.UP * (profile.body_length * 0.35)


## The seat at the representative point (spawning on a perch).
func seat(profile: BirdProfile) -> Vector3:
	return seat_at(position, profile)
