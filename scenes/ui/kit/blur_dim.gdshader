// Pause backdrop: the paused game, blurred and dimmed warm.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.0;
uniform vec4 tint : source_color = vec4(0.07, 0.055, 0.05, 0.62);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod);
	vec3 c = vec3(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.0);
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, lod).rgb * w;
			wsum += w;
		}
	}
	COLOR = vec4(mix(c / wsum, tint.rgb, tint.a), 1.0);
}
