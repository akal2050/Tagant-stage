extends Node3D
## Presentation only. The existing world owns movement, paths, impacts and burial.

const ASSETS := "res://dove_man/pilgrim_variant/assets/"
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var foot_bones: Array[int] = []
var foot_rest := 0.0
var idle_time := 0.0
var current_clip := ""
var walk_length := 1.0
var walk_stride := 1.0
var walk_phase := 0.0

func find_kind(node: Node, kind: String) -> Node:
	if node.is_class(kind): return node
	for child in node.get_children():
		var found := find_kind(child, kind)
		if found != null: return found
	return null

func setup(height: float, phase: float) -> void:
	visual = (load(ASSETS + "lizzard cube obj.fbx") as PackedScene).instantiate()
	add_child(visual)
	skeleton = find_kind(visual, "Skeleton3D") as Skeleton3D
	assert(skeleton != null, "Pilgrim skeleton is missing")
	player = AnimationPlayer.new()
	visual.add_child(player)
	player.root_node = player.get_path_to(visual)
	player.speed_scale = 0.0
	var library := AnimationLibrary.new()
	var root_travel := Vector3.ZERO
	for clip: String in ["walking", "idle"]:
		var source := (load(ASSETS + clip + ".fbx") as PackedScene).instantiate()
		var source_player := find_kind(source, "AnimationPlayer") as AnimationPlayer
		assert(source_player != null)
		var names := source_player.get_animation_list()
		var source_name := ""
		for name in names:
			if name != "RESET":
				source_name = name
				break
		assert(not source_name.is_empty())
		var animation := source_player.get_animation(source_name).duplicate(true) as Animation
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			assert(path.get_subname_count() == 1, "Unexpected non-bone animation track")
			var bone := str(path.get_subname(0))
			assert(skeleton.find_bone(bone) >= 0, "Unmatched animation bone: " + bone)
			animation.track_set_path(track, NodePath(str(visual.get_path_to(skeleton)) + ":" + bone))
			# World movement supplies horizontal travel. Retain vertical gait motion.
			if bone.to_lower().ends_with("hips") and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var initial: Vector3 = animation.track_get_key_value(track, 0)
				if clip == "walking":
					root_travel = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1) - initial
					root_travel.y = 0.0
				for key in animation.track_get_key_count(track):
					var value: Vector3 = animation.track_get_key_value(track, key)
					value.x = initial.x
					value.z = initial.z
					animation.track_set_key_value(track, key, value)
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip, animation)
		source.free()
	player.add_animation_library("pilgrim", library)
	walk_length = player.get_animation("pilgrim/walking").length
	var bounds := AABB()
	var first := true
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.30, 0.21, 0.14)
	clay.roughness = 0.88
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.material_override = clay
	assert(not first and bounds.size.y > 0.000001)
	var factor := height / bounds.size.y
	visual.scale *= factor
	visual.position.y = -bounds.position.y * factor
	var skeleton_to_actor := global_transform.affine_inverse() * skeleton.global_transform
	walk_stride = (skeleton_to_actor.basis * root_travel).length()
	assert(walk_stride > 0.001, "Walk clip must contain measurable root travel")
	walk_phase = fposmod(phase * 0.5, 1.0)
	for index in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(index).to_lower()
		if name.ends_with("foot") or name.ends_with("toebase"):
			foot_bones.append(index)
	assert(not foot_bones.is_empty())
	player.play("pilgrim/walking")
	player.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	foot_rest = minimum_foot_y()
	idle_time = phase
	update_pose(0.0, 0.0, 0.0, false)

func minimum_foot_y() -> float:
	var result := INF
	for index in foot_bones:
		var bone_pos := skeleton.get_bone_global_pose(index).origin
		var local_pos := global_transform.affine_inverse() * skeleton.global_transform * bone_pos
		result = minf(result, local_pos.y)
	return result

func update_pose(delta: float, distance_m: float, speed: float, fallen: bool) -> void:
	idle_time += delta
	var clip := "pilgrim/walking" if speed > 0.015 and not fallen else "pilgrim/idle"
	if clip != current_clip:
		player.play(clip)
		current_clip = clip
	if not fallen:
		walk_phase = fposmod(walk_phase + maxf(distance_m, 0.0) / walk_stride, 1.0)
	var time := walk_phase * walk_length if clip.ends_with("walking") else fposmod(idle_time, player.get_animation(clip).length)
	player.seek(time, true)
	skeleton.force_update_all_bone_transforms()
	if not fallen:
		visual.position.y += foot_rest - minimum_foot_y()
