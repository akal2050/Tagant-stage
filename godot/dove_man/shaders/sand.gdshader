// DOVE MAN — reactive sand
// Same dune function as world_000, plus:
//  - Godzilla's moving bowl
//  - footprints (ring buffer, fade over ~90 s)
//  - car craters (the wind fills them level again over a few minutes)
// All positions are world XZ. Times are in world seconds (uniform world_time).
shader_type spatial;
render_mode cull_disabled;

uniform float world_time = 0.0;

uniform vec2 beast_pos = vec2(10000.0);
uniform float beast_strength = 0.0;

// footprints: x, z, birth_time, heading (radians, direction the foot points)
uniform vec4 prints[32];
uniform int print_count = 0;
uniform float print_depth = 1.7;
uniform float print_half_width = 4.5;
uniform float print_half_length = 7.0;
uniform float print_memory = 90.0;

// craters: x, z, birth_time, active(0/1)
uniform vec4 craters[12];
uniform int crater_count = 0;
uniform float crater_depth = 1.1;
uniform float crater_radius = 5.5;
uniform float crater_rim = 0.6;
uniform float crater_rim_radius = 7.5;
uniform float crater_fill_delay = 20.0;
uniform float crater_fill_s = 180.0;

// realistic desert sand (sRGB values, converted by source_color)
uniform vec3 sand_light : source_color = vec3(0.86, 0.72, 0.53);
uniform vec3 sand_mid : source_color = vec3(0.78, 0.62, 0.43);
uniform vec3 sand_dark : source_color = vec3(0.62, 0.47, 0.31);
uniform vec3 disturbed : source_color = vec3(0.66, 0.50, 0.34);
uniform vec2 wind_dir = vec2(0.82, 0.57);
uniform float ripple_strength = 0.14;

varying vec3 wpos;
varying float disturb;

float s_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float s_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(s_hash(i), s_hash(i + vec2(1, 0)), f.x), mix(s_hash(i + vec2(0, 1)), s_hash(i + vec2(1, 1)), f.x), f.y);
}
float s_fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += s_noise(p) * a; p *= 2.07; a *= 0.5; }
	return v;
}

float dune_height(vec2 p) {
	float u = p.x * 0.82 + p.y * 0.24;
	float v = -p.x * 0.15 + p.y * 0.95;
	return sin(u * 0.010 + 0.7) * 6.0
		+ sin(u * 0.004 - 0.4) * 8.0
		+ sin(v * 0.006 + 1.2) * 3.0
		+ sin(u * 0.045 + v * 0.012) * 0.45;
}

float beast_deformation(vec2 p) {
	float d = distance(p, beast_pos);
	float bowl = -exp(-pow(d / 11.0, 2.0)) * 4.2;
	float ridge = exp(-pow((d - 12.0) / 3.5, 2.0)) * 1.5;
	return (bowl + ridge) * beast_strength;
}

float footprint(vec2 p, vec4 fp) {
	float age = world_time - fp.z;
	if (age < -0.07 || age > print_memory * 3.0) return 0.0;
	vec2 rel = p - fp.xy;
	vec2 fwd = vec2(sin(fp.w), cos(fp.w));
	vec2 side = vec2(fwd.y, -fwd.x);
	float a = dot(rel, fwd) / print_half_length;
	float b = dot(rel, side) / print_half_width;
	float dd = sqrt(a * a + b * b);
	float dent = -exp(-dd * dd) * print_depth;
	float rim = exp(-pow((dd - 1.45) / 0.3, 2.0)) * 0.55;
	float appear = smoothstep(-0.07, 0.27, age);
	float fade = exp(-max(age, 0.0) / print_memory);
	return (dent + rim) * appear * fade;
}

float crater(vec2 p, vec4 c) {
	if (c.w < 0.5) return 0.0;
	float age = world_time - c.z;
	if (age < 0.0) return 0.0;
	float d = distance(p, c.xy);
	float bowl = -exp(-pow(d / crater_radius, 2.0)) * crater_depth;
	float rim = exp(-pow((d - crater_rim_radius) / (crater_radius * 0.4), 2.0)) * crater_rim;
	float spray = exp(-pow((d - crater_rim_radius * 1.6) / (crater_radius * 0.9), 2.0)) * 0.2 * crater_rim / 0.6;
	float fu = clamp((age - crater_fill_delay) / crater_fill_s, 0.0, 1.0);
	float presence = 1.0 - fu * fu * (3.0 - 2.0 * fu);
	return (bowl + rim + spray) * smoothstep(0.0, 0.13, age) * presence;
}

float complete_height(vec2 p) {
	float h = dune_height(p) + beast_deformation(p);
	for (int i = 0; i < 32; i++) {
		if (i >= print_count) break;
		h += footprint(p, prints[i]);
	}
	for (int i = 0; i < 12; i++) {
		if (i >= crater_count) break;
		h += crater(p, craters[i]);
	}
	return h;
}

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float base = dune_height(p);
	float full = complete_height(p);
	disturb = clamp(abs(full - base) * 0.9, 0.0, 1.0);
	VERTEX.y += full;
	wpos = vec3(p.x, full, p.y);
	float e = 0.6;
	float hx = complete_height(p + vec2(e, 0.0)) - complete_height(p - vec2(e, 0.0));
	float hz = complete_height(p + vec2(0.0, e)) - complete_height(p - vec2(0.0, e));
	NORMAL = normalize(vec3(-hx, 2.0 * e, -hz));
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float dist = length(VERTEX);
	// large tonal drifts across the dunes
	float drift = s_fbm(wpos.xz * 0.012);
	vec3 col = mix(sand_mid, sand_light, smoothstep(0.35, 0.75, drift));
	// lee slopes and troughs a touch darker and redder
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	col = mix(col, sand_dark, clamp(slope * 2.2, 0.0, 0.6));
	// footprints and craters: churned, darker sand
	col = mix(col, disturbed, disturb * 0.75);
	// fine grain, fading with distance
	float grain = s_hash(floor(wpos.xz * 24.0)) - 0.5;
	col *= 1.0 + grain * 0.06 * clamp(1.0 - dist / 60.0, 0.0, 1.0);
	ALBEDO = col;
	// wind ripples: small parallel crests, only near the camera (no shimmering far away)
	vec2 wd = normalize(wind_dir);
	float along = dot(wpos.xz, wd);
	float wobble = s_fbm(wpos.xz * 0.15) * 6.0 + s_fbm(wpos.xz * 0.6) * 2.5;
	float near = clamp(1.0 - dist / 90.0, 0.0, 1.0) * (1.0 - disturb);
	float patch = smoothstep(0.35, 0.7, s_fbm(wpos.xz * 0.04 + 3.1));
	float rip = cos(along * 7.0 + wobble) * ripple_strength * near * patch;
	vec3 tangent_wd = normalize((VIEW_MATRIX * vec4(wd.x, 0.0, wd.y, 0.0)).xyz);
	NORMAL = normalize(NORMAL + tangent_wd * rip * 0.35);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
