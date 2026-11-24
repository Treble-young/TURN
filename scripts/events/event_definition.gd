class_name StoryEventDefinition
extends Resource

static var background_library: Resource

@export var event_id: String = ""
@export var title: String = ""
@export var npc_name: String = ""
@export var background: Texture2D
## 0 使用自定义 background，其他数字对应背景库编号。
@export_range(0, 99) var background_id: int = 0
@export var portrait: Texture2D
@export_multiline var story: String = ""
@export_range(1, 5) var min_floor: int = 1
@export_range(1, 5) var max_floor: int = 5
@export var choices: Array[StoryEventChoice] = []

func available_on(floor_number: int) -> bool:
	return floor_number >= min_floor and floor_number <= max_floor and background_texture() != null and choices.size() >= 2 and choices.size() <= 3

func background_texture() -> Texture2D:
	if background_id <= 0: return background
	if background_library == null: background_library = load("res://assets/backgrounds/library.tres")
	return background_library.get_background(background_id)
