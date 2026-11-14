shader_type canvas_item;
render_mode unshaded;

uniform vec2 shape_size;
uniform vec2 aura_size;
uniform bool round_shape = false;

void fragment() {
	vec2 position = (UV - vec2(0.5)) * aura_size;
	vec2 offset = abs(position) - shape_size * 0.5;
	float distance_from_edge = length(max(offset, vec2(0.0))) + min(max(offset.x, offset.y), 0.0);
	if (round_shape) {
		distance_from_edge = (length(position / (shape_size * 0.5)) - 1.0) * min(shape_size.x, shape_size.y) * 0.5;
	}
	float shimmer = sin(position.x * 0.11 + TIME * 3.2) + sin(position.y * 0.14 - TIME * 2.5);
	float glow = 1.0 - smoothstep(0.0, 22.0, max(distance_from_edge + shimmer * 2.5, 0.0));
	float pulse = 0.65 + 0.15 * sin(TIME * 3.0 + position.x * 0.04);
	COLOR = vec4(COLOR.rgb, COLOR.a * glow * pulse);
}
