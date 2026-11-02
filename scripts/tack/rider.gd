class_name Rider
extends Node3D
## The pilot: a man in a leather flying helmet and goggles, a leather coat with a sheepskin collar, a silk
## scarf, a Sam Browne belt, khaki riding breeches, tall boots and gauntlets; `height` m tall (7.5 cm: 1:23).
## Rig space, a child of the bird's rig beside the Saddle.
##
## Rigid segments (pelvis, torso, head, upper and lower arms, hands, thighs, shins, feet) placed each frame
## from a small solve, their ends overlapping at the joints:
##   flying (stand 0): a motorcycle racer's tuck -- on the seat, chest down over the launcher, hands on its
##     spade grips, knees into the tank, feet on the side pegs; goggles down; the scarf streams back.
##   perched (stand 1): the bird sits pitched up (up to ~70 deg for a falcon), so the rider stands up on the
##     footrest -- upright in the world, facing the bird's back, hands on the grips -- like a lineman on a pole;
##     goggles pushed up on the helmet, the scarf hanging.
## Legs and arms are two-bone IK to the saddle's pegs and grips; the head looks where the bird looks.

const REAL := {   ## real cm (a 175 cm man)
	"hip_w": 9.5, "spine": 50.0, "shoulder_w": 19.0, "neck": 9.0, "head_r": 10.0,
	"upper_arm": 30.0, "forearm": 27.0, "hand": 9.0, "thigh": 44.0, "shin": 43.0, "ankle": 8.0, "foot": 25.0,
	"seat_lift": 8.0, "lean": 58.0,
}

var height := 0.075
var k := 0.0                     ## model m per real cm
var saddle: Saddle
var stand := 0.0                 ## 0 kneeling in flight .. 1 standing on the footrest
var goggles_up := 0.0
var upright := 0.0
var joints := {}                 ## name -> rig-space point, as last solved (tests)
var _segs := {}                  ## name -> MeshInstance3D
var _goggles: Node3D
var _head: Node3D
var _scarf: MeshInstance3D
var _scarf_mesh := ImmediateMesh.new()
var _scarf_pts: Array[Vector3] = []
var _t := 0.0
const SCARF_N := 10


func build(s: Saddle, h := 0.075) -> void:
	saddle = s
	height = h
	k = h / (TackMesh.REAL_H * 100.0)
	_build_torso()
	_build_head()
	for side in [-1.0, 1.0]:
		_build_arm(side)
		_build_leg(side)
	_scarf = MeshInstance3D.new()
	_scarf.name = "Scarf"
	_scarf.mesh = _scarf_mesh
	_scarf.material_override = TackMaterials.get_mat("silk")
	_scarf.top_level = false
	add_child(_scarf)


func _r(id: String) -> float:
	return float(REAL[id]) * k


func _tmk() -> TackMesh:
	return TackMesh.new(height)


func _mi(seg: String, parts: Dictionary) -> MeshInstance3D:
	## parts: material id -> TackMesh, all in the segment's own frame; one MeshInstance, a surface each.
	var m := ArrayMesh.new()
	var mats := []
	for id in parts:
		(parts[id] as TackMesh).commit(m)
		mats.append(id)
	for i in mats.size():
		m.surface_set_material(i, TackMaterials.get_mat(mats[i]))
	var mi := MeshInstance3D.new()
	mi.name = seg
	mi.mesh = m
	add_child(mi)
	_segs[seg] = mi
	return mi


## Rings along +Y (real cm): [y, half width, half depth, z offset (+ back)], superellipse `n`.
func _loft(tm: TackMesh, rings: Array, around := 16, n := 2.4, cav_at := -1.0) -> void:
	var rows := []
	var uv := []
	var uv2 := []
	var cols := []
	for ring in rings:
		var row := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		var rc := PackedColorArray()
		for j in around:
			var a := TAU * j / around
			var c := cos(a)
			var s := sin(a)
			var x := float(ring[1]) * signf(c) * pow(absf(c), 2.0 / n)
			var z := float(ring[2]) * signf(s) * pow(absf(s), 2.0 / n) + float(ring[3])
			row.append(Vector3(x, float(ring[0]), z) * k)
			ru.append(Vector2(float(ring[0]), a * float(ring[1])))
			ru2.append(Vector2(99.0 if cav_at < 0.0 else absf(float(ring[0]) - cav_at), a * float(ring[1])))
			rc.append(Color(0.3 * maxf(-s, 0.0), 0.0, 0.0, 0.0))
		rows.append(row)
		uv.append(ru)
		uv2.append(ru2)
		cols.append(rc)
	tm.grid(rows, uv, uv2, cols, true, true)


