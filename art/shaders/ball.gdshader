// The ball: six beach-ball panels (white / player colour / a palette pop) and a face drawn
// from a 3-cell atlas (calm, shocked, happy). art/scripts/ball_look.gd sets `expr`.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(1.0);
uniform vec3 accent : source_color = vec3(0.235, 0.761, 0.29);
uniform vec3 pop : source_color = vec3(1.0, 0.847, 0.302);
uniform sampler2D faces : source_color, filter_linear_mipmap, repeat_disable;
uniform float expr = 0.0;
uniform float face_angle = 1.15;
uniform float face_size = 0.62;
uniform float rim_amount = 0.5;

varying vec3 n_obj;

void vertex() {
	n_obj = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(n_obj);
	float ang = atan(n.x, n.z) - face_angle + PI / 6.0;
	float k = floor(mod(ang, TAU) / (TAU / 6.0));
	int idx = int(mod(k, 3.0));
	vec3 col = idx == 0 ? base_color : (idx == 1 ? accent : pop);
	col = mix(col, base_color, smoothstep(0.86, 0.88, abs(n.y)));
	vec3 f = vec3(sin(face_angle), 0.0, cos(face_angle));
	vec3 r = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
	vec3 u = cross(r, f);
	vec2 p = vec2(dot(n, r), -dot(n, u)) / face_size + 0.5;
	if (dot(n, f) > 0.3 && p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0) {
		vec4 t = texture(faces, vec2((p.x + expr) / 3.0, p.y));
		col = mix(col, t.rgb, t.a);
	}
	ALBEDO = col;
	ROUGHNESS = 0.4;
	SPECULAR = 0.55;
	RIM = rim_amount;
	RIM_TINT = 0.3;
}
