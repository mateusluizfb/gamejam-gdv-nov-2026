shader_type canvas_item;

uniform float wave_strength : hint_range(0.0, 0.03) = 0.008;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.4;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	float time = TIME * wave_speed;
	vec2 ripple = vec2(
		sin(UV.y * 30.0 + time) + 0.5 * sin(UV.y * 55.0 - time * 0.7),
		sin(UV.x * 24.0 - time * 0.8)
	) * wave_strength;
	vec2 edge = TEXTURE_PIXEL_SIZE * 0.5;
	vec4 card = texture(TEXTURE, clamp(UV + ripple, edge, vec2(1.0) - edge));
	float shimmer = 0.5 + 0.5 * sin(UV.x * 25.0 + UV.y * 20.0 - time);
	card.rgb = mix(card.rgb, card.rgb * vec3(0.85, 0.96, 1.12), 0.4);
	card.rgb += vec3(0.01, 0.025, 0.04) * shimmer;
	COLOR = card * vertex_color;
}
