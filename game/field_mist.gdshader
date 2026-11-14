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
	vec2 flow = UV * vec2(3.0, 7.0) - vec2(TIME * 0.025, TIME * 0.004);
	float wisps = noise(flow) * 0.6;
	wisps += noise(flow * 2.1 + vec2(4.3, -TIME * 0.01)) * 0.3;
	wisps += noise(flow * 4.2 + vec2(-TIME * 0.025, 7.1)) * 0.1;
	float mist = smoothstep(0.32, 0.75, wisps) * 0.18;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.84, 0.84, 0.78), mist);
}
