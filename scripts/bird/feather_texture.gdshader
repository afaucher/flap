// Feather texture (Plumage level 6; docs/research/feather_texture_study.md): the level-5 look -- colour along
// the feather from the plumage strip -- read through a baked feather atlas (FeatherAtlas): the shaft, soft barb
// striations and splits, spots, pale fringes, a darker rim and the shadow where the row in front ends. Lit
// matte like the plain material (roughness 0.9, no sheen, translucency or highlight: the parked
// feather.gdshader's sheen flooded the flat cards).
// Per instance: INSTANCE_CUSTOM.r = the strip row (group and face), .g = the bend, .b = (atlas cell + 1) *
// the side the leading (outer-vane) edge is on (+1: +UV.x), .a = a random value per feather (its own small
// variation: tone, warmth, spot size, fringe wear). The instance colour multiplies (the darker wingtip
// "fingers"). Each face is its own MultiMesh (the under copy is a mirrored mesh), so cull back.
// Relief: `atlas_n` (RG the normal across the vane and down the image), applied in a cotangent frame from the
// screen derivatives -- so it is right on either face and either wing without the card's tangents.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strip : filter_linear, repeat_disable;   // sRGB values, read raw
uniform float rows = 1.0;
uniform sampler2D atlas : filter_linear_mipmap_anisotropic, repeat_disable;   // masks, read raw
uniform sampler2D atlas_n : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 cell_rect[16];    // per atlas cell: x0, y0, w, h (atlas UV)
uniform vec4 cell_shape[16];   // per atlas cell: shaft position (UV.x), chevron, -, -
uniform float relief = 0.8;
uniform float variety = 1.0;   // each feather's own variation (0: all alike)
// Per strip row (group and face), from Plumage.texture_look:
uniform vec4 spot[18];         // spot colour (sRGB), amount
uniform vec4 fringe[18];       // fringe colour (sRGB), width (edge-distance units: 1 = half a vane in)
uniform vec4 misc[18];         // spot size (0..1), shaft tone (x colour), texture strength, vane cup
uniform float strength = 1.0;  // all texture detail (0: the level-5 look plus the cup)

varying flat float row;
varying flat float cell;
varying flat float lead;
varying flat float seed;

void vertex() {
	row = INSTANCE_CUSTOM.r;
	seed = INSTANCE_CUSTOM.a;
	float c = INSTANCE_CUSTOM.b;
	cell = abs(c) - 1.0;
	lead = c < 0.0 ? -1.0 : 1.0;
	// Flex: the feather bends along its length (as feather_marks.gdshader).
	float bend = INSTANCE_CUSTOM.g;
	VERTEX.y += bend * VERTEX.z * VERTEX.z;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, -2.0 * bend * VERTEX.z) * NORMAL.y);
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
	vec3 col = texture(strip, vec2(clamp(v - off, 0.0, 1.0), (float(r) + 0.5) / rows)).rgb * COLOR.rgb;
	col *= 1.0 + (h1 - 0.5) * 0.08 * vary;                                            // tone
	col *= vec3(1.0 + (h2 - 0.5) * 0.04 * vary, 1.0, 1.0 - (h2 - 0.5) * 0.04 * vary);  // warmth
	vec4 sp = spot[r];
	float ss = m.x * (1.0 + (h3 - 0.5) * 0.35 * vary);
	col = mix(col, sp.rgb, smoothstep(0.88 - ss * 0.7, 1.0 - ss * 0.7, t.b) * sp.a * k);
	vec4 fr = fringe[r];
	float fw = fr.a * (1.0 + (h2 - 0.5) * 0.6 * vary);   // fringes wear unevenly
	col = mix(col, fr.rgb, (1.0 - smoothstep(fw * 0.45, fw, t.a)) * step(0.001, fr.a) * k);
	col = mix(col, col * m.y, t.g * k);
	ALBEDO = to_linear(col) * mix(1.0, t.r * 1.1, k);
	ROUGHNESS = 0.9;
	SPECULAR = 0.35;
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
}
