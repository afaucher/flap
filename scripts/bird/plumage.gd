class_name Plumage
extends RefCounted
## Plumage colours per species (docs/research/plumage_coloring.md: the zones, marks and approximate sRGB values
## come from its tables). Built up in steps, so each can be compared (`level`, rig gallery `--plumage N`):
##   0  the old look: one tint per species, darkened per feather kind, the same on both faces
##   1  two-sided feathers (top and underside colours) and a countershaded body (dark back, pale belly)
##   2  + an underwing-covert row, and the wing's leading edge coloured underneath: the patagial bar and the
##        dark wrist comma
##   3  + darker outer primaries (the wingtip "fingers") by feather position
##   4  + head markings: crown, nape, face, throat; the falcon's hood and moustache, the owl's facial disc, the
##        sparrow's bib
##   5  + marks along each feather from a small generated colour strip: dark tips, the dark trailing edge,
##        tail bands, bars, the sparrow's white wing bar (the only step with a shader, and it only sets colour)
## Below level 5 each feather is one flat colour: its strip averaged (bars and fringes read as a mid-tone).

static var level := 5

## Per species. body: dorsal back -> rump, ventral breast -> belly -> vent, flanks; countershade `line`
## (-1 belly .. 1 back) and `soft`; optional `band` [colour, from, to] (along the body, 0 front .. 1 back),
## `bib` [colour, to], `scap` [colour, from, to] (a pale patch over the shoulders, the Red-tail's "V").
## head: crown, nape, face, throat, `cap` (how far down the crown colour comes, -1..1), optional `malar`
## (a stripe below the eye) and `disc` [face, rim]. wing: upperwing lesser/greater/tertial/alula, underwing
## `under` (coverts), `patagial` (leading-edge bar), `carpal` (wrist comma). groups: [top, under] for the
## primaries, secondaries and tail. fingers: [outer primaries, darken top, darken under]. marks: patterns
## along the feather per "group_side" (see `_row`); a list of patterns applies in order.
const DATA := {
	"crow": {
		"body": {"back": "#1c1c22", "rump": "#1c1c22", "breast": "#1f1f24", "belly": "#1f1f24", "vent": "#1f1f24", "flanks": "#1f1f24", "line": 0.0, "soft": 0.3},
		"head": {"crown": "#1b1b21", "nape": "#1b1b21", "face": "#1d1d23", "throat": "#1d1d23", "cap": 0.35},
		"wing": {"lesser": "#1e1e25", "greater": "#1e1e25", "tertial": "#1e1e25", "alula": "#1e1e25", "under": "#1c1c21", "patagial": "#1c1c21", "carpal": "#1c1c21"},
		"groups": {"primary": ["#202026", "#2c2c31"], "secondary": ["#202027", "#2a2a30"], "tail": ["#1e1e24", "#2a2a2f"]},
		"fingers": [0, 0.0, 0.0],
		"marks": {},
	},
	"owl": {
		"body": {"back": "#a8875a", "rump": "#b8996a", "breast": "#efe4cf", "belly": "#f1e8d6", "vent": "#f3ece0", "flanks": "#e6d3b0", "line": 0.2, "soft": 0.3},
		"head": {"crown": "#a8875a", "nape": "#a8875a", "face": "#f2ece0", "throat": "#efe6d6", "cap": 0.45, "disc": ["#f2ece0", "#8a6a48"]},
		"wing": {"lesser": "#a07c50", "greater": "#b08a58", "tertial": "#b08a5a", "alula": "#a07c50", "under": "#f4ede0", "patagial": "#f4ede0", "carpal": "#e9dcc4"},
		"groups": {"primary": ["#b8905c", "#e8dcc6"], "secondary": ["#b89462", "#ebe0cc"], "tail": ["#c09a64", "#ece2cf"]},
		"fingers": [2, 0.1, 0.25],
		"marks": {
			"primary_top": ["bars", "#6e5a46", 4, 0.25], "primary_under": ["bars_tip", "#c9b89c", 4, 0.25, "#9a8c78", 0.85],
			"secondary_top": ["bars", "#6e5a46", 4, 0.25], "secondary_under": ["bars", "#d2c4ac", 4, 0.25],
			"greater_top": ["fringe", "#8e8676", 0.2], "tail_top": ["bars", "#7a6650", 4, 0.25], "tail_under": ["bars", "#d8ccb6", 4, 0.25],
		},
	},
	"hawk": {
		"body": {"back": "#5a3e2b", "rump": "#5e4230", "breast": "#f1e7d6", "belly": "#efe4d2", "vent": "#f3ece2", "flanks": "#c9ae8a", "line": 0.05, "soft": 0.25, "band": ["#a88a6c", 0.42, 0.68], "scap": ["#a8875f", 0.15, 0.45]},
		"head": {"crown": "#5e4230", "nape": "#6b4a32", "face": "#8a6a4e", "throat": "#e8dccb", "cap": 0.3},
		"wing": {"lesser": "#5a3f2c", "greater": "#6b4c34", "tertial": "#64482f", "alula": "#4e3626", "under": "#f0e6d6", "patagial": "#4a3324", "carpal": "#3f2c20"},
		"groups": {"primary": ["#4a3628", "#e9e4dc"], "secondary": ["#5e4632", "#e6e0d6"], "tail": ["#b8532a", "#e8c9a6"]},
		"fingers": [3, 0.35, 0.0],
		"marks": {
			"primary_under": ["bars_tip", "#b8aea2", 5, 0.25, "#2e2621", 0.78], "secondary_top": ["bars", "#4a3828", 5, 0.2],
			"secondary_under": ["bars_tip", "#b8aea2", 6, 0.2, "#6a5c50", 0.88], "greater_top": ["tip", "#8a6c50", 0.8],
			"tail_top": ["subterm", "#3a2a20", 0.85, 0.92, "#e9dccb"], "tail_under": ["subterm", "#b89a7c", 0.85, 0.92, "#f2e6d6"],
		},
	},
	"falcon": {
		"body": {"back": "#5f6b78", "rump": "#7d8a98", "breast": "#f3ece2", "belly": "#bdb6ae", "vent": "#bdb6ae", "flanks": "#bdb6ae", "line": 0.05, "soft": 0.2},
		"head": {"crown": "#2a2e35", "nape": "#2a2e35", "face": "#f4efe6", "throat": "#f4efe6", "cap": -0.05, "malar": "#2a2e35"},
		"wing": {"lesser": "#66727f", "greater": "#66727f", "tertial": "#5a6672", "alula": "#5f6b78", "under": "#b9b2aa", "patagial": "#b9b2aa", "carpal": "#b9b2aa"},
		"groups": {"primary": ["#2b2f36", "#cfc9c2"], "secondary": ["#4f5a66", "#cbc5be"], "tail": ["#5d6874", "#c9c4bd"]},
		"fingers": [4, 0.25, 0.0],
		"marks": {
			"primary_under": ["bars_tip", "#8a8580", 7, 0.3, "#5a5550", 0.85], "secondary_under": ["bars", "#8a8580", 7, 0.3],
			"greater_top": ["bars", "#55606c", 4, 0.2],
			"tail_top": [["bars", "#3e4650", 6, 0.3], ["subterm", "#23262b", 0.86, 0.94, "#ece8e0"]],
			"tail_under": [["bars", "#8f8a84", 6, 0.3], ["subterm", "#55585c", 0.86, 0.94, "#ece8e0"]],
		},
	},
	"sparrow": {
		"body": {"back": "#7a5a3a", "rump": "#8a8578", "breast": "#c4c1b8", "belly": "#c4c1b8", "vent": "#d6d0c3", "flanks": "#b7ae9d", "line": 0.0, "soft": 0.15, "bib": ["#1f1d1b", 0.22]},
		"head": {"crown": "#8a8e8f", "nape": "#7b4a2c", "face": "#c9c6bd", "throat": "#1f1d1b", "cap": 0.35},
		"wing": {"lesser": "#7a4a2c", "greater": "#2a221c", "tertial": "#2e241d", "alula": "#4d3d30", "under": "#c8c2b6", "patagial": "#c8c2b6", "carpal": "#c8c2b6"},
		"groups": {"primary": ["#4d3d30", "#8f8a82"], "secondary": ["#5a4632", "#8f8a82"], "tail": ["#5a4a3c", "#7f786e"]},
		"fingers": [0, 0.0, 0.0],
		"marks": {
			"lesser_bar_top": ["tip", "#eeeae0", 0.62], "greater_top": ["fringe", "#a0663a", 0.4], "tertial_top": ["fringe", "#b07a46", 0.4],
			"primary_top": ["fringe", "#9a7a58", 0.15], "secondary_top": ["fringe", "#9a7a58", 0.15], "tail_top": ["fringe", "#8e7a62", 0.2],
		},
	},
}
const STRIP := 64   ## texels along a feather in the mark strip
## Rows of the mark strip: one per feather group and face.
const GROUPS := ["primary", "secondary", "tertial", "greater", "lesser", "lesser_bar", "alula", "under_covert", "tail"]


