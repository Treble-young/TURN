@tool
class_name MapEnemySpawn
extends Marker2D

@export_enum("goblin", "slime_large", "slime_medium", "slime_small", "boss") var enemy_kind: String = "goblin":
	set(value):
		enemy_kind = value
		queue_redraw()
@export_range(0, 100) var count: int = 1:
	set(value):
		count = value
		queue_redraw()
@export_range(1, 20) var wave: int = 1
@export_range(0, 200) var spacing: float = 36.0
@export_enum("普通和困难", "仅普通", "仅困难") var encounter_variant: int = 0

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 15, Color(0.9, 0.4, 0.3, 0.4))
		draw_string(ThemeDB.fallback_font, Vector2(20, 5), "%s ×%d / W%d" % [enemy_kind, count, wave], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func spawn_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in range(count):
		var column := index % 4
		var row := floori(index / 4.0)
		points.append(global_position + Vector2(column * spacing, row * spacing))
	return points
