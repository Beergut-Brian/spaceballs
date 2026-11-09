// Aurora curtain: unshaded, additive, a soft vertical fade with drifting folds.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color_low : source_color = vec3(0.1, 1.0, 0.6);
uniform vec3 color_high : source_color = vec3(0.6, 0.35, 1.0);
uniform float strength = 0.55;

void fragment() {
	float fold = 0.5 + 0.5 * sin(UV.x * 18.0 + TIME * 0.7 + sin(UV.x * 5.0 + TIME * 0.3) * 2.0);
	float v = smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	v *= 0.35 + 0.65 * pow(fold, 3.0);
	float edge = smoothstep(0.0, 0.1, UV.x) * (1.0 - smoothstep(0.9, 1.0, UV.x));
	ALBEDO = mix(color_high, color_low, UV.y) * (0.5 + 0.5 * fold) * v * edge * strength;
}
