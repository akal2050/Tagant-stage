extends Node3D
## Compatible clips are copied into a small shared library per species.
## Existing skeletal motions are sampled, never regenerated.

const ROOT := "res://dove_man/horde_variant/"
const SHADER = preload("res://dove_man/horde_variant/desert_hybrid.gdshader")
static var cached_libraries: Dictionary = {}
static var cached_models: Dictionary = {}
static var shared_material: ShaderMaterial
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var species := ""
var meshes: Array[MeshInstance3D] = []
var feet: Array[int] = []
var clips: Dictionary = {}
var strides: Dictionary = {}
var size_m := 4.0
var foot_rest := 0.0
var phase := 0.0
var pose_clock := 0.0
var current_clip := ""
var previous_position: Array[Vector3] = []
var previous_rotation: Array[Quaternion] = []
var blend_left := 0.0
var pending_time := 0.0
var pending_distance := 0.0
var update_interval := 1.0 / 30.0

func find_kind(node: Node, kind: String) -> Node:
	if node.is_class(kind): return node
	for child in node.get_children():
		var found := find_kind(child, kind)
		if found != null: return found
	return null

func profile(which: String) -> Dictionary:
	if which == "myna":
		return {"model": "myna/myna.glb", "native": true,
			"clips": {"walk": "Walk", "run": "Sprint", "idle": "Idle_Subtle", "watch": "Idle_FoldArms", "crouch": "Crouch_Idle", "bow": "Bow", "gesture": "Idle_Talking"}}
	return {"model": "longear/lizzard cube obj.fbx" if which == "longear" else "hyena/haynea--camel--.glb.fbx", "native": false,
		"clips": {"walk": which + "/walking.fbx", "idle": which + "/idle.fbx", "run": "hyena/zombie running.fbx", "watch": "hyena/injured idle.fbx", "gesture": "hyena/zombie scratch idle.fbx"}}

func setup(which: String, height: float, seed_value: int, tint: Color) -> void:
	species = which
	size_m = height
	var data := profile(which)
	if not cached_models.has(which): cached_models[which] = load(ROOT + "assets/" + data.model)
	visual = (cached_models[which] as PackedScene).instantiate()
	add_child(visual)
	skeleton = find_kind(visual, "Skeleton3D") as Skeleton3D
	assert(skeleton != null)
	var imported_player := find_kind(visual, "AnimationPlayer") as AnimationPlayer
	if imported_player != null:
		imported_player.stop()
		imported_player.process_mode = Node.PROCESS_MODE_DISABLED
	player = AnimationPlayer.new()
	visual.add_child(player)
	player.root_node = player.get_path_to(visual)
	player.speed_scale = 0.0
	var cache: Dictionary
	if cached_libraries.has(which):
		cache = cached_libraries[which]
	else:
		cache = build_library(data, imported_player)
		cached_libraries[which] = cache
	player.add_animation_library("hybrid", cache.library)
	clips = cache.clips
	strides = cache.strides.duplicate()
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
		meshes.append(mesh)
	assert(not first and box.size.y > 0.000001)
	var scale_factor := height / box.size.y
	visual.scale *= scale_factor
	visual.position.y = -box.position.y * scale_factor
	for name in strides:
		var travel: Vector3 = strides[name]
		var basis_to_actor := (global_transform.affine_inverse() * skeleton.global_transform).basis
		var measured := (basis_to_actor * travel).length()
		strides[name] = measured if measured > height * 0.12 else height * (1.25 if name == "run" else 0.72)
	for index in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(index).to_lower()
		if name.ends_with("foot") or name.ends_with("toebase") or name.begins_with("foot_"):
			feet.append(index)
	assert(feet.size() >= 2)
	player.play("hybrid/walk")
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	foot_rest = minimum_foot_y()
	phase = fposmod(float(seed_value) * 0.137, 1.0)
	pose_clock = float(seed_value % 19) * 0.3
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = SHADER
	for mesh in meshes:
		mesh.material_override = shared_material
		mesh.set_instance_shader_parameter("body_tint", tint)
		mesh.set_instance_shader_parameter("body_height", height)
		mesh.set_instance_shader_parameter("variation", fposmod(float(seed_value) * 0.317, 1.0))
	update_pose(0.1, 0.0, "idle", 0.0, true)
	calibrate_grounding()

