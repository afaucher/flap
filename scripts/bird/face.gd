class_name Face
extends RefCounted
## Faces: eyes, beaks, the owl's facial disc, and how the head looks around (docs/research/eyes_and_beaks.md,
## section 4; its FACE table, trimmed to what the rig uses). Sizes in head radii r, angles in degrees, colours
## sRGB hex. Head shape (skull scale, brow) lives in BodyShape.
##
## Eyes are lens caps on the head's surface -- only the cornea shows on a bird, the globe is inside -- with
## pupil, iris and eye-ring as vertex-coloured rings. Bills are lofted on profiles traced from a photo of each
## species (BillProfiles, beak_meshes): `beak` sets the rest -- `w` the half-width at the base (head radii), `wp`
## its taper, `ridge` how the section narrows to the culmen, `lw` the lower bill's width to the upper's, `pitch`
## the bill's frame turned down (deg), `at` the culmen's base: its height and how far ahead of the head's front.
## Its look (bill.gdshader): `bill` at the base to `bill_tip` over `tip_range` (shares of the way along), `mouth` the
## lining, `nostril` [x, y, rx, ry] in the bill's frame (head radii; none if empty; `tubercle` the falcon's knob in
## it), the cere's front edge from the traced mark leaning back `cere_lean` per unit down (and the crow's bristles
## `bristle_lean`), `edge` how much paler the cutting edge, `gloss` the keratin's roughness.

const DATA := {
	"crow": {
		"eye": {"r": 0.2, "az": 62.0, "el": 14.0, "back": 3.0}, "iris": "#2a1e18", "pupil": "#050505", "pupil_frac": 0.55, "ring": "#1b1b1f", "ring_w": 0.08,
		"beak": {"w": 0.3, "wp": 0.75, "ridge": 0.3, "lw": 0.92, "pitch": 0.0, "at": [0.55, 0.1], "tip_range": [0.5, 1.0], "mouth": "#2e2427", "nostril": [], "bristle_lean": 0.9, "edge": 0.15, "gloss": 0.28},
		"bill": "#121214", "bill_tip": "#121214", "cere_col": "", "head_yaw": 150.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 1.0, "sac_speed": 700.0, "blink_pm": 18.0,
	},
	"owl": {   # Barn Owl face
		"eye": {"r": 0.12, "az": 31.0, "el": 8.0}, "iris": "#1a120e", "pupil": "#050404", "pupil_frac": 0.7, "ring": "#3a2c26", "ring_w": 0.25,
		"beak": {"w": 0.08, "wp": 0.6, "ridge": 0.3, "lw": 0.85, "pitch": -70.0, "tip_range": [0.45, 1.0], "mouth": "#cf9488", "nostril": [], "edge": 0.05, "gloss": 0.35},
		"bill": "#e2d3b6", "bill_tip": "#cdb68f", "cere_col": "", "head_yaw": 135.0, "head_pitch": [-80.0, 80.0],
		"fix_s": 2.0, "sac_speed": 600.0, "blink_pm": 4.0, "disc": "heart",
	},
	"hawk": {   # Red-tailed Hawk, adult
		"eye": {"r": 0.24, "az": 48.0, "el": 10.0, "back": 8.0}, "iris": "#5a321e", "pupil": "#070606", "pupil_frac": 0.45, "ring": "#3a2a20", "ring_w": 0.08,
		"beak": {"w": 0.22, "wp": 0.6, "ridge": 0.35, "lw": 0.9, "pitch": 0.0, "at": [0.4, 0.4], "tip_range": [0.45, 0.95], "mouth": "#c98a80", "nostril": [0.17, -0.19, 0.055, 0.035], "cere_lean": 0.55, "edge": 0.15, "gloss": 0.3},
		"bill": "#4a4d55", "bill_tip": "#18181b", "cere_col": "#e3c04a", "head_yaw": 130.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 4.0, "sac_speed": 450.0, "blink_pm": 15.0,
	},
	"falcon": {   # Common Kestrel, adult male (the concept render's bird; a falcon too: yellow cere and eye ring)
		"eye": {"r": 0.25, "az": 44.0, "el": 10.0, "back": 4.0}, "iris": "#24170f", "pupil": "#050404", "pupil_frac": 0.5, "ring": "#e8c547", "ring_w": 0.3,
		"beak": {"w": 0.2, "wp": 0.6, "ridge": 0.3, "lw": 0.9, "pitch": 0.0, "at": [0.15, 0.18], "tip_range": [0.4, 0.9], "mouth": "#c98a80", "nostril": [0.13, -0.17, 0.045, 0.045], "tubercle": 1.0, "cere_lean": 0.45, "edge": 0.12, "gloss": 0.3},
		"bill": "#6f7f93", "bill_tip": "#1d1f24", "cere_col": "#e8c547", "head_yaw": 130.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 2.5, "sac_speed": 600.0, "blink_pm": 15.0,
	},
	"sparrow": {   # House Sparrow, male (breeding bill)
		"eye": {"r": 0.22, "az": 68.0, "el": 12.0, "back": 5.0}, "iris": "#3a2516", "pupil": "#070606", "pupil_frac": 0.55, "ring": "#2a221c", "ring_w": 0.08,
		"beak": {"w": 0.36, "wp": 0.85, "ridge": 0.15, "lw": 0.95, "pitch": 0.0, "at": [0.25, 0.22], "tip_range": [0.5, 1.0], "mouth": "#4a3a38", "nostril": [0.07, -0.1, 0.035, 0.022], "edge": 0.2, "gloss": 0.32},
		"bill": "#1c1c1e", "bill_tip": "#1c1c1e", "cere_col": "", "head_yaw": 150.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 0.45, "sac_speed": 900.0, "blink_pm": 18.0,
	},
}
const BLINK_S := 0.2   ## a nictitating blink, across and back


