extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func select_smith(expedition: Node) -> void:
	expedition.floor_number = 1
	for seed_value in range(100):
		expedition.run_seed = seed_value
		if expedition.current_story_event().event_id == "village_blacksmith": return
	assert(false)

func check() -> void:
	var expedition = root.get_node("Expedition")
	expedition.start_run(1234)
	expedition.current_kind = expedition.Kind.ENCOUNTER
	expedition.node_pending = true
	select_smith(expedition)
	var smith = expedition.current_story_event()
	assert(smith.event_id == "village_blacksmith")
	assert(not expedition.can_choose_event(1))
	assert(expedition.choose_event(0))
	assert(expedition.gold == 3 and expedition.damage(1) == 21.0)
	assert(not expedition.choose_event(0))
	expedition.node_pending = true
	expedition.gold = 16
	assert(expedition.choose_event(1))
	assert(expedition.gold == 0 and expedition.relics.has("fine_soft_armor"))
	expedition.node_pending = true
	assert(not expedition.can_choose_event(1))
	for floor_number in range(1, 6):
		expedition.floor_number = floor_number
		assert(expedition.current_story_event().available_on(floor_number))
		if floor_number > 2: assert(expedition.current_story_event().event_id != "village_blacksmith")
	expedition.start_run(1234)
	assert(expedition.event_attack_bonus == 0.0 and not expedition.relics.has("fine_soft_armor"))
	expedition.current_kind = expedition.Kind.ENCOUNTER
	expedition.node_pending = true
	select_smith(expedition)
	expedition.gold = 20
	var scene = load("res://scenes/events/story_event.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/story_event_preview.png")
	assert(scene.choices.get_child_count() == 3)
	scene._choose(1)
	assert(scene.choices.get_child_count() == 1 and expedition.gold == 4)
	scene.queue_free()
	await process_frame
	expedition.current_kind = expedition.Kind.BATTLE
	expedition.node_pending = true
	set_meta("battle_map_override", "res://scenes/maps/standard.tscn")
	var arena = load("res://scenes/expedition/arena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.player._finish_transformation()
	assert(arena.player.shield == 5.0)
	arena.player._finish_transformation()
	assert(arena.player.shield == 10.0)
	var hp: float = arena.player.health
	arena.player.take_damage(13.0)
	assert(arena.player.shield == 0.0 and arena.player.health == hp - 3.0)
	arena.queue_free()
	await process_frame
	# Exercise a configured combat choice using a temporary catalog entry.
	expedition.current_kind = expedition.Kind.ENCOUNTER
	expedition.node_pending = true
	var choice = smith.choices[2]
	choice.battle_map = load("res://scenes/maps/standard.tscn")
	assert(expedition.choose_event(2))
	assert(expedition.current_kind == expedition.Kind.BATTLE and expedition.node_pending)
	assert(has_meta("battle_map_override"))
	choice.battle_map = null
	var event_arena = load("res://scenes/expedition/arena.tscn").instantiate()
	root.add_child(event_arena)
	current_scene = event_arena
	await process_frame
	assert(not has_meta("battle_map_override"))
	event_arena._victory()
	assert(not expedition.node_pending and expedition.floor_number == 1 and expedition.active)
	event_arena.queue_free()
	await process_frame
	print("PASS: event floors, purchases, double-click guard, new-run reset, scene layout, transformation shields, damage absorption, combat choice")
	root.get_node("MusicManager").process_mode = Node.PROCESS_MODE_DISABLED
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.15).timeout
	quit()
