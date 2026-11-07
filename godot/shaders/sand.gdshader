// Saharan sand plain and dunes: wind ripples, darker troughs, haze-friendly.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tnor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 sand_a : source_color = vec3(0.80, 0.58, 0.36);
uniform vec3 sand_b : source_color = vec3(0.90, 0.71, 0.48);
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment(){
	vec2 w = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * wp.xz;
	float rip = sin(w.x * 7.0 + fbm(wp.xz * 0.6) * 6.0);
	float macro = fbm(wp.xz * 0.012);
	vec3 c = mix(sand_a, sand_b, smoothstep(0.3, 0.75, macro));
	c *= 0.92 + 0.08 * rip;
	c *= mix(0.78, 1.0, smoothstep(0.55, 1.0, normalize(wn).y));    // dune slip faces darker
	float tl = dot(texture(tex, wp.xz * 0.3).rgb, vec3(0.33));
	c *= 0.7 + 0.6 * tl;
	float rock = smoothstep(35.0, 90.0, wp.y) * smoothstep(0.55, 0.85, 1.0 - normalize(wn).y);
	c = mix(c, vec3(0.45, 0.30, 0.22) * (0.8 + 0.4 * fbm(wp.xz * 0.05)), rock);   // bare rock on steep mountain faces
	ALBEDO = c;
	float d = length(wp.xz);
	vec3 n = vec3(0.0, 1.0, 0.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(cos(w.x * 7.0) * 0.12 * (1.0 - smoothstep(20.0, 90.0, d)), 0.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 0.93;
}
