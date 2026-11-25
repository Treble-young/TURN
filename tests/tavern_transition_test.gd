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
	var e = root.get_node("Expedition")
	var tavern = load("res://assets/events/tavern.tres")
	for floor_value in range(1, 6): assert(tavern.available_on(floor_value))
	assert(tavern.portrait == null and tavern.background_id == 3)
	for round_index in range(3):
		var round_event = tavern
		for step in range(round_index): round_event = round_event.choices[0].next_event
		var choice = round_event.choices[0]
		assert(choice.gold_cost == [3, 5, 7][round_index])
		assert(is_equal_approx(choice.reward_chance, [0.8, 0.6, 0.4][round_index]))
		assert(choice.gold_reward == [7, 9, 12][round_index])
		var outcomes := {}
		for seed_value in range(40):
			e.start_run(12)
			e.current_kind = e.Kind.ENCOUNTER
			e.node_pending = true
			e.event_followup = round_event
			e.gold = choice.gold_cost - 1
			var state_before = e.rng.state
			assert(not e.choose_event(0) and e.rng.state == state_before)
			e.gold = 30
			e.rng.seed = seed_value
			assert(e.choose_event(0))
			var won: bool = e.report.contains("赢了")
			outcomes[won] = true
			assert(e.gold == 30 - choice.gold_cost + (choice.gold_reward if won else 0))
			assert(e.node_pending == (round_index < 2))
			if round_index < 2:
				assert(e.current_story_event() == choice.next_event)
				var after_gold: int = e.gold
				assert(e.choose_event(1) and not e.node_pending and e.gold == after_gold)
			assert(not e.choose_event(0))
		assert(outcomes.size() == 2)
	e.start_run(12)
	assert(e.event_followup == null)
	e.current_kind = e.Kind.ENCOUNTER
	e.node_pending = true
	e.event_followup = tavern
	var scene = load("res://scenes/events/story_event.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await capture("tavern_preview")
	assert(is_equal_approx(scene.choices.position.y, 82 + scene.CHOICE_SIZE.y + 10))
	assert(scene.choices.get_child_count() == 2)
	scene._choose(0)
	await process_frame
	assert(e.node_pending and scene.event.event_id == "tavern_cards_2")
	assert(scene.narrative.text.contains("第1局"))
	await capture("tavern_round_2_preview")
	# Actual route-button entry tests the persistent overlay and input guard.
	e.start_run(12)
	e.maps[0][0][0] = e.Kind.ENCOUNTER
	for seed_value in range(100):
		e.run_seed = seed_value
		if load("res://assets/events/catalog.tres").pick(1, seed_value, 0, 0).event_id == "tavern_cards_1": break
	change_scene_to_file("res://scenes/expedition/route_map.tscn")
	await scene_changed
	await process_frame
	var route = current_scene
	route.selected = Vector2i(0, 0)
	route._confirm_node()
	var transition = root.get_node("TideTransition")
	assert(transition.busy)
	route._confirm_node()
	assert(e.visited.size() == 1)
	await create_timer(0.21).timeout
	await capture("tide_cover_preview")
	while current_scene == route: await process_frame
	assert(transition.busy and transition.surface.visible)
	await create_timer(0.16).timeout
	await capture("tide_reveal_preview")
	while transition.busy: await process_frame
	assert(not transition.surface.visible and current_scene.event.event_id == "tavern_cards_1")
	await capture("tavern_entered_preview")
	root.get_node("MusicManager").set_process(false)
	for player in root.get_node("MusicManager").get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	print("PASS: tavern rounds, win/loss payment, affordability, leave, reset, two-choice alignment, actual route tide transition")
	quit()
