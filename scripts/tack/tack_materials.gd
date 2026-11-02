class_name TackMaterials
extends RefCounted
## The tack's materials, made once and shared by every bird. Each is one of three shaders (leather, metal,
## cloth) with a set of values, plus skin, eyes and goggle glass. Colours are sRGB.
##   leather: saddle (chestnut), seat (oxblood, quilted), strap (dark havana), helmet (brown, glossy),
##            jacket (dark, coarse grain), boot (black-brown, polished), glove (tan, soft)
##   metal:   brass, blued (blued steel), nickel, olive (enamel over steel, chipped), roundel, red (seeker noses)
##   cloth:   breeches (khaki twill), tunic (olive twill), silk (scarf), fleece (sheepskin), lining (the helmet's shearling), canvas, hair
##   skin, eye: their own shaders (skin.gdshader, eye.gdshader)

const LEATHER := preload("res://scripts/tack/leather.gdshader")
const METAL := preload("res://scripts/tack/metal.gdshader")
const CLOTH := preload("res://scripts/tack/cloth.gdshader")
const SKIN := preload("res://scripts/tack/skin.gdshader")
const EYE := preload("res://scripts/tack/eye.gdshader")

const SPECS := {
	"saddle": [LEATHER, {"base_col": Color(0.46, 0.26, 0.13), "dark_col": Color(0.17, 0.08, 0.04), "worn_col": Color(0.68, 0.46, 0.27)}],
	"seat": [LEATHER, {"base_col": Color(0.33, 0.12, 0.08), "dark_col": Color(0.12, 0.04, 0.03), "worn_col": Color(0.5, 0.26, 0.17), "quilt": 1.5, "rough": 0.5, "stitch_row": 0.3}],
	"strap": [LEATHER, {"base_col": Color(0.27, 0.15, 0.08), "dark_col": Color(0.1, 0.05, 0.03), "worn_col": Color(0.45, 0.3, 0.18), "stitch_row": 0.45, "stitch_pitch": 0.6, "edge_band": 0.25}],
	"helmet": [LEATHER, {"base_col": Color(0.4, 0.22, 0.11), "dark_col": Color(0.15, 0.07, 0.03), "worn_col": Color(0.6, 0.4, 0.24), "rough": 0.38, "sheen": 0.3, "stitch_row": 0.35, "grain": 0.16}],
	"jacket": [LEATHER, {"base_col": Color(0.24, 0.14, 0.08), "dark_col": Color(0.08, 0.04, 0.02), "worn_col": Color(0.42, 0.27, 0.16), "rough": 0.52, "grain": 0.32, "grain_depth": 1.4, "stitch_row": 0.5}],
	"boot": [LEATHER, {"base_col": Color(0.1, 0.06, 0.04), "dark_col": Color(0.03, 0.02, 0.015), "worn_col": Color(0.24, 0.15, 0.1), "rough": 0.26, "gloss_worn": 0.15, "grain": 0.12, "grain_depth": 0.4, "stitch_row": 0.0, "sheen": 0.1}],
	"glove": [LEATHER, {"base_col": Color(0.58, 0.4, 0.24), "dark_col": Color(0.3, 0.18, 0.1), "worn_col": Color(0.4, 0.28, 0.18), "rough": 0.66, "grain": 0.12, "stitch_row": 0.15, "stitch_pitch": 0.3, "stitch_w": 0.05}],
	"brass": [METAL, {"metal_col": Color(0.74, 0.56, 0.3), "tarnish_col": Color(0.3, 0.21, 0.1), "tarnish": 0.75, "verdigris": 0.3, "rough": 0.34}],
	"blued": [METAL, {"metal_col": Color(0.09, 0.1, 0.13), "tarnish_col": Color(0.2, 0.14, 0.1), "tarnish": 0.35, "verdigris": 0.0, "rough": 0.3}],
	"nickel": [METAL, {"metal_col": Color(0.66, 0.66, 0.68), "tarnish_col": Color(0.26, 0.25, 0.24), "tarnish": 0.35, "verdigris": 0.0, "rough": 0.24}],
	"olive": [METAL, {"metal_col": Color(0.55, 0.56, 0.58), "tarnish_col": Color(0.3, 0.22, 0.15), "tarnish": 0.4, "verdigris": 0.0, "paint": 1.0, "paint_col": Color(0.3, 0.32, 0.2)}],
	"roundel": [METAL, {"metal_col": Color(0.55, 0.56, 0.58), "verdigris": 0.0, "paint": 1.0, "paint_col": Color(0.3, 0.32, 0.2), "pattern": 1, "chip": 0.5}],
	"red": [METAL, {"metal_col": Color(0.55, 0.56, 0.58), "verdigris": 0.0, "paint": 1.0, "paint_col": Color(0.66, 0.1, 0.07), "chip": 0.45}],
	"breeches": [CLOTH, {"col": Color(0.5, 0.43, 0.29), "dark_col": Color(0.3, 0.25, 0.16), "pitch": 0.22, "seam_row": 0.25}],
	"tunic": [CLOTH, {"col": Color(0.36, 0.37, 0.25), "dark_col": Color(0.2, 0.21, 0.14), "pitch": 0.22, "seam_row": 0.25}],
	"silk": [CLOTH, {"col": Color(0.95, 0.93, 0.88), "dark_col": Color(0.72, 0.7, 0.66), "weave": 1, "pitch": 0.08, "rough": 0.33, "fuzz": 0.2}],
	"fleece": [CLOTH, {"col": Color(0.8, 0.73, 0.6), "dark_col": Color(0.45, 0.38, 0.29), "weave": 2, "pitch": 0.3, "rough": 1.0, "fuzz": 0.75, "bump": 1.4}],
	"lining": [CLOTH, {"col": Color(0.66, 0.56, 0.42), "dark_col": Color(0.34, 0.27, 0.19), "weave": 2, "pitch": 0.2, "rough": 1.0, "fuzz": 0.7, "bump": 1.2}],
	"hair": [CLOTH, {"col": Color(0.34, 0.22, 0.12), "dark_col": Color(0.13, 0.08, 0.04), "weave": 1, "pitch": 0.03, "rough": 0.45, "fuzz": 0.3}],
	"skin": [SKIN, {}],
	"eye": [EYE, {}],
	"canvas": [CLOTH, {"col": Color(0.62, 0.58, 0.44), "dark_col": Color(0.38, 0.35, 0.26), "pitch": 0.16, "rough": 0.9, "seam_row": 0.3}],
}

static var _cache := {}


static func get_mat(id: String) -> Material:
	if _cache.has(id):
		return _cache[id]
	var m: Material
	match id:
		"glass":
			var g := StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.albedo_color = Color(0.32, 0.4, 0.36, 0.45)
			g.roughness = 0.03
			g.metallic_specular = 1.0
			g.clearcoat_enabled = true
			g.clearcoat = 1.0
			g.clearcoat_roughness = 0.02
			m = g
		"dark":
			var d := StandardMaterial3D.new()
			d.albedo_color = Color(0.02, 0.018, 0.016)
			d.roughness = 0.9
			m = d
		_:
			var spec: Array = SPECS[id]
			var sm := ShaderMaterial.new()
			sm.shader = spec[0]
			for k in (spec[1] as Dictionary):
				sm.set_shader_parameter(k, spec[1][k])   # (Colors: source_color uniforms take them as sRGB)
			m = sm
	_cache[id] = m
	return m
