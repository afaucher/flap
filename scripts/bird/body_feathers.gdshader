// Body feathers (Plumage level 6; docs/research/feather_texture_study.md): the body's plumage colours (vertex
// colours, sRGB) under a repeating tile of small overlapping contour feathers, tips toward +v. Matte, as the
// plain body. Two baked tiles (FeatherAtlas): `scales` R shade, G shaft, B spot field, A edge distance;
// `scales_n` RG the relief's normal (tile space), B and A two random values per feather (its own variation).
// The trunk, neck, head and arm loft share one feather chart (BirdRig "Feather coordinates"):
//   UV   = (u across the flow, v along it), in tiles;
//   UV2  = (u's period -- the ring's girth, where u comes round on itself --, up: 1 back .. -1 belly);
//   COLOR.a = how strongly the texture shows there.
// u is periodic: at its seam (u = +-period / 2: under the belly and the chin) the two sides cross-fade, so there
// is neither a seam nor a mirror line. Repeats are broken up by reading the tile at a slowly wandering offset
// (two reads, changing over along the feathers' own outlines), a slow mottle, and each feather's own colour.
// The outline frays (`fray`): where the surface is seen edge-on the body's own pixels give way along the feathers'
// tips and a fine grain of barbs, so the silhouette breaks into feather tips and loose barbs without anything drawn
// off the surface (the first try, shells a few mm out, read as dashed lines floating beside the bird up close).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// In the sun (the concept's backlit kestrel; docs/research/feather_texture_study.md, "In the sun"): the light
// follows each feather, from its own texture. A vane is a thin sheet of barbs: a sun behind it shines through
// (most where it is thin and pale, none through the shaft); its free edge and tip -- the barbs' ends -- catch the
// light and glow, most when looking toward the sun; and the barbs streak the sheen along themselves (anisotropic,
// tight across them). Wrapped diffuse: soft barbs don't fall off hard at the terminator.
uniform float through_boost = 1.0;   // light through the vanes (0: none)
uniform float edge_glow = 1.0;       // the free edges' and tips' glow (0: none)
uniform float barb_sheen = 1.0;      // the sheen streaked along the barbs (0: none)
varying float v_through;
varying float v_edge;
varying vec3 v_barb;
varying vec2 v_spec;                 // (specular level, its width across the barbs)

uniform sampler2D scales : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scales_n : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 spot_tint = vec3(0.5);  // the spot's colour as a multiple of the body colour
uniform float spot_back = 0.0;       // spot amount on the back .. on the belly
uniform float spot_belly = 0.0;
uniform float spot_size = 0.5;
uniform vec3 fringe_col = vec3(1.0); // pale feather edges (sRGB), mixed in by fringe_amt
uniform float fringe_amt = 0.0;
uniform float fringe_w = 0.35;
uniform float strength = 1.0;
uniform float relief = 0.45;         // the relief's strength (0: flat)
uniform float variety = 1.0;         // the offset's wander and each feather's variation (0: the bare tile)
uniform float row_spacing = 1.45;   // rows this much further apart than the tile's own (more of each feather shows)
uniform float seam_band = 0.12;      // tiles: the cross-fade's width at u's seam
uniform bool show_chart = false;     // debug: the feather chart as a grid (red: u, green: v, blue: by the seam)
uniform float fray = 0.0;            // the outline's fraying (0 off .. 1)
uniform float fray_grazing = 0.3;    // frays where |N.V| is below this: the outermost few millimetres

varying vec2 period_up;
instance uniform int gpu_surface = 0;   // BirdRig.gpu_body: 1 the neck, 2 / 3 the left / right arm wing, lofted here
#include "res://scripts/bird/neck_place.gdshaderinc"
#include "res://scripts/bird/arm_place.gdshaderinc"

