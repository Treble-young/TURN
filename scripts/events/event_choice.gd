class_name StoryEventChoice
extends Resource

@export_multiline var text: String = "转身离开"
@export_range(0, 999) var gold_cost: int = 0
@export var attack_bonus: float = 0.0
@export var relic_id: String = ""
@export var heal: float = 0.0
@export var health_cost: float = 0.0
@export var gold_reward: int = 0
## 玩家先选择一件已有遗物，确认后才执行交换。
@export var exchange_relic: bool = false
@export_multiline var result_text: String = "你继续踏上旅途。"
## 设置后，该选项会进入此地图的普通战斗，胜利后返回路线。
@export var battle_map: PackedScene
