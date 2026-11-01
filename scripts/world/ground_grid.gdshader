// Greybox ground: a 5 m grid with a heavier 25 m grid, so speed and height read from the air.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.36, 0.39, 0.33);
uniform vec3 line_color : source_color = vec3(0.26, 0.28, 0.24);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float cell) {
	vec2 q = p / cell;
	vec2 g = abs(fract(q - 0.5) - 0.5) / fwidth(q);
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float l = max(grid(world_pos.xz, 5.0) * 0.5, grid(world_pos.xz, 25.0));
	ALBEDO = mix(base_color, line_color, l);
	ROUGHNESS = 0.95;
}
