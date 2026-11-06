shader_type spatial;
uniform float rust_amount=0.6;
uniform float variation=0.0;
varying vec3 p;
float hash(vec3 v){return fract(sin(dot(v,vec3(12.9898,78.233,37.719)))*43758.5453);}
float noise(vec3 v){vec3 i=floor(v),f=fract(v);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){p=VERTEX;}
void fragment(){float n=noise(p*1.8+variation*31.0);float rust=smoothstep(0.8-rust_amount,1.05-rust_amount,n);vec3 oxide=mix(vec3(0.09,0.037,0.014),vec3(0.38,0.16,0.045),noise(p*9.0));ALBEDO=mix(vec3(0.48,0.43,0.33),oxide,rust);ROUGHNESS=mix(0.72,0.98,rust);METALLIC=(1.0-rust)*0.35;}
