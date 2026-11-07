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
	far = 9000.0
	global_position = Vector3(-200, 60, 300)
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
		var a := _t * 0.02 + PI * 0.5
		target = Vector3(cos(a) * 520.0, 110.0, sin(a) * 520.0)
		look = Vector3(150, 10, 0)
	elif focus.has_meta("view") and not (focus.get_meta("view") as Array).is_empty():
		# the valley: each place has its own framing, held with a slow drift
		var v: Array = focus.get_meta("view")
		var c: Vector3 = v[0]
		var lk: Vector3 = v[1]
		var fwd := (lk - c).normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		var span := clampf(c.distance_to(lk) * 0.04, 0.6, 12.0)
		target = c + side * sin(_t * 0.05) * span + Vector3.UP * sin(_t * 0.07) * span * 0.25
		look = lk
		if lane_open:
			look.y -= c.distance_to(lk) * 0.12
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
