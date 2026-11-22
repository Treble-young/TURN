extends Node

enum Kind { BATTLE, ELITE, BOSS, SHOP, REST, ENCOUNTER, WISH }

const FLOOR_COUNT := 5
const LANE_COUNT := 3
const STAGE_COUNT := 6
const SWITCH_COST := 6
const STARTING_GOLD := 15
const BASE_HEALTH := 100.0
const BASE_DAMAGE := 18.0
const BASE_SPEED := 240.0
const HEALTH_PER_LEVEL := 4.0
const DAMAGE_PER_LEVEL := 2.0
const NORMAL_DROP := 0.12
const ELITE_DROP := 0.30
const DROP_PER_XP := 0.0015
const MAX_XP_DROP_BONUS := 0.30
const KIND_NAMES := ["战斗", "困难战斗", "首领战斗", "商人", "休息处", "不期而遇", "得偿所愿"]
const KIND_DETAILS := [
	"清除一波敌人。战胜后获得金币，并有机会获得物品。",
	"迎战两波更强的敌人，获得更多经验和金币。",
	"击败本层首领，必定获得一件物品。",
	"用金币购买物品。可以购买多件，也可以直接离开。",
	"休息可回复 35% 最大生命。",
	"途中遇见旅人。你可以接受药膏，或冒险取回金币。",
	"从石龛里出现的两件物品中选一件。",
]
const ITEMS := {
	"blade": {"name": "磨锋石", "effect": "攻击伤害 +4", "price": 18},
	"heart": {"name": "琥珀护符", "effect": "生命上限 +12，并回复 12 生命", "price": 22},
	"boots": {"name": "巡路靴", "effect": "移动速度 +20", "price": 17},
	"coin": {"name": "旧王钱币", "effect": "每场胜利额外获得 3 金币", "price": 16},
}

var rng := RandomNumberGenerator.new()
var maps: Array = []
var crossings: Array[Array] = []
var run_seed := 0
var floor_number := 1
var stage := -1
var lane := -1
var gold := 0
var health := BASE_HEALTH
var level := 1
var experience := 0
var total_experience := 0
var relics: Dictionary = {}
var visited: Array[Vector2i] = []
var offers: Array[String] = []
var current_kind: int = -1
var node_pending := false
var active := false
var won := false
var report := ""

func start_run(requested_seed: int = -1) -> void:
	if requested_seed < 0:
		rng.randomize()
		run_seed = rng.randi()
	else:
		run_seed = requested_seed
	rng.seed = run_seed
	maps.clear()
	crossings.clear()
	for _floor_index in range(FLOOR_COUNT):
		maps.append(_generate_floor())
		crossings.append(_generate_crossings())
	floor_number = 1
	stage = -1
	lane = -1
	gold = STARTING_GOLD
	health = BASE_HEALTH
	level = 1
	experience = 0
	total_experience = 0
	relics.clear()
	visited.clear()
	offers.clear()
	current_kind = -1
	node_pending = false
	active = true
	won = false
	report = ""

func _generate_floor() -> Array:
	var first: Array[int] = [Kind.BATTLE, Kind.BATTLE, Kind.ELITE]
	var pool: Array[int] = [
		Kind.BATTLE, Kind.BATTLE, Kind.BATTLE, Kind.BATTLE,
		Kind.ELITE, Kind.ELITE, Kind.SHOP, Kind.SHOP, Kind.REST, Kind.REST,
		Kind.ENCOUNTER, Kind.WISH,
	]
	_shuffle(first)
	_shuffle(pool)
	var result: Array = [first]
	for index in range(0, pool.size(), LANE_COUNT):
		result.append(pool.slice(index, index + LANE_COUNT))
	result.append([Kind.BOSS])
	return result

func _generate_crossings() -> Array[Vector3i]:
	var stages: Array[int] = [1, 2, 3, 4]
	var lanes: Array[int] = [0, 1, 2]
	_shuffle(stages)
	_shuffle(lanes)
	var result: Array[Vector3i] = []
	for index in LANE_COUNT:
		var source := lanes[index]
		var target := 1
		if source == 1:
			target = 0 if rng.randi_range(0, 1) == 0 else 2
		result.append(Vector3i(stages[index], source, target))
	return result

func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value

func current_map() -> Array:
	return maps[floor_number - 1]

func has_route(from_lane: int, to_stage: int, to_lane: int) -> bool:
	if to_stage == STAGE_COUNT - 1:
		return to_lane == 0
	return from_lane == to_lane or crossings[floor_number - 1].has(Vector3i(to_stage, from_lane, to_lane))

func has_crossing(from_stage: int, from_lane: int) -> bool:
	for crossing: Vector3i in crossings[floor_number - 1]:
		if crossing.x == from_stage + 1 and crossing.y == from_lane:
			return true
	return false

func travel_cost(to_stage: int, to_lane: int) -> int:
	if stage < 0 or to_stage == STAGE_COUNT - 1 or lane == to_lane:
		return 0
	return SWITCH_COST

