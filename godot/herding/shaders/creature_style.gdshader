// One material for every creature, so the whole bestiary reads as one family.
// mode 0 SALT   : crystalline white salt, glints, cool shadows (City of Salt and Blood)
// mode 1 CLAY   : rammed-earth / terracotta clay with grit, like the cylinders they stand on
// mode 2 OIL    : blackest black with a thin-film rainbow sheen (the oil of World 02 / the frogs' lake)
// mode 3 BRONZE : dark patinated bronze, warm highlights (museum casts)
// mode 4 MAJORELLE : matte saturated cobalt-ultramarine paint, chalky, the complement of terracotta
// mode 5 LAPIS  : deep lapis lazuli, indigo stone veined with white calcite and gold pyrite flecks
// mode 6 SKY    : zellige glaze, sky-blue to turquoise, glossy with a fine crackle, sky reflected in it
// mode 7 INDIGO : indigo-dyed cloth/skin, near-black blue with a metallic bronze-violet sheen (Tuareg indigo)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform int mode = 1;
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grit_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 1.6;
varying vec3 wp;
varying vec3 wn;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
vec3 tri(sampler2D t, vec3 p, vec3 n){
	vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
	return texture(t, p.yz * tex_scale).rgb * w.x + texture(t, p.xz * tex_scale).rgb * w.y + texture(t, p.xy * tex_scale).rgb * w.z;
}
void vertex(){
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	vec3 g = tri(grit, wp, wn);
	float gl = dot(g, vec3(0.33));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (mode == 0) {
		float glint = pow(vn(wp.xz * 90.0 + wp.y * 37.0), 16.0);
		ALBEDO = vec3(0.93, 0.93, 0.90) * (0.82 + 0.3 * gl);
		ROUGHNESS = 0.35 - glint * 0.3;
		SPECULAR = 0.7;
		EMISSION = vec3(0.55, 0.6, 0.7) * fres * 0.25 + vec3(glint) * 0.4;
	} else if (mode == 1) {
		float band = floor(wp.y * 7.0);
		vec3 c = mix(vec3(0.46, 0.27, 0.16), vec3(0.62, 0.40, 0.25), h21(vec2(band, 5.0)));
		ALBEDO = mix(c * (0.6 + 1.2 * gl), g, 0.3);
		ROUGHNESS = 0.92;
		EMISSION = vec3(0.9, 0.55, 0.35) * fres * 0.12;
	} else if (mode == 2) {
		float h = fract(fres * 2.6 + wp.y * 0.4 + vn(wp.xz * 3.0) * 0.5);
		vec3 sheen = 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
		ALBEDO = vec3(0.012);
		ROUGHNESS = 0.08;
		SPECULAR = 0.9;
		EMISSION = sheen * fres * 0.55;
	} else if (mode == 4) {
		float chalk = vn(wp.xz * 22.0 + wp.y * 9.0);
		ALBEDO = mix(vec3(0.07, 0.16, 0.62), vec3(0.13, 0.27, 0.78), chalk) * (0.85 + 0.3 * gl);
		ROUGHNESS = 0.88;
		EMISSION = vec3(0.10, 0.20, 0.65) * fres * 0.20;
	} else if (mode == 5) {
		float v = vn(wp.xz * 4.0 + wp.y * 3.0) + 0.5 * vn(wp.xy * 11.0);
		float vein = smoothstep(0.86, 0.95, v);
		float py = pow(vn(wp.xz * 70.0 + wp.y * 53.0), 22.0);
		ALBEDO = mix(vec3(0.05, 0.08, 0.32), vec3(0.10, 0.17, 0.55), gl);
		ALBEDO = mix(ALBEDO, vec3(0.75, 0.78, 0.85), vein * 0.6);
		ALBEDO = mix(ALBEDO, vec3(0.85, 0.65, 0.25), clamp(py * 6.0, 0.0, 1.0));
		METALLIC = clamp(py * 6.0, 0.0, 1.0);
		ROUGHNESS = 0.35;
		SPECULAR = 0.6;
		EMISSION = vec3(0.2, 0.3, 0.8) * fres * 0.15;
	} else if (mode == 6) {
		// crackle: thin dark lines where two cell noises meet
		vec2 q = wp.xz * 6.0 + wp.y * 4.0;
		float c1 = vn(q), c2 = vn(q * 1.9 + 3.1);
		float crack = smoothstep(0.035, 0.0, abs(c1 - c2) - 0.0);
		float t = clamp(wp.y * 0.35 + 0.5 * vn(wp.xz * 1.5), 0.0, 1.0);
		vec3 base = mix(vec3(0.30, 0.62, 0.86), vec3(0.18, 0.62, 0.66), t);
		ALBEDO = mix(base * (0.9 + 0.15 * gl), vec3(0.10, 0.22, 0.30), crack * 0.55);
		ROUGHNESS = 0.12 + crack * 0.5;
		SPECULAR = 0.8;
		EMISSION = vec3(0.55, 0.78, 1.0) * fres * 0.35;
	} else if (mode == 7) {
		float h = fract(fres * 1.4 + vn(wp.xz * 2.0) * 0.4);
		vec3 sheen = mix(vec3(0.45, 0.30, 0.55), vec3(0.65, 0.48, 0.22), h);
		ALBEDO = mix(vec3(0.03, 0.04, 0.12), vec3(0.06, 0.08, 0.22), gl);
		ROUGHNESS = 0.55;
		SPECULAR = 0.7;
		EMISSION = sheen * fres * 0.4;
	} else {
		ALBEDO = mix(vec3(0.20, 0.13, 0.07), vec3(0.32, 0.26, 0.17), gl);
		METALLIC = 0.85;
		ROUGHNESS = 0.38 + 0.25 * gl;
		EMISSION = vec3(0.35, 0.5, 0.42) * fres * 0.08;
	}
}
