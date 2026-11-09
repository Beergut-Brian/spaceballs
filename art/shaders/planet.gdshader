// Store-art planet: ocean, chunky continents and drifting cloud bands from 3D value noise.
shader_type spatial;

uniform vec3 ocean : source_color = vec3(0.18, 0.44, 0.88);
uniform vec3 land : source_color = vec3(0.30, 0.72, 0.42);
uniform vec3 land_high : source_color = vec3(0.55, 0.80, 0.40);
uniform vec3 cloud : source_color = vec3(0.95, 0.97, 1.0);

varying vec3 p;

float hash(vec3 q) { q = fract(q * 0.3183099 + 0.1); q *= 17.0; return fract(q.x * q.y * q.z * (q.x + q.y + q.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 x) { return noise(x) * 0.55 + noise(x * 2.1) * 0.3 + noise(x * 4.3) * 0.15; }

void vertex() { p = normalize(VERTEX); }

void fragment() {
	float h = fbm(p * 3.0);
	vec3 col = ocean;
	float l = smoothstep(0.52, 0.55, h);
	col = mix(col, mix(land, land_high, smoothstep(0.6, 0.75, h)), l);
	float c = smoothstep(0.63, 0.7, fbm(p * vec3(2.0, 7.0, 2.0) + vec3(4.0, 0.0, 1.0)));
	col = mix(col, cloud, c * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.75, 0.95, max(l, c));
	SPECULAR = 0.2;
	RIM = 0.25;
	RIM_TINT = 0.0;
}
