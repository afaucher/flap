class_name LegRig
extends RefCounted
## The detailed legs and feet (docs/design/legs_and_feet.md; research: docs/research/legs_and_feet.md), behind
## `LegRig.enabled` (rig gallery `--legs detail`). It draws what BirdRig's leg solve gives it -- hip, knee, ankle,
## foot per side, the world frame, toe_grip and the owl's toe swing -- as continuous lofted surfaces, every join
## an edge loop on the surface it leaves, as the arm wing and the neck join the trunk:
##
##   trunk shell --(edge loop on the shell)--> feathered tibia ("trousers") --(the hem ring tucks onto the skin)-->
##   bare tarsus --(edge loop on the foot pad)--> foot pad <--(edge loop on the pad)-- each toe, its pads bulging
##   under the joints, running on into its claw.
##
## - The FEATHER tube starts at a loop of points on the trunk's surface round where the tibia leaves it (the trunk's
##   own colours and feather coordinates there), lofts down the tibia and ends in a skirt below the ankle whose
##   last ring lies on the tarsus: the bare skin's tube starts from that same ring. On the owl it runs on down the
##   tarsus to a loop on the foot pad (feathered to the toes).
## - The SKIN is one mesh: the tarsus, the foot pad (an ellipsoid at the foot point, under the toes' bases) and the
##   toes. Each toe starts at a loop on the pad (its first ring projected back along the toe onto the pad), so toes
##   never pass through each other or the pad; the toe's phalanges bend at their joints as the grip closes, the
##   pads bulge under the joints (raptors) or the bones (perchers), and the last ring runs on into a curved claw.
##   Scales are drawn by leg_skin.gdshader through the meshes' coordinates (scutes in front, reticulate behind).
## Rebuilt only when its inputs move (perched or flying straight, the legs hold still relative to the body).

static var enabled := false

const SKIN_SHADER := preload("res://scripts/bird/leg_skin.gdshader")
const AROUND := 12        ## feather tube and tarsus rings
const TOE_AROUND := 8     ## toe and claw rings
const PAD_LON := 20
const PAD_LAT := 11
const PAD_FLAT := 0.5    ## the foot pad's height / width
const LEG_FEATHER := 0.55 ## leg feather size, share of the body tile
const ROOT_W := [0.0, 0.5]   ## connector rows' blend from a loop to the tube's first ring
const FILLET_W := [0.0, 0.3, 0.6]   ## the trousers' loop and connector rows: a fillet from the trunk onto the leg
const HANDOVER := [0.35, 0.7]   ## the trousers' first rings: how far their chart has turned from the trunk's to the leg's
const LOOP_FLARE := 1.6     ## the trousers' loop on the trunk: the first ring spread this much

## Per species (docs/research/legs_and_feet.md §7.2; sizes as fractions of L, our picks from its numbers):
## skin / claw / trouser (leg feathers; "" = the body's own colour where the leg leaves it) / toe_col (the owl's
## feathered toes); feathered: "ankle" (bare tarsus) or "foot" (the owl); flag: how far the trousers hang past the
## ankle, share of the tarsus; thigh / shank: the feather tube's radius at the body and at the ankle; tars_r: the
## bare tarsus; toe: the middle toe's length without its claw; toe_r: a toe's radius at its base; claws: [I, II,
## III, IV] claw lengths (Fowler et al. 2009's ratios); arc: the claw's curve (deg); pads: "joint" (raptors) or
## "bone" (perchers) and how much they bulge; scutes: front plates (0 = reticulate all round: falcons); pad_r: the
## foot pad's half-width; curl: total curl of a toe at full grip (deg); toe_len: [II, III, IV, I] / middle toe.
const SPEC := {
	"crow": {"skin": "#232327", "claw": "#0e0e10", "trouser": "", "feathered": "ankle", "flag": 0.06, "thigh": 0.05, "shank": 0.022,
		"tars_r": 0.0085, "toe": 0.075, "toe_r": 0.0054, "claws": [0.025, 0.0205, 0.0245, 0.019], "arc": 115.0, "pads": "bone", "bulge": 0.25,
		"scutes": 1.0, "fuzz": 0.0, "pad_r": 0.018, "curl": 105.0, "toe_len": [0.78, 1.0, 0.8, 0.62]},
	"owl": {"skin": "#958280", "claw": "#2e3035", "trouser": "#e6d8bd", "toe_col": "#dccdb2", "feathered": "foot", "flag": 0.0, "thigh": 0.06, "shank": 0.03,
		"tars_r": 0.012, "toe": 0.075, "toe_r": 0.0072, "claws": [0.036, 0.04, 0.039, 0.034], "arc": 95.0, "pads": "joint", "bulge": 0.4,
		"scutes": 0.0, "fuzz": 1.0, "pad_r": 0.024, "curl": 105.0, "toe_len": [0.85, 1.0, 0.85, 0.7], "end_r": 0.019},
	"hawk": {"skin": "#e3c04a", "claw": "#161514", "trouser": "#e2d4bc", "feathered": "ankle", "flag": 0.22, "thigh": 0.058, "shank": 0.03,
		"tars_r": 0.0105, "toe": 0.085, "toe_r": 0.0062, "claws": [0.047, 0.043, 0.031, 0.026], "arc": 115.0, "pads": "joint", "bulge": 0.5,
		"scutes": 1.0, "fuzz": 0.0, "pad_r": 0.02, "curl": 105.0, "toe_len": [0.78, 1.0, 0.8, 0.62]},
	"falcon": {"skin": "#e8c547", "claw": "#141416", "trouser": "#bdb6ae", "feathered": "ankle", "flag": 0.15, "thigh": 0.055, "shank": 0.028,
		"tars_r": 0.0105, "toe": 0.09, "toe_r": 0.006, "claws": [0.028, 0.025, 0.0245, 0.022], "arc": 118.0, "pads": "joint", "bulge": 0.5,
		"scutes": 0.0, "fuzz": 0.0, "pad_r": 0.02, "curl": 105.0, "toe_len": [0.78, 1.0, 0.8, 0.62]},
	"sparrow": {"skin": "#b38b7c", "claw": "#4e423a", "trouser": "", "feathered": "ankle", "flag": 0.06, "thigh": 0.05, "shank": 0.022,
		"tars_r": 0.0085, "toe": 0.078, "toe_r": 0.0054, "claws": [0.0275, 0.023, 0.027, 0.021], "arc": 110.0, "pads": "bone", "bulge": 0.25,
		"scutes": 0.8, "fuzz": 0.0, "pad_r": 0.018, "curl": 100.0, "toe_len": [0.78, 1.0, 0.8, 0.62]},
}
## The leg bones (tibiotarsus, tarsometatarsus) as fractions of L, from the measured bones (docs/research/
## legs_and_feet.md §1.3): a longer tibiotarsus and a shorter tarsus than BodyShape.DATA's estimates, so a perched
## bird's ankle hangs below its belly and the feathered tibia shows. Applied to the rig when the detailed legs are
## on (BirdRig's IK and stance read them; BodyShape keeps its own until this is taken).
const BONES := {"crow": [0.19, 0.13], "owl": [0.25, 0.16], "hawk": [0.2, 0.15], "falcon": [0.19, 0.12], "sparrow": [0.18, 0.12]}
## Toes in BirdRig's order [inner II, middle III, outer IV, hallux I]: the phalanges before the claw (shares of the
## toe; toe I has 2 phalanges, II 3, III 4, IV 5, the last one inside the claw), the claw's index in SPEC.claws, and
## the toe's heading off the bird's forward (deg, + outward). The front toes splay so their bases on the pad don't
## overlap; the inner toe less, so it stays clear of the other foot's.
const PHALANGES := [[0.55, 0.45], [0.38, 0.32, 0.3], [0.32, 0.25, 0.22, 0.21], [1.0]]
const CLAW_OF := [1, 2, 3, 0]
const YAW := [-36.0, 6.0, 50.0, 190.0]
const OWL_SWING_YAW := 125.0   ## the owl's outer toe when it swings back (2 + 2)

