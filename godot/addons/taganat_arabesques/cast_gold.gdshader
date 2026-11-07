shader_type spatial;
render_mode cull_disabled;
uniform float growth = 0.0;
uniform bool reveal_stem = true;
uniform bool antique = false;
varying float birth;
varying vec3 object_position;
void vertex() { birth = UV.x; object_position = VERTEX; }
void fragment() {
 if (reveal_stem && birth > growth) discard;
 float grain = sin(object_position.x*135.0)*sin(object_position.y*117.0)*sin(object_position.z*123.0);
 float engraving = pow(abs(sin(UV.y*80.0+sin(UV.x*24.0))),24.0);
 vec3 gold = vec3(0.83,0.56,0.19);
 float patina = antique ? 0.22+0.15*engraving : 0.015;
 ALBEDO = gold*(1.0-patina)+vec3(0.006)*grain;
 METALLIC = 1.0;
 ROUGHNESS = (antique ? 0.38 : 0.25)+0.035*engraving;
}
