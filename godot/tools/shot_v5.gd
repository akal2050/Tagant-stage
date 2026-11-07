extends SceneTree
# v5: decluttered UI (mix frames, chevrons, centred spectrogram) + creatures facing the camera,
# then the same view of three blocks in each blue glaze (and clay for comparison).
const Stage := preload("res://scripts/stage.gd")
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run()
func _snap(n: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/v5_%s.png" % n)
	print("shot ", n)
func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(4.0)
	main.select_animal("b3", true)
	main.step_creature(1); main.step_creature(1); main.step_creature(1)   # walker 1, the one that overhung
	await _wait(3.0)
	main.toggle_play()
	await _wait(5.0)
	await _snap("ui")
	main.ui.visible = false
	main.cam.set_process(false)
	var p4: Vector3 = Stage.slot_position(3)
	var out := Vector3(p4.x, 0, p4.z).normalized()
	main.cam.global_position = p4 + out * 11.0 + Vector3(0, 3.5, 0) + Vector3(-out.z, 0, out.x) * 3.0
	main.cam.look_at(p4 + Vector3(0, 1.2, 0))
	for st in ["sky", "majorelle", "lapis", "indigo", "clay"]:
		var guard := 0
		while main.Animal.style != st and guard < 20:
			main.cycle_style(); guard += 1
		await _wait(3.0)
		await _snap("glaze_" + st)
	quit()
