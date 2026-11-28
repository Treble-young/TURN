extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	var encounter = load("res://scripts/expedition/battle_encounter.gd")
	var catalog = load("res://assets/enemies/catalog.tres")
	var damage: float = catalog.goblin.damage
	catalog.goblin.damage = 17
	assert(encounter.stats_for("goblin").damage == 17)
	catalog.goblin.damage = damage
	for id in ["lesser_vitality","greater_vitality","supreme_vitality"]: assert(not e.ITEMS.has(id))
	var backgrounds = load("res://assets/backgrounds/library.tres")
	assert(backgrounds.backgrounds.size() == 13)
	for kind in [e.Kind.BATTLE,e.Kind.ELITE,e.Kind.BOSS]:
		e.start_run(1)
		e.current_kind = kind
		e.node_pending = true
		var progress = load("res://scripts/characters/experience_progress.gd").new()
		e.win_battle(100,progress,true)
		progress.free()
		assert(e.battle_rewards.gold == [6,10,14][kind])
	e.start_run(4)
	e.health = 1
	e.gold = 100
	e.current_kind = e.Kind.SHOP
	e.node_pending = true
	e.offers.assign(["blood_rose"])
	assert(e.shop_price("blood_rose")==16)
	assert(e.buy("blood_rose") and e.gold==84 and e.health==e.max_health())
	assert(not e.can_receive_relic("blood_rose") and not e.buy("blood_rose"))
	assert(not e.ITEMS.blood_rose.get("rare",false))
	assert(load("res://scripts/expedition/expedition_ui.gd").relic_icon("blood_rose") != null)
	e.current_kind = e.Kind.REST
	e.node_pending = true
	change_scene_to_file("res://scenes/events/story_event.tscn")
	await scene_changed
	await process_frame
	await process_frame
	var view = current_scene
	assert(view.event.background_id == 12 and view.event.portrait == null and view.choices.get_child_count()==3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/rest-camp-preview.png")
	var gold_before: int = e.gold
	view._rest_action(2)
	assert(e.gold==gold_before+8 and not e.node_pending)
	assert(not e.organize_backpack() and not e.accept_rest_commission())
	assert(view.choices.get_child_count()==1)
	print("PASS: editable shared catalog, gold 6/10/14, 13 backgrounds, rose purchase/full-heal/unique/icon, removed relics, rest layout and mutually exclusive commission")
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	quit()