static func spec(id: String) -> Dictionary:
	return DATA.get(id, DATA["crow"])


## The eye's direction from the head centre (head space: -Z the bill, +X right), for side `s` (-1 / 1).
static func eye_dir(id: String, s: float) -> Vector3:
	return _eye_dir(id, s, 0.0)


## Where the eye sits on the head (the direction from its centre): `back` degrees further round than its optic axis,
## so it sits further behind the bill, as in the photo (a real face is longer before the eye than a sphere's; the
## snout, Face.snout, makes up the rest), and faces out from there (a cap turned off the surface sinks into it on one
## side): a few degrees more to the side than the optic-axis estimates (docs/research/eyes_and_beaks.md 1).
static func eye_seat(id: String, s: float) -> Vector3:
	return _eye_dir(id, s, float(spec(id).eye.get("back", 0.0)))


static func _eye_dir(id: String, s: float, back: float) -> Vector3:
	var e: Dictionary = spec(id).eye
	var az := deg_to_rad(float(e.az) + back)
	var el := deg_to_rad(float(e.el))
	return Vector3(s * sin(az) * cos(el), sin(el), -cos(az) * cos(el))


## The visible eye: a shallow lens cap of radius `er`, domed out along -Z, coloured in rings from the centre --
## pupil, iris, the eye-ring (bare skin: the falcon's yellow) and a dark lid rim.
static func eye_mesh(id: String, er: float) -> ArrayMesh:
	var f := spec(id)
	var ring_w: float = f.ring_w
	var iris_r := 1.0 - ring_w
	var pupil_r := iris_r * float(f.pupil_frac)
	# radius fraction -> colour, with a hard step at each boundary (two rows at the same radius)
	var stops := [[0.0, f.pupil], [pupil_r, f.pupil], [pupil_r, f.iris], [iris_r, f.iris], [iris_r, f.ring], [0.92, f.ring], [0.92, "#141212"], [1.0, "#141212"]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for k in stops.size() - 1:
		var r0: float = stops[k][0]
		var r1: float = stops[k + 1][0]
		if r1 - r0 < 1e-4:
			continue
		var c := Color.html(stops[k][1])
		for j in n:
			var a0 := TAU * j / n
			var a1 := TAU * (j + 1) / n
			var p := [_cap(r0, a0, er), _cap(r1, a0, er), _cap(r1, a1, er), _cap(r0, a1, er)]
			for q in [[0, 1, 2], [0, 2, 3]]:
				for v in q:
					st.set_color(c)
					st.add_vertex(p[v])
	st.generate_normals()
	return st.commit()


static func _cap(rf: float, a: float, er: float) -> Vector3:
	return Vector3(cos(a) * rf * er, sin(a) * rf * er, -0.25 * er * (1.0 - rf * rf))


## The bill's two mandibles in head space, lofted on the ribs traced from the species' reference photo
## (BillProfiles: tools/bill_profiles_emit.py): the culmen's base at `base` (head space), the bill's frame turned
## down by its `pitch` (x forward along the gape line, y up). Each rib spans the upper bill from the culmen to the
## cutting edge (the lower: from its underside to its cutting edge); round it the cross-section is a half-ellipse
## `w` half-wide at the base (tapering by `wp` to the tip), narrowed toward the culmen by `ridge`, closed underneath
## by the palate (the lower: by the mouth's floor). The base's section is carried on in toward the head's centre
## (BILL_BURY), shrinking, so the bill grows out of the face and nothing of it shows past the head. [upper, lower]
## ArrayMesh, drawn by bill.gdshader from their coordinates:
##   UV     (share of the way to the tip, height up the rib: 0 the cutting edge .. 1 the culmen; the lower: 0 the
##          underside .. 1 its cutting edge)
##   UV2    the point in the bill's frame (head radii), x forward, y up: where the cere, nostril and bristles are
##   COLOR  r: across the bill (0 left .. 1 right), g: the surface (0 the upper's outside, 1/3 the palate, 2/3 the
##          lower's outside, 1 the mouth's floor)
static func beak_meshes(id: String, r: float, base: Vector3) -> Array:
	var b: Dictionary = spec(id).beak
	var prof: Dictionary = BillProfiles.DATA[id]
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(float(b.pitch)))
	var to_head := func(q: Vector2, lat: float) -> Vector3:
		return base + pitch * Vector3(lat * r, q.y * r, -q.x * r)
	var w0: float = b.w
	var wp: float = b.wp
	var lw: float = b.lw
	var c := pitch.inverse() * (-base) / r   # the head's centre in the bill's frame
	var centre := Vector2(-c.z, c.y)
	var upper := _bill_part(prof.upper, false, func(f: float) -> float: return w0 * pow(maxf(1.0 - f, 0.0), wp), float(b.ridge), to_head, centre)
	var lower := _bill_part(prof.lower, true, func(f: float) -> float: return lw * w0 * pow(maxf(1.0 - f, 0.0), wp), float(b.ridge) * 0.5, to_head, centre)
	return [upper, lower]


