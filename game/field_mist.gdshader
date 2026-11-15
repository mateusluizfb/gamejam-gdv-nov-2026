shader_type canvas_item;
render_mode unshaded;

#include "res://game/mist_noise.gdshaderinc"

// Interior of the black outline in background-playmatch.png, in texture UVs.
uniform vec4 board_bounds = vec4(0.1328125, 0.05555556, 0.8671875, 0.70833333);
uniform float board_bottom = 0.70833333;

varying vec4 vertex_color;
varying vec2 board_uv;

void vertex() {
	vertex_color = COLOR;
	// Keep the painted board aligned with the cards in the 1280 × 720 design area.
	board_uv = VERTEX / vec2(1280.0, 720.0);
}

void fragment() {
	float board_top = board_bounds.y;
	float frame_y = board_uv.y;
	if (frame_y > board_top) {
		frame_y = frame_y <= board_bottom
			? mix(board_top, board_bounds.w, (frame_y - board_top) / (board_bottom - board_top))
			: board_bounds.w + frame_y - board_bottom;
	}
	vec2 frame_uv = vec2(board_uv.x, frame_y);
	float inside = step(board_bounds.x, board_uv.x) * step(board_uv.x, board_bounds.z)
		* step(board_top, board_uv.y) * step(board_uv.y, board_bottom);
	vec2 terrain_uv = board_uv * vec2(8.0, 4.5);
	vec2 warp = vec2(
		mist_noise(terrain_uv * 0.7),
		mist_noise(terrain_uv * 0.7 + vec2(7.1, 3.4))
	) - vec2(0.5);
	vec2 terrain = terrain_uv + warp * 0.3;
	float broad = mist_fbm(terrain);
	float rough = mist_fbm(terrain * 2.0 + vec2(3.2, 1.7));
	float grain = mist_noise(terrain * 36.0);
	float height = broad * 0.5 + rough * 0.5;
	vec2 slope = vec2(
		dFdx(height) / max(abs(dFdx(terrain_uv.x)), 0.00001),
		dFdy(height) / max(abs(dFdy(terrain_uv.y)), 0.00001)
	);
	vec3 normal = normalize(vec3(-slope * mix(1.1, 0.55, inside), 1.0));
	vec3 sunlight = normalize(vec3(-0.7, -0.6, 0.8));
	float lighting = 0.6 + 0.55 * max(dot(normal, sunlight), 0.0);
	vec3 soil = mix(vec3(0.27, 0.19, 0.14), vec3(0.55, 0.42, 0.32), smoothstep(0.12, 0.75, height));
	soil *= lighting * mix(0.78 + grain * 0.42, 0.92 + grain * 0.16, inside);
	vec4 background = texture(TEXTURE, clamp(frame_uv, vec2(0.0), vec2(1.0))) * vertex_color;
	float outside_art = step(1.0, max(frame_uv.x, frame_uv.y));
	float ground = max(outside_art, step(0.01, dot(background.rgb, vec3(0.33333))));
	COLOR = vec4(mix(background.rgb, soil * vertex_color.rgb, ground), background.a);

	vec2 flow = board_uv * vec2(3.0, 7.0) - vec2(TIME * 0.025, TIME * 0.004);
	float wisps = mist_wisps(flow, TIME);
	float mist = smoothstep(0.32, 0.75, wisps) * 0.18;
	COLOR.rgb = mix(COLOR.rgb, vec3(0.84, 0.84, 0.78) * vertex_color.rgb, mist * ground);
}
