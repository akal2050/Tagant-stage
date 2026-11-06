shader_type spatial;
render_mode cull_back;
uniform vec3 water_deep : source_color = vec3(0.012,0.105,0.115);
uniform vec3 water_shallow : source_color = vec3(0.07,0.36,0.35);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float refraction_strength = 0.84;
uniform float refraction_distortion = 0.006;
uniform float water_clock = 0.0;
uniform mat4 mesh_to_titan;
uniform float titan_height = 52.0;
uniform float oil_coverage = 0.08;
uniform float foam_amount = 0.55;
uniform float flow_speed = 0.65;
instance uniform float fade = 1.0;
instance uniform float root_y = 0.0;
instance uniform float body_height = 52.0;
varying vec3 body_p;
varying vec3 body_n;
float hash(vec3 p){p=fract(p*0.3183099+vec3(0.13,0.71,0.29));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float field(vec3 p){return noise(p)*0.58+noise(p*2.07)*0.28+noise(p*4.17)*0.14;}
void vertex(){
	body_p=(mesh_to_titan*vec4(VERTEX,1.0)).xyz;
	body_n=normalize(mat3(mesh_to_titan)*NORMAL);
	// Small surface ripples only: the imported bones and walk remain intact.
	float ripple=sin(body_p.x*2.4+body_p.z*1.7+water_clock*2.0)*sin(body_p.y*1.8-water_clock*1.4);
	VERTEX += NORMAL*ripple*0.004;
}
void fragment(){
	if(hash(vec3(FRAGCOORD.xy,0.0))>fade) discard;
	float time=water_clock*flow_speed;
	vec3 flow=body_p*0.19+vec3(sin(time*0.17)*0.4,-time*0.20,time*0.13);
	float liquid=field(flow);
	float small=field(body_p*1.4+vec3(time*0.3,-time*0.25,0.0));
	float oil=smoothstep(0.60-oil_coverage*0.25,0.70-oil_coverage*0.25,liquid)*oil_coverage;
	float up=smoothstep(0.05,0.72,body_n.y);
	float high=smoothstep(0.20,0.65,body_p.y/titan_height);
	float back=smoothstep(-0.15,0.65,-body_n.z);
	float crest=abs(sin(body_p.z*0.9+body_p.x*0.7-time*1.1+small*4.0));
	float foam=smoothstep(0.88,0.995,crest)*smoothstep(0.46,0.70,small)*(0.015+up*0.35+high*back*1.35)*foam_amount;
	foam*=1.0-oil*0.75;
	float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	vec3 water=mix(water_deep,water_shallow,clamp(liquid*0.7+fresnel*0.65,0.0,1.0));
	vec3 film=0.5+0.5*cos(vec3(0.0,2.1,4.2)+liquid*16.0+fresnel*5.0+time*0.18);
	vec3 ripple_normal=normalize(NORMAL+vec3(sin(body_p.z*2.7+time*2.3),cos(body_p.x*2.1-time*1.7),sin(body_p.y*2.6+time))*0.09*(1.0-foam));
	vec2 refracted_uv=clamp(SCREEN_UV+ripple_normal.xy*refraction_distortion,vec2(0.001),vec2(0.999));
	// Transmitted scene colour is composited as radiance, rather than lit a
	// second time as albedo. Fresnel retains the reflective silhouette.
	vec3 refracted=textureLod(screen_texture,refracted_uv,0.15).rgb*vec3(0.82,0.96,0.96);
	float transmission=refraction_strength*(1.0-fresnel*0.86)*(1.0-oil)*(1.0-clamp(foam,0.0,1.0));
	vec3 petrol=vec3(0.009,0.012,0.013)+film*0.085*fresnel;
	vec3 surface_colour=mix(mix(water,petrol,oil),vec3(0.78,0.88,0.84),clamp(foam,0.0,0.92));
	ALBEDO=surface_colour*(1.0-transmission);
	ROUGHNESS=mix(mix(0.085,0.055,oil),0.65,foam);
	METALLIC=oil*0.35;
	SPECULAR=0.9;
	BACKLIGHT=water_shallow*transmission*0.32;
	EMISSION=refracted*transmission+water_shallow*fresnel*0.025*(1.0-oil);
	vec3 perturbed=normalize(NORMAL+vec3(sin(body_p.z*2.7+time*2.3),cos(body_p.x*2.1-time*1.7),sin(body_p.y*2.6+time))*0.09*(1.0-foam));
	NORMAL=perturbed;
}



