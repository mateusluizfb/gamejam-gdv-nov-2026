shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float radius = distance(UV, vec2(0.5));
	COLOR.a *= 1.0 - smoothstep(0.15, 0.5, radius);
}
