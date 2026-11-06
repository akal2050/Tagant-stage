shader_type spatial;
render_mode cull_back;
uniform sampler2D pose_positions : filter_nearest, repeat_disable;
uniform sampler2D pose_normals : filter_nearest, repeat_disable;
uniform float clock = 0.0;
uniform float last_tick = 0.0;
uniform float stride = 3.0;
varying vec3 tint;
void vertex() {
	float elapsed = max(0.0, clock-last_tick);
	float phase = fract(INSTANCE_CUSTOM.r + elapsed*INSTANCE_CUSTOM.b);
	float sample_frame = phase*32.0;
	float first = floor(sample_frame);
	float next = mod(first+1.0,32.0);
	vec2 a = vec2(UV2.x,(first+0.5)/32.0);
	vec2 b = vec2(UV2.x,(next+0.5)/32.0);
	VERTEX = mix(texture(pose_positions,a).xyz,texture(pose_positions,b).xyz,fract(sample_frame));
	NORMAL = normalize(mix(texture(pose_normals,a).xyz,texture(pose_normals,b).xyz,fract(sample_frame)));
	VERTEX.z += elapsed*INSTANCE_CUSTOM.b*stride;
	tint = COLOR.rgb;
}
void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.93;
}
