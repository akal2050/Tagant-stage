extends Camera3D
## Slow documentary camera (no player camera, as in the TAGANT worlds):
## a wide orbit around the oil pool when nobody sings, a patient framing of the singer otherwise.
## When the lane is open the singer is held in the upper part of the frame.

var focus: Node3D = null
var focus_height := 1.5
var lane_open := false
var _t := 0.0
var _look := Vector3(0, 1.5, 0)


func _ready() -> void:
	fov = 50.0
	far = 500.0
	global_position = Vector3(0, 11, 34)
	look_at(_look)
	# key light that travels with the camera: the creatures turned toward us show their faces and
	# textures, while the sun behind them keeps a rim of silhouette
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.84)
	key.light_energy = 0.85
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-18, 12, 0)
	key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(key)


func _process(delta: float) -> void:
	_t += delta
	var target: Vector3
	var look: Vector3
	if focus == null:
		var a := _t * 0.025 + PI * 0.5
		target = Vector3(cos(a) * 72.0, 22.0 + sin(_t * 0.05) * 2.0, sin(a) * 72.0)
		look = Vector3(0, 2.0 - (3.0 if lane_open else 0.0), 0)
	else:
		var p := focus.global_position
		var out := Vector3(p.x, 0, p.z)
		if out.length() < 0.5:
			out = Vector3(0, 0, 1)   # singer over the pool: film from the south
		out = out.normalized()
		var side := out.cross(Vector3.UP)
		var sway := sin(_t * 0.07) * 0.28
		var dist := 3.2 + focus_height * 2.3
		var dir := (out * cos(sway) + side * sin(sway)).normalized()
		target = p + dir * dist + Vector3.UP * (0.6 + focus_height * 0.75)
		look = p + Vector3.UP * focus_height * 0.55
		if lane_open:
			look.y -= focus_height * 0.75 + 0.6
	var k := 1.0 - exp(-delta * 0.9)
	global_position = global_position.lerp(target, k)
	_look = _look.lerp(look, k)
	look_at(_look)
