// The nictitating membrane (BirdRig, the blink): drawn on a copy of the eye's own cap just over it, so it can only
// ever cover the eye. A translucent, faintly blue-white film whose edge sweeps across from the bill side (`dir`, in
// the eye's xy) as `sweep` goes 0 .. 1 and back; nothing shows outside the eye. (The first version was a flattened
// sphere hinged at the eye's rim: part-way across it stood out past the eye as a pale crescent on the feathers.)
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform vec2 dir = vec2(1.0, 0.0);   // toward the bill, in the eye's xy (unit)
uniform float sweep = 0.0;           // 0 open .. 1 across the whole eye
uniform float radius = 1.0;          // the eye's radius (m)
uniform vec3 tint : source_color = vec3(0.86, 0.9, 0.95);
uniform float opacity = 0.5;

varying vec2 local;

void vertex() {
	local = VERTEX.xy / radius;
}

void fragment() {
	float s = 0.5 - 0.5 * dot(local, dir);   // 0 at the bill-side rim .. 1 at the far rim
	float edge = sweep * 1.08;
	float cover = 1.0 - smoothstep(edge - 0.08, edge, s);
	ALBEDO = tint;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
	ALPHA = opacity * cover * (0.85 + 0.15 * smoothstep(edge - 0.12, edge, s));   // (its leading edge a touch denser)
}
