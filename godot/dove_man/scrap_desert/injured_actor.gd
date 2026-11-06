extends "res://dove_man/horde_variant/hybrid_actor.gd"
var personal_tempo:=1.0
var personal_idle_offset:=0.0
func profile(which: String) -> Dictionary:
	var directory: String="myna" if which=="lost_myna" else "hyena"
	var prefix: String="../../scrap_desert/injured_assets/"+directory+"/"
	var model_path: String=prefix+"myna bird.fbx" if which=="lost_myna" else ("longear/lizzard cube obj.fbx" if which=="lost_longear" else "hyena/haynea--camel--.glb.fbx")
	return {"model":model_path,"native":false,"clips":{"walk":prefix+"injured walk.fbx","run":prefix+"injured run.fbx","idle":prefix+"injured hurting idle.fbx","watch":prefix+"injured stumble idle.fbx"}}
func setup(which:String,height:float,seed_value:int,tint:Color)->void:
	personal_tempo=lerpf(0.82,1.16,fposmod(float(seed_value)*0.431,1.0))
	personal_idle_offset=fposmod(float(seed_value)*0.317,1.0)*19.0
	super.setup(which,height,seed_value,tint)
	if which!="lost_myna":
		var species_name: String="longear" if which=="lost_longear" else "hyena"
		for mesh in meshes: mesh.mesh=load("res://dove_man/swarm_variant/meshes/"+species_name+".res")

func update_pose(delta: float, distance_m: float, requested: String, weather: float, immediate := false, fallen := false) -> void:
	pending_time += delta
	pending_distance += distance_m
	if not immediate and pending_time < update_interval: return
	var dt := pending_time
	var travelled := pending_distance
	pending_time = 0.0
	pending_distance = 0.0
	pose_clock += dt * personal_tempo
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
		pose_clock = personal_idle_offset
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


