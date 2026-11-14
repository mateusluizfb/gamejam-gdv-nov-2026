shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float magic_strength : hint_range(0.0, 1.0) = 0.0;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = SCREEN_UV - vec2(0.5);
	vec2 ripple = vec2(sin(SCREEN_UV.y * 16.0 + TIME * 2.0), cos(SCREEN_UV.x * 14.0 - TIME * 1.7));
	vec2 uv = clamp(SCREEN_UV + ripple * SCREEN_PIXEL_SIZE * 4.0 * magic_strength
		+ centered * impact_strength * 0.012, vec2(0.0), vec2(1.0));
	vec3 scene = texture(screen_texture, uv).rgb;
	vec3 blur = textureLod(screen_texture, uv, 2.5).rgb;
	vec3 color = mix(scene, blur, magic_strength * 0.65);
	color = mix(color, color * vec3(0.85, 0.83, 1.1) + vec3(0.08, 0.04, 0.1), magic_strength * 0.45);
	float vignette = smoothstep(0.2, 0.8, length(centered));
	color = mix(color, color * (1.0 - 0.4 * vignette) + vec3(0.22, 0.06, 0.02), impact_strength * 0.55);
	COLOR = vec4(color, 1.0);
}
