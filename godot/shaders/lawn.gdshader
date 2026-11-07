// Grass around the stage and the garden ground beyond the garden circle.
// Poly Haven forrest_ground_01 (lawn) and aerial_grass_rock (garden), ragged edge into the sand.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D lawn : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lawn_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D garden : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D garden_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float garden_r = 41.0;
uniform float outer_r = 76.0;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float r = length(wp.xz);
	float edge = outer_r + (fbm(wp.xz * 0.08) - 0.5) * 10.0;
	if (r > edge) { discard; }
	vec2 uv = wp.xz / 4.0;
	vec3 l = texture(lawn, uv).rgb * vec3(0.92, 1.08, 0.82);
	vec3 g = texture(garden, wp.xz / 6.0).rgb * vec3(0.95, 1.1, 0.85);
	float k = smoothstep(garden_r - 0.6, garden_r + 0.6, r);
	vec3 c = mix(l, g, k);
	c *= 0.8 + 0.35 * fbm(wp.xz * 0.05);
	c = mix(c, vec3(0.62, 0.45, 0.30), smoothstep(edge - 7.0, edge, r) * 0.65);   // grass thins into sand
	ALBEDO = c;
	NORMAL_MAP = mix(texture(lawn_nor, uv).rgb, texture(garden_nor, wp.xz / 6.0).rgb, k);
	ROUGHNESS = 0.95;
}
