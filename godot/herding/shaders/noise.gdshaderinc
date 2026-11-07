// Procedural helpers approximating Blender's Noise / Voronoi / Wave textures.
// Inputs are Blender object coordinates (Z up) so the Blender node values carry over.

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// gradient noise, range roughly [-1, 1]
float gnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n000 = dot(hash33(i + vec3(0,0,0)) * 2.0 - 1.0, f - vec3(0,0,0));
	float n100 = dot(hash33(i + vec3(1,0,0)) * 2.0 - 1.0, f - vec3(1,0,0));
	float n010 = dot(hash33(i + vec3(0,1,0)) * 2.0 - 1.0, f - vec3(0,1,0));
	float n110 = dot(hash33(i + vec3(1,1,0)) * 2.0 - 1.0, f - vec3(1,1,0));
	float n001 = dot(hash33(i + vec3(0,0,1)) * 2.0 - 1.0, f - vec3(0,0,1));
	float n101 = dot(hash33(i + vec3(1,0,1)) * 2.0 - 1.0, f - vec3(1,0,1));
	float n011 = dot(hash33(i + vec3(0,1,1)) * 2.0 - 1.0, f - vec3(0,1,1));
	float n111 = dot(hash33(i + vec3(1,1,1)) * 2.0 - 1.0, f - vec3(1,1,1));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
	           mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z) * 1.6;
}

// Blender-like "Noise Texture" Factor output: fBm remapped to ~[0,1] centred at 0.5
float bnoise(vec3 p, float scale, int detail, float roughness) {
	p *= scale;
	float sum = 0.0;
	float amp = 1.0;
	float norm = 0.0;
	for (int i = 0; i <= detail; i++) {
		sum += gnoise(p) * amp;
		norm += amp;
		amp *= roughness;
		p *= 2.0;
	}
	return clamp(0.5 + 0.5 * sum / norm * 1.25, 0.0, 1.0);
}

// same as bnoise, but octaves finer than the pixel footprint fw (in input units) fade out:
// no pixel-sized speckle on surfaces seen from far away (fw = 0.0 gives exactly bnoise)
float bnoise_aa(vec3 p, float scale, int detail, float roughness, float fw) {
	p *= scale;
	float f = fw * scale;
	float sum = 0.0;
	float amp = 1.0;
	float norm = 0.0;
	for (int i = 0; i <= detail; i++) {
		sum += gnoise(p) * amp * (1.0 - smoothstep(0.25, 0.6, f));
		norm += amp;
		amp *= roughness;
		p *= 2.0;
		f *= 2.0;
	}
	return clamp(0.5 + 0.5 * sum / norm * 1.25, 0.0, 1.0);
}

vec3 bnoise_col(vec3 p, float scale, int detail, float roughness) {
	return vec3(bnoise(p, scale, detail, roughness),
	            bnoise(p + vec3(31.4, 17.7, 5.3), scale, detail, roughness),
	            bnoise(p + vec3(-12.9, 43.1, 21.7), scale, detail, roughness));
}

// Voronoi F1 distance (Blender "Distance" output)
float bvoronoi(vec3 p, float scale) {
	p *= scale;
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = hash33(i + g);
		d = min(d, length(g + o - f));
	}
	return d;
}

// Blender "Wave Texture" (bands, X, sine) with noise distortion
float bwave(vec3 p, float scale, float distortion, int detail, float detail_scale) {
	p *= scale;
	float n = 0.0;
	if (distortion != 0.0) {
		n = distortion * (bnoise(p, detail_scale, detail, 0.5) * 2.0 - 1.0);
	}
	float v = (p.x + p.y + p.z) * 20.0 / 3.0 * 0.05 * 6.2831853 + n;
	return 0.5 + 0.5 * sin(v - 1.5707963);
}

float map_range(float v, float a, float b, float c, float d) {
	return c + clamp((v - a) / (b - a), 0.0, 1.0) * (d - c);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Godot local (Y up) -> Blender object coords (Z up)
vec3 to_blender(vec3 v) {
	return vec3(v.x, -v.z, v.y);
}
