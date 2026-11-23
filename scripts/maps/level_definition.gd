class_name LevelDefinition
extends Resource

@export var level_id: String = ""
@export var display_name: String = "待制作关卡"
@export var map_scene: PackedScene
@export_range(1, 5) var min_floor: int = 1
@export_range(1, 5) var max_floor: int = 1
@export var boss_level: bool = false