func _build_torso() -> void:
	# Pelvis and hips in breeches; the coat from the hips up; a belt and a cross strap; the sheepskin collar.
	var br := _tmk()
	_loft(br, [[-9.0, 0.0, 0.0, 0.0], [-8.0, 9.0, 7.0, 0.5], [-4.0, 16.0, 11.0, 1.0], [2.0, 17.5, 11.5, 1.0], [8.0, 16.5, 11.0, 0.5]])
	_mi("pelvis", {"breeches": br})
	var coat := _tmk()
	coat.seed = 0.2
	_loft(coat, [[0.0, 18.5, 12.5, 0.8], [8.0, 17.5, 12.0, 0.5], [16.0, 16.0, 11.5, 0.0], [26.0, 17.5, 12.5, -0.5], [36.0, 19.5, 12.8, 0.0], [44.0, 20.5, 11.5, 0.5], [49.0, 16.0, 9.5, 0.5], [51.0, 9.0, 7.0, 0.5], [52.0, 0.0, 0.0, 0.5]], 20, 2.6, 0.0)
	var belt := _tmk()
	belt.seed = 0.6
	var path := PackedVector3Array()
	var ups := PackedVector3Array()
	for j in 25:
		var a := TAU * j / 24.0
		var c := cos(a)
		var s := sin(a)
		var p := Vector3(16.9 * signf(c) * pow(absf(c), 0.8), 14.0, 12.2 * signf(s) * pow(absf(s), 0.8)) * k
		path.append(p)
		ups.append(Vector3(p.x, 0.0, p.z).normalized())
	var sec: Array = belt.strap_section(4.5 * k, 0.6 * k)
	# (the strap section's "up" is out from the body: its sweep frame's y)
	belt.sweep(path, ups, sec[0], true, sec[1], sec[2], PackedFloat32Array([0.3]), false)
	# Cross strap from the left hip, over the right shoulder.
	var cross := PackedVector3Array()
	var cups := PackedVector3Array()
	for j in 13:
		var u := float(j) / 12.0
		var a := lerpf(-PI * 0.62, PI * 0.38, u)   # round the front, from the left hip up to the right shoulder
		var y := lerpf(14.0, 47.0, u)
		var hw := lerpf(17.4, 18.0, u) + 2.2 * sin(u * PI)
		var p := Vector3(hw * cos(a) * 0.95, y, 12.6 * sin(a) + 0.3) * k
		cross.append(p)
		cups.append(Vector3(cos(a), 0.0, sin(a)))
	var sec2: Array = belt.strap_section(3.6 * k, 0.5 * k)
	belt.sweep(cross, cups, sec2[0], true, sec2[1], sec2[2], PackedFloat32Array([0.3]), false)
	var brass := _tmk()
	_box(brass, Vector3(0.0, 14.0, -12.9) * k, Vector3(5.0, 5.0, 0.8) * k)
	for side in [-1.0, 1.0]:
		brass.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0 * k, 0.0), Vector2(1.0 * k, 0.4 * k), Vector2(0.0, 0.7 * k)]), 8, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(side * 3.0, 30.0, -12.6) * k))
	# Sheepskin collar, turned down over the shoulders: a broad band sloping out and down from the neck, open
	# at the throat.
	var collar := _tmk()
	var crow := []
	var cuv := []
	var cuv2 := []
	for i in 3:
		var row := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		for j in 19:
			var a := lerpf(-PI * 0.42, PI * 1.42, float(j) / 18.0)   # (round the back; the gap at the throat)
			var rr := lerpf(8.0, 15.5, i / 2.0)
			var y := lerpf(52.5, 45.0, i / 2.0)
			row.append(Vector3(rr * cos(a) * 1.05, y, rr * sin(a) * 0.8 + 0.5) * k)
			ru.append(Vector2(rr * a, i * 4.0))
			ru2.append(Vector2(99.0, rr * a))
		crow.append(row)
		cuv.append(ru)
		cuv2.append(ru2)
	collar.grid(crow, cuv, cuv2, [], false, false)
	_mi("torso", {"jacket": coat, "strap": belt, "brass": brass, "fleece": collar})


