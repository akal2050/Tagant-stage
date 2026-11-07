shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// Rebuild of "SEBOU_Water2": dark olive silt water, glassy surface, ripples stretched along the flow.

#include "res://herding/shaders/noise.gdshaderinc"

global uniform float film_clock;
uniform float flow_speed = 0.35;
uniform float ripple_strength = 0.12;

varying vec3 bo;

void vertex() {
	bo = to_blender((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float ripple(vec3 p) {
	vec3 q = p * vec3(0.12, 0.04, 1.0);
	q.y += film_clock * flow_speed * 0.04;
	return bnoise(q + vec3(0.0, 0.0, film_clock * 0.05), 6.0, 5, 0.5);
}

void fragment() {
	float n = bnoise(bo, 0.02, 2, 0.5);
	ALBEDO = mix(vec3(0.11, 0.13, 0.09), vec3(0.24, 0.21, 0.13), n);
	ROUGHNESS = 0.015;
	SPECULAR = 0.6;
	// bump from the ripple noise
	float e = 0.05;
	float h0 = ripple(bo);
	float hx = ripple(bo + vec3(e, 0.0, 0.0));
	float hy = ripple(bo + vec3(0.0, e, 0.0));
	vec3 g = vec3(h0 - hx, h0 - hy, 0.0) * ripple_strength / e;
	vec3 wn = normalize(vec3(g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
