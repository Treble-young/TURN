extends Node

enum Difficulty { STANDARD, HARD, NIGHTMARE }
const DIFFICULTY_NAMES := ["标准", "困难", "噩梦"]
const ENEMY_MULTIPLIERS := [1.0, 1.2, 1.5]
const EXPERIENCE_PERCENT := [100, 80, 50]
var difficulty: Difficulty = Difficulty.STANDARD
var experience_remainder: float = 0.0

enum Kind { BATTLE, ELITE, BOSS, SHOP, REST, ENCOUNTER, WISH }

const FLOOR_COUNT := 5
const LANE_COUNT := 3
const STAGE_COUNT := 7
const EMPTY_NODE := -1
const CROSSINGS_PER_FLOOR := 7
const LATERAL_CROSSING_COST := 5
const STARTING_GOLD := 15
const BASE_HEALTH := 100.0
const BASE_DAMAGE := 18.0
const BASE_SPEED := 240.0
const HEALTH_PER_LEVEL := 4.0
const DAMAGE_PER_LEVEL := 2.0
const REST_HEAL_FRACTION := 0.35
const REST_ENTRY_BONUS := 12.0
const TRAVELER_GOLD := 8
const PILGRIM_HEAL := 2.0
const SHOP_DISCOUNT := 0.70
const ENEMY_HEALTH_WITH_CURSE := 0.85
const COMMON_ITEM_WEIGHT := 10
const RARE_ITEM_WEIGHT := 2
const NORMAL_DROP := 0.12
const ELITE_DROP := 0.30
const DROP_PER_XP := 0.0015
const MAX_XP_DROP_BONUS := 0.30
const KIND_NAMES := ["常规交锋", "强敌试炼", "宿命对决", "道中行商", "休憩之所", "命运所指", "得偿所愿"]
const KIND_DETAILS := [
	"清除一波敌人。战胜后获得金币，并有机会获得物品。",
	"迎战两波更强的敌人，获得更多经验和金币。",
	"击败本层首领，必定获得一件物品。",
	"用金币购买物品，获得攻击、生命、护盾或金币收益等增益。可以购买多件，也可以直接离开。",
	"在营火旁休息可以恢复生命值。",
	"邂逅不同的人物并作出选择。事件随层数变化，部分选择可能触发战斗。",
	"石龛会出现三件遗物。任选一件免费带走。",
]
# icon 按图集从左到右、从上到下编号。
const ITEMS := {
	"blood_rose": {"icon_path":"res://assets/ui/relics/blood_rose.png", "name":"染血玫瑰", "effect":"获得时立即恢复所有生命值。", "price":16, "unique":true, "full_heal":true},
	"fine_soft_armor": {"icon": 0, "name": "精良软甲", "effect": "战斗中每次形态切换完成后，获得 5 点护盾。", "price": 16, "unique": true, "event_only": true},
	"blade": {"icon": 4, "name": "磨锋石", "effect": "攻击伤害 +4", "price": 18},
	"heart": {"icon": 5, "name": "琥珀护符", "effect": "生命上限 +12，并回复 12 生命", "price": 22, "max_health": 12, "heal_on_acquire": 12},
	"coin": {"icon": 6, "name": "旧王钱币", "effect": "每场胜利额外获得 3 金币", "price": 16},
	"victory_badge": {"icon": 7, "name": "凯旋徽章", "effect": "战斗胜利获得的金币 +20%，向上取整。", "price": 22, "unique": true},
	"eclipse_shield": {"icon": 11, "name": "日蚀护镜", "effect": "开战获得最大生命 30% 的护盾。每次切换光影形态补充当时生命 10% 的护盾，战斗结束后清空。", "price": 32, "rare": true, "unique": true},
	"merchant_pass": {"icon": 12, "name": "行商契约", "effect": "持有时，商店内所有商品按原价七折出售。", "price": 30, "rare": true, "unique": true},
	"camp_kit": {"icon": 13, "name": "营火药囊", "effect": "进入休憩之所时立刻额外恢复 12 点生命。", "price": 20, "unique": true},
	"frailty_seal": {"icon": 14, "name": "衰弱印记", "effect": "战斗中所有敌人的最大生命值降低 15%。", "price": 27, "unique": true},
	"soul_lantern": {"icon": 15, "name": "引魂灯", "effect": "经验吸收效率 +25%。", "price": 19, "unique": true},
	"stone_bracer": {"icon": 16, "name": "断石臂环", "effect": "受到远程攻击时，伤害降低 15%。", "price": 22, "unique": true},
	"homeward_ember": {"icon": 17, "name": "归途火种", "effect": "赢得强敌试炼后，恢复 8 点生命。", "price": 21, "unique": true},
	"salvage_die": {"icon": 18, "name": "拾遗骰", "effect": "每层第一次普通战斗未掉落遗物时，按原概率重投一次。", "price": 24, "unique": true},
	"traveler_ink": {"icon": 19, "name": "旅人墨契", "effect": "每层首次完成事件以及每次进入休憩之所时，额外获得 8 金币。", "price": 22, "unique": true},
	"phoenix_feather": {"icon": 20, "name": "不死鸟之羽", "effect": "本次远征首次触发致命伤时，以最大生命值的 50% 复活。仅可触发一次。", "price": 42, "rare": true, "weight": 1, "unique": true},
	"pilgrim_chalice": {"icon": 21, "name": "旅露圣杯", "effect": "每次进入非战斗节点时，恢复 2 点生命。", "price": 34, "rare": true, "weight": 1, "unique": true},
}

