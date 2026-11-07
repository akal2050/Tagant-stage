shader_type spatial;
render_mode cull_disabled;
uniform float progress : hint_range(0.0,1.0) = 1.0;
uniform float left_edge = -5.0;
uniform float right_edge = 5.0;
uniform vec4 gold_color : source_color = vec4(0.83,0.64,0.32,1.0);
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	float p = (right_edge-local_position.x)/max(right_edge-left_edge,0.001);
	if(progress<=0.0 || p>progress) discard;
	ALBEDO=gold_color.rgb;
	METALLIC=0.92;
	ROUGHNESS=0.28;
}
