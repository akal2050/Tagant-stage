// DOVE MAN — the rock-and-sand camels (eroded sandstone + drifted sand).
// The craggy relief is baked into models/rock_camel.glb.
shader_type spatial;
#include "res://dove_man/shaders/noise.gdshaderinc"

instance uniform float root_y = 0.0;
instance uniform float body_height = 10.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 q = wpos / max(body_height, 0.5);
	vec3 rock = mix(vec3(0.055, 0.042, 0.034), vec3(0.19, 0.12, 0.072), smoothstep(0.3, 0.7, dm_fbm(q * 5.0)));
	float band = 0.5 + 0.5 * sin(q.y * 3.5 * 6.2831 + dm_fbm(q * 2.0) * 14.0);
	rock = mix(rock, vec3(0.3, 0.2, 0.12), smoothstep(0.86, 0.98, band) * 0.35);
	float n = dm_fbm(q * 14.0);
	float top = smoothstep(0.55, 0.85, wnorm.y) * smoothstep(0.3, 0.5, n);
	float h01 = (wpos.y - root_y) / max(body_height, 0.5) + (dm_fbm(q * 10.0) - 0.5) * 0.12;
	float low = 1.0 - smoothstep(0.08, 0.2, h01);
	float sand = clamp(top + low, 0.0, 1.0);
	ALBEDO = mix(rock, vec3(0.5, 0.32, 0.15), sand);
	ROUGHNESS = 0.97;
}
