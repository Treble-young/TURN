extends SceneTree
func _initialize() -> void:
	check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(16)
	e.current_kind = e.Kind.SHOP
	e.node_pending = true
	e.offers.assign(["blade", "heart", "light_range"])
	e.gold = 100
	var shop = load("res://scenes/events/story_event.tscn").instantiate()
	root.add_child(shop)
	current_scene = shop
	await process_frame
	await process_frame
	assert(shop.event.background_id == 10 and shop.event.portrait == null)
	assert(shop.choices.get_child_count() == 4)
	var before: int = e.gold
	shop._shop_buy("blade")
	assert(e.gold < before and e.relics.has("blade"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/shop-polish-preview.png")
	var transition = root.get_node("TideTransition")
	transition.surface.show()
	transition.surface.progress = 0.5
	transition.surface.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/tide-soft-preview.png")
	transition.surface.hide()
	var player = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	for form in [player.Form.SHADOW, player.Form.LIGHT]:
		for right in [true, false]:
			player.current_form = form
			player.facing_right = right
			player._begin_transformation()
			assert(player.sprite.flip_h == right)
			player._finish_transformation()
			assert(not player.sprite.flip_h)
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.stats = load("res://assets/enemies/goblin.tres").duplicate()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.take_damage(1, true)
	assert(get_nodes_in_group("damage_numbers").back().ink == Color("#c18aff"))
	enemy.take_damage(1, false)
	assert(get_nodes_in_group("damage_numbers").back().ink == Color("#ffe069"))
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	print("PASS: shop backdrop/purchase/layout, two damage colors, transformation mirroring in both directions/forms, feather shader")
	quit()
