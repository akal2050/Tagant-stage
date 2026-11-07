// The oil lake of the frogs: blackest black with a thin-film rainbow sheen; ripples follow the frogs' voices.
shader_type spatial;
render_mode specular_schlick_ggx;
uniform float ripple = 0.0;
varying vec3 wp;
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float r = length(wp.xz) + 0.0001;
	float w = sin(r * 7.0 - TIME * 2.6) * (0.08 + ripple) * exp(-r * 0.3);
	vec2 dir = wp.xz / r;
	vec3 n = normalize(vec3(dir.x * w * 0.7, 1.0, dir.y * w * 0.7));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float h = fract(fres * 2.4 + w * 3.0 + r * 0.1);
	vec3 sheen = 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
	ALBEDO = vec3(0.003);
	EMISSION = sheen * fres * (0.18 + ripple * 0.6);
	ROUGHNESS = 0.12;
	SPECULAR = 0.22;
}
