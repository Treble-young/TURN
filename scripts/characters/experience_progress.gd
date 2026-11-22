class_name ExperienceProgress
extends Node

signal experience_changed(level: int, current: int, required: int)
signal leveled_up(new_level: int)

@export_range(1, 100) var max_level: int = 25
@export var first_level_requirement: int = 10
@export var requirement_increase: int = 5
var level: int = 1
var experience: int = 0

func experience_required() -> int:
	if level >= max_level:
		return 0
	return maxi(1, first_level_requirement + (level - 1) * requirement_increase)

func add_experience(amount: int) -> void:
	if amount <= 0 or level >= max_level:
		return
	experience += amount
	while level < max_level and experience >= experience_required():
		experience -= experience_required()
		level += 1
		leveled_up.emit(level)
	if level >= max_level:
		experience = 0
	experience_changed.emit(level, experience, experience_required())
