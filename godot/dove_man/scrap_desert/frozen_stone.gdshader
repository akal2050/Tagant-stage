shader_type spatial;
render_mode cull_back;
uniform sampler2D pose_positions : filter_nearest, repeat_disable;
uniform sampler2D pose_normals : filter_nearest, repeat_disable;
varying vec3 rock_p;
varying vec3 tone;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,45.164)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){
 float frame=floor(INSTANCE_CUSTOM.r*31.0);
 vec2 sample_uv=vec2(UV2.x,(frame+0.5)/32.0);
 VERTEX=texture(pose_positions,sample_uv).xyz;
 NORMAL=normalize(texture(pose_normals,sample_uv).xyz);
 rock_p=VERTEX+vec3(INSTANCE_CUSTOM.g*51.0);
 tone=COLOR.rgb;
}
void fragment(){
 float strata=noise(vec3(rock_p.x*1.7,rock_p.y*9.0,rock_p.z*1.7));
 float grain=noise(rock_p*32.0);
 ALBEDO=tone*mix(0.72,1.18,strata)*mix(0.9,1.07,grain);
 ROUGHNESS=0.98;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.10,0.5+(strata-0.5)*0.08,1.0);
}
