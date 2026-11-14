shader_type canvas_item;
render_mode unshaded;

uniform vec2 card_size;
uniform vec2 aura_size;

void fragment() {
	vec2 offset = abs((UV - vec2(0.5)) * aura_size) - card_size * 0.5;
	float distance_from_card = length(max(offset, vec2(0.0)));
	float glow = 1.0 - smoothstep(0.0, 20.0, distance_from_card);
	float pulse = 0.75 + 0.15 * sin(TIME * 3.0);
	COLOR = vec4(0.55, 0.08, 0.95, glow * pulse);
}
