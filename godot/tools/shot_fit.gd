extends SceneTree
const Stage := preload("res://scripts/stage.gd")
# Fit check: each block option on a cylinder of its block's real radius, seen from the audience side, a bit above.
func _initialize() -> void:
	_run()
func _run() -> void:
	await process_frame
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); root.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.72,0.42,0.28); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.75,0.75,0.8); root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	var A = load("res://scripts/animal.gd")
	A.style = OS.get_environment("ST") if OS.get_environment("ST") != "" else "sky"
	for s in Catalog.SLOTS:
		if typeof(s.slot) != TYPE_INT:
			continue
		var r: float = Stage.cylinder_radius(s.slot)
		var cyl := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.6
		cyl.mesh = cm; cyl.position.y = -0.3; root.add_child(cyl)
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.3, 0.2); cyl.material_override = mat
		for i in s.options.size():
			var info: Dictionary = Catalog.by_id(s.id, i)
			info["fit_r"] = r
			var n = A.new(); root.add_child(n); n.setup(info)
			n.set_yaw_offset(deg_to_rad(info.get("yaw", 0.0)))
			n.position.y = info.get("hover", 0.0)
			var h: float = maxf(info.get("height", 1.2), r)
			cam.position = Vector3(0, r * 1.6 + 0.8, r * 3.4); cam.look_at(Vector3(0, r * 0.45, 0))
			for f in 8: await process_frame
			root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/fit_%s_%d.png" % [s.id, i])
			n.queue_free(); await process_frame
		cyl.queue_free()
	print("fit done")
	quit()
