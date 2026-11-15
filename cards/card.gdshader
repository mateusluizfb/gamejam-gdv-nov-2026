shader_type canvas_item;

uniform vec2 cursor_uv = vec2(0.5);
uniform float foil_strength : hint_range(0.0, 1.0) = 0.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec4 card = texture(TEXTURE, UV) * vertex_color;
	vec2 offset = UV - cursor_uv;
	float highlight = exp(-dot(offset, offset) * 5.0);
	float band = pow(0.5 + 0.5 * cos((UV.x + UV.y - cursor_uv.x * 0.7 - cursor_uv.y * 0.7) * 12.0), 6.0);
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (UV.x + UV.y + cursor_uv.x - cursor_uv.y + vec3(0.0, 0.33, 0.67)));
	card.rgb += (rainbow * 0.25 + vec3(band * 0.3)) * highlight * foil_strength;
	COLOR = card;
}
