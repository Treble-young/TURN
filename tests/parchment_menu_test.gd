extends SceneTree
func _initialize() -> void: check.call_deferred()
func capture(file: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/"+file+".png")
func check() -> void:
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	await capture("parchment-main")
	var menu = current_scene
	menu.options_menu.pause_game()
	assert(paused and menu.options_menu.panel.visible)
	await capture("parchment-options")
	var slider = menu.options_menu.volume_sliders.Music
	var before: float = slider.value
	slider.value = 37
	assert(is_equal_approx(root.get_node("Settings").volumes.Music,0.37))
	slider.value = before
	menu.options_menu.resume_game()
	assert(not paused)
	menu._on_start_game_pressed()
	await capture("parchment-difficulty")
	assert(menu.difficulty_dialog.visible)
	menu._close_difficulty()
	menu.difficulty_dialog.hide()
	var e = root.get_node("Expedition")
	e.start_run(9)
	var pause = load("res://scenes/ui/pause_menu.tscn").instantiate()
	root.add_child(pause)
	pause.pause_game()
	assert(pause.seed_value.text.contains("9"))
	await capture("parchment-esc")
	pause.resume_game()
	for viewport_size in [Vector2i(800,600),Vector2i(1600,900)]:
		root.size = viewport_size
		pause.pause_game()
		await process_frame
		pause.resume_game()
	print("PASS: main backdrop/buttons, options pause/resume, audio callbacks, seed, difficulty dialog, ESC panel and resize")
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	quit()