## The culmen's base in head space (head radius r, the skull's scale `skull`): `at` (its height, and how far it
## stands ahead of the head's front there); the owl's at the foot of its facial disc.
static func bill_base(id: String, r: float, skull: Vector3) -> Vector3:
	var f := spec(id)
	if f.has("disc"):
		return Vector3(0.0, -0.14 * r, disc_z(0.0, -0.14 * r, 0.1, r, skull) + 0.04 * r)
	var at: Array = f.beak.at
	var y := float(at[0]) * r
	var p := Vector3(0.0, y, -skull.z * r * sqrt(maxf(1.0 - pow(y / (skull.y * r), 2.0), 0.0)))
	return p + p.normalized() * float(at[1]) * r


## The face's snout: when the bill's base stands ahead of the head (`at`'s second number, so the eye sits as far
## behind it as in the photo), the head's front is drawn out toward the middle of the bill's base, as far as it:
## flat-topped as far round as the culmen's base or the bill's side, the nearer (`top`, rad), so the bill grows out
## of the face and the forehead runs down onto the culmen, then easing to nothing by `outer`, short of the eyes (the
## rig keeps it off the neck's ring too). [axis (head space, unit), reach (m), outer, top]; reach 0: none (the owl's bill is set in its disc).
static func snout(id: String, r: float, skull: Vector3) -> Array:
	var f := spec(id)
	if f.has("disc") or float(f.beak.at[1]) <= 0.0:
		return [Vector3.FORWARD, 0.0, 0.0, 0.0]
	var base := bill_base(id, r, skull)
	var rib: Array = BillProfiles.DATA[id].upper[0]
	var mid := base + Basis(Vector3.RIGHT, deg_to_rad(float(f.beak.pitch))) * Vector3(0.0, 0.5 * (float(rib[1]) + float(rib[3])) * r, -0.5 * (float(rib[0]) + float(rib[2])) * r)
	var dir := mid.normalized()
	var on_head := r / Vector3(dir.x / skull.x, dir.y / skull.y, dir.z / skull.z).length()   # (the ellipsoid along it)
	var to_eye := acos(clampf(dir.dot(eye_seat(id, 1.0)), -1.0, 1.0))
	var outer := minf(deg_to_rad(40.0), to_eye - float(f.eye.r) - deg_to_rad(6.0))
	# the dome's flat top: round to the culmen's base, but no wider than the bill (or it shows through a narrow bill's sides)
	var top := minf(acos(clampf(dir.dot(base.normalized()), -1.0, 1.0)), 0.8 * atan(float(f.beak.w) * r / mid.length()))
	return [dir, maxf(mid.length() - on_head, 0.0), outer, top]