func can_reach(to_stage: int, to_lane: int) -> bool:
	if not active or node_pending or to_stage != stage + 1 or to_stage >= STAGE_COUNT:
		return false
	var row: Array = current_map()[to_stage]
	return to_lane >= 0 and to_lane < row.size() and (stage < 0 or has_route(lane, to_stage, to_lane))

func enter_node(to_stage: int, to_lane: int) -> bool:
	if not can_reach(to_stage, to_lane):
		return false
	var cost := travel_cost(to_stage, to_lane)
	if gold < cost:
		return false
	gold -= cost
	stage = to_stage
	lane = to_lane
	visited.append(Vector2i(stage, lane))
	current_kind = current_map()[stage][lane]
	node_pending = true
	report = ""
	offers.clear()
	if current_kind == Kind.SHOP or current_kind == Kind.WISH:
		var choices: Array = ITEMS.keys()
		_shuffle(choices)
		var count := 3 if current_kind == Kind.SHOP else 2
		for index in count:
			offers.append(choices[index])
	return true

func is_battle(kind: int) -> bool:
	return kind in [Kind.BATTLE, Kind.ELITE, Kind.BOSS]

func max_health(at_level: int = 0) -> float:
	if at_level == 0:
		at_level = level
	return BASE_HEALTH + (at_level - 1) * HEALTH_PER_LEVEL + 12.0 * relics.get("heart", 0)

func damage(at_level: int) -> float:
	return BASE_DAMAGE + (at_level - 1) * DAMAGE_PER_LEVEL + 4.0 * relics.get("blade", 0)

func speed() -> float:
	return BASE_SPEED + 20.0 * relics.get("boots", 0)

func drop_chance(kind: int) -> float:
	if kind == Kind.BOSS:
		return 1.0
	var base := ELITE_DROP if kind == Kind.ELITE else NORMAL_DROP
	return base + minf(MAX_XP_DROP_BONUS, total_experience * DROP_PER_XP)

func _award_item(id: String) -> void:
	relics[id] = int(relics.get(id, 0)) + 1
	if id == "heart":
		health = minf(max_health(), health + 12.0)

func buy(id: String) -> bool:
	if not node_pending or current_kind != Kind.SHOP or not offers.has(id):
		return false
	var price: int = ITEMS[id]["price"]
	if gold < price:
		return false
	gold -= price
	offers.erase(id)
	_award_item(id)
	report = "购入%s · %s" % [ITEMS[id]["name"], ITEMS[id]["effect"]]
	return true

func complete_shop() -> void:
	if node_pending and current_kind == Kind.SHOP:
		node_pending = false

func complete_rest() -> void:
	if node_pending and current_kind == Kind.REST:
		var healed := minf(max_health() - health, ceilf(max_health() * 0.35))
		health += healed
		report = "休整完毕 · 回复 %d 生命" % roundi(healed)
		node_pending = false

func complete_encounter(take_risk: bool) -> void:
	if not node_pending or current_kind != Kind.ENCOUNTER:
		return
	if take_risk and health > 12.0:
		health -= 12.0
		gold += 18
		report = "取回钱袋 · 获得 18 金币，失去 12 生命"
	elif not take_risk:
		var healed := minf(max_health() - health, 8.0)
		health += healed
		report = "接受旅人的药膏 · 回复 %d 生命" % roundi(healed)
	else:
		return
	node_pending = false

func complete_wish(id: String) -> void:
	if node_pending and current_kind == Kind.WISH and offers.has(id):
		_award_item(id)
		report = "得偿所愿 · 获得%s，%s" % [ITEMS[id]["name"], ITEMS[id]["effect"]]
		node_pending = false

func win_battle(remaining_health: float, progress: ExperienceProgress) -> String:
	if not node_pending or not is_battle(current_kind):
		return report
	level = progress.level
	experience = progress.experience
	total_experience = progress.total_experience
	health = clampf(remaining_health, 0.0, max_health())
	var base_gold := 12
	if current_kind == Kind.ELITE:
		base_gold = 21
	elif current_kind == Kind.BOSS:
		base_gold = 32
	var earned := base_gold + 2 * (floor_number - 1) + 3 * int(relics.get("coin", 0))
	gold += earned
	var result := "获得 %d 金币" % earned
	if rng.randf() < drop_chance(current_kind) or current_kind == Kind.BOSS:
		var item_ids: Array = ITEMS.keys()
		var id: String = item_ids[rng.randi_range(0, item_ids.size() - 1)]
		_award_item(id)
		result += "\n获得%s · %s" % [ITEMS[id]["name"], ITEMS[id]["effect"]]
	var defeated_boss := current_kind == Kind.BOSS
	node_pending = false
	current_kind = -1
	report = result
	if defeated_boss:
		if floor_number == FLOOR_COUNT:
			active = false
			won = true
		else:
			floor_number += 1
			stage = -1
			lane = -1
			visited.clear()
	return result

func lose_battle(progress: ExperienceProgress) -> void:
	health = 0.0
	level = progress.level
	experience = progress.experience
	total_experience = progress.total_experience
	node_pending = false
	active = false
	won = false
