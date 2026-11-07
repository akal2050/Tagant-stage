// Geological strata for the cut edges of the floor slab (and any section of earth).
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D nor : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float wob = fbm(vec2(wp.x + wp.z, 0.0) * 0.35) * 0.18;
	float y = wp.y + wob;
	float band = floor(y * 11.0);
	float k = h21(vec2(band, 3.0));
	vec3 c = mix(vec3(0.42, 0.15, 0.08), vec3(0.74, 0.40, 0.22), k);
	c = mix(c, vec3(0.86, 0.72, 0.52), step(0.86, k) * 0.7);           // pale marl lines
	c *= 0.82 + 0.18 * vnoise(vec2(wp.x + wp.z, wp.y) * 9.0);
	ALBEDO = c;
	NORMAL_MAP = texture(nor, vec2(wp.x + wp.z, wp.y) * 0.4).rgb;
	ROUGHNESS = 0.95;
}
