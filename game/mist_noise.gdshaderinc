float mist_hash(vec2 p) {
	vec3 q = fract(p.xyx * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float mist_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(mist_hash(cell), mist_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(mist_hash(cell + vec2(0.0, 1.0)), mist_hash(cell + 1.0), f.x),
		f.y
	);
}

float mist_fbm(vec2 p) {
	const mat2 rotation = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float density = 0.0;
	float weight = 0.52;
	for (int i = 0; i < 4; i++) {
		density += mist_noise(p) * weight;
		p = rotation * p * 2.07 + vec2(5.2, 1.3);
		weight *= 0.5;
	}
	return density;
}

float mist_wisps(vec2 p, float time) {
	vec2 warp = vec2(
		mist_fbm(p * 0.65 + vec2(0.0, time * 0.045)),
		mist_fbm(p * 0.65 + vec2(7.1, -time * 0.035))
	);
	return mist_fbm(p + (warp - 0.5) * 3.0);
}
