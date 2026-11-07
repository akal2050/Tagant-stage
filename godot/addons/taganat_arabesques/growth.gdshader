shader_type spatial;
render_mode cull_disabled;
uniform float growth = 1.0;
varying float birth;
varying vec3 local_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { birth = UV.x; local_pos = VERTEX; }
void fragment() {
 if (birth > growth) { discard; }
 vec2 bark = vec2(UV.y*23.0,UV.x*38.0);
 float coarse = noise(bark);
 float fine = noise(bark*vec2(4.0,2.0));
 float crack = smoothstep(0.75,0.93,noise(bark*vec2(3.0,0.3)+coarse));
 ALBEDO = mix(vec3(0.13,0.080,0.041),vec3(0.23,0.157,0.087),coarse*0.7+fine*0.3)*(1.0-0.35*crack);
 ROUGHNESS = 0.9;
 METALLIC = 0.0;
}
