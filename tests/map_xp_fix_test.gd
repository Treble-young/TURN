extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var xp := ExperienceProgress.new()
	var requirements := []
	var total := 0
	for value in range(1, 25):
		xp.level = value
		requirements.append(xp.experience_required())
		total += xp.experience_required()
	assert(requirements.slice(0,4) == [20,32,45,60])
	xp.level = 1
	xp.add_experience(total)
	assert(xp.level == 25 and xp.experience == 0 and xp.experience_required() == 0)
	xp.free()
	var e = root.get_node("Expedition")
	e.start_run(11)
	e.current_kind = e.Kind.BATTLE
	e.node_pending = true
	set_meta("battle_map_override", "res://scenes/maps/levels/f1_level_01.tscn")
	change_scene_to_file("res://scenes/expedition/arena.tscn")
	await scene_changed
	await process_frame
	var map = current_scene.battle_map
	assert(map.get_node("Ground").get_used_cells().is_empty())
	assert(map.get_node("Decorations").get_used_cells().size() > 0 and map._has_tiles())
	assert(map.placeholder.z_index < map.get_node("Decorations").z_index)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/f1-map-fixed.png")
	print("PASS: edited Decorations map in real battle; XP 1-25: ", requirements)
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	quit()