static func hex(s: String) -> Color:
	return Color.html(s)


static func spec(id: String) -> Dictionary:
	return DATA.get(id, DATA["crow"])


## The feather group a wing feather belongs to ("lesser_bar": the sparrow's forearm lesser coverts, which
## carry its white wing bar; other species fall back to "lesser").
static func group(kind: int, i: int, bone: int) -> String:
	match kind:
		WingShape.Kind.PRIMARY: return "primary"
		WingShape.Kind.SECONDARY: return "secondary"
		WingShape.Kind.TERTIAL: return "tertial"
		WingShape.Kind.ALULA: return "alula"
		WingShape.Kind.GREATER_COVERT: return "greater"
		WingShape.Kind.UNDER_COVERT: return "under_covert"
		WingShape.Kind.LESSER_COVERT: return "lesser_bar" if bone == WingShape.Bone.FOREARM else "lesser"
	return "tail"


## Base colours of a group's two faces, before marks: [top, under].
static func base(id: String, g: String) -> Array:
	var s := spec(id)
	var w: Dictionary = s.wing
	match g:
		"primary", "secondary", "tail":
			return [hex(s.groups[g][0]), hex(s.groups[g][1])]
		"tertial": return [hex(w.tertial), hex(s.groups.secondary[1])]
		"greater": return [hex(w.greater), hex(w.under)]
		"lesser", "lesser_bar": return [hex(w.lesser), hex(w.under)]
		"alula": return [hex(w.alula), hex(w.carpal)]
		"under_covert": return [hex(w.under), hex(w.under)]
	return [Color.WHITE, Color.WHITE]


