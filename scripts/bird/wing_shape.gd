class_name WingShape
extends RefCounted
## One species' wing planform, from bones and feathers (docs/design/wing_rig.md, wing_rig_plan.html, which
## draws the same numbers). Works in the TOP-VIEW PLANE of one right wing: x outboard from the body
## centreline, y aft, metres. The rig lifts it into 3D (BirdRig).
##
## Bones: shoulder -> humerus -> elbow -> forearm (ulna + radius) -> wrist -> hand -> hand tip. Their angles
## in the plane come from `fold` alone (elbow and wrist are coupled, as in the real linkage):
##   humerus 30 -> 80 deg, forearm -25 -> -165 deg, hand 8 -> 92 deg (0 = outboard, + = aft), fold 0 -> 1.
## Feathers are defined on a bone: (bone, t along it, angle relative to it, length, width), so they follow
## the bone wherever FK or IK puts it.
##
## calibrate() fits two numbers so the drawn wing IS the flight model's wing: an overall scale so the
## spread tip reaches span / 2, and a chord factor so the planform area (both wings + the body strip
## between them) equals wing_area.

enum Bone { HUMERUS, FOREARM, HAND }
enum Kind { PRIMARY, SECONDARY, TERTIAL, ALULA, GREATER_COVERT, LESSER_COVERT }

## Per species: bone lengths (humerus, forearm, hand) and the longest primary as fractions of the half-span;
## which primary is longest; how fast primaries shorten inward (cin) and outward (cout) of it; emarginated
## (slotted) outer primaries; secondaries; tail shape and resting fan (deg). From the wing research.
const DATA := {
	"hawk": {"arm": [0.20, 0.25, 0.11], "pmax": 0.42, "longest": 7, "cin": 0.5, "cout": 0.32, "slots": 5, "nsec": 14, "tail_shape": "fan", "tail_fan": 70.0, "vestigial10": false},
	"owl": {"arm": [0.19, 0.24, 0.11], "pmax": 0.42, "longest": 7, "cin": 0.45, "cout": 0.34, "slots": 4, "nsec": 14, "tail_shape": "square", "tail_fan": 40.0, "vestigial10": false},
	"crow": {"arm": [0.17, 0.21, 0.13], "pmax": 0.45, "longest": 8, "cin": 0.5, "cout": 0.22, "slots": 4, "nsec": 11, "tail_shape": "rounded", "tail_fan": 45.0, "vestigial10": false},
	"falcon": {"arm": [0.13, 0.17, 0.16], "pmax": 0.52, "longest": 9, "cin": 0.55, "cout": 0.05, "slots": 0, "nsec": 10, "tail_shape": "narrow", "tail_fan": 22.0, "vestigial10": false},
	"sparrow": {"arm": [0.15, 0.18, 0.14], "pmax": 0.48, "longest": 7, "cin": 0.4, "cout": 0.3, "slots": 0, "nsec": 9, "tail_shape": "notched", "tail_fan": 30.0, "vestigial10": true},
}

var profile: BirdProfile
var arm: Array = []
var pmax := 0.45
var longest := 8
var cin := 0.5
var cout := 0.2
var slots := 0
var nsec := 11
var tail_shape := "rounded"
var tail_fan := 45.0
var vestigial10 := false
var scale := 1.0        ## calibrated: overall length scale
var chord := 1.0        ## calibrated: chordwise (feather length) scale for the arm wing
var body_half_width := 0.0
var shoulder := Vector2.ZERO


static func for_profile(p: BirdProfile) -> WingShape:
	var w := WingShape.new()
	w.profile = p
	var d: Dictionary = DATA.get(p.id, DATA["crow"])
	w.arm = d.arm
	w.pmax = d.pmax
	w.longest = d.longest
	w.cin = d.cin
	w.cout = d.cout
	w.slots = d.slots
	w.nsec = d.nsec
	w.tail_shape = d.tail_shape
	w.tail_fan = d.tail_fan
	w.vestigial10 = d.vestigial10
	w.body_half_width = p.body_length * 0.16
	w.shoulder = Vector2(w.body_half_width, -p.body_length * 0.12)
	w.calibrate()
	return w


