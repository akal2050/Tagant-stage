// Rammed earth (pise): horizontal compacted lifts, each denser at its base, gravel and lime nodules,
// eroded joints; the top carries the seven lime-wash circles of the Gallery 3 cylinders.
shader_type spatial;
render_mode diffuse_burley;
#include "res://shaders/common_noise.gdshaderinc"
uniform sampler2D nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit : source_color, filter_linear_mipmap_anisotropic, repeat_enable;   // red laterite soil with stones
uniform float radius = 1.0;
uniform float height = 1.0;
uniform float seed = 0.0;
varying vec3 lp;
varying float top;
void vertex(){ lp = VERTEX; top = step(0.9, NORMAL.y); }
void fragment(){
	float ang = atan(lp.z, lp.x) * radius;           // unrolled circumference in metres
	float y = lp.y + height * 0.5;
	float lift = 0.13;                                // one rammed lift = 13 cm
	float li = floor(y / lift);
	float lf = fract(y / lift);
	float k = h21(vec2(li, seed));
	vec3 earth = mix(vec3(0.36, 0.20, 0.11), vec3(0.58, 0.36, 0.21), k);
	earth = mix(earth, vec3(0.50, 0.19, 0.09), step(0.7, h21(vec2(li, seed + 9.0))) * 0.7);
	earth = mix(earth, vec3(0.70, 0.55, 0.38), step(0.9, h21(vec2(li, seed + 4.0))) * 0.6);   // red lifts
	earth *= 0.78 + 0.30 * lf;                        // compaction gradient inside a lift
	float joint = smoothstep(0.0, 0.06, lf) * smoothstep(1.0, 0.94, lf);
	earth *= 0.72 + 0.28 * joint;
	vec3 g = texture(grit, vec2(ang, y + li * 0.37) * 0.28).rgb;
	float gl = dot(g, vec3(0.33));
	earth *= 0.55 + 1.6 * gl;                         // real gravel and grain from the photo texture
	earth = mix(earth, g * vec3(1.15, 1.0, 0.9), 0.25);
	earth *= 0.88 + 0.12 * fbm(vec2(ang, y) * 3.0 + seed);
	vec3 n = texture(nor, vec2(ang, y) * 0.55).rgb;
	if (top > 0.5) {
		float r = length(lp.xz) / radius;
		earth = mix(vec3(0.42, 0.26, 0.15), vec3(0.55, 0.36, 0.22), fbm(lp.xz * 3.0 + seed));
		earth *= 0.6 + 1.4 * dot(texture(grit, lp.xz * 0.45).rgb, vec3(0.33));
		float rings = abs(fract(r * 7.35 + 0.5) - 0.5);                         // the seven lime circles
		float lime = (1.0 - smoothstep(0.035, 0.055, rings)) * step(r * 7.35, 7.4) * step(0.5, r * 7.35);
		lime *= 0.75 + 0.25 * vnoise(lp.xz * 40.0);
		earth = mix(earth, vec3(0.95, 0.94, 0.90), lime);
		n = texture(nor, lp.xz * 0.6).rgb;
	}
	ALBEDO = earth;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = 0.97;
}
