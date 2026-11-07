shader_type spatial;
render_mode cull_disabled;
uniform float progress : hint_range(0.0,1.0) = 1.0;
uniform bool cast_gold = false;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	if(progress<=0.0 || UV.y>progress) discard;
	float grain=sin(local_position.y*130.0+sin(local_position.x*51.0)*2.5)*0.012;
	ALBEDO = cast_gold ? vec3(0.83,0.64,0.30) : vec3(0.64,0.39,0.16)+vec3(grain);
	METALLIC=cast_gold ? 0.95 : 0.0;
	ROUGHNESS=cast_gold ? 0.28 : 0.78;
}