const SKILLS := preload("res://scripts/upgrades/skill_catalog.gd")
var battle_rewards: Dictionary = {}
var upgrades: Dictionary = {}
var pending_upgrades := 0
var upgrade_choices: Array[String] = []
var upgrades_chosen := 0

var rng := RandomNumberGenerator.new()
var maps: Array = []
var crossings: Array[Array] = []
var lateral_crossings: Array[Array] = []
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
var relic_capacity := 6
var event_followup: StoryEventDefinition
var story_catalog: Resource
var event_attack_bonus := 0.0
var rest_entry_healed := 0.0
var pilgrim_entry_healed := 0.0
var revival_spent := false
var salvage_used_floor := 0
var traveler_rewarded_floor := 0
var event_battle_pending := false
var visited: Array[Vector2i] = []
var offers: Array[String] = []
var current_kind: int = -1
var node_pending := false
var active := false
var won := false
var report := ""
var assigned_levels: Dictionary = {}

func start_run(requested_seed: int = -1, selected_difficulty: int = Difficulty.STANDARD) -> void:
	battle_rewards.clear()
	upgrades.clear()
	pending_upgrades = 0
	upgrade_choices.clear()
	upgrades_chosen = 0
	difficulty = clampi(selected_difficulty, 0, 2) as Difficulty
	experience_remainder = 0
	if requested_seed < 0:
		rng.randomize()
		run_seed = rng.randi()
	else:
		run_seed = requested_seed
	rng.seed = run_seed
	maps.clear()
	crossings.clear()
	lateral_crossings.clear()
	for _floor_index in range(FLOOR_COUNT):
		var rows: Array
		var links: Dictionary
		while true:
			rows = _generate_floor()
			links = _generate_links(rows)
			if not links.is_empty(): break
		maps.append(rows)
		crossings.append(links.diagonal)
		lateral_crossings.append(links.lateral)
	var library = load("res://assets/maps/map_library.tres")
	assigned_levels = library.assign_levels(maps, run_seed)
	floor_number = 1
	stage = -1
	lane = -1
	gold = STARTING_GOLD
	health = BASE_HEALTH
	level = 1
	experience = 0
	total_experience = 0
	relics.clear()
	relic_capacity = 6
	event_attack_bonus = 0.0
	rest_entry_healed = 0.0
	pilgrim_entry_healed = 0.0
	revival_spent = false
	salvage_used_floor = 0
	traveler_rewarded_floor = 0
	event_battle_pending = false
	event_followup = null
	visited.clear()
	offers.clear()
	current_kind = -1
	node_pending = false
	active = _level_assignment_complete()
	won = false
	report = "" if active else "关卡库配置不足，请补充符合层数限制的关卡。"

