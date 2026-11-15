shader_type canvas_item;
render_mode unshaded;

#include "res://game/mist_noise.gdshaderinc"

void fragment() {
	vec2 flow = UV * vec2(3.0, 7.0) - vec2(TIME * 0.025, TIME * 0.004);
	float wisps = mist_wisps(flow, TIME);
	float mist = smoothstep(0.32, 0.75, wisps) * 0.18;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.84, 0.84, 0.78), mist);
}
