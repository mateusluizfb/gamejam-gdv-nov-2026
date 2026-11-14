shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float wind_progress : hint_range(0.0, 1.0) = 0.0;

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

float clouds(vec2 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * weight;
		p = p * 2.03 + vec2(5.2, 1.3);
		weight *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 flow = UV * vec2(3.2, 4.6) - vec2(TIME * 0.35, TIME * 0.09);
	float turbulence = clouds(flow);
	float curls = clouds(flow * 1.8 + vec2(turbulence * 2.0, -turbulence));
	float front = mix(-0.65, 1.65, wind_progress);
	float wind_x = UV.x + (turbulence - 0.45) * 0.3 + (curls - 0.45) * 0.12;
	float coverage = 1.0 - smoothstep(front - 0.26, front + 0.18, wind_x);
	float gust_envelope = smoothstep(0.0, 0.08, wind_progress) * (1.0 - smoothstep(0.84, 1.0, wind_progress));
	float gust = exp(-pow((wind_x - front) * 3.8, 2.0)) * gust_envelope;
	vec2 displacement = vec2(turbulence - 0.45, curls - 0.45);
	displacement += vec2(sin(UV.y * 12.0 - TIME * 2.0), cos(UV.x * 11.0 + TIME)) * 0.2;
	vec2 uv = clamp(SCREEN_UV + displacement * (gust * 0.045 + coverage * 0.003), vec2(0.0), vec2(1.0));
	vec3 scene = texture(screen_texture, uv).rgb;
	vec3 blurred = textureLod(screen_texture, uv, 2.5).rgb;
	float vignette = smoothstep(0.2, 0.8, length(centered));
	vec3 purple = mix(vec3(0.08, 0.025, 0.16), vec3(0.38, 0.16, 0.53), turbulence);
	vec3 haze = mix(blurred * vec3(0.55, 0.4, 0.68), purple, 0.72);
	haze *= 1.0 - vignette * 0.3;
	vec3 color = mix(scene, haze, coverage);
	float vapor = smoothstep(0.36, 0.68, turbulence * 0.55 + curls * 0.6);
	color += vec3(0.3, 0.14, 0.4) * gust * vapor * 0.8;
	COLOR = vec4(color, COLOR.a);
}