func _level_assignment_complete() -> bool:
	for floor_index in range(maps.size()):
		for row in range(maps[floor_index].size()):
			for slot in range(maps[floor_index][row].size()):
				if is_battle(maps[floor_index][row][slot]) and not assigned_levels.has("%d:%d:%d" % [floor_index + 1, row, slot]):
					return false
	return true

func _generate_floor() -> Array:
	var first: Array[int] = [Kind.BATTLE,Kind.BATTLE,Kind.ELITE]
	_shuffle(first)
	var pool: Array[int] = [Kind.SHOP,Kind.REST,Kind.SHOP if rng.randi_range(0,1)==0 else Kind.REST,
		Kind.BATTLE,Kind.BATTLE,Kind.BATTLE,Kind.ELITE,Kind.ELITE,EMPTY_NODE,EMPTY_NODE,
		Kind.WISH,Kind.WISH,Kind.ENCOUNTER,Kind.ENCOUNTER,Kind.ENCOUNTER if rng.randi_range(0,1)==0 else Kind.BATTLE]
	while true:
		_shuffle(pool)
		var rows: Array = [first]
		for index in range(0,15,3): rows.append(pool.slice(index,index+3))
		rows.append([Kind.BOSS])
		if not rows[5].has(EMPTY_NODE): continue
		var gaps: Array[int] = []
		var services := {}
		var events := {}
		var treasures := {}
		var valid := true
		for row in range(1,6):
			for col in 3:
				var kind: int = rows[row][col]
				if kind == EMPTY_NODE:
					for prior in gaps:
						if absi(prior-row)<=1: valid = false
					gaps.append(row)
				var used: Dictionary = services if kind in [Kind.SHOP,Kind.REST] else (events if kind==Kind.ENCOUNTER else treasures)
				if kind in [Kind.SHOP,Kind.REST,Kind.ENCOUNTER,Kind.WISH]:
					if used.has(col): valid = false
					used[col] = true
		if valid: return rows
	return []

func _generate_links(rows: Array) -> Dictionary:
	for attempt in 400:
		var diagonal: Array[Vector3i] = []
		var lateral: Array[Vector2i] = []
		var occupied := {}
		for row in range(1,6):
			var gap: int = rows[row].find(EMPTY_NODE)
			if gap < 0: continue
			var choices: Array[int] = []
			for col in [gap-1,gap+1]:
				if col>=0 and col<3 and rows[row][col]!=EMPTY_NODE: choices.append(col)
			diagonal.append(Vector3i(row,gap,choices[rng.randi_range(0,choices.size()-1)]))
			occupied[row-1] = 1
		var possible: Array[Vector3i] = []
		for source in range(0,5):
			for col in 3:
				if rows[source][col]==EMPTY_NODE: continue
				for to in [col-1,col+1]:
					var edge := Vector3i(source+1,col,to)
					if to>=0 and to<3 and rows[source+1][to]!=EMPTY_NODE and not diagonal.has(edge): possible.append(edge)
		_shuffle(possible)
		for edge in possible:
			if diagonal.size()==5: break
			var source: int = edge.x-1
			if occupied.get(source,0)>=2: continue
			diagonal.append(edge)
			occupied[source] = occupied.get(source,0)+1
		var flat: Array[Vector2i] = []
		for row in range(1,6):
			if not rows[row].has(EMPTY_NODE):
				for left in 2: flat.append(Vector2i(row,left))
		_shuffle(flat)
		for edge in flat:
			if lateral.size()==2: break
			if occupied.get(edge.x,0)>=2: continue
			lateral.append(edge)
			occupied[edge.x] = occupied.get(edge.x,0)+1
		if diagonal.size()==5 and lateral.size()==2 and _all_nodes_connected(rows,diagonal,lateral): return {"diagonal":diagonal,"lateral":lateral}
	return {}

