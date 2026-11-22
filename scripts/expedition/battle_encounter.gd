extends RefCounted

const BOSS_NAME := "深沼首领"
const ENEMY_STATS := {
	"goblin": preload("res://assets/enemies/goblin.tres"),
	"slime_medium": preload("res://assets/enemies/slime_medium.tres"),
	"slime_large": preload("res://assets/enemies/slime_large.tres"),
}

static func waves_for(kind: int, floor_number: int) -> Array:
	match kind:
		Expedition.Kind.BOSS:
			return [["goblin", "slime_medium", "goblin"], ["boss", "goblin", "slime_medium"]]
		Expedition.Kind.ELITE:
			return [["goblin", "slime_medium", "goblin"], ["slime_large", "goblin", "goblin"]]
	var first: Array[String] = ["goblin", "goblin", "slime_medium"]
	if floor_number >= 3:
		first.append("goblin")
	if floor_number == Expedition.FLOOR_COUNT:
		first.append("slime_medium")
	return [first]

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

static func battlefield_preview(_kind: int, _floor_number: int, _node: Vector2i) -> Texture2D:
	# Future thumbnails can be selected by floor, battle kind, or node (stage, lane).
	return null
