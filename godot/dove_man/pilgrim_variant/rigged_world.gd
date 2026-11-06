extends "res://dove_man/dove_man_world.gd"
## Additive variant: all original travel, timings and events remain inherited.

const PILGRIM = preload("res://dove_man/pilgrim_variant/rigged_pilgrim.gd")

func create_mannequins() -> void:
	super.create_mannequins()
	for pilgrim in mannequins:
		var sway: Node3D = pilgrim["sway"]
		var original: Node = sway.get_child(0)
		sway.remove_child(original)
		original.queue_free()
		var actor := Node3D.new()
		actor.set_script(PILGRIM)
		sway.add_child(actor)
		actor.setup(float(pilgrim["height"]), float(pilgrim["step"]))
		pilgrim["rigged_actor"] = actor

func update_mannequins(delta: float) -> void:
	var previous_positions: Array[Vector2] = []
	for pilgrim in mannequins:
		previous_positions.append(pilgrim["pos"])
	super.update_mannequins(delta)
	var quake: Dictionary = D["quake"]["mannequin"]
	var config: Dictionary = D["pilgrims"]
	var sink := timeline_value("mannequin_sink")
	for index in mannequins.size():
		var pilgrim: Dictionary = mannequins[index]
		var sway: Node3D = pilgrim["sway"]
		var down := pilgrim_down(pilgrim, config)
		var fall_basis := Basis.IDENTITY
		if pilgrim.get("fallen", false):
			fall_basis = Basis(pilgrim["fall_axis"], deg_to_rad(88.0) * down)
		# Skeletal clips replace the mannequin's rigid-body shamble only.
		# Keep its impact fall, recovery envelope and timeline burial.
		sway.basis = fall_basis
		var hop := quake_at(pilgrim["pos"], 0.0, quake["hop_tau"])
		sway.position.y = float(quake["hop_m"]) * hop.z * (1.0 - down) - 0.15 * float(pilgrim["height"]) * down - sink * float(pilgrim["height"])
		var distance_m := (pilgrim["pos"] as Vector2).distance_to(previous_positions[index])
		pilgrim["rigged_actor"].update_pose(delta, distance_m, float(pilgrim["speed"]), bool(pilgrim.get("fallen", false)))
