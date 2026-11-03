// Feather texture (Plumage level 6; docs/research/feather_texture_study.md): the level-5 look -- colour along
// the feather from the plumage strip -- read through a baked feather atlas (FeatherAtlas): the shaft, soft barb
// striations and splits, spots, pale fringes, a darker rim and the shadow where the row in front ends. Lit
// with each group's own sheen and translucency (Plumage.GLOSS; gentle: the parked feather.gdshader's sheen
// flooded the flat cards).
// Per instance: INSTANCE_CUSTOM.r = the strip row (group and face), .g = the bend, .b = (atlas cell + 1) *
// the side the leading (outer-vane) edge is on (+1: +UV.x), .a = a random value per feather (its own small
// variation: tone, warmth, spot size, fringe wear). The instance colour multiplies (the darker wingtip
// "fingers"). Each face is its own MultiMesh (the under copy is a mirrored mesh), so cull back.
// Relief: `atlas_n` (RG the normal across the vane and down the image), applied in a cotangent frame from the
// screen derivatives -- so it is right on either face and either wing without the card's tangents.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// In the sun (the concept's backlit kestrel; docs/research/feather_texture_study.md, "In the sun"): the light
// follows each feather, from its own texture. A vane is a thin sheet of barbs: a sun behind it shines through
// (most where it is thin and pale, none through the shaft); its free edge and tip -- the barbs' ends -- catch the
// light and glow, most when looking toward the sun; and the barbs streak the sheen along themselves (anisotropic,
// tight across them). Wrapped diffuse: soft barbs don't fall off hard at the terminator.
uniform float through_boost = 2.5;   // light through the vanes (0: none)
uniform float edge_glow = 1.0;       // the free edges' and tips' glow (0: none)
uniform float barb_sheen = 1.0;      // the sheen streaked along the barbs (0: none)
varying float v_through;
varying float v_edge;
varying vec3 v_barb;
varying vec2 v_spec;                 // (specular level, its width across the barbs)

uniform float flex = 0.0;      // the wing's flex this pose (BirdRig.flex): a feather bends by its share of it
uniform sampler2D strip : filter_linear, repeat_disable;   // sRGB values, read raw
uniform float rows = 1.0;
uniform sampler2D atlas : filter_linear_mipmap_anisotropic, repeat_disable;   // masks, read raw
uniform sampler2D atlas_n : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 cell_rect[16];    // per atlas cell: x0, y0, w, h (atlas UV)
uniform vec4 cell_shape[16];   // per atlas cell: shaft position (UV.x), chevron, -, -
uniform float relief = 0.8;
uniform float variety = 1.0;   // each feather's own variation (0: all alike)
// Per strip row (group and face), from Plumage.texture_look:
uniform vec4 spot[20];         // spot colour (sRGB), amount
uniform vec4 fringe[20];       // fringe colour (sRGB), width (edge-distance units: 1 = half a vane in)
uniform vec4 misc[20];         // spot size (0..1), shaft tone (x colour), texture strength, vane cup
uniform vec4 gloss[20];        // roughness, specular, transmission (light through the vane from behind), -
uniform vec4 vane_out[20];     // the outer (leading, narrow) vane's colour (sRGB), amount
uniform vec4 vane_in[20];      // the inner vane's colour (sRGB), amount (fading in toward the base)
uniform vec4 vane_misc[20];    // fringe on the outer vane, on the inner vane; the group's longest feather (m: bars
                               // in metres from the tip, 0: by share of length); 1 = a top face that a neighbour covers
uniform float cover = 0.5;     // how much of a flight feather's inner vane its neighbour hides (follows the fold)
uniform int contour_row = 18;  // rows from here on are the body's silhouette cards: spot colour a multiple of
uniform float contour_fringe = 0.25;   // the card's own colour, the fringe mixed in by this much (as the body tile)
uniform float sheen = 1.0;     // scales the flight feathers' sheen and translucency (0: the old matte cards)
uniform float strength = 1.0;  // all texture detail (0: the level-5 look plus the cup)

varying flat float row;
varying flat float cell;
varying flat float lead;
varying flat float seed;
varying flat float flen;
uniform bool gpu_place = false;   // BirdRig.gpu_feathers: the feather placed here, not by its instance transform
instance uniform int def_offset = -1;   // (its column in `defs`: the slotted primaries follow the plain feathers;
                                        // -1, the silhouette cards that share this material: placed by their instances)
#include "res://scripts/bird/feather_place.gdshaderinc"

