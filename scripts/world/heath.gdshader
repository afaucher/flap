// The hills round the arena (EdgeBuilder._hills): heath, a little darker on the slopes.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://scripts/world/heath.gdshaderinc"

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = heath_albedo(wp.xz);
	col *= mix(0.8, 1.0, smoothstep(0.6, 0.95, wn.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
