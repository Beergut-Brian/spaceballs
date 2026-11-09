// Soft additive halo for the store-art planet.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 glow : source_color = vec3(0.53, 0.96, 1.0);
uniform float power = 2.5;
uniform float strength = 0.4;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = glow * f * strength;
}
