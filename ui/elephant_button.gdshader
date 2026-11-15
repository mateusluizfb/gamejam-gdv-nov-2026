shader_type canvas_item;

uniform vec2 button_center = vec2(0.0);
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
const vec2 UV_PADDING = vec2(0.05, 0.09);
varying vec4 tint;

void vertex() {
	tint = COLOR;
	VERTEX = button_center + (VERTEX - button_center)
		* (1.0 + 2.0 * UV_PADDING) * (1.0 + 0.15 * highlight);
}

float sample_alpha(sampler2D sprite, vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(sprite, uv).a * inside.x * inside.y;
}

float ring_alpha(sampler2D sprite, vec2 uv, vec2 radius) {
	float alpha = 0.0;
	for (int i = 0; i < 12; i++) {
		float angle = float(i) * TAU / 12.0;
		alpha += sample_alpha(sprite, uv + vec2(cos(angle), sin(angle)) * radius);
	}
	return alpha / 12.0;
}

void fragment() {
	vec2 uv = UV * (1.0 + 2.0 * UV_PADDING) - UV_PADDING;
	vec3 sprite = mix(texture(TEXTURE, uv).rgb, vec3(1.0), 0.08 * highlight);
	float sprite_alpha = sample_alpha(TEXTURE, uv);
	float halo = ring_alpha(TEXTURE, uv, TEXTURE_PIXEL_SIZE * 2.0) * 0.45
		+ ring_alpha(TEXTURE, uv, TEXTURE_PIXEL_SIZE * 5.0) * 0.36
		+ ring_alpha(TEXTURE, uv, TEXTURE_PIXEL_SIZE * 9.0) * 0.19;
	float pulse = 0.5 - 0.5 * cos(TIME * PI);
	float glow_strength = mix(0.65, 1.45, pulse) + 0.25 * highlight;
	float glow_alpha = clamp(halo * glow_strength, 0.0, 1.0) * (1.0 - sprite_alpha);
	float alpha = sprite_alpha + glow_alpha;
	vec3 glow_color = vec3(1.0, 0.87, 0.57);
	COLOR = vec4((sprite * sprite_alpha + glow_color * glow_alpha) / max(alpha, 0.0001), alpha) * tint;
}