func _all_nodes_connected(rows: Array, diagonal: Array[Vector3i], lateral: Array[Vector2i]) -> bool:
	var reached := {0:true,1:true,2:true}
	for row in range(1,6):
		var next := {}
		for col in 3:
			if rows[row][col]!=EMPTY_NODE and reached.has(col): next[col] = true
		for link in diagonal:
			if link.x == row and reached.has(link.y): next[link.z] = true
		for pass_index in 3:
			for link in lateral:
				if link.x == row and (next.has(link.y) or next.has(link.y+1)):
					next[link.y] = true
					next[link.y+1] = true
		for col in 3:
			if rows[row][col]!=EMPTY_NODE and not next.has(col): return false
		reached = next
	return true

func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[other]
		values[other] = value

func has_lateral_route(row: int, from_lane: int, to_lane: int) -> bool:
	if not node_exists_at(row, from_lane) or not node_exists_at(row, to_lane):
		return false
	var slots: Array = current_map()[row]
	if slots.size() != LANE_COUNT or slots.has(EMPTY_NODE):
		return false
	return absi(from_lane - to_lane) == 1 and lateral_crossings[floor_number - 1].has(Vector2i(row, mini(from_lane, to_lane)))

func current_map() -> Array:
	return maps[floor_number - 1]

func node_exists_at(row: int, slot: int) -> bool:
	if row < 0 or row >= STAGE_COUNT:
		return false
	var slots: Array = current_map()[row]
	return slot >= 0 and slot < slots.size() and slots[slot] != EMPTY_NODE

func has_route(from_lane: int, to_stage: int, to_lane: int) -> bool:
	if not node_exists_at(to_stage - 1, from_lane) or not node_exists_at(to_stage, to_lane):
		return false
	if to_stage == STAGE_COUNT - 1:
		return true
	return from_lane == to_lane or crossings[floor_number - 1].has(Vector3i(to_stage, from_lane, to_lane))

func has_crossing(from_stage: int, from_lane: int) -> bool:
	for crossing: Vector3i in crossings[floor_number - 1]:
		if crossing.x == from_stage + 1 and crossing.y == from_lane:
			return true
	return false

func can_reach(to_stage: int, to_lane: int, check_balance: bool = true) -> bool:
	if not active or node_pending or not node_exists_at(to_stage, to_lane) or visited.has(Vector2i(to_stage, to_lane)):
		return false
	if to_stage == stage:
		return has_lateral_route(stage, lane, to_lane) and (not check_balance or gold >= LATERAL_CROSSING_COST)
	return to_stage == stage + 1 and (stage < 0 or has_route(lane, to_stage, to_lane))

func enter_node(to_stage: int, to_lane: int) -> bool:
	if not can_reach(to_stage, to_lane):
		return false
	# 确认节点时先扣路费，入场获得的金币不能预付同排路费。
	if to_stage == stage:
		gold -= LATERAL_CROSSING_COST
	stage = to_stage
	lane = to_lane
	visited.append(Vector2i(stage, lane))
	current_kind = current_map()[stage][lane]
	node_pending = true
	report = ""
	rest_entry_healed = 0.0
	pilgrim_entry_healed = 0.0
	event_battle_pending = false
	event_followup = null
	# 入场奖励在节点确认时发放，因此休息或整理背包都能享受同一份奖励。
	if not is_battle(current_kind) and relics.has("pilgrim_chalice"):
		pilgrim_entry_healed = _heal(PILGRIM_HEAL)
	if current_kind == Kind.REST and relics.has("traveler_ink"):
		gold += TRAVELER_GOLD
	offers.clear()
	if current_kind == Kind.SHOP or current_kind == Kind.WISH:
		for _index in 3:
			var id := _roll_item(offers)
			if id.is_empty():
				break
			offers.append(id)
	elif current_kind == Kind.REST and relics.has("camp_kit"):
		rest_entry_healed = _heal(REST_ENTRY_BONUS)
	return true

func is_battle(kind: int) -> bool:
	return kind in [Kind.BATTLE, Kind.ELITE, Kind.BOSS]

func max_health(at_level: int = 0) -> float:
	if at_level == 0:
		at_level = level
	var maximum := BASE_HEALTH + (at_level - 1) * HEALTH_PER_LEVEL
	for id: String in relics:
		var item: Dictionary = ITEMS[id]
		maximum += float(item.get("max_health", 0)) * int(relics[id])
	return maximum

