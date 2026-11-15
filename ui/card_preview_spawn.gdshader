shader_type canvas_item;

uniform float spawn_progress : hint_range(0.0, 1.0) = 0.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

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
	vec2 flow = UV * vec2(3.2, 4.6) - vec2(TIME * 0.35, TIME * 0.09);
	float turbulence = noise(flow) * 0.6 + noise(flow * 2.03 + vec2(5.2, 1.3)) * 0.4;
	float curls = noise(flow * 1.8 + vec2(turbulence * 2.0, -turbulence));
	float front = mix(-0.65, 1.65, spawn_progress);
	float wind_x = UV.x + (turbulence - 0.5) * 0.3 + (curls - 0.5) * 0.12;
	float reveal = 1.0 - smoothstep(front - 0.26, front + 0.18, wind_x);
	float envelope = smoothstep(0.0, 0.08, spawn_progress) * (1.0 - smoothstep(0.92, 1.0, spawn_progress));
	float gust_distance = (wind_x - front) * 3.8;
	float gust = exp(-gust_distance * gust_distance) * envelope;
	vec2 displacement = vec2(turbulence - 0.5, curls - 0.5);
	displacement += vec2(sin(UV.y * 12.0 - TIME * 2.0), cos(UV.x * 11.0 + TIME)) * 0.2;
	vec2 uv = clamp(UV + displacement * gust * 0.06, vec2(0.0), vec2(1.0));
	vec4 card = texture(TEXTURE, uv) * vertex_color;
	vec3 mist = mix(vec3(0.60, 0.61, 0.62), vec3(0.90, 0.91, 0.92), turbulence);
	float wisps = smoothstep(0.35, 0.7, turbulence * 0.55 + curls * 0.6);
	card.rgb = mix(card.rgb, mist, gust * 0.8);
	card.a = max(card.a * reveal, gust * wisps * 0.55 * vertex_color.a);
	COLOR = card;
}