var rig: BirdRig
var spec: Dictionary
var L := 0.3
var skin_mat: ShaderMaterial
var plain_mat: StandardMaterial3D
var feather_mi: Array[MeshInstance3D] = []
var skin_mi: Array[MeshInstance3D] = []
# --- As last drawn, per side (tests, debug) ---
var parts_f: Array = [{}, {}]   ## feather mesh: piece name -> Vector3i(first vertex, rows, columns)
var parts_s: Array = [{}, {}]   ## skin mesh: "tarsus", "pad", "toe0".."toe3" (the claw is the toe's last rows)
var claw_rows: Array = [[0, 0, 0, 0], [0, 0, 0, 0]]   ## per toe: how many of its rows are the claw
var pad_centre: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var exit_on: Array[String] = ["", ""]   ## where the leg leaves the trunk: "tibia", "tarsus" or "" (all inside)
var toe_tips: Array = [[], []]           ## per side, each toe's claw tip
var toe_heading: Array = [[], []]        ## per side, each toe's first phalanx (unit, rig space)

var _skin_col: Color
var _claw_col: Color
var _toe_col: Color
var _unit_s := 0.003   ## a scale's size (m)
var _unit_t := 0.002   ## a toe scale's size
var _key_f: Array = [PackedFloat32Array(), PackedFloat32Array()]
var _key_s: Array = [PackedFloat32Array(), PackedFloat32Array()]
var _loop_key: Array = [PackedFloat32Array(), PackedFloat32Array()]
var _loop: Array = [{}, {}]   ## per side: the cached edge loop on the (unscaled) trunk shell
var _hem: Array = [PackedVector3Array(), PackedVector3Array()]   ## the feather tube's last ring = the skin's first


func _init(r: BirdRig) -> void:
	rig = r
	L = r._L
	spec = SPEC.get(r.profile.id, SPEC["crow"])
	var bones: Array = BONES.get(r.profile.id, BONES["crow"])
	r._tib = float(bones[0]) * L
	r._tars = float(bones[1]) * L
	_skin_col = Color.html(spec.skin)
	_claw_col = Color.html(spec.claw)
	_toe_col = Color.html(spec.get("toe_col", spec.skin))
	_skin_col.a = 0.0   # (COLOR.a is the keratin mask: 0 skin, 1 claw)
	_toe_col.a = 0.0
	_unit_s = float(spec.tars_r) * L * 0.55
	_unit_t = float(spec.toe_r) * L * 0.7
	skin_mat = ShaderMaterial.new()
	skin_mat.shader = SKIN_SHADER
	skin_mat.set_shader_parameter("scutes", float(spec.scutes))
	skin_mat.set_shader_parameter("fuzz", float(spec.fuzz))
	skin_mat.set_shader_parameter("scale_m", _unit_s)
	plain_mat = StandardMaterial3D.new()
	plain_mat.albedo_color = Color.WHITE
	plain_mat.vertex_color_use_as_albedo = true
	plain_mat.vertex_color_is_srgb = true
	plain_mat.roughness = 0.9
	for i in 2:
		var side := "L" if i == 0 else "R"
		var f := MeshInstance3D.new()
		f.name = "LegFeathers" + side
		f.mesh = ArrayMesh.new()
		f.material_override = plain_mat
		rig.add_child(f)
		feather_mi.append(f)
		var k := MeshInstance3D.new()
		k.name = "LegSkin" + side
		k.mesh = ArrayMesh.new()
		k.material_override = skin_mat
		rig.add_child(k)
		skin_mi.append(k)


## Draw leg `i` from the solved joints (rig space). `up_w` / `fwd_h`: world up and level forward (BirdRig._world_frame);
## `grip` 0 open .. 1 curled; `swing` 0..1 the owl's outer toe swung back. Returns each toe's claw tip.
func pose(i: int, knee: Vector3, ankle: Vector3, foot: Vector3, up_w: Vector3, fwd_h: Vector3, grip: float, swing: float) -> Array:
	var st := rig.fluff * (1.0 + 0.012 * rig.breath)   # (the trunk's scale this pose: BirdRig sets it after the legs)
	var kf := PackedFloat32Array([knee.x, knee.y, knee.z, ankle.x, ankle.y, ankle.z, foot.x, foot.y, foot.z, st])
	var ks := PackedFloat32Array([ankle.x, ankle.y, ankle.z, foot.x, foot.y, foot.z, up_w.x, up_w.y, up_w.z, fwd_h.x, fwd_h.y, fwd_h.z, grip, swing])
	if spec.feathered == "foot":   # (the owl's feather tube ends on the pad: it moves with the foot's frame too)
		kf.append_array(ks)
	var fmat: Material = rig.body_texture_material if rig.body_texture_material != null else plain_mat
	if feather_mi[i].material_override != fmat:
		feather_mi[i].material_override = fmat
	var redo_f := not _same(kf, _key_f[i])
	var redo_s := not _same(ks, _key_s[i]) or redo_f   # (the skin starts at the feather tube's hem)
	if redo_f:
		_key_f[i] = kf
		_build_feathers(i, knee, ankle, foot, up_w, fwd_h, st)
	if redo_s:
		_key_s[i] = ks
		_build_skin(i, ankle, foot, up_w, fwd_h, grip, swing)
	return toe_tips[i]


static func _same(a: PackedFloat32Array, b: PackedFloat32Array) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if absf(a[k] - b[k]) > 1e-6:
			return false
	return true


# --- Frames and rings ---------------------------------------------------------------------------------------

## [side, front] round a bone running along `t` on side `s`: `side` out from the body, `front` the bone's front
## (mirrored between the legs, so left and right rings match point for point).
static func _frame(t: Vector3, s: float) -> Array:
	var x := Vector3(s, 0.0, 0.0)
	var side := (x - t * t.dot(x)).normalized()
	return [side, (side.cross(t) * s).normalized()]


