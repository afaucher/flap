// Feather marks (Plumage level 5): the plain feather look, with its colour read along the feather from a
// small strip generated from the plumage spec (scripts/bird/plumage.gd) -- dark tips, the dark trailing edge,
// tail bands, bars, the white wing bar. Colour only: lit like the plain StandardMaterial (roughness 0.9), no
// sheen, translucency or texture detail (the parked feather.gdshader does those).
// Per instance: INSTANCE_CUSTOM.r = the strip row (group and face); the instance colour multiplies it (the
// darker wingtip "fingers"). Each face is its own MultiMesh (the under copy is a mirrored mesh), so cull back.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D strip : filter_linear, repeat_disable;   // sRGB values, read raw
uniform float rows = 1.0;
varying float row;

void vertex() {
	row = INSTANCE_CUSTOM.r;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 c = texture(strip, vec2(clamp(UV.y, 0.0, 1.0), (floor(row + 0.5) + 0.5) / rows)).rgb * COLOR.rgb;
	ALBEDO = to_linear(c);
	ROUGHNESS = 0.9;
}
