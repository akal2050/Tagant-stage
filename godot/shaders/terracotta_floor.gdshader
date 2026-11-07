// Terracotta earth floor of the stage: Poly Haven cracked_red_ground, warmed toward fired clay,
// two rotated samples + macro colour variation so the tiling never shows.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 clay_dark : source_color = vec3(0.47, 0.17, 0.09);
uniform vec3 clay_mid : source_color = vec3(0.70, 0.31, 0.17);
uniform vec3 clay_light : source_color = vec3(0.82, 0.50, 0.32);
uniform float tile = 3.2;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 uv = wp.xz / tile;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * wp.xz / (tile * 2.6) + vec2(0.37, 0.71);
	vec3 t1 = texture(diff, uv).rgb;
	vec3 t2 = texture(diff, uv2).rgb;
	vec3 tex = mix(t1, t2, 0.38);
	float l = dot(tex, vec3(0.3, 0.59, 0.11));
	float macro = fbm(wp.xz * 0.045);
	vec3 base = mix(clay_dark, clay_mid, smoothstep(0.25, 0.65, macro));
	base = mix(base, clay_light, smoothstep(0.55, 0.85, fbm(wp.xz * 0.12 + 5.0)) * 0.6);
	ALBEDO = mix(tex * vec3(1.25, 0.95, 0.8), base * (0.5 + 1.6 * l), 0.55);
	NORMAL_MAP = normalize(mix(texture(nor, uv).rgb, texture(nor, uv2).rgb, 0.38) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = clamp(0.78 + 0.2 * texture(rough, uv).g, 0.0, 1.0);
}