## A ring of `n` points round `c`: angle a_j = PI + TAU j / n (j = 0 on the inner side, where the coordinates'
## seam runs), `rs` to the side, `rf` toward the front (or top), `rb` toward the back (or sole).
static func _ring(c: Vector3, side: Vector3, front: Vector3, rs: float, rf: float, rb: float, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(n)
	for j in n:
		var a := PI + TAU * j / n
		var sa := sin(a)
		out[j] = c + side * (cos(a) * rs) + front * (sa * (rf if sa >= 0.0 else rb))
	return out


## Scale coordinates round a ring of n: u = 0 on the front (j = 3n/4), period `per`; v given.
static func _ring_uv(n: int, per: float, v: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for j in n + 1:
		out.append(Vector2((float(j) / n - 0.75) * per, v))
	return out


static func _fill_c(n: int, c: Color) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(n)
	out.fill(c)
	return out


static func _fill_v2(n: int, v: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	out.fill(v)
	return out


# --- The feather tube ----------------------------------------------------------------------------------------

## Where the polyline knee -> ankle -> foot leaves the trunk (scaled by `st`): [point, segment ("tibia",
## "tarsus" or "")].
func _exit(knee: Vector3, ankle: Vector3, foot: Vector3, st: float) -> Array:
	var b := rig.body
	for seg in [[knee, ankle, "tibia"], [ankle, foot, "tarsus"]]:
		var a: Vector3 = seg[0]
		var e: Vector3 = seg[1]
		if b.gap(e / st) > 0.0:
			if b.gap(a / st) > 0.0:
				return [a, seg[2]]
			var lo := 0.0
			var hi := 1.0
			for k in 18:
				var mid := 0.5 * (lo + hi)
				if b.gap(a.lerp(e, mid) / st) > 0.0:
					hi = mid
				else:
					lo = mid
			return [a.lerp(e, hi), seg[2]]
	return [foot, ""]


## The edge loop on the trunk round where the leg leaves it (at `e`, on the trunk scaled by `st`): an ellipse of the
## leg's size (`rs` to the side, `rf` / `rb` front and back) laid on the trunk's tangent plane there and dropped onto
## the shell -- compact however steeply or glancingly the leg leaves the body (a ring slid along a leg that leaves at
## a glancing angle smears far along the belly), and kept off the midline. Turned to match the leg's ring `ring`
## point for point. Kept on the unscaled shell (its colours, normals and feather coordinates read there); drawn
## scaled by the trunk's scale, so it lies on the drawn trunk whatever the breathing and fluff. Recomputed only
## when the leg moves.
func _shell_loop(i: int, e: Vector3, side: Vector3, rs: float, rf: float, rb: float, ring: PackedVector3Array, st: float) -> Dictionary:
	var key := PackedFloat32Array([e.x, e.y, e.z, side.x, side.y, side.z, rs, rf, st])
	var prev: PackedFloat32Array = _loop_key[i]
	var moved := prev.size() != key.size()
	if not moved:
		for k in 8:
			moved = moved or absf(key[k] - prev[k]) > L * 0.002
		moved = moved or absf(key[8] - prev[8]) > 0.02
	if not moved:
		return _loop[i]
	var b := rig.body
	var eu := e / st
	var hd := L * 0.002
	var nrm_e := Vector3(b.gap(eu + Vector3(hd, 0, 0)) - b.gap(eu - Vector3(hd, 0, 0)), b.gap(eu + Vector3(0, hd, 0)) - b.gap(eu - Vector3(0, hd, 0)), b.gap(eu + Vector3(0, 0, hd)) - b.gap(eu - Vector3(0, 0, hd))).normalized()
	var side_t := (side - nrm_e * nrm_e.dot(side)).normalized()
	var front_t := nrm_e.cross(side_t).normalized()
	var r_s := minf(rs / st, maxf(absf(eu.x) - L * 0.008, L * 0.004) / maxf(absf(side_t.x), 0.3))   # (clear of the other leg's)
	# Which way round: the orientation that sits closer to the leg's ring.
	var best := PackedVector3Array()
	var best_d := INF
	for sg: float in [1.0, -1.0]:
		var cand := PackedVector3Array()
		var dsum := 0.0
		for j in AROUND:
			var a := PI + TAU * j / AROUND
			var sa := sin(a)
			cand.append(eu + side_t * (cos(a) * r_s) + front_t * (sg * sa * (rf if sa >= 0.0 else rb) / st))
			dsum += cand[j].distance_to(ring[j] / st)
		if dsum < best_d:
			best_d = dsum
			best = cand
	var pts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for u in best:
		# Down onto the shell along its normal at the exit: bracket the crossing by stepping in or out, then halve.
		var t := nrm_e
		var step := L * 0.01 * (1.0 if b.gap(u) < 0.0 else -1.0)
		var lo := 0.0
		var hi := 0.0
		var found := false
		for k in 16:
			hi = lo + step
			if (b.gap(u + t * hi) > 0.0) != (step < 0.0):
				found = true
				break
			lo = hi
		if step < 0.0:   # (lo outside, hi inside: swap so lo is inside)
			var tmp := lo
			lo = hi
			hi = tmp
		for k in 16:
			var mid := 0.5 * (lo + hi)
			if b.gap(u + t * mid) > 0.0:
				hi = mid
			else:
				lo = mid
		var p := u + t * hi
		if not found:
			p = _onto_shell(u)
		pts.append(p)
		# The trunk as drawn there: its colour and shading normal, read from its mesh's grid at that point (as
		# BodyShape.uv_at reads the feather coordinates), so the loop matches what the trunk shows round it.
		var at := _trunk_at(p)
		cols.append(at[0])
		nrms.append(at[1])
		var fc := b.uv_at(p)
		uvs.append(fc[0])
		uv2s.append(fc[1])
	# u unwrapped round the loop (within half a period of its neighbour), so no triangle spans the trunk's seam.
	for j in range(1, uvs.size()):
		var per := uv2s[j].x
		if per < 500.0:
			var q := uvs[j]
			q.x -= per * roundf((q.x - uvs[j - 1].x) / per)
			uvs[j] = q
	var out := {"pts": pts, "nrm": nrms, "cols": cols, "uv": uvs, "uv2": uv2s}
	_loop[i] = out
	_loop_key[i] = key
	return out


var _trunk_arrays: Array = []


## The drawn trunk at a point on (or by) its surface (trunk space): [colour, normal], bilinear in its mesh's grid
## (rings along z, points round each ring by angle; BodyShape.trunk_mesh's layout, a seam column per ring).
func _trunk_at(p: Vector3) -> Array:
	var b := rig.body
	if _trunk_arrays.is_empty():
		_trunk_arrays = (rig._trunk.mesh as ArrayMesh).surface_get_arrays(0)
	var cols: PackedColorArray = _trunk_arrays[Mesh.ARRAY_COLOR]
	var nrm: PackedVector3Array = _trunk_arrays[Mesh.ARRAY_NORMAL]
	var tz := b.trunk_z
	var nz := tz.size()
	var w := cols.size() / nz   # (around + 1)
	var fi := clampf((p.z - tz[0]) / (tz[nz - 1] - tz[0]) * (nz - 1), 0.0, nz - 1.001)
	var i := int(fi)
	var r := b.ring_at(clampf(p.z, tz[0], tz[nz - 1]))
	var dy := p.y - r[0]
	var h := r[2] if dy >= 0.0 else r[3]
	var nexp := BodyShape.N_TOP if dy >= 0.0 else BodyShape.N_BOT
	var cx := signf(p.x) * pow(clampf(absf(p.x) / maxf(r[1], 1e-5), 0.0, 1.0), nexp / 2.0)
	var sy := signf(dy) * pow(clampf(absf(dy) / maxf(h, 1e-5), 0.0, 1.0), nexp / 2.0)
	var fj := fposmod(atan2(sy, cx), TAU) / TAU * (w - 1)
	var j := mini(int(fj), w - 2)
	var a := i * w + j
	var fu := fj - j
	var fv := fi - i
	var c := cols[a].lerp(cols[a + 1], fu).lerp(cols[a + w].lerp(cols[a + w + 1], fu), fv)
	var n := nrm[a].lerp(nrm[a + 1], fu).lerp(nrm[a + w].lerp(nrm[a + w + 1], fu), fv)
	return [c, n.normalized()]


## The point of the (unscaled) trunk shell straight out from its ring's centre through `p`.
func _onto_shell(p: Vector3) -> Vector3:
	var b := rig.body
	var z := clampf(p.z, b.front_z() + L * 0.01, b.back_z() - L * 0.01)
	var r := b.ring_at(z)
	var dy := p.y - r[0]
	var h := r[2] if dy >= 0.0 else r[3]
	var nexp := BodyShape.N_TOP if dy >= 0.0 else BodyShape.N_BOT
	var e := pow(pow(absf(p.x) / maxf(r[1], 1e-5), nexp) + pow(absf(dy) / maxf(h, 1e-5), nexp), 1.0 / nexp)
	if e < 1e-5:
		return Vector3(0.0, r[0] - r[3], z)
	return Vector3(p.x / e, r[0] + dy / e, z)


func _trouser_col(loop_cols: PackedColorArray) -> Color:
	if Plumage.level == 0:
		return rig._body_tint
	if spec.trouser != "":
		return Color.html(spec.trouser)
	var c := Color(0, 0, 0, 0)
	for k in loop_cols:
		c += k / float(loop_cols.size())
	c.a = 1.0
	return c


func _build_feathers(i: int, knee: Vector3, ankle: Vector3, foot: Vector3, up_w: Vector3, fwd_h: Vector3, st: float) -> void:
	var s: float = BirdRig.SIDES[i]
	var n := AROUND
	var bld := MeshBuild.new()
	var ex := _exit(knee, ankle, foot, st)
	exit_on[i] = ex[1]
	var owl: bool = spec.feathered == "foot"
	var t1 := (ankle - knee).normalized()
	var t2 := (foot - ankle).normalized()
	var tars := ankle.distance_to(foot)
	var f1 := _frame(t1, s)
	var f2 := _frame(t2, s)
	var thigh := float(spec.thigh) * L
	var shank := float(spec.shank) * L
	var tr := float(spec.tars_r) * L
	var er := float(spec.get("end_r", spec.shank)) * L
	_hem[i] = PackedVector3Array()
	if ex[1] == "":
		(feather_mi[i].mesh as ArrayMesh).clear_surfaces()
		feather_mi[i].visible = false
		parts_f[i] = {}
		return
	feather_mi[i].visible = true
	var e: Vector3 = ex[0]
	var on_tarsus: bool = ex[1] == "tarsus"
	if not on_tarsus and e.distance_to(ankle) < shank * 1.7:   # (barely any tibia shows: hang from the ankle instead)
		on_tarsus = true
		e = ankle
	# Centreline rows: [centre, side, front, radius side, front, back, distance down the leg from the exit].
	var rows: Array = []
	# Round the ankle: the tube's centreline turns on an arc no tighter than the tube (radius `bend_r`), so the rings
	# on the inside of the bend don't cross; rings within `bend_t` of the joint give way to one ring on the arc.
	var dev := acos(clampf(t1.dot(t2), -1.0, 1.0))
	var bend_r := shank * 1.15
	var bend_t := minf(bend_r * tan(minf(dev, 2.4) * 0.5), 0.45 * minf(e.distance_to(ankle), tars))
	if not on_tarsus:
		var dl := e.distance_to(ankle)
		var tib := knee.distance_to(ankle)
		for x: float in [0.12, 0.3, 0.5, 0.7, 0.88]:
			if dl * (1.0 - x) < bend_t and x > 0.12:
				continue
			var c := e + t1 * dl * x
			var r := lerpf(thigh, shank, pow(clampf((c - knee).dot(t1) / tib, 0.0, 1.0), 0.8))   # (thick by the knee, along the bone)
			rows.append([c, f1[0], f1[1], r, r * 0.85, r * 1.15, dl * x, t1])
		var tb := (t1 + t2).normalized()
		var fb := _frame(tb, s)
		var mid := ankle
		if dev > 0.05:   # (the arc's midpoint, inside the corner)
			var inner := (t2 - t1).normalized()
			mid = ankle + inner * (bend_r / cos(minf(dev, 2.4) * 0.5) - bend_r)
		rows.append([mid, fb[0], fb[1], shank, shank * 0.85, shank * 1.12, dl, tb])
		if owl:
			for x: float in [0.3, 0.55, 0.75]:
				if tars * x < bend_t:
					continue
				var r := lerpf(shank, er, x)
				rows.append([ankle + t2 * tars * x, f2[0], f2[1], r, r * 0.9, r * 1.1, dl + tars * x, t2])
	elif not owl:   # (the ankle tucked in the belly: the trousers still hang over the top of the tarsus)
		var r := shank * 1.1
		rows.append([e + t2 * tars * 0.03, f2[0], f2[1], r, r * 0.9, r * 1.1, tars * 0.03, t2])
	else:   # (owl, the ankle tucked inside: the feathered tarsus leaves the body)
		var dl := e.distance_to(foot)
		for x: float in [0.15, 0.45, 0.75]:
			var r := lerpf(shank, er, x)
			rows.append([e + t2 * dl * x, f2[0], f2[1], r, r * 0.9, r * 1.1, dl * x, t2])
	var axis := t2 if on_tarsus else t1
	var r0: Array = rows[0]
	var c0: Vector3 = r0[0]
	var first_ring := _ring(c0, r0[1], r0[2], r0[3], r0[4], r0[5], n)
	# The loop: the first ring spread wider (the leg's feathers fan out onto the belly), slid along the leg onto the
	# shell.
	var lp := _shell_loop(i, e, r0[1], float(r0[3]) * LOOP_FLARE, float(r0[4]) * LOOP_FLARE, float(r0[5]) * LOOP_FLARE, first_ring, st)
	var loop := PackedVector3Array()
	for p in (lp.pts as PackedVector3Array):
		loop.append(p * st)
	var lnrm: PackedVector3Array = lp.nrm
	var lcols: PackedColorArray = lp.cols
	var luv: PackedVector2Array = lp.uv
	var luv2: PackedVector2Array = lp.uv2
	var tcol := _trouser_col(lcols)
	# The rest of the tube after the loop: [points, centre, colour weight (loop's .. trouser colour), distance down].
	var tail: Array = []
	var total_d: float = float(rows[rows.size() - 1][6])
	for k in rows.size():
		var rk: Array = rows[k]
		var pts := first_ring if k == 0 else _ring(rk[0], rk[1], rk[2], rk[3], rk[4], rk[5], n)
		tail.append([pts, rk[0], lerpf(0.3, 1.0, smoothstep(0.0, 0.6, float(rk[6]) / maxf(total_d, 1e-5))), float(rk[6]), rk[7]])
	if owl:
		# Down to the foot pad: the last ring slid along the tarsus onto the pad (as the toes' loops).
		var last: Array = rows[rows.size() - 1]
		var frame := _pad_frame(i, foot, up_w, fwd_h)
		var ring := _ring(last[0], last[1], last[2], last[3], last[4], last[5], n)
		var on_pad := PackedVector3Array()
		for q in ring:
			on_pad.append(_onto_pad(q, t2, frame))
		var mid := PackedVector3Array()
		for j in n:
			mid.append(ring[j].lerp(on_pad[j], 0.5))
		var d_last: float = last[6]
		var gap_d: float = (on_pad[n / 4] - (last[0] as Vector3)).dot(t2)
		tail.append([mid, (last[0] as Vector3) + t2 * gap_d * 0.5, 1.0, d_last + gap_d * 0.5, t2])
		tail.append([on_pad, (last[0] as Vector3) + t2 * gap_d, 1.0, d_last + gap_d, t2])
		_hem[i] = on_pad
	else:
		# The skirt: the trousers hang past the ankle (or, the ankle tucked in, past where the tarsus leaves the
		# belly), longer behind (the "flags"), narrowing, then tuck in onto the bare tarsus: the last ring lies on the
		# skin, and the skin's tube starts from that same ring.
		var flag := (maxf(float(spec.flag), 0.12) if on_tarsus else float(spec.flag)) * tars
		var d_row := ((e - ankle).dot(t2) + tars * 0.03) if on_tarsus else bend_t   # (the last row's distance down the tarsus: past the ankle's arc)
		var skirt := PackedVector3Array()
		var edge := PackedVector3Array()
		var hem := PackedVector3Array()
		for j in n:
			var a := PI + TAU * j / n
			var sa := sin(a)
			var d_edge := d_row + flag * (1.0 - 0.35 * sa) + tr * 0.5
			var dir: Vector3 = f2[0] * cos(a) + f2[1] * sa
			skirt.append(ankle + t2 * lerpf(d_row, d_edge, 0.5) + dir * shank * 0.97)
			edge.append(ankle + t2 * d_edge + dir * shank * 0.8)
			var d_fin := lerpf(d_row, d_edge, 0.72)
			hem.append(ankle + t2 * d_fin + (f2[0] * (cos(a) * 0.92) + f2[1] * sa) * _tars_r(d_fin / tars) * tr)
		var d0: float = total_d - d_row   # (distance down the leg at the tarsus's d = 0)
		var dm := d_row + flag * 0.6
		tail.append([skirt, ankle + t2 * lerpf(d_row, dm, 0.5), 1.0, d0 + lerpf(d_row, dm, 0.5), t2])
		tail.append([edge, ankle + t2 * dm, 1.0, d0 + dm, t2])
		tail.append([hem, ankle + t2 * (dm * 0.85), 1.0, d0 + dm * 1.05, t2])
		_hem[i] = hem
	# No folds where the leg bends: down each column, every ring's point must lie further along its own ring's
	# axis than the ring before's (on the inside of a sharp ankle the rings would cross); one that doesn't slides
	# along its axis until it does -- the hem too, along the tarsus, and the skin starts from wherever it ends.
	for k in range(1, tail.size() - (0 if owl else 1)):   # (not the hem: it tucks back up under the skirt)
		var prev: PackedVector3Array = tail[k - 1][0]
		var cur: PackedVector3Array = tail[k][0]
		var ax: Vector3 = tail[k][4]
		var gap_min := L * 0.004
		for j in n:
			var ahead := (cur[j] - prev[j]).dot(ax)
			if ahead < gap_min:
				cur[j] += ax * (gap_min - ahead)
		tail[k][0] = cur
	if not owl:
		_hem[i] = tail[tail.size() - 1][0]
	# Feather coordinates. u round the leg (its seam on the inner side), running the same way as the trunk's u along
	# the loop and equal to it on the outer side, its period the loop's girth in the trunk's feather size there (so
	# the feathers narrow as the leg does); v down the leg from the loop's mean, the feathers shrinking from the
	# trunk's size to LEG_FEATHER.
	var unit_top := rig._tile * rig._size_trunk(c0.z / st)
	var unit_bot := rig._tile * LEG_FEATHER
	var d_end: float = tail[tail.size() - 1][3]
	var per := TAU * float(r0[3]) * LOOP_FLARE / unit_top
	var sgn := signf(luv[n / 2 + 1].x - luv[n / 2 - 1].x)
	sgn = sgn if sgn != 0.0 else 1.0
	var u_off := luv[n / 2].x
	var v := 0.0
	for q in luv:
		v += q.y / n
	var lc := Vector3.ZERO
	for p in loop:
		lc += p / n
	var d_prev := -(c0 - lc).dot(axis)   # (the loop, a little above the first ring)
	var own2 := _fill_v2(n + 1, Vector2(per, -0.8))
	var tail_uv: Array = []
	for row in tail:
		var d: float = row[3]
		v += (d - d_prev) / lerpf(unit_top, unit_bot, smoothstep(0.0, d_end * 0.8, 0.5 * (d + d_prev)))
		d_prev = d
		var urow := PackedVector2Array()
		for j in n + 1:
			urow.append(Vector2(u_off + sgn * (float(j) / n - 0.5) * per, v))
		tail_uv.append(urow)
	var all_rows: Array = []
	var centres: Array = []
	var cols: Array = []
	var uvs: Array = []
	var uv2s: Array = []
	var luv_c := luv.duplicate()
	luv_c.append(luv[0])
	var luv2_c := luv2.duplicate()
	luv2_c.append(luv2[0])
	var first_uv: PackedVector2Array = tail_uv[0]
	# The loop and connector rows: a fillet from the shell to the leg -- each column a curve leaving the loop toward
	# the leg (along the belly) and arriving along the leg -- with colours and coordinates blending from the loop's
	# to the first ring's (as BirdRig._loft_arm and _loft_neck join the trunk).
	for w: float in FILLET_W:
		var ws := smoothstep(0.0, 1.0, w)
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		var urow := PackedVector2Array()
		var u2row := PackedVector2Array()
		for j in n + 1:
			if j < n:
				var to := first_ring[j] - loop[j]
				var sn: Vector3 = lnrm[j]
				var h := to.length() * 0.45
				var p1 := loop[j] + (to - sn * sn.dot(to)).normalized() * h   # (along the trunk's surface)
				var p2 := first_ring[j] - axis * h                              # (along the leg)
				var w1 := 1.0 - w
				row.append(loop[j] * w1 * w1 * w1 + p1 * 3.0 * w1 * w1 * w + p2 * 3.0 * w1 * w * w + first_ring[j] * w * w * w)
				crow.append(lcols[j].lerp(lcols[j].lerp(tcol, 0.3), ws))
		# The fillet lies along the belly: it carries the trunk's own chart on (as if the belly ran on), so the
		# contour feathers don't change at the loop.
		if w == 0.0:
			urow = luv_c
			u2row = luv2_c
		else:
			var tc := _trunk_chart(row, luv_c, st)
			urow = tc[0]
			u2row = tc[1]
		all_rows.append(row)
		centres.append(c0 - axis * thigh * (1.0 - w))
		cols.append(crow)
		uvs.append(urow)
		uv2s.append(u2row)
	# Down the leg the chart hands over from the trunk's (its flow back along the body) to the leg's own (down the
	# leg) over the first rings; the texture shows less where the chart turns, so the turn doesn't read as a band.
	for k in tail.size():
		var row: Array = tail[k]
		all_rows.append(row[0])
		centres.append(row[1])
		var bw: float = HANDOVER[k] if k < HANDOVER.size() else 1.0
		var crow := PackedColorArray()
		for j in n:
			var c := lcols[j].lerp(tcol, float(row[2]))
			c.a = lerpf(1.0, 0.45, sin(PI * bw))
			crow.append(c)
		cols.append(crow)
		if bw < 1.0:
			var tc := _trunk_chart(row[0], luv_c, st)
			var urow := PackedVector2Array()
			var u2row := PackedVector2Array()
			for j in n + 1:
				urow.append((tc[0][j] as Vector2).lerp(tail_uv[k][j], bw))
				u2row.append((tc[1][j] as Vector2).lerp(own2[j], bw))
			uvs.append(urow)
			uv2s.append(u2row)
		else:
			uvs.append(tail_uv[k])
			uv2s.append(own2)
	bld.tube("trouser", all_rows, centres, cols, uvs, uv2s)
	for j in n + 1:   # (the loop shades as the trunk does there: its normals are the trunk's)
		bld.fixed[j] = lnrm[j % n]
	bld.commit(feather_mi[i].mesh as ArrayMesh)
	parts_f[i] = bld.parts


## The trunk's feather chart carried onto a row of points by the belly (rig space, the trunk scaled by `st`): [uv,
## uv2], n + 1 each, u unwrapped to stay by the loop's u in the same column.
func _trunk_chart(row: PackedVector3Array, ref: PackedVector2Array, st: float) -> Array:
	var n := row.size()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for j in n + 1:
		var fc := rig.body.uv_at(row[j % n] / st)
		var uv: Vector2 = fc[0]
		var per: float = (fc[1] as Vector2).x
		if per < 500.0:
			uv.x -= per * roundf((uv.x - ref[j].x) / per)
		uvs.append(uv)
		uv2s.append(fc[1])
	return [uvs, uv2s]


## The bare tarsus's radius along it (x 0 ankle .. 1 foot), share of tars_r: a little thicker by the ankle.
static func _tars_r(x: float) -> float:
	return lerpf(1.08, 0.94, clampf(x, 0.0, 1.0))


# --- The foot pad -----------------------------------------------------------------------------------------------

## The foot pad's frame: [centre, out (away from the body), up, forward, half-width, half-height].
func _pad_frame(i: int, foot: Vector3, up_w: Vector3, fwd_h: Vector3) -> Array:
	var s: float = BirdRig.SIDES[i]
	var right := fwd_h.cross(up_w).normalized()
	var pr := float(spec.pad_r) * L
	return [foot, right * s, up_w, fwd_h, pr, pr * PAD_FLAT]


static func _pad_local(p: Vector3, fr: Array) -> Vector3:
	var q: Vector3 = p - fr[0]
	return Vector3(q.dot(fr[1]) / float(fr[4]), q.dot(fr[2]) / float(fr[5]), q.dot(fr[3]) / float(fr[4]))


static func _pad_world(l: Vector3, fr: Array) -> Vector3:
	return (fr[0] as Vector3) + (fr[1] as Vector3) * l.x * float(fr[4]) + (fr[2] as Vector3) * l.y * float(fr[5]) + (fr[3] as Vector3) * l.z * float(fr[4])


## `q` slid along `dir` onto the pad (the first point where the line meets it; straight in toward the centre if it
## misses).
static func _onto_pad(q: Vector3, dir: Vector3, fr: Array) -> Vector3:
	var o := _pad_local(q, fr)
	var dd := Vector3(dir.dot(fr[1]) / float(fr[4]), dir.dot(fr[2]) / float(fr[5]), dir.dot(fr[3]) / float(fr[4]))
	var a := dd.dot(dd)
	var b := 2.0 * o.dot(dd)
	var c := o.dot(o) - 1.0
	var disc := b * b - 4.0 * a * c
	if disc >= 0.0 and a > 1e-12:
		var sq := sqrt(disc)
		var t0 := (-b - sq) / (2.0 * a)
		var t1 := (-b + sq) / (2.0 * a)
		var tt := t0 if absf(t0) < absf(t1) else t1
		return _pad_world(o + dd * tt, fr)
	return _pad_world(o.normalized(), fr)


## The pad's scale coordinates at a point on it: [uv, uv2] (latitude from the top, longitude from the inner side
## round through the front, as its mesh).
func _pad_uv(p: Vector3, fr: Array) -> Array:
	var l := _pad_local(p, fr).normalized()
	var th := acos(clampf(l.y, -1.0, 1.0))
	var ph := atan2(l.z, l.x)
	var per := maxf(TAU * float(fr[4]) * sin(th) / _unit_t, 0.05)
	var f := fposmod((ph - PI) / TAU, 1.0)
	return [Vector2((f - 0.75) * per, th * 0.5 * (float(fr[4]) + float(fr[5])) / _unit_t), Vector2(per, 0.0)]


## Unwrap u along a row of [uv, uv2] pairs: each within half a period of the one before.
static func _unwrap(uvs: PackedVector2Array, uv2s: PackedVector2Array) -> void:
	for j in range(1, uvs.size()):
		var per := uv2s[j].x
		var q := uvs[j]
		q.x -= per * roundf((q.x - uvs[j - 1].x) / per)
		uvs[j] = q


# --- The skin: tarsus, pad, toes, claws ---------------------------------------------------------------------------

func _build_skin(i: int, ankle: Vector3, foot: Vector3, up_w: Vector3, fwd_h: Vector3, grip: float, swing: float) -> void:
	var s: float = BirdRig.SIDES[i]
	var bld := MeshBuild.new()
	var fr := _pad_frame(i, foot, up_w, fwd_h)
	pad_centre[i] = foot
	var owl: bool = spec.feathered == "foot"
	var pad_col := _toe_col if owl else _skin_col
	var t2 := (foot - ankle).normalized()
	var tars := ankle.distance_to(foot)
	var f2 := _frame(t2, s)
	var tr := float(spec.tars_r) * L
	var n := AROUND
	# Tarsus (bare legs): from the feather tube's hem ring (or from the ankle, when the leg leaves the body below it)
	# down to a loop on the pad.
	if not owl:
		var top: PackedVector3Array = _hem[i]
		var d_top := PackedFloat32Array()
		if top.is_empty():
			var start := ankle
			if exit_on[i] == "tarsus":
				start = _exit(rig.leg_joints[i][1], ankle, foot, rig._trunk.scale.x)[0]
			top = _ring(start, f2[0], f2[1], tr, tr, tr, n)
		for q in top:
			d_top.append((q - ankle).dot(t2))
		var pr := float(spec.pad_r) * L
		var d_bot := maxf(tars - pr * 1.1, d_top[0] + tars * 0.1)
		var rows: Array = [top]
		var centres: Array = [ankle + t2 * d_top[n / 4]]
		var uvs: Array = []
		var per := TAU * tr / _unit_s
		var u0 := PackedVector2Array()
		for j in n + 1:
			u0.append(Vector2((float(j) / n - 0.75) * per, d_top[j % n] / _unit_s))
		uvs.append(u0)
		var K := 4
		for k in range(1, K + 1):
			var row := PackedVector3Array()
			var urow := PackedVector2Array()
			for j in n:
				var d := lerpf(d_top[j], d_bot, float(k) / K)
				var a := PI + TAU * j / n
				var rr := _tars_r(d / tars) * tr
				row.append(ankle + t2 * d + f2[0] * (cos(a) * rr * 0.92) + f2[1] * (sin(a) * rr))
			for j in n + 1:
				urow.append(Vector2((float(j) / n - 0.75) * per, lerpf(d_top[j % n], d_bot, float(k) / K) / _unit_s))
			rows.append(row)
			centres.append(ankle + t2 * lerpf(d_top[0], d_bot, float(k) / K))
			uvs.append(urow)
		# The loop on the pad: the last ring, a little fuller (the skin spreads onto the pad), slid down onto it.
		var last: PackedVector3Array = rows[rows.size() - 1]
		var c_last: Vector3 = centres[centres.size() - 1]
		var loop := PackedVector3Array()
		var luv := PackedVector2Array()
		var luv2 := PackedVector2Array()
		for j in n:
			var q := c_last + (last[j] - c_last) * 1.45   # (the tarsus widens onto the toes' bases)
			var p := _onto_pad(q, t2, fr)
			loop.append(p)
			var pu := _pad_uv(p, fr)
			luv.append(pu[0])
			luv2.append(pu[1])
		_unwrap(luv, luv2)
		luv.append(luv[0] + Vector2(luv2[0].x * roundf((luv[n - 1].x - luv[0].x) / luv2[0].x), 0.0))   # (the seam column)
		luv2.append(luv2[0])
		var own_last: PackedVector2Array = uvs[uvs.size() - 1]
		var mid := PackedVector3Array()
		var mid_uv := PackedVector2Array()
		var mid_uv2 := PackedVector2Array()
		for j in n + 1:
			if j < n:
				mid.append(last[j].lerp(loop[j], 0.5))
			mid_uv.append(own_last[j].lerp(luv[j], 0.5))
			mid_uv2.append(Vector2(per, 1.0).lerp(luv2[j], 0.5))
		rows.append_array([mid, loop])
		centres.append_array([c_last.lerp(foot, 0.5), foot])
		uvs.append_array([mid_uv, luv])
		var uv2s: Array = []
		for k in rows.size() - 2:
			uv2s.append(_fill_v2(n + 1, Vector2(per, 1.0)))
		uv2s.append_array([mid_uv2, luv2])
		var cols: Array = []
		for k in rows.size():
			cols.append(_fill_c(n, _skin_col))
		bld.tube("tarsus", rows, centres, cols, uvs, uv2s)
	# The pad: an ellipsoid at the foot point, poles up and down, its longitude seam on the inner side.
	var prow: Array = []
	var pcen: Array = []
	var puv: Array = []
	var puv2: Array = []
	var pcol: Array = []
	for a in PAD_LAT:
		var th := PI * a / (PAD_LAT - 1)
		var row := PackedVector3Array()
		var urow := PackedVector2Array()
		var u2row := PackedVector2Array()
		var per := maxf(TAU * float(fr[4]) * sin(th) / _unit_t, 0.05)
		for j in PAD_LON + 1:
			var ph := PI + TAU * j / PAD_LON
			if j < PAD_LON:
				row.append(_pad_world(Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)), fr))
			urow.append(Vector2((float(j) / PAD_LON - 0.75) * per, th * 0.5 * (float(fr[4]) + float(fr[5])) / _unit_t))
			u2row.append(Vector2(per, 0.0))
		prow.append(row)
		pcen.append(foot)
		puv.append(urow)
		puv2.append(u2row)
		pcol.append(_fill_c(PAD_LON, pad_col))
	bld.tube("pad", prow, pcen, pcol, puv, puv2)
	# Toes.
	toe_heading[i] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var right := fwd_h.cross(up_w).normalized()
	var tips: Array = []
	for k in 4:
		var yaw := deg_to_rad(float(YAW[k]))
		if k == 2 and rig.body.zygo:
			yaw = lerp_angle(yaw, deg_to_rad(OWL_SWING_YAW), swing)
		var base := (fwd_h * cos(yaw) + right * s * sin(yaw)).normalized()
		tips.append(_toe(bld, i, k, base, fr, grip, pad_col))
	toe_tips[i] = tips
	bld.commit(skin_mi[i].mesh as ArrayMesh)
	parts_s[i] = bld.parts


## One toe, from a loop on the pad out along its phalanges into its claw. Returns the claw's tip.
func _toe(bld: MeshBuild, i: int, k: int, base: Vector3, fr: Array, grip: float, col: Color) -> Vector3:
	var s: float = BirdRig.SIDES[i]
	var n := TOE_AROUND
	var up: Vector3 = fr[2]
	var side := (up.cross(base) * s).normalized()
	var phal: Array = PHALANGES[k]
	var length := float(spec.toe) * L * float(spec.toe_len[k])
	var total := deg_to_rad(float(spec.curl)) * grip
	var per_joint := total * 0.85 / phal.size()
	# The chain: joints from the pad's centre; each phalanx turned down by the curl at the joint before it.
	var dirs: Array[Vector3] = []
	var joints: Array[Vector3] = [fr[0]]
	var xs := PackedFloat32Array([0.0])
	var d := base.rotated(side, s * total * 0.15)
	for p in phal.size():
		if p > 0:
			d = d.rotated(side, s * per_joint)
		dirs.append(d)
		joints.append(joints[p] + d * length * float(phal[p]))
		xs.append(xs[p] + length * float(phal[p]))
	var claw_dir := d.rotated(side, s * per_joint)
	toe_heading[i][k] = dirs[0]
	var r0 := float(spec.toe_r) * L
	var r_tip := r0 * 0.72
	var bulge := float(spec.bulge)
	var at_joint: bool = spec.pads == "joint"
	var pad_fn := func(x: float) -> float:
		var out := 0.0
		for p in phal.size():
			var seg := length * float(phal[p])
			var cx := xs[p + 1] if at_joint else xs[p] + seg * 0.5
			out = maxf(out, exp(-pow((x - cx) / (seg * 0.28), 2.0)))
		return out
	# Stations: [x along, centre, direction] -- three per phalanx, the joints on the bisector of the two bones.
	var e0 := 1.0 / maxf(_pad_local(fr[0] + dirs[0], fr).length(), 1e-4)   # (the pad's surface along the first bone)
	var x0 := minf(e0 + r0 * 0.6, length * float(phal[0]) * 0.8)
	var stations: Array = [[x0, joints[0] + dirs[0] * x0, dirs[0]]]
	for p in phal.size():
		var seg := length * float(phal[p])
		for f: float in [0.0, 0.25, 0.5, 0.75]:
			var x := xs[p] + seg * f
			if x <= x0 + seg * 0.15:
				continue
			var dd: Vector3 = dirs[p] if f > 0.0 else (dirs[p - 1] + dirs[p]).normalized()
			stations.append([x, joints[p] + dirs[p] * seg * f, dd])
	stations.append([xs[phal.size()], joints[phal.size()], (dirs[phal.size() - 1] + claw_dir).normalized()])
	var rows: Array = []
	var centres: Array = []
	var cols: Array = []
	var uvs: Array = []
	var uv2s: Array = []
	var per := TAU * r0 / _unit_t
	for stn in stations:
		var x: float = stn[0]
		var dd: Vector3 = stn[2]
		var r := lerpf(r0, r_tip, x / length)
		var dorsal := (dd.cross(side) * s).normalized()
		var sd := (dorsal.cross(dd) * s).normalized()
		rows.append(_ring(stn[1], sd, dorsal, r, r * 0.9, r * (1.0 + bulge * pad_fn.call(x)), n))
		centres.append(stn[1])
		cols.append(_fill_c(n, col))
		uvs.append(_ring_uv(n, per, x / _unit_t))
		uv2s.append(_fill_v2(n + 1, Vector2(per, 1.0)))
	# The claw: the toe's last ring runs on along an arc curving down (ventral), tapering to a point, flattened
	# side to side; its colour turns to horn just past the base.
	var claw_len := float(spec.claws[CLAW_OF[k]]) * L
	var arc := deg_to_rad(float(spec.arc))
	var R := claw_len / arc
	var p_end: Vector3 = joints[phal.size()]
	var dors := (claw_dir.cross(side) * s).normalized()
	var cc := p_end - dors * R
	var tip := p_end
	var claw_n := 0
	for f: float in [0.06, 0.3, 0.55, 0.8, 1.0]:
		var ph: float = arc * f
		var cpos := cc + R * (dors * cos(ph) + claw_dir * sin(ph))
		var tang := (claw_dir * cos(ph) - dors * sin(ph)).normalized()
		var nrm := (dors * cos(ph) + claw_dir * sin(ph)).normalized()
		var sd := (nrm.cross(tang) * s).normalized()
		var r := r_tip * pow(1.0 - f, 0.8) * (1.04 if f < 0.1 else 1.0)
		rows.append(_ring(cpos, sd, nrm, r * 0.62, r, r * 0.8, n))
		centres.append(cpos)
		var cc_col := _claw_col
		cc_col.a = 1.0
		cols.append(_fill_c(n, cc_col))
		uvs.append(_ring_uv(n, per, (xs[phal.size()] + claw_len * f) / _unit_t))
		uv2s.append(_fill_v2(n + 1, Vector2(per, 0.0)))
		tip = cpos
		claw_n += 1
	claw_rows[i][k] = claw_n
	# The loop on the pad and a connector row in front of the first ring, the coordinates blending from the pad's.
	var first: PackedVector3Array = rows[0]
	var c0: Vector3 = centres[0]
	var loop := PackedVector3Array()
	var luv := PackedVector2Array()
	var luv2 := PackedVector2Array()
	for j in n:
		var p := _onto_pad(first[j], -dirs[0], fr)
		loop.append(p)
		var pu := _pad_uv(p, fr)
		luv.append(pu[0])
		luv2.append(pu[1])
	_unwrap(luv, luv2)
	luv.append(luv[0] + Vector2(luv2[0].x * roundf((luv[n - 1].x - luv[0].x) / luv2[0].x), 0.0))
	luv2.append(luv2[0])
	var mid := PackedVector3Array()
	var mid_uv := PackedVector2Array()
	var mid_uv2 := PackedVector2Array()
	var fuv: PackedVector2Array = uvs[0]
	for j in n + 1:
		if j < n:
			mid.append(loop[j].lerp(first[j], 0.5))
		mid_uv.append(luv[j].lerp(fuv[j], 0.5))
		mid_uv2.append(luv2[j].lerp(Vector2(per, 1.0), 0.5))
	var lc := col
	bld.tube("toe%d" % k, [loop, mid] + rows, [fr[0], c0.lerp(fr[0], 0.5)] + centres, [_fill_c(n, lc), _fill_c(n, lc)] + cols, [luv, mid_uv] + uvs, [luv2, mid_uv2] + uv2s)
	return tip


## Mesh arrays built tube by tube, normals from the faces (each tube's seam column shares its first column's).
class MeshBuild:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var parts := {}
	var fixed := {}   ## vertex index -> normal, kept as given (a loop on another surface shades as that surface)

	## A tube through `rows` of ring points (n each), with each row's centre (which way is out), colours (n per row)
	## and coordinates (n + 1 per row: the ring's first point again, so a coordinate running round it needn't wrap
	## on a shared vertex). Faces wound clockwise seen from outside (Godot's front face).
	func tube(name: String, rows: Array, centres: Array, cols: Array, uvs: Array, uv2s: Array) -> void:
		var n: int = (rows[0] as PackedVector3Array).size()
		var m := rows.size()
		var w := n + 1
		var first := v.size()
		for i in m:
			var row: PackedVector3Array = rows[i]
			var crow: PackedColorArray = cols[i]
			var urow: PackedVector2Array = uvs[i]
			var u2row: PackedVector2Array = uv2s[i]
			for j in w:
				v.append(row[j % n])
				c.append(crow[j % n])
				uv.append(urow[j])
				uv2.append(u2row[j])
		# Which way round faces out: test one quad in a row with some girth.
		var ti := clampi(m / 2, 0, m - 2)
		var a0 := first + ti * w
		var out := v[a0] - (centres[ti] as Vector3)
		var flip := (v[a0 + 1] - v[a0]).cross(v[a0 + w] - v[a0]).dot(out) < 0.0
		for i in m - 1:
			for j in n:
				var a := first + i * w + j
				var b := a + 1
				var cc := a + w
				var d := cc + 1
				if flip:
					idx.append_array([a, b, cc, b, d, cc])
				else:
					idx.append_array([a, cc, b, b, cc, d])
		parts[name] = Vector3i(first, m, w)

	func commit(mesh: ArrayMesh) -> void:
		mesh.clear_surfaces()
		if idx.is_empty():
			return
		var nrm := PackedVector3Array()
		nrm.resize(v.size())
		nrm.fill(Vector3.ZERO)
		for t in range(0, idx.size(), 3):
			var p0 := v[idx[t]]
			var fn := (v[idx[t + 2]] - p0).cross(v[idx[t + 1]] - p0)
			nrm[idx[t]] += fn
			nrm[idx[t + 1]] += fn
			nrm[idx[t + 2]] += fn
		for key in parts:
			var pt: Vector3i = parts[key]
			var n := pt.z - 1
			for i in pt.y:
				var r0 := pt.x + i * pt.z
				var sum := nrm[r0] + nrm[r0 + n]
				nrm[r0] = sum
				nrm[r0 + n] = sum
				if v[r0].distance_squared_to(v[r0 + n / 2]) < 1e-14:   # (a pole or a tip: every point the same)
					var all := Vector3.ZERO
					for j in n:
						all += nrm[r0 + j]
					for j in pt.z:
						nrm[r0 + j] = all
		for k in nrm.size():
			nrm[k] = nrm[k].normalized() if nrm[k].length_squared() > 1e-30 else Vector3.UP
		for k: int in fixed:
			nrm[k] = fixed[k]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