const BILL_SHADER := preload("res://scripts/bird/bill.gdshader")


## The bill's material (bill.gdshader), set from the species' `beak` and colours and its traced marks (the cere's
## end, the bristles' end).
static func bill_material(id: String) -> ShaderMaterial:
	var f := spec(id)
	var b: Dictionary = f.beak
	var marks: Dictionary = BillProfiles.DATA[id].marks
	var m := ShaderMaterial.new()
	m.shader = BILL_SHADER
	m.set_shader_parameter("bill", Color.html(f.bill))
	m.set_shader_parameter("tip", Color.html(f.bill_tip))
	m.set_shader_parameter("tip_range", Vector2(b.tip_range[0], b.tip_range[1]))
	m.set_shader_parameter("mouth", Color.html(b.mouth))
	m.set_shader_parameter("edge", float(b.edge))
	m.set_shader_parameter("gloss", float(b.gloss))
	if f.cere_col != "" and marks.has("cere ends"):
		m.set_shader_parameter("cere", 1.0)
		m.set_shader_parameter("cere_col", Color.html(f.cere_col))
		m.set_shader_parameter("cere_end", Vector2(marks["cere ends"][0], marks["cere ends"][1]))
		m.set_shader_parameter("cere_lean", float(b.get("cere_lean", 0.5)))
	var n: Array = b.nostril
	if n.size() == 4:
		m.set_shader_parameter("nostril", Vector4(n[0], n[1], n[2], n[3]))
		m.set_shader_parameter("tubercle", float(b.get("tubercle", 0.0)))
	if marks.has("bristles end"):
		m.set_shader_parameter("bristles", 1.0)
		m.set_shader_parameter("bristle_col", Color.html(f.bill).lightened(0.04))
		m.set_shader_parameter("bristle_end", Vector2(marks["bristles end"][0], marks["bristles end"][1]))
		m.set_shader_parameter("bristle_lean", float(b.get("bristle_lean", 0.8)))
	return m


## The lower bill's hinge (head space): the gape's corner, the upper bill's cutting edge at its base.
static func jaw_pivot(id: String, r: float, base: Vector3) -> Vector3:
	var rib: Array = BillProfiles.DATA[id].upper[0]
	return base + Basis(Vector3.RIGHT, deg_to_rad(float(spec(id).beak.pitch))) * Vector3(0.0, float(rib[3]) * r, -float(rib[2]) * r)


const BILL_RINGS := 44    ## loft stations from the base to the tip (the ribs, splined)
const BILL_AROUND := 14    ## points round each half: the outside, and the palate or the mouth's floor
const BILL_BURY := 0.6     ## the base's section carried this share of the way in to the head's centre, shrinking
const PALATE := 0.18       ## the palate's vault up into the upper bill (share of the rib); the floor's down into the lower
const LOWER_TUCK := 0.012  ## head radii: the lower bill's cutting edge raised inside the upper's


## The rib at continuous index k (Catmull-Rom through them): [driver x, y, partner x, y].
static func _rib_at(ribs: Array, k: float) -> PackedFloat32Array:
	var n := ribs.size()
	var i := clampi(int(floor(k)), 0, n - 2)
	var t := clampf(k - i, 0.0, 1.0)
	var out := PackedFloat32Array()
	for c in 4:
		var p0: float = ribs[maxi(i - 1, 0)][c]
		var p1: float = ribs[i][c]
		var p2: float = ribs[i + 1][c]
		var p3: float = ribs[mini(i + 2, n - 1)][c]
		out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	return out


