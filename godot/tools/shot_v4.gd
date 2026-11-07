extends SceneTree
# Doubled stage (S=10): wide view with UI + spectrogram lane while a song plays, then a close orbit view.
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run()
func _snap(n: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/v4_%s.png" % n)
	print("shot ", n)
func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(5.0)
	if true:
		main.toggle_play()
	await _wait(5.0)
	await _snap("ui")
	main.ui.visible = false
	main.cam.set_process(false)
	main.cam.global_position = Vector3(0, 30, 62); main.cam.look_at(Vector3(0, 2, 0))
	await _wait(1.5)
	await _snap("wide")
	main.cam.global_position = Vector3(6, 6, 36); main.cam.look_at(Vector3(0, 3, 10))
	await _wait(1.5)
	await _snap("close")
	quit()
