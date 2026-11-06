shader_type spatial;
render_mode cull_back;
varying vec3 local_p;
varying float dust_up;
varying vec4 wear;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,45.164)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){local_p=VERTEX;dust_up=max((MODEL_MATRIX*vec4(NORMAL,0.0)).y,0.0);wear=INSTANCE_CUSTOM;}
void fragment(){
	float grain=noise(local_p*6.0+wear.r*37.0);
	float rust=smoothstep(0.25,0.8,noise(local_p*1.8+wear.r*19.0)+wear.g*0.32);
	vec3 oxide=mix(vec3(0.055,0.034,0.023),vec3(0.30,0.12,0.045),grain);
	vec3 paint=COLOR.rgb*0.65;
	vec3 surface=mix(paint,oxide,rust);
	float sand=clamp(wear.b*(0.3+dust_up*0.7)+grain*0.1,0.0,0.8);
	ALBEDO=mix(surface,vec3(0.39,0.30,0.19),sand);
	ROUGHNESS=0.88+grain*0.1;
	METALLIC=(1.0-rust)*0.25;
}
