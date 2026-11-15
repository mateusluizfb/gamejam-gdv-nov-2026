shader_type canvas_item;

uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 seeds = vec4(
		dot(cell, vec2(127.1, 311.7)),
		dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7)),
		dot(cell + vec2(1.0), vec2(127.1, 311.7))
	);
	vec4 values = fract(sin(seeds) * 43758.5453);
	return mix(mix(values.x, values.y, f.x), mix(values.z, values.w, f.x), f.y);
}

void fragment() {
	vec2 flow = UV * vec2(6.0, 10.0) + vec2(0.0, TIME * 1.5);
	float flames = noise(flow) * 0.6 + noise(flow * 2.0) * 0.4;
	float edge = mix(1.4, -0.4, burn_progress) - UV.y + (flames - 0.5) * 0.3;
	float remaining = smoothstep(-0.08, 0.08, edge);
	float fire = (1.0 - smoothstep(0.0, 0.24, abs(edge))) * remaining;
	vec4 card = COLOR;
	card.rgb = mix(card.rgb, mix(vec3(0.8, 0.12, 0.02), vec3(1.0, 0.85, 0.25), flames), fire);
	card.a *= remaining;
	COLOR = card;
}