void vertex() {
	if (gpu_surface == 1) {
		vec4 col;
		vec2 uv;
		vec2 uv2;
		neck_vertex(int(UV.x + 0.5), int(UV.y + 0.5), VERTEX, NORMAL, col, uv, uv2);
		COLOR = col;
		UV = uv;
		UV2 = uv2;
	} else if (gpu_surface >= 2) {
		vec4 col;
		vec2 uv;
		vec2 uv2;
		arm_vertex(gpu_surface - 2, int(UV.x + 0.5), int(UV.y + 0.5), VERTEX, NORMAL, col, uv, uv2);
		COLOR = col;
		UV = uv;
		UV2 = uv2;
	}
	period_up = UV2;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The tile at `st`, read at an offset that wanders with a slow noise: two offsets, changing over where one
// read's feather lies further inside its outline than the other's, so the change follows feather edges.
void read_tile(vec2 st, vec2 dx, vec2 dy, out vec4 t, out vec4 n) {
	float k = value_noise(st * 0.2) * 4.0 * variety;   // (patches a few tiles across: few change-overs in view)
	float ia = floor(k);
	float f = fract(k);
	vec2 oa = vec2(hash12(vec2(ia, 3.1)), hash12(vec2(ia, 7.7)));
	vec2 ob = vec2(hash12(vec2(ia + 1.0, 3.1)), hash12(vec2(ia + 1.0, 7.7)));
	vec4 ta = textureGrad(scales, st + oa, dx, dy);
	vec4 tb = textureGrad(scales, st + ob, dx, dy);
	float w = smoothstep(0.42, 0.58, f + 1.2 * (tb.a - ta.a));
	t = mix(ta, tb, w);
	n = mix(textureGrad(scales_n, st + oa, dx, dy), textureGrad(scales_n, st + ob, dx, dy), w);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec2 uv = UV * vec2(1.0, 1.0 / row_spacing);
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	float period = period_up.x;
	float up = period_up.y;
	// u comes round on itself every `period`: wrap it, and cross-fade with the other side's read by the seam.
	float half_p = 0.5 * period;
	float uw = uv.x - period * round(uv.x / period);
	float seam = (period < 500.0) ? 0.5 * smoothstep(half_p - seam_band, half_p, abs(uw)) : 0.0;
	vec4 t;
	vec4 n;
	read_tile(vec2(uw, uv.y), dx, dy, t, n);
	if (seam > 0.001) {
		vec4 t2;
		vec4 n2;
		read_tile(vec2(uw - sign(uw) * period, uv.y), dx, dy, t2, n2);
		t = mix(t, t2, seam);
		n = mix(n, n2, seam);
	}
	float k = strength * COLOR.a;
	// Fray the outline: give way where a feather's edge is near (its tip and sides) and between fine barbs, more
	// toward the very edge.
	if (fray > 0.0) {
		float rim = 1.0 - smoothstep(0.0, fray_grazing, facing);
		float barbs = value_noise(vec2(uw * 28.0, uv.y * 9.0));
		if (fray * rim * k > t.a * 0.85 + barbs * 0.3 + 0.08) {
			discard;
		}
	}
	float vary = variety * k;
	// Each feather a touch lighter or darker, warmer or cooler; a slow mottle over the tracts.
	float mottle = (value_noise(uv * 1.3 + 4.0) - 0.5) * 0.08 * vary;
	vec3 c = COLOR.rgb * (1.0 + mottle + (n.b - 0.5) * 0.08 * vary);
	c *= vec3(1.0 + (n.a - 0.5) * 0.04 * vary, 1.0, 1.0 - (n.a - 0.5) * 0.04 * vary);
	float spot_amt = mix(spot_belly, spot_back, smoothstep(-0.3, 0.3, up)) * (1.0 + (n.a - 0.5) * 0.5 * vary);
	float ss = spot_size * (1.0 + (n.b - 0.5) * 0.4 * vary);
	c = mix(c, c * spot_tint, smoothstep(0.88 - ss * 0.7, 1.0 - ss * 0.7, t.b) * clamp(spot_amt, 0.0, 1.0) * k);
	c = mix(c, mix(c, fringe_col, fringe_amt), (1.0 - smoothstep(fringe_w * 0.4, fringe_w, t.a)) * k);
	c = mix(c, c * 0.8, t.g * k);
	ALBEDO = to_linear(c) * mix(1.0, t.r * 1.1, k);
	ROUGHNESS = 0.95;
	SPECULAR = 0.35;
	if (show_chart) {
		vec2 g = abs(fract(vec2(uw, uv.y) * vec2(4.0, 8.0)) - 0.5);
		ALBEDO = vec3(smoothstep(0.42, 0.48, g.x), smoothstep(0.42, 0.48, g.y), seam * 2.0) * 0.8 + 0.1;
	}
	// Relief: each feather lifts toward its tip and steps down onto the row behind. The tile's normal is in the
	// chart's frame (u, v): a cotangent frame from the screen derivatives, so the meshes need no tangents.
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec3 nrm = NORMAL;
	vec3 dp2perp = cross(dp2, nrm);
	vec3 dp1perp = cross(nrm, dp1);
	vec3 tu = dp2perp * dx.x + dp1perp * dy.x;
	vec3 tv = dp2perp * dx.y + dp1perp * dy.y;
	float invmax = inversesqrt(max(max(dot(tu, tu), dot(tv, tv)), 1e-20));
	vec2 nn = (n.rg * 2.0 - 1.0) * relief * k;
	NORMAL = normalize(nrm * sqrt(max(1.0 - dot(nn, nn), 0.0)) + (tu * nn.x + tv * nn.y) * invmax);
	// For the light: each contour feather's barbs run back along the flow; its free edge (the tile's edge distance)
	// catches the light; the body is thick, so only the feathers' thin edges pass any.
	v_barb = tv * invmax;   // (left unnormalised: light() makes it a unit tangent)
	float pale = clamp(dot(ALBEDO, vec3(0.3, 0.59, 0.11)) * 3.0, 0.0, 1.0);
	float fedge = (1.0 - smoothstep(0.0, 0.3, t.a)) * k;
	v_through = 0.12 * fedge * pale;
	v_edge = fedge * (0.4 + 0.6 * pale) * 0.7;
	v_spec = vec2(0.12, 0.3);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 lc = LIGHT_COLOR * ATTENUATION / PI;
	DIFFUSE_LIGHT += lc * max(0.0, (ndl + 0.2) / 1.2);
	float toward = pow(max(0.0, dot(-VIEW, LIGHT)), 2.0);   // (looking toward the light)
	DIFFUSE_LIGHT += lc * v_through * through_boost * (max(0.0, -ndl) * 1.2 + toward * 2.0);
	DIFFUSE_LIGHT += lc * v_edge * edge_glow * (0.15 + toward) * (1.0 - 0.5 * max(0.0, dot(NORMAL, VIEW)));
	vec3 h = normalize(VIEW + LIGHT);
	vec3 t = v_barb - NORMAL * dot(v_barb, NORMAL);
	t = dot(t, t) > 1e-8 ? normalize(t) : normalize(cross(NORMAL, abs(NORMAL.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 b = cross(NORMAL, t);
	float hn = max(dot(h, NORMAL), 1e-3);
	float ht = dot(h, t) / max(v_spec.y, 0.02);
	float hb = dot(h, b) / max(v_spec.y * 3.0, 0.06);
	float s = exp(-(ht * ht + hb * hb) / (hn * hn)) * max(0.0, ndl);
	SPECULAR_LIGHT += lc * s * v_spec.x * barb_sheen * mix(vec3(1.0), ALBEDO * 4.0, METALLIC);
}