func damage(at_level: int) -> float:
	return event_attack_bonus + BASE_DAMAGE + (at_level - 1) * DAMAGE_PER_LEVEL + 4.0 * relics.get("blade", 0)

func drop_chance(kind: int) -> float:
	if kind == Kind.BOSS:
		return 1.0
	var base := ELITE_DROP if kind == Kind.ELITE else NORMAL_DROP
	return base + minf(MAX_XP_DROP_BONUS, total_experience * DROP_PER_XP)

func _item_roll_weight(id: String, common_only: bool) -> int:
	var item: Dictionary = ITEMS[id]
	var rare: bool = item.get("rare", false)
	if item.get("event_only", false) or (common_only and rare) or _unique_relic_unavailable(id):
		return 0
	return item.get("weight", RARE_ITEM_WEIGHT if rare else COMMON_ITEM_WEIGHT)

func _roll_item(excluded: Array[String] = [], common_only: bool = false) -> String:
	var weights := {}
	var total_weight := 0
	for id: String in ITEMS:
		if excluded.has(id):
			continue
		var weight := _item_roll_weight(id, common_only)
		if weight <= 0:
			continue
		weights[id] = weight
		total_weight += weight
	if total_weight <= 0:
		return ""
	var roll := rng.randi_range(1, total_weight)
	for id: String in weights:
		roll -= weights[id]
		if roll <= 0:
			return id
	return ""

func _heal(amount: float) -> float:
	var before := health
	health = minf(max_health(), health + amount)
	return health - before

func _award_item(id: String) -> String:
	if not can_receive_relic(id): return "背包已满或已持有该唯一遗物"
	var item: Dictionary = ITEMS[id]
	relics[id] = int(relics.get(id, 0)) + 1
	if item.get("full_heal",false): _heal(max_health())
	var instant_heal: float = item.get("heal_on_acquire", 0.0)
	if instant_heal > 0.0:
		_heal(instant_heal)
	return item["effect"]

func shop_price(id: String) -> int:
	var base_price: int = ITEMS[id]["price"]
	return roundi(base_price * SHOP_DISCOUNT) if relics.has("merchant_pass") else base_price

func enemy_health_modifier() -> float:
	return ENEMY_HEALTH_WITH_CURSE if active and node_pending and is_battle(current_kind) and relics.has("frailty_seal") else 1.0

func buy(id: String) -> bool:
	if not node_pending or current_kind != Kind.SHOP or not offers.has(id) or not can_receive_relic(id):
		return false
	var price := shop_price(id)
	if gold < price:
		return false
	gold -= price
	offers.erase(id)
	report = "购入%s · %s" % [ITEMS[id]["name"], _award_item(id)]
	return true

func complete_shop() -> void:
	if node_pending and current_kind == Kind.SHOP:
		node_pending = false

func rest_heal_amount(include_entry_bonus: bool = false) -> float:
	var amount := ceilf(max_health() * REST_HEAL_FRACTION)
	if include_entry_bonus and relics.has("camp_kit"):
		amount += REST_ENTRY_BONUS
	return minf(max_health() - health, amount)

func complete_rest() -> void:
	if node_pending and current_kind == Kind.REST:
		var healed := _heal(rest_heal_amount())
		report = "休整完毕 · 共回复 %d 生命" % roundi(rest_entry_healed + healed)
		node_pending = false

func organize_backpack() -> bool:
	if not active or not node_pending or current_kind != Kind.REST: return false
	relic_capacity += 1
	report = "整理背包 · 遗物槽位 +1，当前容量 %d" % relic_capacity
	node_pending = false
	return true

func complete_encounter(take_risk: bool) -> void:
	if not node_pending or current_kind != Kind.ENCOUNTER:
		return
	if take_risk and health > 12.0:
		health -= 12.0
		gold += 18
		report = "取回钱袋 · 获得 18 金币，失去 12 生命"
	elif not take_risk:
		var healed := _heal(8.0)
		report = "接受旅人的药膏 · 回复 %d 生命" % roundi(healed)
	else:
		return
	report += _reward_event_completion()
	node_pending = false

