extends Resource

@export var events: Array[StoryEventDefinition] = []

func pick(floor_number: int, run_seed: int, stage: int, lane: int) -> StoryEventDefinition:
	var candidates: Array[StoryEventDefinition] = []
	for event in events:
		if event != null and event.available_on(floor_number): candidates.append(event)
	if candidates.is_empty(): return null
	var random := RandomNumberGenerator.new()
	random.seed = hash("event:%d:%d:%d:%d" % [run_seed, floor_number, stage, lane])
	return candidates[random.randi_range(0, candidates.size() - 1)]
