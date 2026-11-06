// shared value-noise / fbm used by the DOVE MAN shaders
float dm_hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float dm_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = dm_hash31(i);
	float n100 = dm_hash31(i + vec3(1, 0, 0));
	float n010 = dm_hash31(i + vec3(0, 1, 0));
	float n110 = dm_hash31(i + vec3(1, 1, 0));
	float n001 = dm_hash31(i + vec3(0, 0, 1));
	float n101 = dm_hash31(i + vec3(1, 0, 1));
	float n011 = dm_hash31(i + vec3(0, 1, 1));
	float n111 = dm_hash31(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}
float dm_fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += dm_noise3(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