func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "head"
	add_child(_head)
	# The head: lofted from the chin to the crown -- a narrow jaw, cheekbones, the widest above the ears -- with a
	# nose; the helmet covers the top, the goggles the eyes, the moustache the lip.
	var face := _tmk()
	var hr := 9.0
	_loft(face, [[-11.0, 0.0, 0.0, -1.2], [-10.6, 2.6, 2.8, -1.2], [-9.6, 4.6, 5.6, -0.6], [-7.5, 6.4, 7.8, 0.0], [-4.5, 7.4, 8.8, 0.2], [-1.0, 7.9, 9.2, 0.2], [2.5, 8.2, 9.2, 0.2], [5.5, 7.8, 8.6, 0.2], [8.0, 6.2, 7.0, 0.2], [9.6, 3.4, 4.0, 0.2], [10.2, 0.0, 0.0, 0.2]], 20, 2.2)
	face.lathe(_sphere_prof(1.6, 6, 1.7), 10, Transform3D(Basis(Vector3.RIGHT, -PI * 0.38), Vector3(0.0, -2.0, -9.3) * k))
	var helm := _tmk()
	helm.seed = 0.4
	# Helmet shell: the upper back of a slightly bigger sphere, cut level with the brow in front and lower behind.
	var rows := []
	var uv := []
	var uv2 := []
	var R := hr + 2.0
	for i in 11:
		var th := PI * 0.5 * i / 10.0   # from the crown down
		var row := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		for j in 25:
			var a := TAU * j / 24.0
			var back := 0.5 + 0.5 * sin(a)          # 1 behind, 0 in front
			var drop := lerpf(0.8, 1.12, back)      # the brim: down to the brow in front, low at the nape
			var t := th * drop
			var p := Vector3(R * sin(t) * cos(a), R * cos(t) * 1.1, R * sin(t) * sin(a))
			row.append(p * k)
			ru.append(Vector2(R * t, R * a))
			ru2.append(Vector2(R * (PI * 0.5 * drop - t), R * a))
		rows.append(row)
		uv.append(ru)
		uv2.append(ru2)
	helm.grid(rows, uv, uv2, [], false, false)
	# Ear flaps, hanging, with a chin strap.
	for side in [-1.0, 1.0]:
		var flap := PackedVector3Array()
		var fups := PackedVector3Array()
		for j in 7:
			var u := float(j) / 6.0
			flap.append(Vector3(side * (R - 0.3 + 0.4 * u), 1.0 - 9.5 * u, 1.2 - 1.5 * u) * k)
			fups.append(Vector3(side, 0.0, 0.0))
		var prof := PackedVector2Array()
		for j in 10:
			var a := TAU * j / 10.0
			prof.append(Vector2(4.2 * cos(a), 0.6 * sin(a) + 0.6) * k)
		helm.sweep(flap, fups, prof, true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.2]))
	var strap := _tmk()
	var sp := PackedVector3Array()
	var sups := PackedVector3Array()
	for j in 9:
		var a := lerpf(-PI * 0.95, -PI * 0.05, float(j) / 8.0)
		sp.append(Vector3(9.4 * cos(a), -8.0 + 2.0 * absf(cos(a)), 4.5 * sin(a) - 1.0) * k)
		sups.append(Vector3(cos(a), 0.0, sin(a)))
	var ssec: Array = strap.strap_section(1.6 * k, 0.4 * k)
	strap.sweep(sp, sups, ssec[0], true, ssec[1], ssec[2])
	# Moustache.
	var stache := _tmk()
	for side in [-1.0, 1.0]:
		var mp := PackedVector3Array()
		for j in 6:
			var u := float(j) / 5.0
			mp.append(Vector3(side * (0.4 + 4.0 * u), -3.6 + 1.6 * u * u, -8.5 + 2.2 * u * u) * k)
		stache.sweep(mp, PackedVector3Array([Vector3.FORWARD]), TackMesh.circle(0.9 * k, 6), true)
	var mi := _mi("head_mesh", {"skin": face, "helmet": helm, "strap": strap, "boot": stache})
	remove_child(mi)
	_head.add_child(mi)
	# Goggles: two brass-rimmed cups with glass and a strap from each cup's outer rim round the back of the
	# helmet (nothing crosses the face).
	_goggles = Node3D.new()
	_goggles.name = "goggles"
	_head.add_child(_goggles)
	var gband := _tmk()
	var gp := PackedVector3Array()
	var gups := PackedVector3Array()
	var a0 := -0.8   # rad: just behind the right cup's outer rim (the front is -PI/2)
	gp.append(Vector3(6.4, 1.5, -10.6) * k)
	gups.append(Vector3(0.85, 0.0, -0.53))
	for j in 21:
		var a := lerpf(a0, PI - a0, j / 20.0)
		gp.append(Vector3((R + 0.3) * cos(a), 1.5, (R + 0.3) * sin(a)) * k)
		gups.append(Vector3(cos(a), 0.0, sin(a)))
	gp.append(Vector3(-6.4, 1.5, -10.6) * k)
	gups.append(Vector3(-0.85, 0.0, -0.53))
	var gsec: Array = gband.strap_section(2.4 * k, 0.5 * k)
	gband.sweep(gp, gups, gsec[0], true, gsec[1], gsec[2], PackedFloat32Array([0.4]), true)
	var rim := _tmk()
	var glass := _tmk()
	for side in [-1.0, 1.0]:
		var c := Vector3(side * 3.6, 1.5, -(R + 0.6)) * k
		var b := Basis(Vector3.RIGHT, -PI * 0.5).rotated(Vector3.UP, -side * 0.35)
		rim.lathe(PackedVector2Array([Vector2(3.0 * k, -1.2 * k), Vector2(3.3 * k, 0.0), Vector2(3.1 * k, 1.4 * k), Vector2(2.5 * k, 1.6 * k), Vector2(2.4 * k, 1.0 * k)]), 16, Transform3D(b, c))
		glass.lathe(PackedVector2Array([Vector2(2.5 * k, 1.1 * k), Vector2(1.6 * k, 1.5 * k), Vector2(0.0, 1.7 * k)]), 16, Transform3D(b, c))
	rim.sweep(PackedVector3Array([Vector3(-1.2, 1.7, -(R + 1.6)) * k, Vector3(1.2, 1.7, -(R + 1.6)) * k]), PackedVector3Array([Vector3.UP]), TackMesh.circle(0.5 * k, 6), true)
	var gm := ArrayMesh.new()
	gband.commit(gm)
	rim.commit(gm)
	glass.commit(gm)
	gm.surface_set_material(0, TackMaterials.get_mat("strap"))
	gm.surface_set_material(1, TackMaterials.get_mat("brass"))
	gm.surface_set_material(2, TackMaterials.get_mat("glass"))
	var gmi := MeshInstance3D.new()
	gmi.mesh = gm
	_goggles.add_child(gmi)