void vertex() {
	row = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.a;
	float c = INSTANCE_CUSTOM.b;
	cell = abs(c) - 1.0;
	lead = c < 0.0 ? -1.0 : 1.0;
	flen = length(MODEL_MATRIX[2].xyz);   // the feather's length (m: the instance transform's z scales with it)
	// Flex: the feather bends along its length (as feather_marks.gdshader).
	float bend = INSTANCE_CUSTOM.g * flex;   // (.g: this feather's share of the wing's flex)
	VERTEX.y += bend * VERTEX.z * VERTEX.z;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, -2.0 * bend * VERTEX.z) * NORMAL.y);
	if (gpu_place && def_offset >= 0) {
		mat4 fx = feather_place(INSTANCE_ID + def_offset);
		vec3 X = fx[0].xyz;
		vec3 Y = fx[1].xyz;
		vec3 Z = fx[2].xyz;
		VERTEX = fx[3].xyz + X * VERTEX.x + Y * VERTEX.y + Z * VERTEX.z;
		// (the frame's columns are orthogonal: its inverse transpose divides each by its squared length)
		NORMAL = normalize(X / dot(X, X) * NORMAL.x + Y / dot(Y, Y) * NORMAL.y + Z / dot(Z, Z) * NORMAL.z);
		TANGENT = normalize(X * TANGENT.x + Y * TANGENT.y + Z * TANGENT.z);
		BINORMAL = normalize(X * BINORMAL.x + Y * BINORMAL.y + Z * BINORMAL.z);
		flen = length(Z) * length(MODEL_MATRIX[2].xyz);
	}
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	int r = int(row + 0.5);
	int ci = clamp(int(cell + 0.5), 0, 15);
	float us = UV.x * lead;   // +1 = the leading edge (the narrow outer vane)
	float v = clamp(UV.y, 0.0, 1.0);
	vec4 rect = cell_rect[ci];
	vec2 auv = rect.xy + vec2(us * 0.5 + 0.5, 1.0 - v) * rect.zw;
	vec4 t = texture(atlas, auv);
	vec4 m = misc[r];
	float k = strength * m.z;
	// The feather's own variation (seed), and two more values from it.
	float h1 = seed;
	float h2 = fract(seed * 7.13 + 0.37);
	float h3 = fract(seed * 13.7 + 0.71);
	float vary = variety * k;
	// Colour along the feather, its bands bent into shallow chevrons along the barbs. (Bars stay in register
	// across neighbours, as on a real wing: no per-feather shift.)
	float off = abs(us - cell_shape[ci].x) * cell_shape[ci].y * k;
	// Bars in metres from the tip, so they run on as bands across feathers of different lengths (a shorter
	// feather reads the strip from further toward its tip end).
	vec4 vm = vane_misc[r];
	float vs = vm.z > 0.0 ? 1.0 - (1.0 - v) * flen / vm.z : v;
	vec3 col = texture(strip, vec2(clamp(vs - off, 0.0, 1.0), (float(r) + 0.5) / rows)).rgb * COLOR.rgb;
	// The two vanes differ (from above a wing shows mostly outer vanes, from below inner ones).
	float shaft_u = cell_shape[ci].x;
	float outer = smoothstep(shaft_u - 0.03, shaft_u + 0.03, us);
	vec4 vo = vane_out[r];
	vec4 vi = vane_in[r];
	col = mix(col, vo.rgb * COLOR.rgb, vo.a * outer * k);
	col = mix(col, vi.rgb * COLOR.rgb, vi.a * (1.0 - outer) * (1.0 - 0.6 * v) * k);
	col *= 1.0 + (h1 - 0.5) * 0.08 * vary;                                            // tone
	col *= vec3(1.0 + (h2 - 0.5) * 0.04 * vary, 1.0, 1.0 - (h2 - 0.5) * 0.04 * vary);  // warmth
	vec4 sp = spot[r];
	float ss = m.x * (1.0 + (h3 - 0.5) * 0.35 * vary);
	bool contour = r >= contour_row;
	col = mix(col, contour ? col * sp.rgb : sp.rgb, smoothstep(0.88 - ss * 0.7, 1.0 - ss * 0.7, t.b) * sp.a * k);
	vec4 fr = fringe[r];
	float fw = fr.a * (1.0 + (h2 - 0.5) * 0.6 * vary) * mix(vm.y, vm.x, outer);   // fringes wear unevenly; per vane
	col = mix(col, contour ? mix(col, fr.rgb, contour_fringe) : fr.rgb, (1.0 - smoothstep(fw * 0.45, fw, t.a)) * step(0.001, fr.a) * k);
	col = mix(col, col * m.y, t.g * k);
	ALBEDO = to_linear(col) * mix(1.0, t.r * 1.1, k);
	// The step where the inner neighbour lies over this feather's inner vane: a soft dark band just before its
	// edge (the layers are too close for the sun's shadow to draw it). Top faces of flight feathers.
	float cov = clamp((shaft_u - us) / (shaft_u + 1.0), 0.0, 1.0);   // 0 at the shaft .. 1 the inner edge
	ALBEDO *= 1.0 - 0.32 * vm.w * k * smoothstep(1.0 - cover - 0.22, 1.0 - cover, cov);
	// Sheen: smooth vanes; the fringe's worn barbs and the shaft rougher. Translucency: a low sun behind the
	// feather shines through the vane (the shaft, opaque, stays dark; thicker toward the base).
	vec4 gl = gloss[r];
	float edge = 1.0 - smoothstep(0.0, 0.25, t.a);
	ROUGHNESS = mix(0.9, clamp(gl.x + 0.2 * edge + 0.15 * t.g, 0.0, 1.0), sheen);
	SPECULAR = mix(0.35, gl.y, sheen);
	// Gloss tint (the crow): highlights and sky reflections take a dark blue-violet, as a metal's, the diffuse
	// stays near black.
	METALLIC = gl.w * sheen * (1.0 - edge);
	ALBEDO = mix(ALBEDO, vec3(0.05, 0.05, 0.11), gl.w * sheen * 0.8);
	// (transmittance, not BACKLIGHT: the feather above shadows each card from a sun behind it, and BACKLIGHT is
	// shadowed with it; transmittance reads the thickness off the shadow map, so a thin vane glows through)
	float through = gl.z * sheen * (1.0 - 0.8 * t.g) * mix(0.6, 1.0, v);
	SSS_TRANSMITTANCE_COLOR = vec4(ALBEDO * through * 3.0 * through_boost, 1.0);
	SSS_TRANSMITTANCE_DEPTH = 0.02 * through_boost;
	SSS_TRANSMITTANCE_BOOST = 0.3 * through_boost;
	// Soft round tips: the atlas's outline rounds the card's tip off (its edge distance is 0 outside).
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.01;
	// A vane is cupped, not flat: its shading normal leans out toward each edge, so each feather is lit a
	// little differently across and neighbours separate. (Underside rows are odd: seen from below the cup is
	// concave, so it leans the other way.)
	float cup = m.w * (mod(float(r), 2.0) > 0.5 ? -1.0 : 1.0);
	vec3 nrm = normalize(NORMAL + normalize(TANGENT) * UV.x * cup);
	// The baked relief (the shaft's ridge, the barbs, the vane's cup), in the frame of (us, v): the image's x is
	// +us, its y is -v.
	vec2 st = vec2(us, v);
	vec2 dx = dFdx(st);
	vec2 dy = dFdy(st);
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec3 dp2perp = cross(dp2, nrm);
	vec3 dp1perp = cross(nrm, dp1);
	vec3 tu = dp2perp * dx.x + dp1perp * dy.x;
	vec3 tv = dp2perp * dx.y + dp1perp * dy.y;
	float invmax = inversesqrt(max(max(dot(tu, tu), dot(tv, tv)), 1e-20));
	vec2 nn = (texture(atlas_n, auv).rg * 2.0 - 1.0) * relief * k;
	NORMAL = normalize(nrm * sqrt(max(1.0 - dot(nn, nn), 0.0)) + (tu * nn.x - tv * nn.y) * invmax);
	// For the light: the barbs run out from the shaft toward the tip; light passes the thin pale vane, not the
	// shaft; the free edge (and the rounded tip) is where barb ends catch it.
	v_barb = tu * sign(us - shaft_u + 1e-4) * invmax + tv * invmax * 0.6;   // (left unnormalised: light() makes it a unit tangent)
	float pale = clamp(dot(ALBEDO, vec3(0.3, 0.59, 0.11)) * 3.0, 0.0, 1.0);
	v_through = through * (0.35 + 0.65 * pale);
	v_edge = edge * k * (0.4 + 0.6 * pale) * (1.0 - t.g);
	v_spec = vec2(SPECULAR * (1.0 - ROUGHNESS) * 2.0, mix(0.06, 0.3, ROUGHNESS));
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

