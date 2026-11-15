shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

#include "res://game/mist_noise.gdshaderinc"

uniform float spawn_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (spawn_progress <= 0.0) {
		COLOR = vec4(0.0);
	} else if (spawn_progress >= 1.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 flow = UV * vec2(8.0, 5.0) - vec2(TIME * 0.7, TIME * 0.24);
		float wisps = mist_wisps(flow, TIME);
		float curl = mist_fbm(flow * 1.8 + vec2(4.3, 1.7));
		float front = mix(-0.28, 1.28, spawn_progress);
		float distance_to_front = UV.x - front + (wisps - 0.5) * 0.32;
		float reveal = 1.0 - smoothstep(-0.12, 0.08, distance_to_front);
		float band = 1.0 - smoothstep(0.02, 0.21, abs(distance_to_front));

		vec2 drift = vec2(10.0 + curl * 16.0, -5.0 - wisps * 14.0) * TEXTURE_PIXEL_SIZE;
		vec4 letters = texture(TEXTURE, UV - drift * band * 0.35) * reveal;
		// Sample the glyphs upstream so the smoke follows the strokes of the text.
		float trail = texture(TEXTURE, UV - drift * 0.5).a * 0.24;
		trail += texture(TEXTURE, UV - drift).a * 0.18;
		trail += texture(TEXTURE, UV - drift * 1.55).a * 0.10;
		float vapor = trail * band * smoothstep(0.26, 0.66, wisps);
		// Keep distant wisps faint and confine them to the moving front.
		float haze = band * smoothstep(0.47, 0.76, wisps) * 0.13;
		haze *= 1.0 - smoothstep(0.04, 0.24, abs(UV.y - 0.5));
		float smoke = max(vapor, haze);
		COLOR = letters + vec4(vec3(0.69, 0.73, 0.76) * smoke, smoke) * (1.0 - letters.a);
	}
}
