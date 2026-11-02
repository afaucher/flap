// Feather texture (Plumage level 6; docs/research/feather_texture_study.md): the level-5 look -- colour along
// the feather from the plumage strip -- read through a baked feather atlas (FeatherAtlas): the shaft, soft barb
// striations and splits, spots, pale fringes, a darker rim and the shadow where the row in front ends. Lit
// matte like the plain material (roughness 0.9, no sheen, translucency or highlight: the parked
// feather.gdshader's sheen flooded the flat cards).
// Per instance: INSTANCE_CUSTOM.r = the strip row (group and face), .g = the bend, .b = (atlas cell + 1) *
// the side the leading (outer-vane) edge is on (+1: +UV.x), .a unused. The instance colour multiplies (the
// darker wingtip "fingers"). Each face is its own MultiMesh (the under copy is a mirrored mesh), so cull back.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strip : filter_linear, repeat_disable;   // sRGB values, read raw
uniform float rows = 1.0;
uniform sampler2D atlas : filter_linear_mipmap_anisotropic, repeat_disable;   // masks, read raw
uniform vec4 cell_rect[12];    // per atlas cell: x0, y0, w, h (atlas UV)
uniform vec4 cell_shape[12];   // per atlas cell: shaft position (UV.x), chevron, -, -
// Per strip row (group and face), from Plumage.texture_look:
uniform vec4 spot[18];         // spot colour (sRGB), amount
uniform vec4 fringe[18];       // fringe colour (sRGB), width (edge-distance units: 1 = half a vane in)
uniform vec4 misc[18];         // spot size (0..1), shaft tone (x colour), texture strength, vane cup
uniform float strength = 1.0;  // all texture detail (0: the level-5 look plus the cup)

varying flat float row;
varying flat float cell;
varying flat float lead;

void vertex() {
	row = INSTANCE_CUSTOM.r;
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
	int ci = clamp(int(cell + 0.5), 0, 11);
	float us = UV.x * lead;   // +1 = the leading edge (the narrow outer vane)
	float v = clamp(UV.y, 0.0, 1.0);
	vec4 rect = cell_rect[ci];
	vec4 t = texture(atlas, rect.xy + vec2(us * 0.5 + 0.5, 1.0 - v) * rect.zw);
	vec4 m = misc[r];
	float k = strength * m.z;
	// Colour along the feather, its bands bent into shallow chevrons along the barbs.
	float off = abs(us - cell_shape[ci].x) * cell_shape[ci].y * k;
	vec3 col = texture(strip, vec2(clamp(v - off, 0.0, 1.0), (float(r) + 0.5) / rows)).rgb * COLOR.rgb;
	vec4 sp = spot[r];
	col = mix(col, sp.rgb, smoothstep(0.88 - m.x * 0.7, 1.0 - m.x * 0.7, t.b) * sp.a * k);
	vec4 fr = fringe[r];
	col = mix(col, fr.rgb, (1.0 - smoothstep(fr.a * 0.45, fr.a, t.a)) * step(0.001, fr.a) * k);
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
	NORMAL = normalize(NORMAL + normalize(TANGENT) * UV.x * cup);
}
