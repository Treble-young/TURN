extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func snapshot(filename: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func check() -> void:
	var expedition = root.get_node("Expedition")
	expedition.start_run(1234)
	var tiles = load("res://assets/maps/shared_tileset.tres")
	assert(tiles.tile_size == Vector2i(64, 64) and tiles.get_source_count() == 2)
	for id in range(2): assert(tiles.get_source(id).has_tile(Vector2i.ZERO))
	assert(tiles.get_source(1).get_tiles_count() == 24)
	assert(tiles.get_source(0).get_tiles_count() == 20)
	assert(tiles.get_source(1).get_tile_data(Vector2i.ZERO, 0).get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == 1)
	for pair in [[0, 1], [0, 2], [3, 4]]:
		var connected := TileMapLayer.new()
		connected.tile_set = tiles
		root.add_child(connected)
		var outside: Array[Vector2i] = []
		var inside: Array[Vector2i] = []
		for y in range(7):
			for x in range(7):
				outside.append(Vector2i(x, y))
				if x >= 2 and x <= 4 and y >= 2 and y <= 4: inside.append(Vector2i(x, y))
		connected.set_cells_terrain_connect(outside, 0, pair[1])
		connected.set_cells_terrain_connect(inside, 0, pair[0])
		var has_transition := false
		for cell in connected.get_used_cells():
			if connected.get_cell_source_id(cell) == 1: has_transition = true
		assert(has_transition)
		connected.free()
	var preview = load("res://scenes/maps/terrain_transition_preview.tscn").instantiate()
	assert(preview.get_script() != null)
	root.add_child(preview)
	current_scene = preview
	await snapshot("updated_terrain_preview")
	preview.queue_free()
	await process_frame
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_tiles := TileMapLayer.new()
	floor_tiles.tile_set = tiles
	scene.add_child(floor_tiles)
	for y in range(11):
		for x in range(19): floor_tiles.set_cell(Vector2i(x, y), 0, Vector2i((x + y) % 4, 0))
	var enemies: Array = []
	for index in range(5):
		var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
		enemy.stats = load("res://assets/enemies/" + ["goblin", "goblin_stone_thrower", "slime_small", "slime_medium", "slime_large"][index] + ".tres")
		enemy.position = Vector2(140 + index * 215, 370)
		scene.add_child(enemy)
		enemy.set_physics_process(false)
		assert(enemy.health_bar.visible and enemy.health_bar.fraction == 1.0)
		enemies.append(enemy)
	var victim = enemies[0]
	victim.take_damage(5.5)
	assert(is_equal_approx(victim.health_bar.fraction, (victim.stats.max_health - 5.5) / victim.stats.max_health))
	assert(get_nodes_in_group("damage_numbers").size() == 1)
	assert(get_nodes_in_group("damage_numbers")[0].caption == "5.5")
	victim.take_damage(0)
	victim.take_damage(-10)
	assert(get_nodes_in_group("damage_numbers").size() == 1)
	for index in range(1, 5): enemies[index].take_damage(3.0 + index)
	await snapshot("enemy_health_damage_preview")
	var killing_number: Node
	victim.take_damage(100)
	killing_number = get_nodes_in_group("damage_numbers").back()
	assert(victim.is_dead and not victim.health_bar.visible and killing_number.caption == "100")
	var count := get_nodes_in_group("damage_numbers").size()
	victim.take_damage(1)
	assert(get_nodes_in_group("damage_numbers").size() == count)
	victim.queue_free()
	await process_frame
	assert(is_instance_valid(killing_number))
	# Exercise the actual blade swept-hit path into the same damage entry point.
	var player = load("res://scenes/characters/player.tscn").instantiate()
	scene.add_child(player)
	player.position = Vector2(100, 600)
	player.set_physics_process(false)
	var blade = load("res://scripts/projectiles/light_blade.gd").new()
	blade.owner_player = player
	blade.damage = 2.5
	blade.position = enemies[1].position + Vector2(-45, -30)
	scene.add_child(blade)
	blade.set_physics_process(false)
	var before: float = enemies[1].health
	blade._physics_process(0.1)
	assert(is_equal_approx(enemies[1].health, before - 2.5))
	assert(get_nodes_in_group("damage_numbers").back().caption == "2.5")
	player.position = enemies[1].position - Vector2(40, 0)
	player.attack_damage = 2.0
	player.facing_right = true
	player.is_attacking = true
	player.combo_stage = 2
	player._attack_hit = true
	player.sprite.frame = 2
	player.sprite.pause()
	before = enemies[1].health
	player._attack_hit = false
	player._on_attack_frame()
	assert(is_equal_approx(enemies[1].health, before - 2.2))
	assert(get_nodes_in_group("damage_numbers").back().caption == "2.2")
	var enemy_count := get_nodes_in_group("enemies").size()
	enemies[3].take_damage(100)
	enemies[3]._animation_finished()
	await process_frame
	assert(get_nodes_in_group("enemies").size() == enemy_count + 1)
	for enemy in get_nodes_in_group("enemies"):
		if not enemy.is_dead: assert(enemy.health_bar.visible)
	await create_timer(0.85).timeout
	assert(get_nodes_in_group("damage_numbers").is_empty())
	scene.queue_free()
	await process_frame
	print("PASS: tile IDs/variants/terrain painting, all enemy health bars, decimal damage, zero/dead guards, lethal popup lifetime, melee and blade hits, split enemies, popup cleanup")
	quit()
