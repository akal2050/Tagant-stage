extends SceneTree
func _initialize() -> void:
	_run()
func _run() -> void:
	await process_frame
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 10, 0); root.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.45,0.48); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.8,0.8,0.8); root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	var A = load("res://scripts/animal.gd")
	for key in OS.get_environment("YB").split(","):
		for yaw in [0, 90, 180, 270]:
			var info: Dictionary = Catalog.BODIES[key].duplicate()
			info["id"] = key; info["name"] = key; info["songs"] = []; info["hover"] = 0.0
			var n = A.new(); root.add_child(n); n.setup(info); n.rotate_y(deg_to_rad(yaw))
			var h: float = info.height
			cam.position = Vector3(0, h * 0.9 + info.get("span", 0.0) * 0.3, maxf(h, info.get("span", 0.0)) * 2.2 + 0.5); cam.look_at(Vector3(0, h * 0.55, 0))
			for f in 6: await process_frame
			root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/y_%s_%d.png" % [key, yaw])
			n.queue_free(); await process_frame
	quit()
