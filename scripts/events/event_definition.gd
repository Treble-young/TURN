class_name StoryEventDefinition
extends Resource

@export var event_id: String = ""
@export var title: String = ""
@export var npc_name: String = ""
@export var background: Texture2D
@export var portrait: Texture2D
@export_multiline var story: String = ""
@export_range(1, 5) var min_floor: int = 1
@export_range(1, 5) var max_floor: int = 5
@export var choices: Array[StoryEventChoice] = []

func available_on(floor_number: int) -> bool:
	return floor_number >= min_floor and floor_number <= max_floor and background != null and portrait != null and choices.size() >= 2 and choices.size() <= 3