## A sphere's profile for lathe (radius r real cm, n rows, stretched by `sy` along its axis).
func _sphere_prof(r: float, n: int, sy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := -PI * 0.5 + PI * i / n
		out.append(Vector2(r * cos(a), r * sin(a) * sy) * k)
	return out


func _build_arm(side: float) -> void:
	var sl := _tmk()
	sl.seed = 0.3 + 0.1 * side
	var ua := float(REAL.upper_arm)
	_loft(sl, [[-3.0, 0.0, 0.0, 0.0], [-2.0, 4.0, 4.5, 0.0], [2.0, 6.0, 6.0, 0.0], [ua * 0.5, 5.2, 5.2, 0.0], [ua, 4.6, 4.6, 0.0], [ua + 3.0, 3.0, 3.0, 0.0], [ua + 4.0, 0.0, 0.0, 0.0]], 12, 2.0)
	_mi("upper_arm%d" % int(side > 0), {"jacket": sl})
	var fa := _tmk()
	fa.seed = 0.5
	var fl := float(REAL.forearm)
	_loft(fa, [[-2.0, 0.0, 0.0, 0.0], [-1.0, 4.2, 4.2, 0.0], [fl * 0.4, 4.4, 4.0, 0.0], [fl * 0.7, 3.8, 3.6, 0.0], [fl, 3.4, 3.2, 0.0]], 12, 2.0)
	# The gauntlet's cuff over the sleeve's end.
	var gl := _tmk()
	_loft(gl, [[fl * 0.62, 5.6, 5.4, 0.0], [fl * 0.66, 5.9, 5.7, 0.0], [fl * 0.8, 4.6, 4.4, 0.0], [fl, 3.6, 3.3, 0.0], [fl + 1.0, 3.2, 3.0, 0.0]], 12, 2.0, fl * 0.62)
	_mi("forearm%d" % int(side > 0), {"jacket": fa, "glove": gl})
	# The hand: a mitten round the grip, a thumb.
	var hd := _tmk()
	_loft(hd, [[-1.0, 0.0, 0.0, 0.0], [0.0, 3.6, 2.0, 0.0], [4.0, 4.2, 2.4, 0.3], [8.0, 3.8, 2.6, 0.8], [10.0, 2.0, 1.8, 0.8], [10.5, 0.0, 0.0, 0.8]], 12, 2.6)
	hd.sweep(PackedVector3Array([Vector3(side * -2.5, 2.0, -1.0) * k, Vector3(side * -3.4, 5.5, -2.6) * k]), PackedVector3Array([Vector3.BACK]), TackMesh.circle(1.2 * k, 8), true)
	_mi("hand%d" % int(side > 0), {"glove": hd})


func _build_leg(side: float) -> void:
	var th := _tmk()
	th.seed = 0.4
	var tl := float(REAL.thigh)
	# Riding breeches: full at the thigh, tight at the knee.
	_loft(th, [[-4.0, 0.0, 0.0, 0.0], [-3.0, 7.0, 7.0, 0.0], [4.0, 8.5, 8.0, 0.0], [tl * 0.4, 10.0, 8.5, -0.5], [tl * 0.75, 7.0, 6.5, 0.0], [tl, 5.2, 5.2, 0.0], [tl + 3.0, 4.6, 4.6, 0.0], [tl + 4.0, 0.0, 0.0, 0.0]], 14, 2.0)
	_mi("thigh%d" % int(side > 0), {"breeches": th})
	var sh := _tmk()
	sh.seed = 0.7
	var sl := float(REAL.shin)
	# The boot from below the knee down: shaft, ankle; a knee-cap of breeches at the top.
	var kn := _tmk()
	_loft(kn, [[-3.0, 0.0, 0.0, 0.0], [-2.0, 4.8, 4.8, 0.0], [3.0, 5.0, 5.0, 0.0], [5.0, 5.0, 5.0, 0.0]], 12, 2.0)
	_loft(sh, [[4.0, 5.6, 5.6, 0.0], [5.0, 5.8, 5.8, 0.0], [sl * 0.4, 5.6, 5.8, 0.6], [sl * 0.8, 4.2, 4.4, 0.0], [sl, 4.2, 4.6, 0.0], [sl + 2.0, 4.0, 4.4, 0.0], [sl + 3.0, 0.0, 0.0, 0.0]], 14, 2.0, 4.0)
	_mi("shin%d" % int(side > 0), {"breeches": kn, "boot": sh})
	# The foot: toe forward (-Z), sole, heel.
	var ft := _tmk()
	var fl := float(REAL.foot)
	var rows := []
	for i in 7:
		var u := float(i) / 6.0
		var z := lerpf(4.0, -fl + 4.0, u)
		var w := 4.0 * sqrt(maxf(1.0 - pow(u * 1.05 - 0.05, 8.0), 0.0)) + 0.01
		var h := lerpf(6.5, 3.2, smoothstep(0.0, 0.8, u)) * sqrt(maxf(1.0 - pow(u, 6.0), 0.0)) + 0.01
		rows.append([z, w, h])
	var grid_rows := []
	var uv := []
	var uv2 := []
	for r in rows:
		var row := PackedVector3Array()
		var ru := PackedVector2Array()
		var ru2 := PackedVector2Array()
		for j in 16:
			var a := TAU * j / 16.0
			var c := cos(a)
			var s := sin(a)
			var y := (float(r[2]) * maxf(s, 0.0) - 1.6 * maxf(-s, 0.0) * 0.6) - 0.6
			row.append(Vector3(float(r[1]) * signf(c) * pow(absf(c), 0.6), y - float(REAL.ankle) + 6.0, float(r[0])) * k)
			ru.append(Vector2(float(r[0]), a * 4.0))
			ru2.append(Vector2(99.0 if s > -0.2 else 0.3, float(r[0])))
		grid_rows.append(row)
		uv.append(ru)
		uv2.append(ru2)
	ft.grid(grid_rows, uv, uv2, [], true, true)
	# A spur strap? No -- aviators. A brass buckle on the boot strap at the ankle instead.
	var bk := _tmk()
	_box(bk, Vector3(side * 4.4, -1.0, 0.0) * k, Vector3(0.5, 2.2, 2.6) * k)
	_mi("foot%d" % int(side > 0), {"boot": ft, "brass": bk})


func _box(tm: TackMesh, c: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var prof := PackedVector2Array([Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)])
	tm.sweep(PackedVector3Array([c - Vector3(0, 0, h.z), c + Vector3(0, 0, h.z)]), PackedVector3Array([Vector3.UP]), prof, true, PackedFloat32Array(), PackedFloat32Array(), PackedFloat32Array([0.6]))


# --- Pose ------------------------------------------------------------------------------------------------------

## Solve and place the figure. `stand_t`: 0 kneeling .. 1 standing on the footrest; `upright_t`: kneeling,
## 0 leaning over the launcher .. 1 sitting up straight in the world (a bird at rest on a shallow perch).
## `up`: world up in rig space; `look`: where to look (rig-space direction);
## `wind`: the airflow over the bird (rig space, m/s: minus its velocity); `trunk_scale`: the trunk's fluff
## scale (the saddle rides on it).
func pose(dt: float, stand_t: float, upright_t: float, up: Vector3, look: Vector3, wind: Vector3, trunk_scale := 1.0) -> void:
	_t += dt
	stand = lerpf(stand, stand_t, 1.0 - exp(-4.0 * dt)) if dt > 0.0 else stand_t
	upright = lerpf(upright, upright_t, 1.0 - exp(-4.0 * dt)) if dt > 0.0 else upright_t
	goggles_up = lerpf(goggles_up, upright_t, 1.0 - exp(-3.0 * dt)) if dt > 0.0 else upright_t
	var sc := trunk_scale
	var sp := saddle.seat_point * sc
	var sn := saddle.seat_normal
	var pegs: Array[Vector3] = [saddle.pegs[0] * sc, saddle.pegs[1] * sc]
	var grips: Array[Vector3] = [saddle.grips[0] * sc, saddle.grips[1] * sc]
	var u := up.normalized()
	var fwd := Vector3.FORWARD
	# Seated: on the seat, leaning forward over the launcher. Standing: on the footrest, upright in the world.
	var lean := deg_to_rad(float(REAL.lean))
	var tang := (fwd - sn * fwd.dot(sn)).normalized()
	var t_seat := (sn * cos(lean) + tang * sin(lean)).normalized().slerp(u, upright).normalized()
	var p_seat := sp + sn * _r("seat_lift")
	var leg := _r("thigh") + _r("shin") + _r("ankle")
	var mid_peg := (pegs[0] + pegs[1]) * 0.5
	var p_stand := mid_peg + u * leg * 0.93 + sn * 1.0 * k
	var st := smoothstep(0.0, 1.0, stand)
	var pelvis := p_seat.lerp(p_stand, st) + sn * 6.0 * k * sin(PI * st)   # (lifts clear of the pommel on the way)
	var trunk := t_seat.slerp(u, st).normalized()
	var facing := fwd.slerp(-sn, st)
	var back := -(facing - trunk * facing.dot(trunk)).normalized()
	var pb := Basis(trunk.cross(back).normalized(), trunk, back)
	_place("pelvis", pelvis, pb)
	var chest := pelvis + trunk * _r("spine")
	_place("torso", pelvis, pb)
	# Head: on the neck, looking where asked (no further than the neck allows).
	var neck_top := chest + trunk * _r("neck") * 0.6
	var want := look.normalized() if look.length() > 0.01 else facing
	var lk := (pb.z * -1.0).slerp(want, 0.8).normalized()
	if lk.dot(-pb.z) < 0.2:
		lk = (-pb.z).slerp(want, 0.4).normalized()
	var hz := -lk
	var hx := trunk.cross(hz).normalized()
	var hb := Basis(hx, hz.cross(hx).normalized(), hz)
	var head_c := neck_top + trunk * _r("head_r") * 0.95
	_head.transform = Transform3D(hb, head_c)
	_goggles.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(48.0) * goggles_up), Vector3(0.0, 2.5 * k * goggles_up, 0.0))
	joints.pelvis = pelvis
	joints.chest = chest
	joints.head = head_c
	# Arms to the grips.
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var sh := chest - trunk * 4.0 * k + pb.x * s * _r("shoulder_w")
		var hand: Vector3 = grips[i].lerp(saddle.holds[i] * sc, st)
		var pole := (pb.x * s * 0.8 - trunk * 0.6 + back * 0.4).normalized()
		var el := _ik(sh, hand, _r("upper_arm"), _r("forearm"), pole)
		_place_seg("upper_arm%d" % i, sh, el, back)
		_place_seg("forearm%d" % i, el, hand, back)
		var hd := (hand - el).normalized()
		_place_seg("hand%d" % i, hand - hd * 3.0 * k, hand + hd * 6.0 * k, -sn)
		joints["shoulder%d" % i] = sh
		joints["elbow%d" % i] = el
		joints["hand%d" % i] = hand
	# Legs. Riding (flying): a racer's tuck -- astride the seat, knees forward and pressed into the tank's sides,
	# shins back and down to the side footpegs. Standing (perched): straight-ish down to the footrest, knees
	# toward the bird.
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip := pelvis + pb.x * s * _r("hip_w") - trunk * 2.0 * k
		var heel: Vector3 = saddle.heels[i] * sc
		var ankle := heel.lerp(pegs[i] + u * _r("ankle") * 1.2, st)
		# (kneeling, the knees go forward and out round the seat's sides, not down into the bird)
		var kneel_pole := ((saddle.knees[i] * sc - hip).normalized() + pb.x * s * 0.3).normalized()
		var pole := kneel_pole.slerp((facing + pb.x * s * 0.2).normalized(), st).normalized()
		var kn := _ik(hip, ankle, _r("thigh"), _r("shin"), pole)
		_place_seg("thigh%d" % i, hip, kn, -facing)
		_place_seg("shin%d" % i, kn, ankle, -facing)
		# The foot: on its peg, toes forward and a little down (riding) or in toward the bird (standing).
		var toe_dir := (tang - sn * 0.3).normalized().slerp((facing - u * facing.dot(u)).normalized(), st).normalized()
		var top_dir := sn.slerp(u, st).normalized()
		var fz := -toe_dir
		var fy := (top_dir - fz * top_dir.dot(fz)).normalized()
		_place("foot%d" % i, ankle, Basis(fy.cross(fz).normalized(), fy, fz))
		joints["hip%d" % i] = hip
		joints["knee%d" % i] = kn
		joints["ankle%d" % i] = ankle
	_pose_scarf(dt, chest, back, trunk, wind, u)


