extends MeshInstance3D
## The titan's water cannon: a tube that follows the real ballistic arc of the water,
## from the mouth to where it lands. Its front travels out when the water is switched on,
## and when it is switched off the stream is cut at the mouth and its tail falls away.

var origin := Vector3.ZERO
var velocity := Vector3.ZERO      # launch velocity at the mouth
var flight := 2.0                  # seconds from the mouth to the sand
var on := false
var head := 0.0                    # how far the front of the stream has travelled (s)
var tail := 0.0                    # where the stream now starts (s), after it is cut
var clock := 0.0
var mat: ShaderMaterial
const SEG := 48
const RING := 12
const G := 9.8


func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://dove_man/assembly/shaders/water_jet.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	extra_cull_margin = 200.0


func aim(from: Vector3, launch: Vector3, t_flight: float) -> void:
	origin = from
	velocity = launch
	flight = maxf(t_flight, 0.2)


func set_on(v: bool) -> void:
	if v and not on:
		head = 0.0
		tail = 0.0
	on = v


func point(tt: float) -> Vector3:
	return origin + velocity * tt + Vector3(0, -0.5 * G * tt * tt, 0)


func visible_amount() -> float:
	return head - tail


func _process(delta: float) -> void:
	clock += delta
	if on:
		head = minf(head + delta, flight)
	else:
		tail = minf(tail + delta, head)
		if tail >= head - 0.01:
			mesh = null
			return
	if head <= 0.02:
		mesh = null
		return
	var t0: float = tail
	var t1: float = head
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	var prev := point(t0)
	var rings: Array = []
	for i in SEG + 1:
		var u: float = float(i) / float(SEG)
		var tt: float = lerpf(t0, t1, u)
		var p: Vector3 = point(tt)
		length += p.distance_to(prev)
		prev = p
		var dir: Vector3 = (velocity + Vector3(0, -G * tt, 0)).normalized()
		var side: Vector3 = dir.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(dir).normalized()
		var s: float = tt / flight
		# it leaves the mouth narrow and widens as it falls; a pressure flutter runs down it
		var r: float = lerpf(0.8, 4.8, pow(s, 1.2)) * (1.0 + 0.10 * sin(clock * 21.0 - tt * 30.0) + 0.06 * sin(clock * 9.0 + tt * 11.0))
		var wob: Vector3 = side * sin(clock * 3.1 + tt * 4.0) * 0.35 * s + up * sin(clock * 2.3 + tt * 3.0) * 0.25 * s
		rings.append({"p": p + wob, "side": side, "up": up, "r": r, "len": length, "s": s})
	for i in SEG:
		var A: Dictionary = rings[i]
		var B: Dictionary = rings[i + 1]
		for k in RING:
			var a0: float = TAU * float(k) / RING
			var a1: float = TAU * float(k + 1) / RING
			var quad := [[A, a0, float(k) / RING], [B, a0, float(k) / RING], [B, a1, float(k + 1) / RING], [A, a1, float(k + 1) / RING]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var R: Dictionary = quad[idx][0]
				var ang: float = quad[idx][1]
				var n: Vector3 = (R.side * cos(ang) + R.up * sin(ang))
				st.set_normal(n)
				st.set_uv(Vector2(quad[idx][2], R.len))
				st.set_uv2(Vector2(R.s, 0.0))
				st.add_vertex(R.p + n * float(R.r))
	mesh = st.commit()
	mat.set_shader_parameter("jet_time", clock)
	mat.set_shader_parameter("jet_length", length)


func landing() -> Vector3:
	return point(head)
