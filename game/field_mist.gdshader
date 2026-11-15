shader_type canvas_item;
render_mode unshaded;

#include "res://game/mist_noise.gdshaderinc"

uniform sampler2D soil_texture : source_color, filter_linear, repeat_disable;
// Interior of the black outline in background-playmatch.png, in texture UVs.
uniform vec4 board_bounds = vec4(0.1328125, 0.05555556, 0.8671875, 0.70833333);

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	float inside = step(board_bounds.x, UV.x) * step(UV.x, board_bounds.z)
		* step(board_bounds.y, UV.y) * step(UV.y, board_bounds.w);
	vec2 soil_size = vec2(textureSize(soil_texture, 0));
	float soil_aspect = soil_size.x / soil_size.y;
	float background_aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 crop = vec2(min(background_aspect / soil_aspect, 1.0), min(soil_aspect / background_aspect, 1.0));
	vec2 soil_uv = (UV - vec2(0.5)) * crop + vec2(0.5);
	vec2 texel = 3.0 / soil_size;
	vec3 center = texture(soil_texture, soil_uv).rgb;
	vec3 left = texture(soil_texture, soil_uv - vec2(texel.x, 0.0)).rgb;
	vec3 right = texture(soil_texture, soil_uv + vec2(texel.x, 0.0)).rgb;
	vec3 top = texture(soil_texture, soil_uv - vec2(0.0, texel.y)).rgb;
	vec3 bottom = texture(soil_texture, soil_uv + vec2(0.0, texel.y)).rgb;
	vec3 soil = mix(center, (center + left + right + top + bottom) / 5.0, inside * 0.8);
	vec3 luminance = vec3(0.299, 0.587, 0.114);
	vec2 slope = vec2(dot(right - left, luminance), dot(bottom - top, luminance));
	float lighting = clamp(1.0 + dot(slope, vec2(-0.75, -0.65)) * mix(1.5, 0.65, inside), 0.72, 1.28);
	vec4 background = texture(TEXTURE, UV) * vertex_color;
	float ground = step(0.01, dot(background.rgb, vec3(0.33333)));
	COLOR = vec4(mix(background.rgb, soil * lighting * vertex_color.rgb, ground), background.a);

	vec2 flow = UV * vec2(3.0, 7.0) - vec2(TIME * 0.025, TIME * 0.004);
	float wisps = mist_wisps(flow, TIME);
	float mist = smoothstep(0.32, 0.75, wisps) * 0.18;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.84, 0.84, 0.78) * vertex_color.rgb, mist * ground);
}
