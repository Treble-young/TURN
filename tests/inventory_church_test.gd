extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func select_event(expedition: Node, id: String, floor_number: int = 1) -> void:
	expedition.floor_number = floor_number
	expedition.current_kind = expedition.Kind.ENCOUNTER
	expedition.node_pending = true
	for seed_value in range(1000):
		expedition.run_seed = seed_value
		if expedition.current_story_event().event_id == id: return
	assert(false, "Could not select event " + id)

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func check() -> void:
	var expedition = root.get_node("Expedition")
	expedition.start_run(1234)
	assert(expedition.relic_capacity == 6)
	assert(not expedition.ITEMS.has("boots") and not expedition.can_receive_relic("boots"))
	for index in range(6): expedition._award_item("blade")
	assert(expedition.used_relic_slots() == 6 and expedition.damage(1) == 42)
	expedition._award_item("light_range")
	assert(not expedition.relics.has("light_range"))
	expedition.current_kind = expedition.Kind.SHOP
	expedition.node_pending = true
	expedition.offers.assign(["light_range"])
	expedition.gold = 100
	assert(not expedition.buy("light_range") and expedition.gold == 100)
	expedition.current_kind = expedition.Kind.WISH
	expedition.complete_wish("light_range")
	assert(expedition.node_pending and not expedition.relics.has("light_range"))
	expedition.leave_wish()
	assert(not expedition.node_pending)
	expedition.current_kind = expedition.Kind.BOSS
	expedition.node_pending = true
	var progress := ExperienceProgress.new()
	var battle_report: String = expedition.win_battle(100, progress)
	progress.free()
	assert(battle_report.contains("背包已满") and expedition.used_relic_slots() == 6)
	select_event(expedition, "village_blacksmith")
	assert(not expedition.can_choose_event(1))
	assert(expedition.can_choose_event(0))
	expedition.current_kind = expedition.Kind.REST
	assert(expedition.organize_backpack())
	assert(expedition.relic_capacity == 7 and not expedition.organize_backpack())
	assert(expedition.can_receive_relic("light_range"))
	expedition._award_item("light_range")
	assert(expedition.used_relic_slots() == 7)
	select_event(expedition, "ruined_church")
	assert(expedition.can_choose_event(0))
	var gold_before: int = expedition.gold
	assert(not expedition.choose_event(0))
	assert(not expedition.exchange_event_relic(0, "not_owned"))
	assert(expedition.exchange_event_relic(0, "light_range"))
	assert(expedition.used_relic_slots() == 7 and not expedition.relics.has("light_range"))
	assert(expedition.gold == gold_before)
	assert(not expedition.exchange_event_relic(0, "blade"))
	for number in range(1, 6):
		select_event(expedition, "ruined_church", number)
		assert(expedition.current_story_event().portrait == null)
		assert(expedition.current_story_event().background_texture().resource_path.ends_with("background_9.png"))
	# Losing a health relic updates the derived maximum immediately.
	expedition.relics = {"supreme_vitality": 1}
	expedition.health = 128
	select_event(expedition, "ruined_church")
	assert(expedition.exchange_event_relic(0, "supreme_vitality"))
	assert(expedition.health <= expedition.max_health())
	var library = load("res://assets/backgrounds/library.tres")
	assert(library.backgrounds.size() == 11)
	for number in range(1, 12):
		assert(library.get_background(number).resource_path.ends_with("background_%d.png" % number))
	assert(not FileAccess.file_exists("res://assets/events/town.png"))
	var tiles = load("res://assets/maps/shared_tileset.tres")
	assert(tiles.get_source_count() == 2)
	assert(tiles.get_source(0).get_tiles_count() == 20)
	assert(tiles.get_source(1).get_tiles_count() == 24)
	var map = load("res://scenes/maps/tile_material_preview.tscn").instantiate()
	var ground = map.get_node("Ground")
	for cell in ground.get_used_cells():
		assert(tiles.has_source(ground.get_cell_source_id(cell)))
		assert(tiles.get_source(ground.get_cell_source_id(cell)).has_tile(ground.get_cell_atlas_coords(cell)))
	map.free()
	expedition.start_run(1)
	assert(expedition.relic_capacity == 6 and expedition.used_relic_slots() == 0)
	select_event(expedition, "ruined_church")
	assert(not expedition.can_choose_event(0))
	var church = load("res://scenes/events/story_event.tscn").instantiate()
	root.add_child(church)
	current_scene = church
	await capture("church_empty_preview")
	assert(church.choices.get_child(0).disabled)
	for id in ["blade", "light_range", "heart", "coin", "camp_kit", "fine_soft_armor"]: expedition._award_item(id)
	church._refresh_choices()
	assert(not church.choices.get_child(0).disabled)
	church.shared_header._open_backpack()
	await capture("backpack_slots_preview")
	church.shared_header._open_backpack()
	church._choose(0)
	await capture("church_exchange_preview")
	church._cancel_exchange()
	assert(expedition.node_pending and expedition.used_relic_slots() == 6)
	church._choose(0)
	church._confirm_exchange("heart")
	var confirmation: ConfirmationDialog
	for child in church.get_children():
		if child is ConfirmationDialog: confirmation = child
	assert(confirmation != null)
	confirmation.confirmed.emit()
	await capture("church_result_preview")
	assert(not expedition.node_pending and expedition.used_relic_slots() == 6)
	church.queue_free()
	await process_frame
	expedition.current_kind = expedition.Kind.REST
	expedition.node_pending = true
	var rest = load("res://scenes/expedition/node_visit.tscn").instantiate()
	root.add_child(rest)
	current_scene = rest
	await capture("rest_organize_preview")
	rest._organize()
	assert(expedition.relic_capacity == 7 and not expedition.node_pending)
	rest.queue_free()
	await process_frame
	print("PASS: slot capacity across all grants, rest choice, atomic exchange/cancel/double-click, derived stats, church floors/no-NPC, 11 backgrounds, 20+24 tile palettes and existing maps")
	var music = root.get_node("MusicManager")
	music.process_mode = Node.PROCESS_MODE_DISABLED
	for child in music.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.15).timeout
	quit()
