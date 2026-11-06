shader_type spatial;
// A high-pressure water stream: a coherent glassy core with streaks running along it,
// fraying into foam and droplets toward its end. UV.x = around the tube, UV.y = metres along it.
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform float jet_time = 0.0;
uniform float flow_speed = 26.0;
uniform float jet_length = 100.0;
uniform vec4 water_color : source_color = vec4(0.80, 0.90, 0.97, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.98, 1.0, 1.0);
varying float along;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15; }

void vertex() {
	along = UV2.x;   // 0 at the mouth, 1 where it lands
}

void fragment() {
	float s = along;
	vec2 q = vec2(UV.x * 7.0, UV.y * 0.22 - jet_time * flow_speed * 0.22);
	float streak = fbm(vec2(UV.x * 18.0, UV.y * 0.08 - jet_time * flow_speed * 0.08));
	float churn = fbm(q * vec2(1.0, 1.6));
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	// near the mouth: dense, glassy; further on: foam, holes, breaking up
	float foam = smoothstep(0.15, 0.85, s) * smoothstep(0.35, 0.75, churn);
	float holes = smoothstep(0.45 + 0.5 * (1.0 - s), 0.9, churn + s * 0.35);
	vec3 col = mix(water_color.rgb, foam_color.rgb, clamp(foam + fres * 0.5 + streak * 0.25, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(0.08, 0.6, foam);
	SPECULAR = 0.6;
	EMISSION = foam_color.rgb * 0.18 * (foam + fres);
	float a = mix(0.82, 0.5, s) * (0.65 + 0.35 * streak) + fres * 0.25;
	a *= 1.0 - holes;
	a *= smoothstep(0.0, 0.02, s) * (1.0 - smoothstep(0.9, 1.0, s));
	ALPHA = clamp(a, 0.0, 1.0);
}
