@tool
extends EditableBattleMap

var preview_player: EclipsePlayer

func _test_map() -> void:
	MusicManager.set_context(&"non_combat")
	preview_player = preload("res://scenes/characters/player.tscn").instantiate()
	add_child(preview_player)
	preview_player.position = $PlayerStart.position
	var camera := BattleFollowCamera.new()
	add_child(camera)
	camera.configure(preview_player, arena_bounds, camera_zoom, camera_follow_speed, camera_edge_margin)
	add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())
	var names := ["草地", "花草地", "干土地", "暗影地", "沼泽地", "雪地", "岩石地", "熔岩地"]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	for index in range(8):
		var label := Label.new()
		label.text = names[index]
		label.position = Vector2(index % 4 * 320 + 16, floori(index / 4.0) * 384 + 38)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", Color("322d22"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and is_instance_valid(preview_player):
		preview_player.position = preview_player.position.clamp(arena_bounds.position + Vector2(16, 32), arena_bounds.end - Vector2(16, 12))
