shader_type spatial;
render_mode diffuse_burley;

instance uniform vec4 body_tint : source_color = vec4(0.26, 0.19, 0.12, 1.0);
instance uniform float root_y = 0.0;
instance uniform float body_height = 4.0;
instance uniform float age_dust = 0.25;
instance uniform float variation = 0.0;
instance uniform float dust_bias = 0.0;
instance uniform float grain_scale = 1.0;
instance uniform float grain_strength = 0.03;
varying vec3 world_position;
varying vec3 world_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_position / max(body_height, 0.01);
	float mottling = noise3(p * 9.0 * grain_scale + variation * 13.0);
	float grain = noise3(p * 65.0 * grain_scale + variation * 5.0);
	vec3 stone = body_tint.rgb * mix(0.8, 1.18, mottling);
	float height01 = (world_position.y - root_y) / max(body_height, 0.01);
	float caked = 1.0 - smoothstep(0.03, 0.27 + mottling * 0.08, height01);
	float settled = smoothstep(0.12, 0.85, world_normal.y) * mix(0.12, 0.50, mottling);
	float dust = clamp(caked * 0.58 + settled + age_dust * 0.22 + dust_bias, 0.0, 0.76);
	vec3 sand = mix(vec3(0.34, 0.23, 0.13), vec3(0.49, 0.35, 0.20), mottling);
	ALBEDO = mix(stone, sand, dust) * mix(1.0 - grain_strength, 1.0 + grain_strength, grain);
	ROUGHNESS = mix(0.82, 0.98, dust);
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