## Two-bone IK: the middle joint for a chain a -> c with lengths l1, l2, bent toward `pole`.
static func _ik(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d := c - a
	var dist := clampf(d.length(), absf(l1 - l2) + 1e-5, l1 + l2 - 1e-5)
	var dir := d.normalized()
	var x := (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := (pole - dir * pole.dot(dir)).normalized()
	if side.length() < 0.5:
		side = dir.cross(Vector3.RIGHT).normalized()
	return a + dir * x + side * h


func _place(seg: String, at: Vector3, b: Basis) -> void:
	(_segs[seg] as MeshInstance3D).transform = Transform3D(b, at)


## A segment built along its +Y from a to b (its length baked in), its +Z toward `back`.
func _place_seg(seg: String, a: Vector3, b: Vector3, back: Vector3) -> void:
	var y := (b - a).normalized()
	var z := (back - y * back.dot(y)).normalized()
	if z.length() < 0.5:
		z = y.cross(Vector3.RIGHT).normalized()
	_place(seg, a, Basis(y.cross(z).normalized(), y, z))


## The scarf: a ribbon from the back of the neck, streaming down the airflow (and fluttering) at speed,
## hanging under gravity at rest.
func _pose_scarf(dt: float, chest: Vector3, back: Vector3, trunk: Vector3, wind: Vector3, up: Vector3) -> void:
	var anchor := chest + trunk * 1.0 * k + back * 7.0 * k
	var seg := 8.0 * k
	var spd := wind.length()
	var stream := clampf(spd / 8.0, 0.0, 1.0)
	var flow := wind.normalized() if spd > 0.1 else -up
	if _scarf_pts.size() != SCARF_N:
		_scarf_pts.clear()
		for i in SCARF_N:
			_scarf_pts.append(anchor + (flow * stream - up * (1.0 - stream)).normalized() * seg * i)
	_scarf_pts[0] = anchor
	var side := flow.cross(up).normalized() if absf(flow.dot(up)) < 0.95 else back.cross(up).normalized()
	for i in range(1, SCARF_N):
		var w := float(i) / SCARF_N
		var flutter := (side * sin(_t * 17.0 - i * 0.9) + up * 0.6 * sin(_t * 23.0 - i * 1.3)) * (0.6 * w * stream)
		var sway := side * 0.15 * sin(_t * 1.3 + i * 0.4) * (1.0 - stream)
		var d := (flow * stream * 1.4 - up * (1.0 - stream) + back * 0.25 * (1.0 - stream) + flutter + sway).normalized()
		var want := _scarf_pts[i - 1] + d * seg
		_scarf_pts[i] = want if dt <= 0.0 else _scarf_pts[i].lerp(want, 1.0 - exp(-(8.0 + 20.0 * stream) * dt))
		_scarf_pts[i] = _scarf_pts[i - 1] + (_scarf_pts[i] - _scarf_pts[i - 1]).normalized() * seg
	_scarf_mesh.clear_surfaces()
	_scarf_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SCARF_N:
		var p := _scarf_pts[i]
		var t := (_scarf_pts[mini(i + 1, SCARF_N - 1)] - _scarf_pts[maxi(i - 1, 0)]).normalized()
		var wv := side.slerp(trunk, 0.3).normalized()
		var hw := lerpf(3.5, 4.5, float(i) / SCARF_N) * k
		var n := t.cross(wv).normalized()
		for e in [-1.0, 1.0]:
			_scarf_mesh.surface_set_normal(n)
			_scarf_mesh.surface_set_tangent(Plane(t, 1.0))
			_scarf_mesh.surface_set_color(Color(0.0, 0.0, 0.3, 0.0))
			_scarf_mesh.surface_set_uv(Vector2(i * 8.0, e * 6.0))
			_scarf_mesh.surface_set_uv2(Vector2(6.0 - absf(e) * 6.0 + 0.01, i * 8.0))
			_scarf_mesh.surface_add_vertex(p + wv * hw * e)
	_scarf_mesh.surface_end()
