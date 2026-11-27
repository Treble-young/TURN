class_name EnemyStats
extends Resource

@export var display_name: String = "Goblin"
@export var max_health: float = 24.0
@export_range(0, 10000) var experience_reward: int = 6
@export var damage: float = 8.0
@export var move_speed: float = 100.0
@export var attack_range: float = 42.0
@export var attack_interval: float = 1.3
@export var throws_stones: bool = false
@export var visual_scale: float = 0.42
@export var body_radius: float = 14.0
@export_file("*.tres") var frames_path: String
@export_file("*.tres") var split_stats_path: String

@export var is_shaman: bool = false
@export var retreat_distance: float = 300.0
@export var heal_interval: float = 2.4
@export var heal_multiplier: float = 4.0
@export var explosion_multiplier: float = 0.0
@export var explosion_radius: float = 50.0
@export var frame_origin := Vector2(-128, -224)

@export var is_necromancer: bool = false
@export var summon_interval: float = 3.0
@export var is_yeti: bool = false
@export var ranged_damage: float = 0.0
@export var ranged_range: float = 350.0
@export var ranged_interval: float = 1.5
@export var hit_frame: int = 1

## 可选受击椭圆，与移动碰撞独立；零向量使用原有受击规则。
@export var hurt_radii := Vector2.ZERO
@export var hurt_offset := Vector2(0,-30)
