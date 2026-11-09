// Vertical gores in three colours (hot-air balloon). Object-space angle, smooth-shaded.
shader_type spatial;

uniform vec3 color_a : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 color_b : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 color_c : source_color = vec3(1.0, 0.31, 0.85);
uniform float gores = 12.0;

varying vec3 p_obj;

void vertex() {
	p_obj = VERTEX;
}

void fragment() {
	float a = atan(p_obj.x, p_obj.z) / TAU + 0.5;
	int k = int(mod(floor(a * gores), 3.0));
	ALBEDO = k == 0 ? color_a : (k == 1 ? color_b : color_c);
	ROUGHNESS = 0.6;
	RIM = 0.4;
	RIM_TINT = 0.3;
}
