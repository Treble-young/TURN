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

## 概率奖励：先扣除 gold_cost，命中概率后发放完整 gold_reward。
@export_range(0.0, 1.0) var reward_chance: float = 1.0
@export_multiline var failure_text: String = ""
## 不为空时继续下一段事件，成功或失败均进入。
@export var next_event: Resource
