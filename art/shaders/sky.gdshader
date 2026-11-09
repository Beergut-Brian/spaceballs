// Sky ramp: top -> horizon gradient, soft sun, stars that fade in near space.
// art/scripts/sky_ramp.gd drives the uniforms from the camera height and data/tiers.tres.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.30, 0.71, 1.0);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.97, 1.0);
uniform vec3 ground_color : source_color = vec3(0.55, 0.78, 0.55);
uniform float curve : hint_range(0.1, 2.0) = 0.55;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform float sun_glow : hint_range(0.0, 1.0) = 0.35;
uniform float planet : hint_range(0.0, 1.0) = 0.0;
uniform vec3 planet_color : source_color = vec3(0.13, 0.36, 0.78);
uniform vec3 atmosphere : source_color = vec3(0.53, 0.96, 1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 c;
	if (d.y >= 0.0) {
		c = mix(horizon_color, top_color, pow(clamp(d.y, 0.0, 1.0), curve));
	} else {
		c = mix(horizon_color, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
		vec3 world = mix(atmosphere, planet_color, smoothstep(0.0, 0.08, -d.y));
		c = mix(c, world, planet);
	}
	// Thin bright atmosphere line on the horizon when the planet shows.
	c += atmosphere * planet * exp(-abs(d.y) * 90.0) * 0.45;
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		c += vec3(1.0, 0.95, 0.8) * (smoothstep(0.9993, 0.9997, s) * 1.5 + pow(s, 64.0) * sun_glow);
	}
	if (stars > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 p = d * 220.0;
		vec3 cell = floor(p);
		float h = hash(cell);
		float r = length(fract(p) - 0.5);
		float star = step(0.975, h) * smoothstep(0.32, 0.05, r) * (0.6 + 0.4 * hash(cell + 7.0));
		c += vec3(star) * stars * smoothstep(-0.1, 0.1, d.y);
	}
	COLOR = c;
}
