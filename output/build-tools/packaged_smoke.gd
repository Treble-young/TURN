extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	assert(FileAccess.file_exists("res://assets/ui/stats/regions.json"))
	assert(not FileAccess.file_exists("res://tests/skills_test.gd"))
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	var main = current_scene
	main.options_menu.pause_game()
	assert(paused)
	main.options_menu.resume_game()
	main._start_expedition(20261128,0)
	await scene_changed
	assert(current_scene.get_script().resource_path == "res://scripts/expedition/route_map.gd")
	await process_frame
	current_scene.selected = Vector2i(0,0)
	current_scene._confirm_node()
	await create_timer(1.8).timeout
	var arena = current_scene
	assert(arena.get_script().resource_path == "res://scripts/expedition/arena.gd")
	assert(arena.battle_map != null)
	var e = root.get_node("Expedition")
	assert(e.active)
	var catalogue = load("res://assets/enemies/catalog.tres")
	assert(catalogue.spider_matriarch.max_health == 1024)
	assert(load("res://assets/backgrounds/background_13.png") != null)
	assert(load("res://assets/ui/relics/blood_rose.png") != null)
	arena._victory()
	await process_frame
	var reward = arena.get_child(arena.get_child_count()-1)
	assert(reward.cards.get_child_count() == 3)
	print("PACKAGED_SMOKE_PASS: main/settings/seeded route/transition/combat/rewards/dynamic assets; executable=",OS.get_executable_path())
	for player in root.get_node("MusicManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	quit()
