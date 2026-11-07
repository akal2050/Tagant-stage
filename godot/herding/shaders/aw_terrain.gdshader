shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Rebuild of the Blender material "VALLEY_Ground".
// Vertex COLOR = (slope, wall, canal, wet); UV2 = (poppy, village)

#include "res://herding/shaders/noise.gdshaderinc"

uniform sampler2D dry_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
global uniform float cine;
global uniform float bloom;
// the poppies that take the valley (data/poppy_grow_map.png): R = when, G = where; spans +-2200 m
uniform sampler2D grow_map : filter_linear, repeat_disable;
uniform float grow_ext = 2200.0;
uniform float tex_scale = 0.425;
uniform float normal_strength = 1.0;
// herding karaoke: the valley earth darker and warmer than the film's daylight, and the poppy field's ground
uniform vec3 earth_tint = vec3(0.80, 0.62, 0.48);
uniform vec3 field_c = vec3(0.0, 0.0, 100000.0);
uniform float field_r = 140.0;

varying vec3 bo;      // Blender object coords
varying vec3 wnorm;   // world normal
varying vec4 attr;
varying vec2 attr2;

void vertex() {
	bo = to_blender(VERTEX);
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	attr = COLOR;
	attr2 = UV2;
}

void fragment() {
	float slope = attr.r;
	float wall = attr.g;
	float canal = attr.b;
	float wet = attr.a;
	float poppy = attr2.x;
	vec4 gm = texture(grow_map, (vec2(bo.x, -bo.y) + grow_ext) / (2.0 * grow_ext));
	float grown = gm.g * smoothstep(gm.r, gm.r + 0.025, bloom);
	float dist = length(VERTEX);

	vec2 uv = bo.xy * tex_scale;
	// dry ground / withered grass blend
	float m = smoothstep(0.48, 0.62, bnoise(bo, 0.12, 6, 0.5));
	vec3 c = mix(texture(dry_diff, uv).rgb, texture(grass_diff, uv).rgb, m);
	// Hue/Saturation/Value (sat 0.55, val 1.15)
	vec3 hsv = rgb2hsv(c);
	hsv.y *= 0.55;
	hsv.z *= 1.15;
	c = hsv2rgb(hsv);
	// distance fade toward the flat valley tone
	vec3 far_tone = vec3(0.56, 0.47, 0.37);
	float fwb = 0.0;
	if (cine > 0.5) {
		// cinematic render: the far ground keeps patches, scrub and gullies instead of one flat tone
		fwb = length(fwidth(bo));
		float mac = bnoise_aa(bo, 0.03, 5, 0.55, fwb);
		float mac2 = bnoise(bo, 0.008, 3, 0.5);
		float scr = smoothstep(0.58, 0.72, bnoise_aa(bo, 0.18, 3, 0.5, fwb));
		far_tone *= mix(0.80, 1.16, mac) * mix(0.94, 1.05, mac2);
		far_tone = mix(far_tone, vec3(0.34, 0.33, 0.22), scr * 0.35);
	}
	c = mix(c, far_tone, map_range(dist, 35.0, 170.0, 0.0, 0.88));

	// strata bands on escarpments and canal walls
	float sz = bnoise(bo, 0.02, 6, 0.5) * 9.0 + bo.z;
	float n2 = bnoise(bo, 0.6, 8, 0.5);
	float band = fract((n2 * 0.8 + sz) / 7.0);
	vec3 strata;
	if (band < 0.22) strata = mix(vec3(0.52, 0.38, 0.25), vec3(0.66, 0.56, 0.42), band / 0.22);
	else if (band < 0.38) strata = mix(vec3(0.66, 0.56, 0.42), vec3(0.47, 0.28, 0.18), (band - 0.22) / 0.16);
	else if (band < 0.55) strata = mix(vec3(0.47, 0.28, 0.18), vec3(0.72, 0.66, 0.55), (band - 0.38) / 0.17);
	else if (band < 0.72) strata = mix(vec3(0.72, 0.66, 0.55), vec3(0.42, 0.39, 0.35), (band - 0.55) / 0.17);
	else if (band < 0.88) strata = mix(vec3(0.42, 0.39, 0.35), vec3(0.60, 0.46, 0.30), (band - 0.72) / 0.16);
	else strata = vec3(0.60, 0.46, 0.30);
	vec3 n2c = bnoise_col(bo, 0.6, 8, 0.5);
	// overlay blend 0.35
	vec3 ov = mix(2.0 * strata * n2c, 1.0 - 2.0 * (1.0 - strata) * (1.0 - n2c), step(0.5, strata));
	strata = mix(strata, ov, 0.35);
	float rockmask = max(map_range(slope, 0.1, 0.32, 0.0, 1.0), map_range(wall, 0.02, 0.4, 0.0, 0.45));
	c = mix(c, strata, rockmask);

	// canal silt: cracked mud cells
	float vd = map_range(bvoronoi(bo, 9.0), 0.0, 0.45, 0.55, 1.0);
	vec3 silt = vec3(0.58, 0.52, 0.43) * vd;
	c = mix(c, silt, map_range(canal, 0.05, 0.7, 0.0, 1.0));

	// wet darkening
	float wf = map_range(wet, 0.0, 1.0, 0.0, 0.55);
	c = mix(c, c * vec3(0.33, 0.30, 0.19), wf);

	// very large tonal variation
	float big = bnoise(bo, 0.004, 4, 0.5);
	c *= mix(vec3(0.82, 0.78, 0.72), vec3(1.12, 1.06, 0.98), big);

	// poppy fields read as red from a distance
	float pf = poppy * map_range(dist, 30.0, 380.0, 0.12, 0.62) * map_range(bnoise(bo, 0.9, 2, 0.5), 0.35, 0.7, 0.6, 1.0);
	// where the poppies have taken the valley: a carpet of petals under the flowers, denser with distance
	pf = max(pf, grown * map_range(dist, 8.0, 260.0, 0.45, 0.82) * map_range(bnoise(bo, 0.35, 3, 0.5), 0.3, 0.7, 0.75, 1.0));
	c = mix(c, vec3(0.42, 0.02, 0.02), clamp(pf, 0.0, 1.0));

	c *= earth_tint;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fd = length((wpos.xz - field_c.xz) * vec2(1.0 / 1.4, 1.0)) / field_r;
	float fm = (1.0 - smoothstep(0.55, 1.0, fd)) * map_range(bnoise(bo, 0.25, 3, 0.5), 0.3, 0.7, 0.55, 1.0);
	c = mix(c, mix(vec3(0.20, 0.24, 0.08), vec3(0.42, 0.03, 0.02), map_range(dist, 6.0, 120.0, 0.25, 0.75)), fm * 0.85);
	ALBEDO = c;
	float r = mix(texture(dry_rough, uv).g, texture(grass_rough, uv).g, m);
	ROUGHNESS = mix(r, 0.35, wf);
	SPECULAR = 0.5;

	// normal mapping in world space (mesh has no UVs / tangents)
	vec3 nt = mix(texture(dry_nor, uv).rgb, texture(grass_nor, uv).rgb, m) * 2.0 - 1.0;
	nt.xy *= normal_strength * (1.0 - map_range(dist, 60.0, 400.0, 0.0, 0.85));
	vec3 N = normalize(wnorm);
	vec3 T = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
	vec3 B = normalize(cross(N, T));
	vec3 wn = normalize(T * nt.x + B * nt.y + N * nt.z);
	if (cine > 0.5) {
		// large relief the sun can model at a distance (metres, Blender coords)
		float e = max(0.5, fwb);
		vec3 q = bo;
		float h0 = 6.0 * bnoise_aa(q, 0.012, 4, 0.5, fwb) + 1.5 * bnoise_aa(q, 0.06, 4, 0.5, fwb);
		vec3 gb = vec3(
			6.0 * bnoise_aa(q + vec3(e, 0.0, 0.0), 0.012, 4, 0.5, fwb) + 1.5 * bnoise_aa(q + vec3(e, 0.0, 0.0), 0.06, 4, 0.5, fwb),
			6.0 * bnoise_aa(q + vec3(0.0, e, 0.0), 0.012, 4, 0.5, fwb) + 1.5 * bnoise_aa(q + vec3(0.0, e, 0.0), 0.06, 4, 0.5, fwb),
			6.0 * bnoise_aa(q + vec3(0.0, 0.0, e), 0.012, 4, 0.5, fwb) + 1.5 * bnoise_aa(q + vec3(0.0, 0.0, e), 0.06, 4, 0.5, fwb)) - h0;
		vec3 g = vec3(gb.x, gb.z, -gb.y) / e;
		float k = map_range(dist, 40.0, 300.0, 0.3, 1.0);
		wn = normalize(wn - (g - wn * dot(g, wn)) * k);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
