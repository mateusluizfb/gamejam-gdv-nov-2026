shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float wind_progress : hint_range(0.0, 1.0) = 0.0;
uniform int transition_mode : hint_range(0, 2) = 0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;

#include "res://game/mist_noise.gdshaderinc"

void fragment() {
	vec2 centered = UV - vec2(0.5);
	vec2 flow = UV * vec2(3.2, 4.6) - vec2(TIME * 0.35, TIME * 0.09);
	float turbulence = mist_wisps(flow, TIME);
	float curls = mist_fbm(flow * 1.8 + vec2(turbulence * 2.0, -turbulence));
	float progress = transition_mode == 0 ? wind_progress : transition_progress;
	float front = mix(-0.65, 1.65, progress);
	float wind_x = UV.x + (turbulence - 0.45) * 0.3 + (curls - 0.45) * 0.12;
	float coverage = 1.0 - smoothstep(front - 0.26, front + 0.18, wind_x);
	float gust_envelope = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.84, 1.0, progress));
	float gust_distance = (wind_x - front) * 3.8;
	float gust = exp(-gust_distance * gust_distance) * gust_envelope;
	vec2 displacement = vec2(turbulence - 0.45, curls - 0.45);
	displacement += vec2(sin(UV.y * 12.0 - TIME * 2.0), cos(UV.x * 11.0 + TIME)) * 0.2;
	vec2 uv = clamp(SCREEN_UV + displacement * (gust * 0.045 + coverage * 0.003), vec2(0.0), vec2(1.0));
	vec3 scene = texture(screen_texture, uv).rgb;
	vec3 blurred = textureLod(screen_texture, uv, 2.5).rgb;
	float vignette = smoothstep(0.2, 0.8, length(centered));
	vec3 mist = mix(vec3(0.60, 0.61, 0.62), vec3(0.90, 0.91, 0.92), turbulence);
	vec3 haze = mix(blurred * vec3(0.78), mist, 0.72);
	haze *= 1.0 - vignette * 0.16;
	vec3 color = mix(scene, haze, coverage);
	if (transition_mode != 0) {
		vec3 base = transition_mode == 1 ? haze : scene;
		float cover = transition_mode == 1 ? coverage : 1.0 - coverage;
		vec3 veil = mist * (1.0 - vignette * 0.16);
		color = mix(base, veil, cover);
	}
	float vapor = smoothstep(0.36, 0.68, turbulence * 0.55 + curls * 0.6);
	color += vec3(0.2) * gust * vapor * 0.8;
	COLOR = vec4(color, COLOR.a);
}
