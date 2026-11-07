// Grass tufts (MultiMesh): green at the root, dry gold at the tips, swaying in the wind.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec3 root_col : source_color = vec3(0.16, 0.24, 0.07);
uniform vec3 tip_col : source_color = vec3(0.62, 0.60, 0.30);
uniform float wind = 1.0;
varying float hgt;
void vertex(){
	hgt = UV.y;
	vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.7 + wpos.x * 0.21 + wpos.z * 0.17) * 0.5 + sin(TIME * 3.1 + wpos.x * 0.7) * 0.2;
	VERTEX.x += sway * 0.18 * wind * UV.y * UV.y;
	VERTEX.z += sway * 0.09 * wind * UV.y * UV.y;
}
void fragment(){
	vec3 c = mix(root_col, tip_col, hgt * hgt);
	c *= 0.85 + 0.3 * COLOR.r;
	ALBEDO = c;
	ROUGHNESS = 0.8;
}
