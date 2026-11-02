// The rider's eyes: a wet eyeball -- off-white sclera with faint vessels, pinker toward the corners, a grey-blue
// iris with radial fibres and a dark limbal ring, a black pupil, a glossy cornea. UV.x is the angle (rad) from
// the eye's gaze axis, UV.y the angle round it (Rider builds the eyeball so).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/tack/tack_noise.gdshaderinc"

uniform vec3 sclera_col : source_color = vec3(0.86, 0.82, 0.76);
uniform vec3 iris_col : source_color = vec3(0.36, 0.45, 0.5);
uniform vec3 iris_dark : source_color = vec3(0.13, 0.17, 0.2);
uniform float iris_a = 0.5;     // rad: the iris's edge
uniform float pupil_a = 0.19;

void fragment() {
	float a = UV.x;
	float b = UV.y;
	vec3 col = sclera_col;
	float vessel = smoothstep(0.62, 0.8, tk_noise(vec2(a * 9.0, b * 3.0))) * smoothstep(0.7, 1.2, a);
	col = mix(col, vec3(0.75, 0.45, 0.42), 0.3 * vessel + 0.2 * smoothstep(0.9, 1.5, a));
	float fib = tk_noise(vec2(b * 14.0, a * 6.0));
	vec3 ir = mix(iris_dark, iris_col, 0.55 + 0.45 * fib);
	ir = mix(ir, vec3(0.5, 0.42, 0.25), 0.35 * (1.0 - smoothstep(pupil_a, pupil_a + 0.12, a)));   // the warmer ring round the pupil
	ir = mix(ir, iris_dark * 0.5, smoothstep(iris_a - 0.1, iris_a, a));                            // the limbal ring
	col = mix(ir, col, smoothstep(iris_a - 0.015, iris_a + 0.015, a));
	col = mix(vec3(0.01), col, smoothstep(pupil_a - 0.02, pupil_a + 0.02, a));
	ALBEDO = col;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
