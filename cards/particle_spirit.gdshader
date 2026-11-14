shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 position = (UV - vec2(0.5)) * 2.0;
	float radius = length(position);
	float angle = atan(position.y, position.x + 0.00001);
	float ripple = sin(angle * 3.0 - TIME * 3.0 + radius * 7.0) * 0.08;
	float glow = 1.0 - smoothstep(0.1, 0.95, radius + ripple);
	float core = exp(-radius * 6.0);
	float shimmer = 0.8 + 0.2 * sin(TIME * 4.0 + angle * 2.0);
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0, 0.92, 1.0), core * 0.65);
	COLOR.a *= glow * shimmer;
}
