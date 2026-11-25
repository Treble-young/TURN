class_name ExperienceProgress
extends Node

signal experience_changed(level: int, current: int, required: int)
signal leveled_up(new_level: int)

@export_range(1, 100) var max_level: int = 25
@export var first_level_requirement: int = 20
@export var requirement_increase: int = 12
var level: int = 1
var experience: int = 0
var total_experience: int = 0

func experience_required() -> int:
	if level >= max_level:
		return 0
	var required := first_level_requirement
	var increase := requirement_increase
	for step in range(1, level):
		required += increase
		increase += step
	return maxi(1, required)

func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	total_experience += amount
	if level >= max_level:
		experience_changed.emit(level, experience, 0)
		return
	experience += amount
	while level < max_level and experience >= experience_required():
		experience -= experience_required()
		level += 1
		leveled_up.emit(level)
	if level >= max_level:
		experience = 0
	experience_changed.emit(level, experience, experience_required())
