extends Node3D
## An ordinary animal walking with the crowd: hyena, ibex, camel, mule (bodies from the
## Eye and the Needle beasts, with their wings, organs, cloth and props hidden) and doves.
## It keeps its own authored clips: idle, walk (sped up for running), and for the dove
## standing / flapping / landing. One skin for everyone: the same desert family as the hybrids.

const SWARM_SHADER = preload("res://dove_man/swarm_variant/swarm_skin.gdshader")
static var skin: ShaderMaterial
const KINDS := {
	"hyena": {"file": "family05_HY01_master.glb", "keep": ["HY01_body"], "idle": "HY_IDLE", "walk": "HY_WALK", "stride": 1.15},
	"ibex": {"file": "family07_GT01_master.glb", "keep": ["GT01_body"], "idle": "GT_IDLE", "walk": "GT_WALK", "stride": 1.0},
	"camel": {"file": "family04_CA02_master.glb", "keep": ["CA01_body", "CA01_hooves", "CA01_eye_L", "CA01_eye_R"], "idle": "CA_IDLE", "walk": "CA_PACE", "look": "CA_LOOK", "graze": "CA_GRAZE", "stride": 1.3},
	"mule": {"file": "family03_MG02_master.glb", "keep": ["MG01_mule_body"], "idle": "MG_IDLE", "walk": "MG_WALK", "look": "MG_LOOK", "stride": 1.1},
	"dove": {"file": "dove.glb", "keep": [], "idle": "BirdRig|Standing Idle", "walk": "BirdRig|Flapping", "fly": "BirdRig|Flapping", "land": "BirdRig|Landing", "stride": 3.0},
}
var kind := ""
var model: Node3D
var player: AnimationPlayer
var size_m := 1.0
var clip := ""
var D: Dictionary
var meshes: Array = []


func setup(which: String, height: float, seed_value: int, tint: Color) -> void:
	kind = which
	D = KINDS[which]
	size_m = height
	model = (load("res://dove_man/assembly/animals/" + String(D.file)) as PackedScene).instantiate()
	add_child(model)
	var keep: Array = D.keep
	var box := AABB()
	var first := true
	for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not keep.is_empty() and not keep.has(String(m.name)):
			m.visible = false
			continue
		var b: AABB = (model.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
		meshes.append(m)
	var s: float = height / maxf(box.size.y, 0.001)
	model.scale = Vector3.ONE * s
	model.position.y = -box.position.y * s
	if which == "dove":
		model.rotation.y = PI          # this model looks down -Z
	if skin == null:
		skin = ShaderMaterial.new()
		skin.shader = SWARM_SHADER
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for m in meshes:
		m.material_override = skin
		m.set_instance_shader_parameter("body_tint", tint)
		m.set_instance_shader_parameter("body_height", height)
		m.set_instance_shader_parameter("variation", r.randf())
		m.set_instance_shader_parameter("grain_scale", r.randf_range(0.8, 1.3))
		m.set_instance_shader_parameter("grain_strength", r.randf_range(0.02, 0.05))
	var ps := model.find_children("*", "AnimationPlayer", true, false)
	if ps.size() > 0:
		player = ps[0]
		for a in player.get_animation_list():
			var an := player.get_animation(a)
			if a != String(D.get("land", "")):
				an.loop_mode = Animation.LOOP_LINEAR
		play(String(D.idle))
		player.seek(r.randf_range(0.0, 2.0), true)


func play(c: String, speed := 1.0) -> void:
	if player == null or not player.has_animation(c):
		return
	if c != clip:
		player.play(c, 0.35)
		clip = c
	player.speed_scale = speed


# move_speed in m/s; the walk cycle is played at the rate that matches it
func pose(state: String, move_speed: float, sing: float) -> void:
	for m in meshes:
		m.set_instance_shader_parameter("root_y", global_position.y)
	if kind == "dove":
		if state == "home":
			play(String(D.idle), 1.0 + sing * 0.6)
		else:
			play(String(D.fly), 1.4)
		return
	if state == "flee" or state == "return":
		var stride: float = float(D.stride) * size_m
		play(String(D.walk), clampf(move_speed / stride, 0.5, 3.2))
	else:
		play(String(D.idle), 1.0 + sing * 0.5)
