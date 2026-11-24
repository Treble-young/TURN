extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func check() -> void:
	var expedition = root.get_node("Expedition")
	expedition.start_run(1234)
	expedition.experience = 7
	var route = load("res://scenes/expedition/route_map.tscn").instantiate()
	root.add_child(route)
	current_scene = route
	await capture("route_header_preview")
	assert(route.shared_header.last_values[6] == 7)
	route.shared_header.backpack_button.pressed.emit()
	assert(route.backpack.visible)
	route.backpack.hide()
	var pause = route.get_node("PauseMenu")
	pause.pause_game()
	assert(pause.seed_value.text.contains("1234"))
	assert(pause.seed_value.get_index() == pause.window_options.get_index() + 1)
	await capture("pause_seed_preview")
	pause.resume_game()
	route.queue_free()
	await process_frame
	for kind in [expedition.Kind.SHOP, expedition.Kind.WISH, expedition.Kind.REST]:
		expedition.current_kind = kind
		expedition.node_pending = true
		expedition.offers.assign(["blade", "heart"])
		expedition.gold = 100
		expedition.health = 50
		var visit = load("res://scenes/expedition/node_visit.tscn").instantiate()
		root.add_child(visit)
		current_scene = visit
		await capture("node_header_" + str(kind))
		var header = visit.get_node("ExpeditionHeader")
		assert(header != null)
		if kind == expedition.Kind.SHOP:
			visit._buy("blade")
			await process_frame
			await process_frame
			assert(header.last_values[3] == expedition.damage(expedition.level))
			assert(header.last_values[4] == expedition.gold)
		elif kind == expedition.Kind.REST:
			visit._rest()
			await process_frame
			await process_frame
			assert(header.last_values[1] == expedition.health and expedition.health > 50)
		header.backpack_button.pressed.emit()
		assert(is_instance_valid(header.inventory))
		visit.queue_free()
		await process_frame
	expedition.current_kind = expedition.Kind.ENCOUNTER
	expedition.node_pending = true
	var event = load("res://scenes/events/story_event.tscn").instantiate()
	root.add_child(event)
	current_scene = event
	await capture("event_header_preview")
	assert(event.get_node("ExpeditionHeader") != null)
	var portraits: Array = event.stage.find_children("*", "AnimatedSprite2D", true, false)
	assert(portraits.is_empty())
	root.size = Vector2i(960, 540)
	await capture("event_header_small_preview")
	event.queue_free()
	await process_frame
	print("PASS: shared header on all five screens, current XP, live shop/rest stats, seed under window size, backpacks, event layout at two sizes")
	var music = root.get_node("MusicManager")
	music.process_mode = Node.PROCESS_MODE_DISABLED
	for child in music.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.15).timeout
	quit()
