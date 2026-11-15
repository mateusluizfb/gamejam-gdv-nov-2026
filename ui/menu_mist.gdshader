shader_type canvas_item;
render_mode unshaded;

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
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 flow = UV * vec2(aspect * 3.0, 3.0) - vec2(TIME * 0.08, TIME * 0.025);
	float mist = noise(flow) * 0.65 + noise(flow * 2.2 + vec2(4.3, TIME * 0.015)) * 0.35;
	float density = smoothstep(0.28, 0.8, mist) * 0.26;
	COLOR = vec4(vec3(0.83, 0.86, 0.88), density * COLOR.a);
}
