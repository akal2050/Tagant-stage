// DOVE MAN — mountain rock with snow
// The mesh (models/dove_man_mountain.glb) already carries the eroded gullies as geometry.
// object_center / object_scale map world space back to the sculpture's own unit space
// (head ~ +1.0, feet ~ -1.0), the same space the Blender material used.
shader_type spatial;
#include "res://dove_man/shaders/noise.gdshaderinc"

uniform vec3 object_center = vec3(0.0, 90.0, 0.0);
uniform float object_scale = 90.0;
uniform float snow_line = 0.62;
uniform float snow_amount : hint_range(0.0, 1.5) = 1.0;

varying vec3 obj;
varying vec3 world_n;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj = (w - object_center) / object_scale;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// erosion gullies: noise stretched along the vertical axis
	float gully = dm_fbm(vec3(obj.x * 12.0, obj.y * 1.6, obj.z * 12.0));
	vec3 basalt = vec3(0.045, 0.038, 0.034);
	vec3 brown = vec3(0.17, 0.105, 0.062);
	vec3 rock = mix(basalt, brown, smoothstep(0.35, 0.65, gully));

	// strata: distorted horizontal bands
	float warp = dm_fbm(obj * 3.0) * 14.0;
	float band = 0.5 + 0.5 * sin(obj.y * 2.2 * 6.2831 + warp);
	rock = mix(rock, vec3(0.24, 0.17, 0.11), smoothstep(0.8, 0.97, band));

	// fine pale grains
	float fine = dm_fbm(obj * 18.0);
	rock = mix(rock, vec3(0.26, 0.2, 0.15), smoothstep(0.72, 0.92, fine));

	// snow: head cap + up-facing ledges on the shoulders
	float h = obj.y + (dm_fbm(obj * 7.0) - 0.5) * 0.12;
	float up = world_n.y;
	float cap = smoothstep(snow_line, snow_line + 0.1, h) * smoothstep(-0.35, 0.2, up);
	float ledge = smoothstep(0.38, 0.5, h) * smoothstep(0.7, 0.9, up);
	float snow = clamp(cap + ledge, 0.0, 1.0) * smoothstep(0.25, 0.45, fine) * snow_amount;

	ALBEDO = mix(rock, vec3(0.88, 0.9, 0.95), snow);
	ROUGHNESS = mix(0.96, 0.55, snow);
	SPECULAR = 0.2;
}
