extends SceneTree
# v6: the two sections - real ANIMALS and the imaginary BESTIARY - on the same stage.
func _wait(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run()
func _snap(n: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/home/claude/shots/v6_%s.png" % n)
	print("shot ", n)
func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(4.0)
	main.select_animal("b7", true)
	main.toggle_play()
	await _wait(6.0)
	await _snap("animals")
	main.set_section("bestiary")
	await _wait(3.0)
	main.select_animal("x3", true)
	main.toggle_play()
	await _wait(6.0)
	await _snap("bestiary")
	quit()
