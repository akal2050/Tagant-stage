extends Node3D
## One singer on the stage: a TAGANT body, its tap target, its voice (3D call player)
## and its motion (rigged clips when the model has them, procedural breathing/singing otherwise).

## One style for the whole bestiary (Catalog bodies keep their own look only in "natural").
const STYLES := ["sky", "majorelle", "lapis", "indigo", "salt", "clay", "oil", "bronze", "natural"]
const SHADER_MODES := ["salt", "clay", "oil", "bronze", "majorelle", "lapis", "sky", "indigo"]
static var style := "sky"
static var _style_mats := {}

var info: Dictionary
var model: Node3D
var body: Node3D            # holder that turns the model so its real front faces forward (+Z)
var _lean := 0.0
var _kind := "keep"
var anim: AnimationPlayer
var height := 1.0
var hover := 0.0
var base_y := 0.0          # top of the rammed-earth cylinder it stands on
var yaw_offset := 0.0      # turns the model so its real front is the one that faces the camera
var face_target := Vector3.INF   # the creatures turn (slowly, only around Y) to face the camera
var sing_level := 0.0      # 0..1, set every frame by main from the song's energy
var call_player: AudioStreamPlayer3D
var _call_end := -1.0
var _t := 0.0
var _react := 0.0          # procedural reaction pulse
var _react_kind := ""
var _state_anim := ""
var _mats := {}


func setup(i: Dictionary) -> void:
	info = i
	name = i.id
	height = i.get("height", 1.0)
	hover = i.get("hover", 0.0)
	_t = randf() * 10.0
	if i.model != "":
		var ps: PackedScene = load(i.model)
		model = ps.instantiate()
		body = Node3D.new()
		add_child(body)
		body.add_child(model)
		_kind = i.get("material", "keep")
		apply_style()
		anim = _find_anim(model)
		set_state("idle")
		if anim:
			anim.advance(0.0)            # measure the body in its idle pose, not its rest pose
		_normalize()
		_add_collider()
	call_player = AudioStreamPlayer3D.new()
	call_player.bus = "Calls"
	call_player.unit_size = 10.0
	call_player.max_db = 3.0
	add_child(call_player)
	set_state("idle")


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func _skeletons(n: Node, out: Array) -> void:
	if n is Skeleton3D:
		out.append(n)
	for c in n.get_children():
		_skeletons(c, out)


## Skinned vertices posed by the skeleton (every 9th vertex is enough for a bounding box).
func _skinned_points(mi: MeshInstance3D, inv: Transform3D, pts: Array) -> void:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var skin := mi.skin
	if skel == null or skin == null or mi.mesh == null:
		return
	var bind_xf: Array = []
	for bi in skin.get_bind_count():
		var bone := skin.get_bind_bone(bi)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(bi))
		bind_xf.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(bi) if bone >= 0 else Transform3D())
	var to_here: Transform3D = inv * skel.global_transform
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if arr[Mesh.ARRAY_BONES] == null or vv.is_empty():
			continue
		var bb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ww: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var nb := bb.size() / vv.size()
		var i := 0
		while i < vv.size():
			var p := Vector3.ZERO
			for k in nb:
				var w := ww[i * nb + k]
				if w > 0.0:
					var b := bb[i * nb + k]
					if b < bind_xf.size():
						p += (bind_xf[b] * vv[i]) * w
			pts.append(to_here * p)
			i += 9


## Bounds in this node's space. Skinned meshes report their bind-space box (often 100x off
## with Mixamo/armature scales), so for them the skeleton's bones give the size instead.
func _model_aabb() -> AABB:
	var pts: Array = []
	var inv := global_transform.affine_inverse()
	var ms: Array = []
	_meshes(model, ms)
	var skinned := false
	for mi: MeshInstance3D in ms:
		if mi.mesh == null:
			continue
		if mi.skin != null or (mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D):
			skinned = true
			mi.extra_cull_margin = 50.0     # bind-space box is wrong for skinned bodies: never cull them
			continue
		var a: AABB = mi.get_aabb()
		var xf: Transform3D = inv * mi.global_transform
		for k in 8:
			pts.append(xf * a.get_endpoint(k))
	if skinned:
		for mi: MeshInstance3D in ms:
			_skinned_points(mi, inv, pts)
	if pts.is_empty():
		return AABB()
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box


func _normalize() -> void:
	var box := _model_aabb()
	if box.size.y <= 0.0001:
		return
	var s := height / box.size.y
	if info.has("span"):        # long or spread bodies (serpents, flocks): fit the largest dimension
		s = float(info.span) / maxf(box.size.x, maxf(box.size.y, box.size.z))
	# fit the footprint on the top of its rammed-earth block: the widest reach (any yaw) stays inside it
	if info.get("fit_r", 0.0) > 0.0:
		var reach := 0.5 * Vector2(box.size.x, box.size.z).length() * s
		var lim: float = float(info.fit_r) * 0.84
		if hover <= 0.0 and not info.has("span"):
			s *= minf(lim / reach, 1.4)          # grounded bodies are sized to their block (never more than 1.4x)
			s = minf(s, float(info.fit_r) * 1.6 / box.size.y)   # and never towering over it
		elif reach > lim:
			s *= lim / reach                     # floating / flock bodies only shrink to stay over it
	model.scale = Vector3.ONE * s
	box = _model_aabb()
	var c := box.get_center()
	model.position -= Vector3(c.x, box.position.y, c.z)
	if OS.is_debug_build():
		pass # print("[animal] %s scale %.4f box %s" % [info.id, s, str(_model_aabb())])