func complete_wish(id: String) -> void:
	if node_pending and current_kind == Kind.WISH and offers.has(id) and can_receive_relic(id):
		report = "得偿所愿 · 获得%s，%s" % [ITEMS[id]["name"], _award_item(id)]
		node_pending = false

func leave_wish() -> void:
	if node_pending and current_kind == Kind.WISH:
		report = "你没有带走遗物，继续踏上旅途。"
		node_pending = false

func win_battle(remaining_health: float, progress: ExperienceProgress, defer_rewards: bool = false) -> String:
	if not node_pending or not is_battle(current_kind):
		return report
	level = progress.level
	experience = progress.experience
	total_experience = progress.total_experience
	health = clampf(remaining_health, 0.0, max_health())
	var base_gold := 6
	if current_kind == Kind.ELITE:
		base_gold = 10
	elif current_kind == Kind.BOSS:
		base_gold = 14
	var earned := base_gold + 2 * (floor_number - 1) + 3 * int(relics.get("coin", 0))
	if relics.has("victory_badge"):
		earned = ceili(earned * 1.20)
	battle_rewards = {"gold": earned, "gold_claimed": not defer_rewards, "relic": "", "relic_claimed": true}
	if not defer_rewards: gold += earned
	var result := "获得 %d 金币" % earned
	if current_kind == Kind.ELITE and relics.has("homeward_ember"):
		var healed := _heal(8.0)
		if healed > 0.0:
			result += "\n归途火种 · 回复 %s 生命" % str(snappedf(healed, 0.01))
	var drop_probability := drop_chance(current_kind)
	var dropped := rng.randf() < drop_probability or current_kind == Kind.BOSS
	# 首次普通节点掉落判定失败时消耗本层重投机会，沿用原概率。
	if not dropped and current_kind == Kind.BATTLE and not event_battle_pending and salvage_used_floor != floor_number and relics.has("salvage_die"):
		salvage_used_floor = floor_number
		dropped = rng.randf() < drop_probability
		result += "\n拾遗骰 · 已重投本场遗物掉落"
	if dropped:
		var id := _roll_item()
		if not id.is_empty():
			if defer_rewards:
				battle_rewards.relic = id
				battle_rewards.relic_claimed = false
			elif can_receive_relic(id):
				result += "\n获得%s · %s" % [ITEMS[id]["name"], _award_item(id)]
			else:
				result += "\n背包已满，无法携带掉落的%s。" % ITEMS[id]["name"]
	# 战斗型事件通关后才算完成，因此墨契奖励在此结算。
	if event_battle_pending:
		result += _reward_event_completion()
		event_battle_pending = false
	event_followup = null
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

func current_story_event() -> StoryEventDefinition:
	if event_followup != null: return event_followup
	if story_catalog == null: story_catalog = load("res://assets/events/catalog.tres")
	return story_catalog.pick(floor_number, run_seed, stage, lane)

func can_choose_event(index: int) -> bool:
	if not active or not node_pending or current_kind != Kind.ENCOUNTER: return false
	var event := current_story_event()
	if event == null or index < 0 or index >= event.choices.size(): return false
	var choice := event.choices[index]
	if choice.exchange_relic: return used_relic_slots() > 0
	if choice.random_common_relic:
		if used_relic_slots() >= relic_capacity or not ITEMS.keys().any(func(id: String): return _item_roll_weight(id, true) > 0):
			return false
	return gold >= choice.gold_cost and (choice.health_cost <= 0.0 or health > choice.health_cost) and (choice.relic_id.is_empty() or can_receive_relic(choice.relic_id))

func choose_event(index: int) -> bool:
	if not can_choose_event(index): return false
	var choice := current_story_event().choices[index]
	if choice.exchange_relic: return false
	var reward_won := choice.reward_chance >= 1.0 or rng.randf() < choice.reward_chance
	var prize_id := _roll_item([], true) if reward_won and choice.random_common_relic else ""
	if reward_won and choice.random_common_relic and not can_receive_relic(prize_id):
		return false
	gold -= choice.gold_cost
	if reward_won: gold += choice.gold_reward
	health -= choice.health_cost
	_heal(choice.heal)
	event_attack_bonus += choice.attack_bonus
	if not choice.relic_id.is_empty(): _award_item(choice.relic_id)
	report = choice.result_text if reward_won else choice.failure_text
	if not prize_id.is_empty():
		report += "\n获得%s · %s" % [ITEMS[prize_id]["name"], _award_item(prize_id)]
	if not reward_won and choice.retry_on_failure:
		return true
	if choice.next_event is StoryEventDefinition:
		event_followup = choice.next_event
		return true
	if choice.battle_map != null:
		get_tree().set_meta("battle_map_override", choice.battle_map.resource_path)
		current_kind = Kind.BATTLE
		event_battle_pending = true
	else:
		report += _reward_event_completion()
		node_pending = false
	return true

