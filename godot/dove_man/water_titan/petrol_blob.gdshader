shader_type spatial;
uniform float water_clock=0.0;
instance uniform float variation=0.0;
instance uniform float fade=1.0;
void vertex(){
	float t=water_clock;
	VERTEX*=1.0+0.12*sin(VERTEX.x*4.0+t*0.7+variation*9.0)*cos(VERTEX.z*3.2-t*0.5);
}
void fragment(){
	if(fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)>fade)discard;
	float f=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),2.5);
	vec3 film=0.5+0.5*cos(vec3(0,2.1,4.2)+f*8.0+variation*10.0+water_clock*0.12);
	ALBEDO=vec3(0.006,0.009,0.01)+film*f*0.12;
	ROUGHNESS=0.055;
	METALLIC=0.52;
	SPECULAR=0.9;
}
