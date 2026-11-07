shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float grain = fract(sin(dot(floor(world_pos.xz*190.0),vec2(12.9898,78.233)))*43758.5453);
 float paving = smoothstep(0.018,0.028,min(fract(world_pos.x*0.5),fract(world_pos.z*0.5)));
 ALBEDO = mix(vec3(0.34,0.32,0.26),vec3(0.52,0.49,0.39),paving)*(0.97+grain*0.05);
 ROUGHNESS = 0.96;
}
