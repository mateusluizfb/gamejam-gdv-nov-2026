shader_type canvas_item;
render_mode unshaded;

#include "res://game/mist_noise.gdshaderinc"

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 flow = UV * vec2(aspect * 2.2, 5.0) - vec2(TIME * 0.08, TIME * 0.025);
	float mist = mist_wisps(flow, TIME);
	float density = smoothstep(0.32, 0.72, mist) * 0.26;
	COLOR = vec4(vec3(0.83, 0.86, 0.88), density * COLOR.a);
}