## One face of a group along the feather (0 base .. 1 tip): its base colour with its marks applied.
static func row(id: String, g: String, under: bool) -> PackedColorArray:
	var b: Color = base(id, g)[1 if under else 0]
	var out := PackedColorArray()
	out.resize(STRIP)
	out.fill(b)
	var marks: Dictionary = spec(id).marks
	var key := "%s_%s" % [g, "under" if under else "top"]
	if not marks.has(key) and g == "lesser_bar":
		key = "lesser_%s" % ("under" if under else "top")
	if not marks.has(key):
		return out
	var m: Array = marks[key]
	var list: Array = m if m.size() > 0 and m[0] is Array else [m]
	for pat in list:
		for k in STRIP:
			out[k] = _apply(out[k], pat, (k + 0.5) / STRIP)
	return out


## Pattern ids (docs/research/plumage_coloring.md, section 4), at position t along the feather:
## tip [mark, from], base [mark, to], subterm [mark, from, to, tip], bars [mark, n, duty],
## bars_tip [mark, n, duty, tip, from], fringe / streak [mark, width] (averaged across the vane: a mid-tone).
static func _apply(c: Color, p: Array, t: float) -> Color:
	var mark := hex(p[1])
	match String(p[0]):
		"tip": return c.lerp(mark, smoothstep(float(p[2]) - 0.02, float(p[2]) + 0.02, t))
		"base": return c.lerp(mark, 1.0 - smoothstep(float(p[2]) - 0.02, float(p[2]) + 0.02, t))
		"subterm":
			var band := smoothstep(float(p[2]) - 0.015, float(p[2]) + 0.015, t)
			var tip := smoothstep(float(p[3]) - 0.015, float(p[3]) + 0.015, t)
			return c.lerp(mark, band * (1.0 - tip)).lerp(hex(p[4]), tip)
		"bars", "bars_tip":
			var n := float(p[2])
			var duty := float(p[3])
			var ph := fposmod(t * n, 1.0)
			var on := smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(duty, duty + 0.06, ph))
			var out := c.lerp(mark, on)
			if p[0] == "bars_tip":
				out = out.lerp(hex(p[4]), smoothstep(float(p[5]) - 0.02, float(p[5]) + 0.02, t))
			return out
		"fringe", "streak": return c.lerp(mark, float(p[2]))
	return c


## A face's single flat colour (levels 1-4): its strip averaged, over the exposed outer two-thirds.
static func flat(id: String, g: String, under: bool) -> Color:
	var r := row(id, g, under)
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for k in range(STRIP / 3, STRIP):
		acc += r[k]
		n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n, 1.0)


## The mark strip: one row per group and face (row index = group index * 2 + under).
static func strip(id: String) -> ImageTexture:
	var img := Image.create(STRIP, GROUPS.size() * 2, false, Image.FORMAT_RGBA8)
	for gi in GROUPS.size():
		for u in 2:
			var r := row(id, GROUPS[gi], u == 1)
			for k in STRIP:
				img.set_pixel(k, gi * 2 + u, r[k])
	return ImageTexture.create_from_image(img)


static func row_index(g: String, under: bool) -> int:
	return GROUPS.find(g) * 2 + (1 if under else 0)


