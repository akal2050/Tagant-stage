shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float grain = fract(sin(dot(floor(world_pos.xz*130.0),vec2(12.9898,78.233)))*43758.5453);
 float coarse = fract(sin(dot(floor(world_pos.xz*27.0),vec2(42.123,19.231)))*9123.21);
 ALBEDO = mix(vec3(0.065,0.060,0.037),vec3(0.105,0.095,0.055),grain)*mix(0.85,1.05,coarse);
 ROUGHNESS = 1.0;
}
