class_name Face
extends RefCounted
## Faces: eyes, beaks, the owl's facial disc, and how the head looks around (docs/research/eyes_and_beaks.md,
## section 4; its FACE table, trimmed to what the rig uses). Sizes in head radii r, angles in degrees, colours
## sRGB hex. Head shape (skull scale, brow) lives in BodyShape.
##
## Eyes are lens caps on the head's surface -- only the cornea shows on a bird, the globe is inside -- with
## pupil, iris and eye-ring as vertex-coloured rings. Beaks are lofted upper and lower mandibles: a taper,
## a droop, a raptor's hook (the upper bill overhanging the lower), the falcon's tomial tooth, the cere band.

const DATA := {
	"crow": {
		"eye": {"r": 0.2, "az": 62.0, "el": 14.0}, "iris": "#2a1e18", "pupil": "#050505", "pupil_frac": 0.55, "ring": "#1b1b1f", "ring_w": 0.08,
		"beak": {"len": 2.0, "depth": 0.78, "width": 0.6, "upper": 0.55, "taper": 0.9, "droop": 0.08, "hook": 0.04, "tooth": 0.0, "cere": 0.0, "bristle": 0.3, "pitch": 0.0},
		"bill": "#121214", "bill_tip": "#121214", "cere_col": "", "head_yaw": 150.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 1.0, "sac_speed": 700.0, "blink_pm": 18.0,
	},
	"owl": {   # Barn Owl face
		"eye": {"r": 0.12, "az": 31.0, "el": 8.0}, "iris": "#1a120e", "pupil": "#050404", "pupil_frac": 0.7, "ring": "#3a2c26", "ring_w": 0.25,
		"beak": {"len": 0.3, "depth": 0.18, "width": 0.15, "upper": 0.7, "taper": 1.0, "droop": 0.3, "hook": 0.35, "tooth": 0.0, "cere": 0.0, "bristle": 0.0, "pitch": -35.0},
		"bill": "#e2d3b6", "bill_tip": "#cdb68f", "cere_col": "", "head_yaw": 135.0, "head_pitch": [-80.0, 80.0],
		"fix_s": 2.0, "sac_speed": 600.0, "blink_pm": 4.0, "disc": "heart",
	},
	"hawk": {   # Red-tailed Hawk, adult
		"eye": {"r": 0.24, "az": 48.0, "el": 10.0}, "iris": "#5a321e", "pupil": "#070606", "pupil_frac": 0.45, "ring": "#3a2a20", "ring_w": 0.08,
		"beak": {"len": 1.05, "depth": 0.6, "width": 0.45, "upper": 0.65, "taper": 0.8, "droop": 0.15, "hook": 0.22, "tooth": 0.0, "cere": 0.25, "bristle": 0.0, "pitch": 0.0},
		"bill": "#4a4d55", "bill_tip": "#18181b", "cere_col": "#e3c04a", "head_yaw": 130.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 4.0, "sac_speed": 450.0, "blink_pm": 15.0,
	},
	"falcon": {   # Peregrine, adult
		"eye": {"r": 0.25, "az": 44.0, "el": 10.0}, "iris": "#24170f", "pupil": "#050404", "pupil_frac": 0.5, "ring": "#e8c547", "ring_w": 0.3,
		"beak": {"len": 1.0, "depth": 0.7, "width": 0.5, "upper": 0.65, "taper": 0.8, "droop": 0.15, "hook": 0.25, "tooth": 0.7, "cere": 0.2, "bristle": 0.0, "pitch": 0.0},
		"bill": "#6f7f93", "bill_tip": "#1d1f24", "cere_col": "#e8c547", "head_yaw": 130.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 2.5, "sac_speed": 600.0, "blink_pm": 15.0,
	},
	"sparrow": {   # House Sparrow, male (breeding bill)
		"eye": {"r": 0.22, "az": 68.0, "el": 12.0}, "iris": "#3a2516", "pupil": "#070606", "pupil_frac": 0.55, "ring": "#2a221c", "ring_w": 0.08,
		"beak": {"len": 1.25, "depth": 0.75, "width": 0.7, "upper": 0.5, "taper": 1.0, "droop": 0.04, "hook": 0.0, "tooth": 0.0, "cere": 0.0, "bristle": 0.0, "pitch": 0.0},
		"bill": "#1c1c1e", "bill_tip": "#1c1c1e", "cere_col": "", "head_yaw": 150.0, "head_pitch": [-80.0, 60.0],
		"fix_s": 0.45, "sac_speed": 900.0, "blink_pm": 18.0,
	},
}
const RINGS := 14   ## beak stations
const AROUND := 12
const BLINK_S := 0.2   ## a nictitating blink, across and back


