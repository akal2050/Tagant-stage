shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_tint : source_color = vec4(0.25,0.43,0.23,1.0);
void fragment() {
 float x = UV.x*2.0-1.0;
 float edge = smoothstep(0.70,1.0,abs(x));
 float central = exp(-abs(x)*65.0);
 float ribs = pow(max(0.0,cos((UV.y-abs(x)*0.28)*95.0)),18.0)*(1.0-edge);
 vec3 base = mix(vec3(0.055,0.18,0.12),vec3(0.20,0.35,0.20),UV.y);
 base = mix(base,vec3(0.28,0.40,0.21),edge*0.5);
 ALBEDO = mix(base,vec3(0.41,0.46,0.23),clamp(central*0.65+ribs*0.24,0.0,0.8))*leaf_tint.rgb/vec3(0.25,0.43,0.23);
 ROUGHNESS = 0.62;
 BACKLIGHT = vec3(0.12,0.22,0.045);
}