## How much a primary darkens (the wingtip "fingers"), from level 3: [top, under] multipliers.
static func finger(id: String, i: int) -> Array:
	var f: Array = spec(id).fingers
	if level < 3 or int(f[0]) == 0 or i <= 10 - int(f[0]):
		return [1.0, 1.0]
	var k := float(i - (10 - int(f[0]))) / float(f[0])   # 1/n .. 1 toward the tip
	return [1.0 - float(f[1]) * k, 1.0 - float(f[2]) * k]


## The body's colour at a point of the trunk: `u` along it (0 front .. 1 back), `v` up its side (-1 keel ..
## 1 spine), `side` how far round to the flank (0 midline .. 1 widest).
static func body(id: String, u: float, v: float, side: float) -> Color:
	var b: Dictionary = spec(id).body
	var dorsal := hex(b.back).lerp(hex(b.rump), smoothstep(0.5, 0.9, u))
	var ventral := hex(b.breast).lerp(hex(b.belly), smoothstep(0.25, 0.5, u)).lerp(hex(b.vent), smoothstep(0.75, 0.95, u))
	ventral = ventral.lerp(hex(b.flanks), smoothstep(0.55, 0.95, side) * 0.8)
	if b.has("band"):
		ventral = ventral.lerp(hex(b.band[0]), smoothstep(b.band[1] - 0.05, b.band[1] + 0.05, u) * (1.0 - smoothstep(b.band[2] - 0.05, b.band[2] + 0.05, u)) * 0.85)
	if level >= 4 and b.has("bib"):
		ventral = ventral.lerp(hex(b.bib[0]), 1.0 - smoothstep(b.bib[1] - 0.05, b.bib[1] + 0.05, u))
	if b.has("scap"):
		dorsal = dorsal.lerp(hex(b.scap[0]), smoothstep(0.45, 0.8, side) * smoothstep(b.scap[1] - 0.05, b.scap[1] + 0.05, u) * (1.0 - smoothstep(b.scap[2] - 0.05, b.scap[2] + 0.05, u)) * 0.7)
	return ventral.lerp(dorsal, smoothstep(float(b.line) - float(b.soft), float(b.line) + float(b.soft), v))


## The head's colour in direction `d` from its centre (head space: -Z the bill, +Y up). Below level 4 it is
## just countershaded: crown above, throat below.
static func head(id: String, d: Vector3, eye: Vector3) -> Color:
	var h: Dictionary = spec(id).head
	var crown := hex(h.crown)
	var throat := hex(h.throat) if level >= 4 else hex(spec(id).body.breast)
	if level < 4:
		return throat.lerp(crown, smoothstep(-0.4, 0.2, d.y))
	var front := -d.z
	var c := hex(h.face)
	c = c.lerp(hex(h.nape), smoothstep(-0.1, 0.45, -front))                    # the back of the head
	c = c.lerp(throat, smoothstep(-0.25, -0.55, d.y) * smoothstep(-0.3, 0.1, front))
	if h.has("disc"):   # the owl's facial disc: a pale dish on the front, rimmed dark
		var ang := acos(clampf(front, -1.0, 1.0))
		c = c.lerp(hex(h.disc[0]), 1.0 - smoothstep(0.85, 0.95, ang))
		c = c.lerp(hex(h.disc[1]), smoothstep(0.82, 0.92, ang) * (1.0 - smoothstep(1.02, 1.12, ang)))
	if h.has("malar"):   # a dark stripe from below the eye down the cheek
		var e := Vector2(absf(d.x) - absf(eye.x) * 0.9, d.z - eye.z).length()
		var below := smoothstep(eye.y + 0.05, eye.y - 0.1, d.y) * smoothstep(eye.y - 0.8, eye.y - 0.55, d.y)
		c = c.lerp(hex(h.malar), (1.0 - smoothstep(0.16, 0.26, e)) * below)
	return c.lerp(crown, smoothstep(float(h.cap) - 0.1, float(h.cap) + 0.1, d.y))


## The wing's leading-edge pieces (BirdRig limbs): colour at a point of one piece (0 propatagium, 1 humerus,
## 2 forearm, 3 hand), `x` 0 front .. 1 back across it, `u` 0 root .. 1 tip along it, on the top or underside.
static func limb(id: String, piece: int, x: float, u: float, under: bool) -> Color:
	var w: Dictionary = spec(id).wing
	var top := hex(w.lesser)
	if level < 2 or not under:
		return top
	var c := hex(w.under)
	var edge := 1.0 - smoothstep(0.25, 0.45, x)        # the front underside
	if piece <= 2:
		c = c.lerp(hex(w.patagial), edge)
	if piece == 3 or (piece == 2 and u > 0.7):
		c = c.lerp(hex(w.carpal), edge * (1.0 if piece == 3 else smoothstep(0.7, 0.9, u)))
	return c
