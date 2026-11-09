// Screen-space speed lines for the flight: streaks rushing down past the edges of the screen.
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);

float hash(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void fragment() {
	vec2 uv = UV;
	float cols = 70.0;
	float id = floor(uv.x * cols);
	float h = hash(id);
	float speed = 2.5 + h * 3.0;
	float len = 0.15 + 0.25 * hash(id + 3.1);
	float y = fract(uv.y * 0.6 + TIME * speed + h * 10.0);
	float streak = smoothstep(0.0, 0.02, y) * (1.0 - smoothstep(len * 0.5, len, y));
	float thin = 1.0 - smoothstep(0.08, 0.3, abs(fract(uv.x * cols) - 0.5));
	float keep = step(0.55, hash(id + 17.0));
	// Strong at the edges, clear in the middle where the ball is.
	float edge = smoothstep(0.18, 0.45, abs(uv.x - 0.5));
	float a = streak * thin * keep * edge * amount * line_color.a;
	COLOR = vec4(line_color.rgb, a);
}
