extends RefCounted

const TYPES := ["专精光", "专精影", "专精轮换", "状态时长控制"]
const SKILLS := {
	"light_damage": {"name":"光刃","type":0,"max":3,"description":"光形态伤害每级+10%。"},
	"charge": {"name":"凝光","type":0,"max":3,"description":"满蓄力时间每级缩短10%，最多30%。"},
	"light_speed": {"name":"逐光","type":0,"max":3,"description":"光形态移速每级+10%。"},
	"pierce": {"name":"贯日","type":0,"max":3,"description":"每级额外命中1个敌人；每次穿透后当前伤害降低20%。"},
	"falloff": {"name":"长虹","type":0,"max":2,"description":"每级减少10个百分点穿透伤害衰减，满级无衰减。"},
	"size": {"name":"飞光","type":0,"max":3,"description":"每级光刃尺寸+15%、射程+10%。"},
	"slow": {"name":"压制","type":0,"max":3,"description":"光刃命中减速，每级10%，持续3秒。"},
	"full_charge": {"name":"日耀","type":0,"max":2,"description":"满蓄力光刃每级额外增伤25%。"},
	"shadow_damage": {"name":"影刃","type":1,"max":3,"description":"影形态伤害每级+10%。"},
	"attack_speed": {"name":"疾影","type":1,"max":3,"description":"影攻击与连击速度每级+10%。"},
	"sweep": {"name":"横扫","type":1,"max":2,"description":"每级多命中1个目标、近战范围+10%。"},
	"combo": {"name":"连斩","type":1,"max":2,"description":"第三段攻击每级额外增伤30%。"},
	"shadow_speed": {"name":"踏影","type":1,"max":3,"description":"影形态移速每级+10%，最多30%。"},
	"leech": {"name":"汲取","type":1,"max":3,"description":"每消灭3/2/1个敌人恢复1生命。"},
	"dawn": {"name":"破晓","type":2,"max":3,"description":"转为光时眩晕所有非首领敌人2/3/4秒。"},
	"eclipse": {"name":"影蚀","type":2,"max":3,"description":"转为影时对全场造成攻击力80%/100%/120%伤害。"},
	"opening": {"name":"起势","type":2,"max":2,"description":"转换后首次挥击或光刃每级增伤50%。"},
	"mark": {"name":"共灭","type":2,"max":3,"description":"异形态命中消耗印记，追加攻击力40%/60%/80%伤害。"},
	"heal_turn": {"name":"共生","type":2,"max":3,"description":"转换完成恢复2/3/4生命。"},
	"light_long": {"name":"浴光","type":3,"max":5,"description":"每级光形态时长+2秒。"},
	"shadow_long": {"name":"沐影","type":3,"max":5,"description":"每级影形态时长+2秒。"},
	"shadow_short": {"name":"弃影","type":3,"max":5,"description":"每级影形态时长-2秒。"},
	"light_short": {"name":"背光","type":3,"max":5,"description":"每级光形态时长-2秒。"},
}

static func offers(levels: Dictionary, seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var groups := {}
	for id in SKILLS:
		if int(levels.get(id,0)) >= SKILLS[id].max: continue
		var group: int = SKILLS[id].type
		if not groups.has(group): groups[group] = []
		groups[group].append(id)
	var result: Array[String] = []
	var types: Array = groups.keys()
	while not types.is_empty() and result.size() < 3:
		var index := rng.randi_range(0,types.size()-1)
		var group: int = types.pop_at(index)
		var pool: Array = groups[group]
		result.append(pool[rng.randi_range(0,pool.size()-1)])
	return result
