// DOVE MAN — shared desert skin for every animal and car.
// Built at runtime from each imported StandardMaterial3D (albedo/normal textures are copied over).
// Per-instance: root_y = world height of the feet, body_height = character height in metres.
shader_type spatial;
#include "res://dove_man/shaders/noise.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo_tex = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal_tex = false;
uniform float base_roughness = 0.8;
uniform float base_metallic = 0.0;

uniform float cake_height = 0.18;   // fraction of body height caked with sand
uniform float dust = 1.0;           // dust settled on up-facing surfaces
instance uniform float root_y = 0.0;
instance uniform float body_height = 10.0;
instance uniform float fade = 1.0;      // 1 = solid, 0 = gone (dithered dissolve)

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade < 0.999) {
		float n = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		if (n > fade) discard;
	}
	vec4 base = albedo_color;
	if (has_albedo_tex) base *= texture(albedo_tex, UV);
	vec3 c = base.rgb;
	// sun-bleach: desaturate, warm multiply, slight sand tint
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.7) * 0.95;
	c = mix(c, c * vec3(0.62, 0.42, 0.24), 0.22);
	c = mix(c, vec3(0.45, 0.31, 0.18), 0.18);

	float n = dm_fbm(wpos / max(body_height, 0.5) * 7.0);
	float d = smoothstep(0.25, 0.85, wnorm.y) * smoothstep(0.35, 0.6, n) * 0.75 * dust;
	float h01 = (wpos.y - root_y) / max(body_height, 0.5) + (n - 0.5) * 0.08;
	float cake = (cake_height > 0.0) ? (1.0 - smoothstep(cake_height * 0.35, cake_height, h01)) : 0.0;
	float amt = clamp(d + cake * 0.9, 0.0, 1.0);

	ALBEDO = mix(c, vec3(0.55, 0.36, 0.17), amt);
	if (has_normal_tex) NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = clamp(base_roughness + amt * 0.5, 0.0, 1.0);
	METALLIC = base_metallic * (1.0 - amt);
}