func calibrate_grounding() -> void:
	# Imported bind-pose bounds can sit above/below the actual deformed soles.
	# Calibrate once against rendered skin geometry; subsequent updates use bones.
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await get_tree().process_frame
	skeleton.force_update_all_bone_transforms()
	var lowest := INF
	var to_actor := global_transform.affine_inverse()
	for mesh in meshes:
		var baked := mesh.bake_mesh_from_current_skeleton_pose()
		if baked == null: continue
		var box: AABB = (to_actor * mesh.global_transform) * baked.get_aabb()
		lowest = minf(lowest, box.position.y)
	if is_finite(lowest):
		visual.position.y -= lowest
		foot_rest = minimum_foot_y()

func build_library(data: Dictionary, native_player: AnimationPlayer) -> Dictionary:
	var library := AnimationLibrary.new()
	var names := {}
	var travel := {}
	for name: String in data.clips:
		var source: Node = null
		var source_player: AnimationPlayer = native_player
		var source_name: String = data.clips[name]
		if not data.native:
			source = (load(ROOT + "assets/" + source_name) as PackedScene).instantiate()
			source_player = find_kind(source, "AnimationPlayer") as AnimationPlayer
			assert(source_player != null)
			for candidate in source_player.get_animation_list():
				if candidate != "RESET":
					source_name = candidate
					break
		assert(source_player.has_animation(source_name), "Missing clip: " + source_name)
		var animation := source_player.get_animation(source_name).duplicate(true) as Animation
		var root_travel := Vector3.ZERO
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			assert(path.get_subname_count() == 1, "Non-bone track: " + str(path))
			var bone := str(path.get_subname(0))
			assert(skeleton.find_bone(bone) >= 0, species + " incompatible bone: " + bone)
			animation.track_set_path(track, NodePath(str(visual.get_path_to(skeleton)) + ":" + bone))
			if not data.native and bone.to_lower().ends_with("hips") and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var initial: Vector3 = animation.track_get_key_value(track, 0)
				root_travel = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1) - initial
				root_travel.y = 0.0
				for key in animation.track_get_key_count(track):
					var value: Vector3 = animation.track_get_key_value(track, key)
					value.x = initial.x
					value.z = initial.z
					animation.track_set_key_value(track, key, value)
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(name, animation)
		names[name] = source_name
		travel[name] = root_travel
		if source != null: source.free()
	return {"library": library, "clips": names, "strides": travel}

func minimum_foot_y() -> float:
	var lowest := INF
	var to_local_space := global_transform.affine_inverse() * skeleton.global_transform
	for index in feet:
		lowest = minf(lowest, (to_local_space * skeleton.get_bone_global_pose(index).origin).y)
	return lowest

func update_pose(delta: float, distance_m: float, requested: String, weather: float, immediate := false, fallen := false) -> void:
	pending_time += delta
	pending_distance += distance_m
	if not immediate and pending_time < update_interval: return
	var dt := pending_time
	var travelled := pending_distance
	pending_time = 0.0
	pending_distance = 0.0
	pose_clock += dt
	var selected := requested if clips.has(requested) else "idle"
	if fallen: selected = "idle"
	if selected != current_clip:
		previous_position.clear()
		previous_rotation.clear()
		for index in skeleton.get_bone_count():
			previous_position.append(skeleton.get_bone_pose_position(index))
			previous_rotation.append(skeleton.get_bone_pose_rotation(index))
		blend_left = 0.32
		current_clip = selected
		player.play("hybrid/" + selected)
		pose_clock = 0.0
	if selected == "walk" or selected == "run":
		phase = fposmod(phase + maxf(travelled, 0.0) / float(strides[selected]), 1.0)
	var length := player.get_animation("hybrid/" + selected).length
	var sample_time := phase * length if selected == "walk" or selected == "run" else fposmod(pose_clock, length)
	player.seek(sample_time, true)
	if blend_left > 0.0:
		blend_left = maxf(0.0, blend_left - dt)
		var weight := smoothstep(0.0, 1.0, 1.0 - blend_left / 0.32)
		for index in skeleton.get_bone_count():
			skeleton.set_bone_pose_position(index, previous_position[index].lerp(skeleton.get_bone_pose_position(index), weight))
			skeleton.set_bone_pose_rotation(index, previous_rotation[index].slerp(skeleton.get_bone_pose_rotation(index), weight))
	skeleton.force_update_all_bone_transforms()
	if not fallen:
		visual.position.y += foot_rest - minimum_foot_y()
	for mesh in meshes:
		mesh.set_instance_shader_parameter("root_y", global_position.y)
		mesh.set_instance_shader_parameter("age_dust", clampf(0.2 + weather * 0.8, 0.0, 1.0))

