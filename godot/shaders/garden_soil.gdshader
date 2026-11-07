// Dark irrigated garden soil under the shamsa gardens.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common_noise.gdshaderinc"
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float n = fbm(wp.xz * 0.9);
	ALBEDO = mix(vec3(0.16, 0.09, 0.06), vec3(0.30, 0.17, 0.10), n);
	ROUGHNESS = 0.98;
}