static func style_material(st: String) -> Material:
	if not _style_mats.has(st):
		var m := ShaderMaterial.new()
		m.shader = load("res://herding/shaders/creature_style.gdshader")
		m.set_shader_parameter("mode", SHADER_MODES.find(st))
		m.set_shader_parameter("grit", load("res://textures/earth/red_laterite_soil_stones_diff_2k.jpg"))
		_style_mats[st] = m
	return _style_mats[st]


func set_yaw_offset(r: float) -> void:
	yaw_offset = r
	if body:
		body.rotation.y = r


## Applies the shared bestiary style (or, in "natural", each body's own look).
func apply_style() -> void:
	if model == null:
		return
	if style == "natural":
		var ms: Array = []
		_meshes(model, ms)
		for mi: MeshInstance3D in ms:
			mi.material_override = null
		_apply_material(_kind)
		return
	var sm := style_material(style)
	var ms2: Array = []
	_meshes(model, ms2)
	for mi: MeshInstance3D in ms2:
		mi.material_override = sm


func _apply_material(kind: String) -> void:
	var m: Material = null
	match kind:
		"salt":
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.95, 0.95, 0.93)
			sm.roughness = 0.22
			sm.metallic_specular = 0.9
			sm.rim_enabled = true
			sm.rim = 0.8
			sm.clearcoat_enabled = true
			m = sm
		"earth":
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(0.42, 0.33, 0.25)
			em.roughness = 0.9
			m = em
		"hyena":
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color(0.5, 0.41, 0.3)
			hm.roughness = 0.85
			m = hm
		"hybrid":
			var ym := StandardMaterial3D.new()
			ym.albedo_color = Color(0.46, 0.34, 0.25)
			ym.roughness = 0.75
			m = ym
	if m == null:
		return
	var ms: Array = []
	_meshes(model, ms)
	for mi: MeshInstance3D in ms:
		mi.material_override = m


func _add_collider() -> void:
	var box := _model_aabb()
	var b := StaticBody3D.new()
	b.set_meta("animal_id", info.id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(max(box.size.x, 1.2), max(box.size.y, 1.2), max(box.size.z, 1.2)) * 1.25
	cs.shape = bs
	b.add_child(cs)
	b.position = box.get_center()
	add_child(b)


## Plays a named clip from the catalog's "anims" table if the body has it.
func _play_clip(key: String, loop: bool) -> bool:
	if anim == null:
		return false
	var table: Dictionary = info.get("anims", {})
	if not table.has(key):
		return false
	var clip: String = table[key]
	if not anim.has_animation(clip):
		return false
	var a := anim.get_animation(clip)
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(clip, 0.35)
	_state_anim = clip
	return true


func set_state(s: String) -> void:
	# idle / sing / listen
	if not _play_clip(s, true):
		_play_clip("idle", true)


func react(kind: String) -> void:
	# good / great / confused
	_react = 1.0
	_react_kind = kind
	if _play_clip(kind, false):
		await anim.animation_finished
		set_state("idle")


func call_phrase(stream: AudioStream, a: float, b: float) -> void:
	call_player.stream = stream
	call_player.play(a)
	_call_end = b


func calling() -> bool:
	return call_player.playing and _call_end > 0.0


func call_position() -> float:
	return call_player.get_playback_position()


func _process(delta: float) -> void:
	_t += delta
	if call_player.playing and _call_end > 0.0 and call_player.get_playback_position() >= _call_end:
		call_player.stop()
		_call_end = -1.0
	_react = max(0.0, _react - delta * 1.4)
	if model == null:
		return
	var lvl := sing_level
	var breathe := 1.0 + 0.012 * sin(_t * 1.7) + 0.05 * lvl
	var y := hover + (sin(_t * 0.9) * 0.18 if hover > 0.0 else 0.0)
	var jump := 0.0
	var tilt := 0.0
	if _react > 0.0:
		match _react_kind:
			"good", "great":
				jump = sin(_react * PI) * 0.25 * (2.0 if _react_kind == "great" else 1.0)
			"confused":
				tilt = sin(_react * PI * 3.0) * 0.12
	position.y = base_y + y + jump
	# singing in action: the head lifts to call (the whole body leans back on its hind end),
	# the chest pumps with the energy of the voice, a little sway; rigged bodies also speed their clip
	var call_lift := -0.20 * lvl - 0.05 * lvl * sin(_t * 5.3)
	_lean = lerp(_lean, call_lift, 1.0 - exp(-delta * 6.0))
	var sway := sin(_t * 6.0) * 0.04 * lvl
	rotation.x = _lean
	rotation.z = tilt + sway
	position.y += absf(sin(_t * 7.5)) * 0.06 * lvl
	if anim:
		anim.speed_scale = 1.0 + 0.8 * lvl
	if face_target != Vector3.INF:     # every creature turns (only around Y) to look at the karaoke camera
		var d := face_target - global_position
		if Vector2(d.x, d.z).length() > 0.5:
			var want := atan2(d.x, d.z)
			rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-delta * 1.6))
	scale = Vector3(1.0 + 0.03 * lvl, breathe, 1.0 + 0.03 * lvl)
