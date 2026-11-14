shader_type canvas_item;
render_mode unshaded;

uniform float beam_length = 1.0;

void fragment() {
	float along = UV.x;
	float across = (UV.y - 0.5) * 2.0;
	float wave = sin(along * 17.0 - TIME * 3.0) * 0.12;
	float wisp = sin(along * 31.0 - TIME * 4.5) * 0.15;
	float glow = exp(-abs(across - wave) * 3.0);
	float core = 1.0 - smoothstep(0.025, 0.13, abs(across - wave * 0.5));
	float filament = 1.0 - smoothstep(0.015, 0.08, abs(across + wave + wisp));
	float flow = 0.7 + 0.3 * sin(along * 26.0 - TIME * 5.0);
	float tip_distance = (1.0 - along) * beam_length;
	float tip_width = clamp(tip_distance / 22.0, 0.0, 1.0) * 0.65;
	float arrowhead = (1.0 - smoothstep(tip_width, tip_width + 0.06, abs(across)))
		* (1.0 - smoothstep(20.0, 32.0, tip_distance));
	float ends = smoothstep(0.0, 0.05, along) * smoothstep(0.0, 0.01, 1.0 - along);
	float alpha = clamp(glow * 0.38 + core * 0.42 + filament * 0.2 * flow + arrowhead * 0.55, 0.0, 0.85) * ends;
	vec3 color = mix(vec3(0.52, 0.12, 0.84), vec3(0.9, 0.75, 1.0), clamp(core + filament * 0.4 + arrowhead, 0.0, 1.0));
	COLOR = vec4(color, alpha);
}
