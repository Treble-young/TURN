extends Resource

@export var levels: Array[LevelDefinition] = []

func level_by_id(id: String) -> LevelDefinition:
	for level in levels:
		if level != null and level.level_id == id: return level
	return null

func assign_levels(routes: Array, seed_value: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var assigned: Dictionary = {}
	var slots: Array = []
	for floor_index in range(routes.size()):
		for row in range(routes[floor_index].size()):
			for lane in range(routes[floor_index][row].size()):
				var kind: int = routes[floor_index][row][lane]
				if kind not in [0, 1, 2]: continue
				var candidates: Array[LevelDefinition] = []
				for level in levels:
					if level != null and level.map_scene != null and not level.level_id.is_empty() and level.min_floor <= floor_index + 1 and level.max_floor >= floor_index + 1 and level.boss_level == (kind == 2):
						candidates.append(level)
				slots.append({"key": "%d:%d:%d" % [floor_index + 1, row, lane], "candidates": candidates})
	for slot in slots:
		for index in range(slot.candidates.size() - 1, 0, -1):
			var other := random.randi_range(0, index)
			var swap = slot.candidates[index]
			slot.candidates[index] = slot.candidates[other]
			slot.candidates[other] = swap
	slots.sort_custom(func(a: Dictionary, b: Dictionary): return a.candidates.size() < b.candidates.size())
	var owners: Dictionary = {}
	for index in range(slots.size()):
		var seen: Dictionary = {}
		if not _match_slot(index, slots, owners, assigned, seen):
			push_warning("关卡库不足：无法分配节点 %s" % slots[index].key)
	return assigned

func _match_slot(index: int, slots: Array, owners: Dictionary, assigned: Dictionary, seen: Dictionary) -> bool:
	for level in slots[index].candidates:
		if seen.has(level.level_id): continue
		seen[level.level_id] = true
		if not owners.has(level.level_id) or _match_slot(owners[level.level_id], slots, owners, assigned, seen):
			owners[level.level_id] = index
			assigned[slots[index].key] = level.level_id
			return true
	return false

func definition_for(floor_number: int, stage: int, lane: int) -> LevelDefinition:
	return level_by_id(Expedition.assigned_levels.get("%d:%d:%d" % [floor_number, stage, lane], ""))

func map_for(_kind: int, floor_number: int = 1, stage: int = -1, lane: int = -1) -> PackedScene:
	var definition := definition_for(floor_number, stage, lane)
	return definition.map_scene if definition != null else null