static func spec(id: String) -> Dictionary:
	return DATA.get(id, DATA["crow"])


## The eye's direction from the head centre (head space: -Z the bill, +X right), for side `s` (-1 / 1).
static func eye_dir(id: String, s: float) -> Vector3:
	var e: Dictionary = spec(id).eye
	var az := deg_to_rad(float(e.az))
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


## The beak's two mandibles in head space, base at `base` (head space) pointing along -Z pitched by the
## species' beak pitch: [upper, lower] ArrayMesh, vertex-coloured (cere band, bill, darker tip).
static func beak_meshes(id: String, r: float, base: Vector3) -> Array:
	var f := spec(id)
	var b: Dictionary = f.beak
	var length: float = b.len * r
	var depth: float = b.depth * r
	var width: float = b.width * r
	var hook: float = b.hook
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(float(b.pitch)))
	var bill := Color.html(f.bill)
	var tip := Color.html(f.bill_tip)
	var cere := Color.html(f.cere_col) if f.cere_col != "" else bill
	var out := []
	for lower in [false, true]:
		var rows: Array = []
		var cols: Array = []
		for k in RINGS:
			var u := float(k) / (RINGS - 1)
			var taper := pow(maxf(1.0 - u, 0.0), float(b.taper))
			var yc := -float(b.droop) * length * u * u
			var half_w := 0.5 * width * taper
			var d_up := float(b.upper) * depth * taper
			var lo_u := u / maxf(1.0 - hook, 0.05)
			var d_lo := (1.0 - float(b.upper)) * depth * pow(maxf(1.0 - lo_u, 0.0), float(b.taper))
			var lo_w := 0.5 * width * pow(maxf(1.0 - lo_u, 0.0), float(b.taper))
			if hook > 0.0 and u > 1.0 - hook:   # the hook: the upper bill's tip curls down past the lower
				var h := (u - (1.0 - hook)) / hook
				yc -= 0.6 * hook * length * h * h
				d_up *= lerpf(1.0, 0.6, h)
			var under_edge := 0.02 * r
			if float(b.tooth) > 0.0:   # the falcon's tomial tooth: a bump down on the upper bill's cutting edge
				under_edge += 0.06 * r * exp(-pow((u - float(b.tooth)) / 0.06, 2.0))
			var row: Array = []
			var crow: Array = []
			for j in AROUND:
				var a := -TAU * j / AROUND   # (reversed: outward faces for rows running along -Z)
				var sx := cos(a)
				var sy := sin(a)
				var p: Vector3
				if not lower:
					p = Vector3(half_w * sx, yc + (d_up * sy if sy >= 0.0 else under_edge * sy), -length * u)
				else:
					p = Vector3(lo_w * sx, yc - 0.01 * r + (0.01 * r * sy if sy >= 0.0 else d_lo * sy), -length * u * (1.0 - hook * 0.5))
				row.append(base + pitch * p)
				var c := bill.lerp(tip, smoothstep(0.55, 1.0, u))
				if u < float(b.cere) and not lower:
					c = cere
				if u < float(b.bristle) and not lower and sy > 0.2:
					c = Color.html("#141418")   # the crow's nasal bristles over the base
				crow.append(c)
			rows.append(row)
			cols.append(crow)
		out.append(BodyShape.tube_mesh(rows, null, cols))
	return out


## The owl's facial disc: the Barn Owl's heart-shaped dish of feathers over the front of the head, pale with a
## dark rim. It follows the head's front (`skull`: the head sphere's scale), raised a little and rising toward
## the rim into a ruff, then wraps back onto the head just past it, so it is part of the head, not a mask.
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
			var x := 0.95 * r * sin(t) * s
			var y := r * (0.75 * cos(t) - 0.25 * cos(2.0 * t)) * s - 0.1 * r
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
	var q := Vector2(x, y + 0.1 * r)
	if q.length() < 1e-6:
		return 0.0
	var best := -2.0
	var rim := 1.0
	for k in 96:
		var t := TAU * k / 96.0
		var o := Vector2(0.95 * r * sin(t), r * (0.75 * cos(t) - 0.25 * cos(2.0 * t)))
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
