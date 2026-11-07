shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Poppies of the Ait Wadu valley: vertex-coloured petals that sway with the wind (stronger at the top).
global uniform float film_clock;
varying float h;
void vertex() {
	h = clamp(VERTEX.y / 0.55, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = sin(film_clock * 1.7 + wp.x * 0.35 + wp.z * 0.21) * 0.6 + sin(film_clock * 3.1 + wp.z * 0.9) * 0.25;
	VERTEX.x += w * 0.05 * h * h;
	VERTEX.z += w * 0.03 * h * h;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.7;
	BACKLIGHT = COLOR.rgb * 0.6;   // petals glow when the sun is behind them
}
