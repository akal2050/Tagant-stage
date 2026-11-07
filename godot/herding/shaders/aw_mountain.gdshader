shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// The animal mountains: layered rock, darker scrub on the lower slopes, snow on the high parts
// (more on surfaces that face the sky, wind-scoured on steep ones).
// cine (cinematic render): the same rock, band-limited (no pixel speckle) and carved in relief
// (strata ledges, weathered lumps, cracks) so the sun models it close up.
#include "res://herding/shaders/noise.gdshaderinc"
global uniform float cine;
instance uniform float ybase = 0.0;
instance uniform float ysize = 100.0;
uniform float snow_line = 0.80;
uniform float relief = 1.0;
varying vec3 W;
varying vec3 WN;

void vertex() {
	W = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	WN = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// rock surface height in metres (Blender coords, z up)
float hrock(vec3 p, float fw) {
	float band = (p.z + 6.0 * bnoise(p, 0.02, 4, 0.5)) / 9.0;
	float ledge = smoothstep(0.30, 0.62, fract(band));
	float crack = 1.0 - smoothstep(0.02, 0.10, bvoronoi(p, 0.35));
	float cfade = 1.0 - smoothstep(0.04, 0.2, fw * 0.35);
	return 1.6 * bnoise_aa(p, 0.05, 4, 0.5, fw) + 0.55 * bnoise_aa(p, 0.25, 5, 0.55, fw)
		+ 0.45 * ledge - 0.22 * crack * cfade;
}

void fragment() {
	vec3 p = vec3(W.x, -W.z, W.y);
	float fw = cine > 0.5 ? length(fwidth(W)) : 0.0;
	float f = (W.y - ybase) / max(ysize, 1.0);
	// rock strata
	float band = fract((W.y + 6.0 * bnoise(p, 0.02, 4, 0.5)) / 9.0);
	vec3 r1 = vec3(0.50, 0.40, 0.31), r2 = vec3(0.36, 0.29, 0.23), r3 = vec3(0.60, 0.52, 0.42);
	vec3 rock = band < 0.4 ? mix(r1, r2, band / 0.4) : (band < 0.7 ? mix(r2, r3, (band - 0.4) / 0.3) : mix(r3, r1, (band - 0.7) / 0.3));
	float n = bnoise_aa(p, 0.25, 6, 0.55, fw);
	rock *= 0.78 + 0.4 * n;
	float cracks = smoothstep(0.02, 0.10, bvoronoi(p, 0.35));
	float cfade = cine > 0.5 ? 1.0 - smoothstep(0.04, 0.2, fw * 0.35) : 1.0;
	rock *= mix(1.0, mix(0.55, 1.0, cracks), cfade);
	// scrub / dry grass on gentle lower slopes
	float up = clamp(WN.y, 0.0, 1.0);
	float scrub = smoothstep(0.55, 0.85, up) * (1.0 - smoothstep(0.35, 0.6, f)) * smoothstep(0.45, 0.6, bnoise_aa(p, 0.12, 4, 0.5, fw));
	vec3 c = mix(rock, vec3(0.46, 0.42, 0.29) * (0.85 + 0.3 * n), scrub * 0.45);
	// snow cap
	float sl = snow_line + 0.07 * (bnoise(p, 0.05, 4, 0.5) - 0.5) * 2.0;
	float snow = smoothstep(sl - 0.03, sl + 0.05, f) * smoothstep(0.25, 0.65, up + 0.25 * (f - sl));
	snow = max(snow, smoothstep(sl + 0.10, sl + 0.16, f) * 0.85);     // the very top is white even when steep
	snow *= 0.85 + 0.15 * bnoise_aa(p, 1.5, 3, 0.5, fw);
	snow = clamp(snow, 0.0, 1.0);
	vec3 snowc = vec3(0.90, 0.92, 0.95);
	ALBEDO = mix(c, snowc, snow);
	ROUGHNESS = mix(0.92, 0.55, snow);
	SPECULAR = mix(0.4, 0.6, snow);
	if (cine > 0.5) {
		float e = max(0.06, fw);
		float h0 = hrock(p, fw);
		vec3 gb = (vec3(hrock(p + vec3(e, 0.0, 0.0), fw), hrock(p + vec3(0.0, e, 0.0), fw), hrock(p + vec3(0.0, 0.0, e), fw)) - h0) / e;
		vec3 g = vec3(gb.x, gb.z, -gb.y);
		vec3 N = normalize(WN);
		N = normalize(N - (g - N * dot(g, N)) * relief * (1.0 - 0.7 * snow));
		NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
		AO = mix(0.75, 1.0, cracks * cfade + (1.0 - cfade));
		AO_LIGHT_AFFECT = 0.3;
	}
}
