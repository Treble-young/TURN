extends RefCounted

const BOSS_NAME := "深沼首领"
const ENEMY_STATS := {
	"slime_small": preload("res://assets/enemies/slime_small.tres"),
	"goblin": preload("res://assets/enemies/goblin.tres"),
	"slime_medium": preload("res://assets/enemies/slime_medium.tres"),
	"slime_large": preload("res://assets/enemies/slime_large.tres"),
}

static func waves_for(kind: int, floor_number: int, stage: int = -1, lane: int = -1) -> Array:
	var library = load("res://assets/maps/map_library.tres")
	var scene: PackedScene = library.map_for(kind, floor_number, stage, lane)
	if scene == null: return []
	var map = scene.instantiate()
	var waves: Array = []
	for number in range(map.configured_wave_count(kind)):
		var units: Array = []
		for marker in map.spawn_markers(kind):
			if marker.wave == number + 1:
				for index in marker.count: units.append(marker.enemy_kind)
		waves.append(units)
	map.free()
	return waves

static func stats_for(kind: String) -> EnemyStats:
	return ENEMY_STATS["slime_large" if kind == "boss" else kind]

static func wave_summary(wave: Array) -> String:
	var counts := {}
	for kind: String in wave:
		var display_name := BOSS_NAME if kind == "boss" else stats_for(kind).display_name
		counts[display_name] = counts.get(display_name, 0) + 1
	return _format_counts(counts)

static func split_summary(waves: Array) -> String:
	var counts := {}
	for wave: Array in waves:
		for kind: String in wave:
			var stats := stats_for(kind)
			var count := 1
			while not stats.split_stats_path.is_empty():
				stats = load(stats.split_stats_path) as EnemyStats
				count *= EclipseEnemy.SPLIT_OFFSETS.size()
				counts[stats.display_name] = counts.get(stats.display_name, 0) + count
	return _format_counts(counts)

static func _format_counts(counts: Dictionary) -> String:
	var parts := PackedStringArray()
	for display_name: String in counts:
		parts.append("%s ×%d" % [display_name, counts[display_name]])
	return "、".join(parts)

static func battlefield_preview(kind: int, floor_number: int, node: Vector2i) -> Texture2D:
	var library = load("res://assets/maps/map_library.tres")
	var scene: PackedScene = library.map_for(kind, floor_number, node.x, node.y)
	if scene == null: return null
	var map = scene.instantiate()
	var texture: Texture2D = map.preview_texture
	map.free()
	return texture