func half_span() -> float:
	return profile.span * 0.5


func bone_lengths() -> PackedFloat32Array:
	var s := half_span() * scale
	return PackedFloat32Array([arm[0] * s, arm[1] * s, arm[2] * s])


## Primary i (1 = innermost .. 10 = outermost) as a share of the longest.
func primary_shape(i: int) -> float:
	if vestigial10 and i == 10:
		return 0.18
	if i <= longest:
		return 1.0 - cin * pow(float(longest - i) / float(longest - 1), 1.4)
	return 1.0 - cout * pow(float(i - longest) / float(10 - longest), 1.2)


## Bone directions in the plane (deg; 0 = outboard, + = aft) for a fold.
static func bone_angles(fold: float) -> Vector3:
	return Vector3(lerpf(30.0, 80.0, fold), lerpf(-25.0, -165.0, fold), lerpf(8.0, 92.0, fold))


static func dir2(deg: float) -> Vector2:
	return Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))


## Joint positions in the plane: [shoulder, elbow, wrist, hand tip].
func joints(fold: float) -> PackedVector2Array:
	var a := bone_angles(fold)
	var l := bone_lengths()
	var e := shoulder + dir2(a.x) * l[0]
	var w := e + dir2(a.y) * l[1]
	var h := w + dir2(a.z) * l[2]
	return PackedVector2Array([shoulder, e, w, h])


## The feathers of one wing at a fold: Array of Dictionary {kind, i, bone, t, rel (deg, relative to the
## bone's direction, + = aft), len, w, emarg, layer}. `slot` (0..1) splays the emarginated primaries apart.
func feathers(fold: float, slot := 0.0) -> Array:
	var a := bone_angles(fold)
	var s := half_span() * scale
	var pm := pmax * s
	var sec := 0.27 * s * chord
	var out: Array = []
	var first_slot := 10 - slots
	for i in range(1, 11):
		var t := float(i - 1) / 9.0
		var rel := lerpf(lerpf(95.0, 8.0, t), 2.0 + 2.0 * t, fold)
		var emarg := i > first_slot
		if emarg and slots > 1:
			var k := float(i - first_slot - 1) / float(slots - 1) - 0.5   # -0.5 .. 0.5 across the slotted fingers
			rel += -k * 14.0 * slot * (1.0 - fold)
		var length := pm * primary_shape(i)
		out.append({"kind": Kind.PRIMARY, "i": i, "bone": Bone.HAND, "t": t, "rel": rel, "len": length, "w": length * 0.17, "emarg": emarg, "layer": 0.0 + 0.0004 * (10 - i)})
		if i <= 7:
			out.append({"kind": Kind.GREATER_COVERT, "i": i, "bone": Bone.HAND, "t": t, "rel": rel, "len": length * 0.32, "w": length * 0.17 * 1.05, "emarg": false, "layer": 0.006})
	for j in nsec:
		var tp := float(j) / float(maxi(1, nsec - 1))   # 0 at the wrist .. 1 at the elbow
		var ang := lerpf(lerpf(74.0, 90.0, tp), 94.0, fold)
		var length := sec * lerpf(1.0, 0.93, tp)
		out.append({"kind": Kind.SECONDARY, "i": j + 1, "bone": Bone.FOREARM, "t": 1.0 - tp, "rel": ang - a.y, "len": length, "w": sec * 0.24, "emarg": false, "layer": 0.003 + 0.0002 * j})
		out.append({"kind": Kind.GREATER_COVERT, "i": j + 1, "bone": Bone.FOREARM, "t": 1.0 - tp, "rel": ang - a.y, "len": length * 0.45, "w": sec * 0.25, "emarg": false, "layer": 0.006})
	for k in 3:
		out.append({"kind": Kind.TERTIAL, "i": k + 1, "bone": Bone.HUMERUS, "t": 1.0 - (0.12 + 0.22 * k), "rel": lerpf(100.0, 96.0, fold) - a.x, "len": sec * (0.88 - 0.08 * k), "w": sec * 0.26, "emarg": false, "layer": 0.004})
	# Lesser coverts: a row just behind the leading edge (humerus, forearm, hand), pointing aft.
	for k in 4:
		out.append({"kind": Kind.LESSER_COVERT, "i": k, "bone": Bone.HUMERUS, "t": 0.15 + 0.25 * k, "rel": 92.0 - a.x, "len": sec * 0.42, "w": sec * 0.3, "emarg": false, "layer": 0.008})
	for k in 4:
		out.append({"kind": Kind.LESSER_COVERT, "i": 4 + k, "bone": Bone.FOREARM, "t": 0.1 + 0.25 * k, "rel": 92.0 - a.y, "len": sec * 0.4, "w": sec * 0.3, "emarg": false, "layer": 0.008})
	for k in 2:
		out.append({"kind": Kind.LESSER_COVERT, "i": 8 + k, "bone": Bone.HAND, "t": 0.15 + 0.4 * k, "rel": 85.0, "len": pm * 0.22, "w": pm * 0.08, "emarg": false, "layer": 0.008})
	var lm := bone_lengths()[2]
	for k in 3:
		out.append({"kind": Kind.ALULA, "i": k + 1, "bone": Bone.FOREARM, "t": 1.0, "rel": lerpf(-12.0, 18.0, k / 2.0), "len": lm * (0.45 - 0.08 * k), "w": lm * 0.12, "emarg": false, "layer": 0.009})
	return out


