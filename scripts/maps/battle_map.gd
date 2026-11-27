@tool
class_name EditableBattleMap
extends Node2D

@export var arena_bounds := Rect2(40, 107, 1072, 498):
	set(value):
		arena_bounds = value
		queue_redraw()
@export_enum("常规交锋", "强敌试炼", "宿命对决") var test_battle_type: int = 0
@export var preview_texture: Texture2D
@export var show_placeholder_grid: bool = true
@export_group("Camera")
## Zoom > 1 enlarges the world; zoom < 1 shows more of a large map.
@export_range(0.25, 4.0, 0.05) var camera_zoom: float = 1.0
## Zero means instant tracking; larger values follow more quickly.
@export_range(0.0, 20.0, 0.5) var camera_follow_speed: float = 8.0
## 相机可越出战斗边界的距离；不改变角色和敌人的可行走区域。
@export var camera_edge_margin := Vector2(120, 180)

var placeholder: Node2D

func _ready() -> void:
	add_to_group("battle_bounds")
	placeholder = Node2D.new()
	placeholder.name = "EmptyMapPlaceholder"
	placeholder.z_index = -100
	add_child(placeholder)
	placeholder.draw.connect(_draw_placeholder)
	for child in get_children():
		if child is TileMapLayer: child.changed.connect(placeholder.queue_redraw)
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		_test_map.call_deferred()

func _test_map() -> void:
	# F6 on a map scene launches the real combat loop with that map.
	get_tree().set_meta("battle_map_override", scene_file_path)
	Expedition.start_run(1)
	Expedition.current_kind = [Expedition.Kind.BATTLE, Expedition.Kind.ELITE, Expedition.Kind.BOSS][test_battle_type]
	Expedition.node_pending = true
	get_tree().change_scene_to_file("res://scenes/expedition/arena.tscn")

func spawn_markers(battle_kind: int = -1) -> Array[MapEnemySpawn]:
	var markers: Array[MapEnemySpawn] = []
	for node in find_children("*", "Marker2D", true, false):
		if node is MapEnemySpawn and node.count > 0:
			if battle_kind >= 0 and node.encounter_variant != 0:
				if (node.encounter_variant == 2) != (battle_kind in [1, 2]): continue
			markers.append(node)
	return markers

func configured_wave_count(battle_kind: int = -1) -> int:
	var result := 0
	for marker in spawn_markers(battle_kind):
		result = maxi(result, marker.wave)
	return result

func _has_tiles() -> bool:
	for child in get_children():
		if child is TileMapLayer and not child.get_used_cells().is_empty(): return true
	return false

func _draw_placeholder() -> void:
	if not Engine.is_editor_hint() and show_placeholder_grid and not _has_tiles():
		placeholder.draw_rect(arena_bounds, Color("252839"))
		for x in range(int(arena_bounds.position.x), int(arena_bounds.end.x), 64):
			placeholder.draw_line(Vector2(x, arena_bounds.position.y), Vector2(x, arena_bounds.end.y), Color("34394b"))
		for y in range(int(arena_bounds.position.y), int(arena_bounds.end.y), 64):
			placeholder.draw_line(Vector2(arena_bounds.position.x, y), Vector2(arena_bounds.end.x, y), Color("34394b"))

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(arena_bounds, Color("e5c082"), false, 2)