## One mandible. `ribs` run base to tip ([driver, partner] in the bill frame); `lower`: the driver is the underside
## and the partner the cutting edge (else the culmen and the cutting edge); `half_w(f)` the half-width a share f of
## the way along (as the ribs were spaced along the driver: denser toward the tip, BillProfiles); `ridge` narrows
## the section toward the driver.
static func _bill_part(ribs: Array, lower: bool, half_w: Callable, ridge: float, to_head: Callable, centre: Vector2) -> ArrayMesh:
	var n := ribs.size()
	var grids: Array = [[], []]   # the outside, the inside: rows of [head point, uv, uv2, lat]
	var stations: Array = []   # [rib index, share of the way in to the centre]: the heel rounded in, then the bill
	for k in [1.0, 0.55, 0.25, 0.08]:
		stations.append([0.0, BILL_BURY * k])
	for i in BILL_RINGS + 1:
		stations.append([float(n - 1) * i / BILL_RINGS, 0.0])
	for sta in stations:
		var rb := _rib_at(ribs, sta[0])
		var pull: float = sta[1]
		var d := Vector2(rb[0], rb[1]).lerp(centre, pull)   # the driver's point
		var e := Vector2(rb[2], rb[3]).lerp(centre, pull)   # the partner's
		var u: float = sta[0] / float(n - 1)
		var hw: float = half_w.call(1.0 - pow(1.0 - u, 1.35)) * sqrt(maxf(1.0 - pull / BILL_BURY * 0.75, 0.0))
		var foot := e if not lower else d   # the section's foot: the cutting edge (the lower: its underside)
		var v := (d - e) if not lower else (e - d + Vector2(0.0, LOWER_TUCK))
		var rows := [[], []]
		for j in BILL_AROUND + 1:
			# the outside: from the right cutting edge over the culmen (under the gonys) to the left
			var a := PI * j / BILL_AROUND
			var s := sin(a)
			var h := s if not lower else 1.0 - s
			var lat := cos(a) * (1.0 - ridge * s * s)
			var q := foot + v * h
			rows[0].append([to_head.call(q, hw * lat), Vector2(u, h), q, lat])
			# the inside: from the left edge back to the right, the palate vaulted up (the mouth's floor down)
			var ai := PI + PI * j / BILL_AROUND
			var si := absf(sin(ai))
			var hi := PALATE * si if not lower else 1.0 - PALATE * si
			var lati := cos(ai) * (1.0 - 0.1 * si)
			var qi := foot + v * hi
			rows[1].append([to_head.call(qi, hw * lati), Vector2(u, hi), qi, lati])
		grids[0].append(rows[0])
		grids[1].append(rows[1])
	var mids: Array = []   # each ring's centre, inside the mandible: outward is away from it
	for i in grids[0].size():
		var m := Vector3.ZERO
		for j in BILL_AROUND + 1:
			m += grids[0][i][j][0] + grids[1][i][j][0]
		mids.append(m / (2.0 * (BILL_AROUND + 1)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surf := [2.0 / 3.0, 1.0] if lower else [0.0, 1.0 / 3.0]
	var first := 0
	for part in 2:
		var grid: Array = grids[part]
		var rows: int = grid.size()
		var cols := BILL_AROUND + 1
		for i in rows:
			for j in cols:
				var p: Vector3 = grid[i][j][0]
				var da: Vector3 = grid[mini(i + 1, rows - 1)][j][0] - grid[maxi(i - 1, 0)][j][0]
				var db: Vector3 = grid[i][mini(j + 1, cols - 1)][0] - grid[i][maxi(j - 1, 0)][0]
				var nrm := da.cross(db)
				var out_dir: Vector3 = p - mids[i]
				if nrm.length() < 1e-14 or out_dir.length() < 1e-9:   # (the tip, where the ring closes to a point)
					nrm = p - mids[maxi(i - 1, 0)]
				else:
					nrm = nrm * signf(nrm.dot(out_dir))
				st.set_normal(nrm.normalized())
				st.set_uv(grid[i][j][1])
				st.set_uv2(grid[i][j][2])
				st.set_color(Color(0.5 + 0.5 * float(grid[i][j][3]), surf[part], 0.0, 1.0))
				st.add_vertex(p)
		for i in rows - 1:
			for j in cols - 1:
				for tri in [[Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1)], [Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)]]:
					var p0: Vector3 = grid[tri[0].x][tri[0].y][0]
					var p1: Vector3 = grid[tri[1].x][tri[1].y][0]
					var p2: Vector3 = grid[tri[2].x][tri[2].y][0]
					var c := (p1 - p0).cross(p2 - p0)
					if c.length() < 1e-14:
						continue
					var ids: Array = tri.map(func(g: Vector2i) -> int: return first + g.x * cols + g.y)
					# (Godot's front faces wind clockwise seen from outside: the triangle's normal points in)
					if c.dot((p0 + p1 + p2) / 3.0 - mids[tri[0].x]) > 0.0:
						ids = [ids[0], ids[2], ids[1]]
					for k in ids:
						st.add_index(k)
		first += rows * cols
	return st.commit()


