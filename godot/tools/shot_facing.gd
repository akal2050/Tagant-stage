extends SceneTree
# Facing check: every block option spawned exactly as main._spawn does (yaw offset + outward = +Z here),
# photographed from +Z (where the audience / camera is). A creature looking at us shows its face.
func _initialize() -> void:
	_run()
func _run() -> void:
	await process_frame
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); root.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.45,0.48); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.7,0.7,0.7); root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	var A = load("res://scripts/animal.gd")
	A.style = "natural"
	for s in Catalog.SLOTS:
		for i in s.options.size():
			var info: Dictionary = Catalog.by_id(s.id, i)
			var n = A.new(); root.add_child(n); n.setup(info)
			n.set_yaw_offset(deg_to_rad(info.get("yaw", 0.0)))
			n.rotation.y = 0.0
			var box: AABB = n._model_aabb()
			var h: float = info.get("height", 1.2)
			var r: float = maxf(box.size.x, maxf(box.size.z, h)) * 1.3 + 0.3
			cam.position = Vector3(r * 0.25, h * 0.7 + n.hover, r); cam.look_at(Vector3(0, h * 0.5 + n.hover, 0))
			for f in 8: await process_frame
			root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/face_%s_%d.png" % [s.id, i])
			print("face ", s.id, " ", i, " ", info.get("body", info.get("name")))
			n.queue_free(); await process_frame
	quit()
