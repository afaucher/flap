// The bare skin of the legs and feet, and the claws (LegRig; docs/design/legs_and_feet.md): the podotheca's
// scales, read from ScaleTile's baked tile over the leg meshes' own coordinates. Per vertex (LegRig builds every
// piece with them):
//   COLOR.rgb  the skin's colour (sRGB); the claws' horn colour on the claws
//   COLOR.a    keratin: 0 skin .. 1 claw (smooth and glossier, no scales)
//   UV         (u round the tube, v along it), in scales: u = 0 on the front of the tarsus and the top of a toe
//   UV2        (u's period: the ring's girth in scales, where u comes round on itself; how far front plates may
//              show there: 1 on the tarsus and toes, 0 on the foot pad)
// Front plates (scutes: the acrotarsium and the tops of the toes) where `scutes` and UV2.y allow, small domed
// reticulate scales elsewhere and on the soles; the barn owl's bristled toes (`bristles`) add fine pale hairs.
// The tile is mipmapped, so with distance the relief averages away to the skin's plain colour on its own.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scales : filter_linear_mipmap_anisotropic, repeat_enable;     // ScaleTile: R dome, G plate, B tone, A bristle
uniform sampler2D scales_n : filter_linear_mipmap_anisotropic, repeat_enable;   // RG dome normal, B plate normal (v)
uniform float tile = 8.0;         // scales across the tile (ScaleTile.TILE)
uniform float scutes = 1.0;       // front plates: 1 scutellate (hawk, crow, sparrow) .. 0 reticulate all round (falcon)
uniform float bristles = 0.0;     // bristled toes (the barn owl)
uniform float relief = 1.0;       // the scales' bump (0: flat)
uniform float bow = 0.35;         // the plates' lower edges curve down round the sides (scales, at the band's edge)
uniform bool show_chart = false;  // debug: the coordinates as a grid

varying vec2 info;

void vertex() {
	info = UV2;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	float period = max(info.x, 0.05);
	float uw = UV.x - period * round(UV.x / period);   // 0 on the front / top
	float around = abs(uw) / period;                   // 0 front .. 0.5 back / sole
	float keratin = clamp(COLOR.a, 0.0, 1.0);
	float skin = 1.0 - keratin;
	// Front plates in a band down the front; domed reticulate scales everywhere else.
	float front = 1.0 - smoothstep(0.16, 0.24, around);
	float sw = clamp(scutes * info.y, 0.0, 1.0) * front;
	vec2 tuv = UV / tile;
	vec4 t = texture(scales, tuv);
	vec4 tn = texture(scales_n, tuv);
	vec2 puv = vec2(UV.x, UV.y - bow * pow(around / 0.2, 2.0)) / tile;   // (the plates' edges bowed)
	float plate = texture(scales, puv).g;
	float plate_n = texture(scales_n, puv).b * 2.0 - 1.0;
	float h = mix(t.r, plate, sw);
	vec3 col = to_linear(COLOR.rgb);
	col *= mix(1.0, mix(0.72, 1.04, h), skin);                      // grooves and the steps under the lips darker
	col *= 1.0 + (t.b - 0.5) * 0.12 * skin * (1.0 - sw);           // each scale its own tone
	float br = t.a * bristles * skin * (1.0 - sw);
	col = mix(col, col * 1.6 + 0.03, br * 0.7);                     // pale bristles
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.6, 0.85, bristles), 0.3, keratin);
	SPECULAR = mix(0.4, 0.65, keratin);
	if (show_chart) {
		vec2 g = abs(fract(vec2(uw, UV.y)) - 0.5);
		ALBEDO = vec3(smoothstep(0.42, 0.48, g.x), smoothstep(0.42, 0.48, g.y), info.y) * 0.8 + 0.1;
	}
	// Relief: the tile's normal is in the coordinates' frame (u, v): a cotangent frame from the screen derivatives,
	// so the meshes need no tangents (as body_feathers.gdshader).
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec3 dp1 = dFdx(VERTEX);
	vec3 dp2 = dFdy(VERTEX);
	vec3 nrm = NORMAL;
	vec3 dp2perp = cross(dp2, nrm);
	vec3 dp1perp = cross(nrm, dp1);
	vec3 tu = dp2perp * dx.x + dp1perp * dy.x;
	vec3 tv = dp2perp * dx.y + dp1perp * dy.y;
	float invmax = inversesqrt(max(max(dot(tu, tu), dot(tv, tv)), 1e-20));
	vec2 nn = mix(tn.rg * 2.0 - 1.0, vec2(0.0, plate_n), sw) * relief * skin;
	NORMAL = normalize(nrm * sqrt(max(1.0 - dot(nn, nn), 0.0)) + (tu * nn.x + tv * nn.y) * invmax);
}
