shader_type spatial;
render_mode cull_disabled;
uniform float growth = 0.0;
uniform vec4 base_color : source_color = vec4(0.12,0.32,0.12,1.0);
uniform bool leaf = true;
uniform int finish = 0;
varying float visible_growth;
void vertex() {
 float amount = smoothstep(INSTANCE_CUSTOM.r,INSTANCE_CUSTOM.r+0.18,growth);
 VERTEX *= max(0.0001,amount);
 visible_growth = amount;
}
void fragment() {
 if (visible_growth < 0.001) discard;
 float x = UV.x*2.0-1.0;
 float vein = exp(-abs(x)*50.0)+pow(max(0.0,cos((UV.y-abs(x)*0.28)*85.0)),18.0)*0.18;
 if (finish > 0) {
  ALBEDO = vec3(0.83,0.56,0.19)*(finish == 2 ? 0.76 : 1.0);
  METALLIC = 1.0;
  ROUGHNESS = finish == 2 ? 0.35 : 0.2;
 } else {
  ALBEDO = base_color.rgb*(leaf ? 0.75+UV.y*0.24+vein*0.18 : 1.0);
  ROUGHNESS = leaf ? 0.68 : 0.47;
  BACKLIGHT = leaf ? vec3(0.08,0.14,0.025) : vec3(0.0);
 }
}
