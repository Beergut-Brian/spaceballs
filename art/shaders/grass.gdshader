// Soft TV-sports lawn: mowing stripes in world space, gentle large-scale colour drift.
shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 grass_a : source_color = vec3(0.37, 0.69, 0.29);
uniform vec3 grass_b : source_color = vec3(0.32, 0.62, 0.26);
uniform vec3 far_tint : source_color = vec3(0.45, 0.72, 0.38);
uniform float stripe_width = 2.5;
uniform float stripe_soft = 0.15;
uniform vec3 line_color : source_color = vec3(0.97, 0.98, 0.95);
uniform float line_z = 0.9;
uniform float line_half = 4.5;

varying vec3 wpos;

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(12.9898, 78.233))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(12.9898, 78.233))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = 0.5 + 0.5 * clamp(sin(wpos.x * PI / stripe_width) / stripe_soft, -1.0, 1.0);
	vec3 col = mix(grass_a, grass_b, s);
	float n = vnoise(wpos.xz * 0.08) * 0.6 + vnoise(wpos.xz * 0.5) * 0.4;
	col *= 0.94 + 0.1 * n;
	float far = smoothstep(40.0, 160.0, length(wpos.xz));
	col = mix(col, far_tint, far * 0.6);
	// The kick line through both tees.
	float line = (1.0 - smoothstep(0.06, 0.09, abs(wpos.z - line_z))) * (1.0 - smoothstep(line_half, line_half + 0.05, abs(wpos.x)));
	col = mix(col, line_color, line);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