## The owl's facial disc: the Barn Owl's heart-shaped dish of feathers over the front of the head, pale with a
## dark rim. It follows the head's front (`skull`: the head sphere's scale), raised a little and rising toward
## the rim into a ruff, then wraps back onto the head just past it, so it is part of the head, not a mask.
## It is the whole front of the head: the heart's top notch on the forehead (DISC_TOP of the head's radius above
## its centre), its point at the chin (DISC_BOTTOM below). (It once ran from 0.4 above the centre to 1.1 below:
## a face plate low on a brown dome, seen from ahead and above.)
const DISC_TOP := 0.65
const DISC_BOTTOM := 0.8
const DISC_K := (DISC_TOP + DISC_BOTTOM) / 1.5          ## the heart's height scale (its curve spans 0.5 .. -1.0)
const DISC_Y := DISC_TOP - 0.5 * (DISC_TOP + DISC_BOTTOM) / 1.5   ## its centre, above the head's (share of r)


static func _disc_outline(t: float, r: float) -> Vector2:
	return Vector2(0.95 * r * sin(t), r * DISC_K * (0.75 * cos(t) - 0.25 * cos(2.0 * t)))


static func disc_mesh(r: float, face: Color, rim: Color, skull := Vector3.ONE) -> ArrayMesh:
	var rows: Array = []
	var cols: Array = []
	var rings := 16
	var n := 48
	for k in rings + 3:
		var s := minf(float(k) / rings, 1.0 + 0.03 * (k - rings))   # (two rings past the rim: down onto the head)
		var row: Array = []
		var crow: Array = []
		for j in n:
			var t := -TAU * j / n   # (wound to face forward)
			var o := _disc_outline(t, r)
			var x := o.x * s
			var y := o.y * s + DISC_Y * r
			row.append(Vector3(x, y, disc_z(x, y, s, r, skull)))
			crow.append(face.lerp(rim, smoothstep(0.82, 0.92, s)))
		rows.append(row)
		cols.append(crow)
	return BodyShape.tube_mesh(rows, null, cols)


## The disc's surface depth at (x, y) for disc radius fraction `s` (head space; -Z forward): the head's front
## surface, raised 0.03 r at the centre rising to a 0.12 r ruff at the rim, easing back onto the head by 1.12 s.
static func disc_z(x: float, y: float, s: float, r: float, skull: Vector3) -> float:
	var q := 1.0 - pow(x / (skull.x * r), 2.0) - pow(y / (skull.y * r), 2.0)
	var surf := -skull.z * r * sqrt(maxf(q, 0.0))
	var lift := (0.03 + 0.06 * pow(minf(s, 1.0), 3.0) + 0.03 * exp(-pow((s - 0.93) / 0.06, 2.0))) * (1.0 - smoothstep(1.0, 1.12, s))
	return surf - r * lift


## Where (x, y) (head space) falls in the heart-shaped disc: 0 at its centre, 1 on its rim.
static func disc_s(x: float, y: float, r: float) -> float:
	var q := Vector2(x, y - DISC_Y * r)
	if q.length() < 1e-6:
		return 0.0
	var best := -2.0
	var rim := 1.0
	for k in 96:
		var t := TAU * k / 96.0
		var o := _disc_outline(t, r)
		var c := o.normalized().dot(q.normalized())
		if c > best:
			best = c
			rim = o.length()
	return q.length() / maxf(rim, 1e-6)

## A fixation time (s): log-normal round `mean`, as raptor inter-saccade intervals are (docs §3.4).
static func fixation(rng: RandomNumberGenerator, mean: float) -> float:
	var sigma := 0.5
	var mu := log(mean) - 0.5 * sigma * sigma   # so the mean comes out at `mean`
	return clampf(exp(mu + sigma * rng.randfn(0.0, 1.0)), 0.08, mean * 5.0)
