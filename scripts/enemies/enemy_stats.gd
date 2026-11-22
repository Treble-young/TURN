class_name EnemyStats
extends Resource

@export var display_name: String = "Goblin"
@export var max_health: float = 24.0
@export_range(0, 10000) var experience_reward: int = 6
@export var damage: float = 8.0
@export var move_speed: float = 100.0
@export var attack_range: float = 42.0
@export var attack_interval: float = 1.3
@export var visual_scale: float = 0.42
@export var body_radius: float = 14.0
@export_file("*.tres") var frames_path: String
@export_file("*.tres") var split_stats_path: String
