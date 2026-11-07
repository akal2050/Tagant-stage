// Salt crust rings: white crystalline crust, cracked polygons (dry_ground normal at small scale),
// glints, a slightly grey wet edge where salt meets the clay.
shader_type spatial;
render_mode specular_schlick_ggx;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D diff : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying vec2 band;   // UV.x = across the ring 0..1
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; band = UV; }
void fragment(){
	float l = dot(texture(diff, wp.xz * 0.9).rgb, vec3(0.33));
	float edge = 1.0 - smoothstep(0.0, 0.18, min(band.x, 1.0 - band.x));
	vec3 salt = mix(vec3(0.97, 0.96, 0.93), vec3(0.84, 0.82, 0.78), edge * 0.8);
	salt *= 0.86 + 0.22 * l;
	float glint = pow(vnoise(wp.xz * 140.0), 18.0);
	ALBEDO = salt;
	NORMAL_MAP = texture(nor, wp.xz * 0.9).rgb;
	NORMAL_MAP_DEPTH = 1.6;
	ROUGHNESS = 0.42 - glint * 0.35;
	SPECULAR = 0.6 + glint * 0.4;
	EMISSION = vec3(glint) * 0.6;
}