func used_relic_slots() -> int:
	var count := 0
	for amount: int in relics.values(): count += amount
	return count

func can_receive_relic(id: String) -> bool:
	return ITEMS.has(id) and used_relic_slots() < relic_capacity and not _unique_relic_unavailable(id)

func _unique_relic_unavailable(id: String) -> bool:
	return (id == "phoenix_feather" and revival_spent) or (ITEMS[id].get("unique", false) and relics.has(id))

## 由玩家受致命伤时调用。消耗遗物，并记录本轮远征已复活。
func try_use_revival() -> bool:
	if not active or not node_pending or not is_battle(current_kind) or revival_spent or not relics.has("phoenix_feather"):
		return false
	revival_spent = true
	relics.erase("phoenix_feather")
	return true

func _reward_event_completion() -> String:
	if traveler_rewarded_floor == floor_number or not relics.has("traveler_ink"):
		return ""
	traveler_rewarded_floor = floor_number
	gold += TRAVELER_GOLD
	return "\n旅人墨契 · 获得 %d 金币" % TRAVELER_GOLD

func exchange_event_relic(index: int, discarded_id: String) -> bool:
	if not can_choose_event(index) or not relics.has(discarded_id): return false
	var choice := current_story_event().choices[index]
	if not choice.exchange_relic: return false
	var previous := relics.duplicate()
	relics[discarded_id] -= 1
	if relics[discarded_id] <= 0: relics.erase(discarded_id)
	var excluded: Array[String] = [discarded_id]
	var received_id := _roll_item(excluded)
	if received_id.is_empty() or not can_receive_relic(received_id):
		relics = previous
		return false
	var effect := _award_item(received_id)
	health = minf(health, max_health())
	report = "你将%s放上天平，它随光芒消失。\n获得%s · %s" % [ITEMS[discarded_id]["name"], ITEMS[received_id]["name"], effect]
	report += _reward_event_completion()
	node_pending = false
	return true

func skill(id: String) -> int:
	return int(upgrades.get(id, 0))

func next_upgrade_choices() -> Array[String]:
	if pending_upgrades <= 0: return []
	if upgrade_choices.is_empty():
		upgrade_choices = SKILLS.offers(upgrades, hash("skills:%d:%d" % [run_seed,upgrades_chosen]))
	return upgrade_choices.duplicate()

func choose_upgrade(id: String) -> bool:
	if pending_upgrades <= 0 or not id in upgrade_choices: return false
	if skill(id) >= SKILLS.SKILLS[id].max: return false
	upgrades[id] = skill(id) + 1
	pending_upgrades -= 1
	upgrades_chosen += 1
	upgrade_choices.clear()
	return true

func claim_battle_gold() -> bool:
	if battle_rewards.is_empty() or battle_rewards.gold_claimed: return false
	gold += int(battle_rewards.gold)
	battle_rewards.gold_claimed = true
	return true

func claim_battle_relic() -> bool:
	if battle_rewards.is_empty() or battle_rewards.relic_claimed: return false
	var id: String = battle_rewards.relic
	if not can_receive_relic(id): return false
	_award_item(id)
	battle_rewards.relic_claimed = true
	return true

func skip_battle_relic() -> void:
	if not battle_rewards.is_empty(): battle_rewards.relic_claimed = true

func accept_rest_commission() -> bool:
	if not active or not node_pending or current_kind != Kind.REST: return false
	gold += 8
	report = "你替营地的旅人整理好物资，获得了8枚金币作为报酬。"
	node_pending = false
	return true