## Where a feather sits in the plane: [base, tip].
func feather_points_2d(f: Dictionary, j: PackedVector2Array, fold: float) -> PackedVector2Array:
	var a := bone_angles(fold)
	var seg_a: Vector2
	var seg_b: Vector2
	var ang: float
	match int(f.bone):
		Bone.HUMERUS: seg_a = j[0]; seg_b = j[1]; ang = a.x
		Bone.FOREARM: seg_a = j[1]; seg_b = j[2]; ang = a.y
		_: seg_a = j[2]; seg_b = j[3]; ang = a.z
	var base := seg_a.lerp(seg_b, f.t)
	return PackedVector2Array([base, base + dir2(ang + f.rel) * f.len])


## The planform outline of one spread wing (leading edge, then the trailing edge's feather tips).
func outline(fold := 0.0) -> PackedVector2Array:
	var j := joints(fold)
	var fs := feathers(fold)
	var pts := PackedVector2Array([j[0], j[2], j[3]])
	var prim := {}
	var secs := []
	var terts := []
	for f in fs:
		match int(f.kind):
			Kind.PRIMARY: prim[f.i] = feather_points_2d(f, j, fold)[1]
			Kind.SECONDARY: secs.append(feather_points_2d(f, j, fold)[1])
			Kind.TERTIAL: terts.append(feather_points_2d(f, j, fold)[1])
	for i in range(10, 0, -1):
		pts.append(prim[i])
	for p in secs:
		pts.append(p)
	for p in terts:
		pts.append(p)
	pts.append(Vector2(body_half_width, shoulder.y + root_chord()))
	return pts


func root_chord() -> float:
	return 0.27 * half_span() * scale * chord * 0.85


static func polygon_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5


## Both wings plus the body strip between them, spread.
func drawn_area() -> float:
	return 2.0 * (polygon_area(outline(0.0)) + body_half_width * root_chord())


func drawn_half_span() -> float:
	var m := 0.0
	for p in outline(0.0):
		m = maxf(m, p.x)
	return m


func calibrate() -> void:
	scale = 1.0
	chord = 1.0
	for it in 40:
		scale *= half_span() / drawn_half_span()
		var target_half := profile.wing_area * 0.5 - body_half_width * root_chord()
		chord *= pow(target_half / polygon_area(outline(0.0)), 0.7)
