extends "res://dove_man/horde_variant/hybrid_actor.gd"

const SWARM_SHADER = preload("res://dove_man/swarm_variant/swarm_skin.gdshader")
static var swarm_material: ShaderMaterial
static var contact_cache: Dictionary = {}
var contact_phase := 0.0

func setup(which: String, height: float, seed_value: int, tint: Color) -> void:
	super.setup(which, height, seed_value, tint)
	if not contact_cache.has(which): contact_cache[which] = measure_contact_phase()
	contact_phase = contact_cache[which]
	if swarm_material == null:
		swarm_material = ShaderMaterial.new()
		swarm_material.shader = SWARM_SHADER
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for mesh in meshes:
		# Crowd-only derivative mesh; keep the original skeleton and skin bindings.
		mesh.mesh = load("res://dove_man/swarm_variant/meshes/" + which + ".res")
		mesh.material_override = swarm_material
		mesh.lod_bias = 0.65
		mesh.set_instance_shader_parameter("dust_bias", random.randf_range(-0.12, 0.12))
		mesh.set_instance_shader_parameter("grain_scale", random.randf_range(0.72, 1.35))
		mesh.set_instance_shader_parameter("grain_strength", random.randf_range(0.018, 0.055))

func measure_contact_phase() -> float:
	var left := -1
	for index in feet:
		var name := skeleton.get_bone_name(index).to_lower()
		if name.contains("leftfoot") or name == "foot_l":
			left = index
			break
	assert(left >= 0)
	player.play("hybrid/walk")
	var length := player.get_animation("hybrid/walk").length
	var max_forward := -INF
	var result := 0.0
	var transform_to_actor := global_transform.affine_inverse() * skeleton.global_transform
	for sample in 48:
		var sample_phase := float(sample) / 48.0
		player.seek(sample_phase * length, true)
		skeleton.force_update_all_bone_transforms()
		var foot := transform_to_actor * skeleton.get_bone_global_pose(left).origin
		if foot.z > max_forward:
			max_forward = foot.z
			result = sample_phase
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	return result
