extends Node2D

const ENCOUNTER := preload("res://scripts/expedition/battle_encounter.gd")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const MAP := "res://scenes/expedition/route_map.tscn"
const FIELD := Rect2(40, 107, 1072, 498)
const GOLD := Color("#e5c082")
const TEXT := Color("#e6ded3")
const SPAWN_POINTS := [
	Vector2(230, 216), Vector2(922, 216), Vector2(228, 507),
	Vector2(925, 507), Vector2(578, 200), Vector2(578, 519),
]

@onready var player: EclipsePlayer = $Player
@onready var hud: CanvasLayer = $HUD
var font: SystemFont
var status_label: Label
var health_label: Label
var wave_label: Label
var experience_bar: ProgressBar
var progress: ExperienceProgress
var waves: Array = []
var wave_index := -1
var intermission := -1.0
var collecting := false
var finished := false
var initial_experience := 0

func _ready() -> void:
	if not Expedition.active or not Expedition.node_pending or not Expedition.is_battle(Expedition.current_kind):
		get_tree().change_scene_to_file.bind(MAP).call_deferred()
		return
	y_sort_enabled = true
	progress = player.experience_progress
	progress.level = Expedition.level
	progress.experience = Expedition.experience
	progress.total_experience = Expedition.total_experience
	initial_experience = progress.total_experience
	player.max_health = Expedition.max_health(progress.level)
	player.attack_damage = Expedition.damage(progress.level)
	player.enhanced_light_blade = Expedition.relics.has("light_blade")
	player.light_blade_range *= 1.0 + 0.25 * int(Expedition.relics.get("light_range", 0))
	player.light_blade_extra_hits = int(Expedition.relics.get("light_pierce", 0))
	player.move_speed = Expedition.speed()
	player.health = Expedition.health
	waves = ENCOUNTER.waves_for(Expedition.current_kind, Expedition.floor_number)
	_build_hud()
	player.health_changed.connect(_update_health)
	player.died.connect(_defeat)
	progress.experience_changed.connect(_update_experience)
	progress.leveled_up.connect(_level_up)
	_update_health(player.health, player.max_health)
	_update_experience(progress.level, progress.experience, progress.experience_required())
	_spawn_next_wave()

func _process(delta: float) -> void:
	if not is_instance_valid(progress) or finished or player.is_dead or player.is_transforming:
		return
	player.position = player.position.clamp(FIELD.position + Vector2(16, 32), FIELD.end - Vector2(16, 12))
	if collecting:
		var orbs := get_tree().get_nodes_in_group("experience_pickups")
		for node in orbs:
			var orb := node as ExperienceOrb
			orb.attracted = true
		if orbs.is_empty():
			_victory()
		return
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		return
	if wave_index == waves.size() - 1:
		collecting = true
		player.lock_combat()
		wave_label.text = "战斗完成 · 正在拾取经验"
		return
	if intermission < 0.0:
		intermission = 1.15
		wave_label.text = "下一波即将到来"
	intermission -= delta
	if intermission <= 0.0:
		_spawn_next_wave()

func _spawn_next_wave() -> void:
	intermission = -1.0
	wave_index += 1
	var units: Array = waves[wave_index]
	for index in units.size():
		var spot: Vector2 = SPAWN_POINTS[(index + 3 * wave_index) % SPAWN_POINTS.size()]
		if spot.distance_to(player.position) < 135.0:
			spot = FIELD.get_center() * 2.0 - spot
		_spawn(units[index], spot)
	wave_label.text = "第 %d / %d 波" % [wave_index + 1, waves.size()]

func _spawn(kind: String, spot: Vector2) -> void:
	var is_boss := kind == "boss"
	var enemy := ENEMY_SCENE.instantiate() as EclipseEnemy
	var stats := ENCOUNTER.stats_for(kind).duplicate() as EnemyStats
	var floor_scale := 1.0 + 0.13 * (Expedition.floor_number - 1)
	var hard := Expedition.current_kind != Expedition.Kind.BATTLE
	stats.max_health *= floor_scale * (1.21 if hard else 1.0)
	stats.damage *= floor_scale * (1.15 if hard else 1.0)
	if hard:
		stats.experience_reward = ceili(stats.experience_reward * 1.55)
	if is_boss:
		stats.display_name = ENCOUNTER.BOSS_NAME
		stats.max_health *= 2.2
		stats.damage *= 1.30
		stats.visual_scale *= 1.32
		stats.attack_range += 15.0
		stats.body_radius += 7.0
		stats.experience_reward = 40 + Expedition.floor_number * 4
		enemy.modulate = Color("#ffd6bd")
	enemy.stats = stats
	enemy.position = spot
	add_child(enemy)

func _level_up(new_level: int) -> void:
	var bonus := Expedition.max_health(new_level) - player.max_health
	player.max_health += bonus
	player.health = minf(player.max_health, player.health + bonus)
	player.attack_damage = Expedition.damage(new_level)
	_update_health(player.health, player.max_health)

func _victory() -> void:
	finished = true
	var result := Expedition.win_battle(player.health, progress)
	var message := "%s\n拾取 %d 经验 · 等级 %d" % [result, progress.total_experience - initial_experience, progress.level]
	_result("战斗胜利", message, "查看远征结果" if Expedition.won else "返回路线图")

func _defeat() -> void:
	finished = true
	Expedition.lose_battle(progress)
	_result("勇者倒下了", "本次远征止步于第 %d 层。" % Expedition.floor_number, "查看远征结果")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("#141721"))
	draw_rect(FIELD, Color("#252839"))
	draw_rect(FIELD, Color("#75604c"), false, 2.0)
	for x in range(74, 1100, 48):
		draw_line(Vector2(x, FIELD.position.y), Vector2(x, FIELD.end.y), Color("#2e3144"))
	for y in range(131, 600, 48):
		draw_line(Vector2(FIELD.position.x, y), Vector2(FIELD.end.x, y), Color("#2e3144"))
	var center := FIELD.get_center()
	draw_arc(center, 147.0, 0.0, TAU, 96, Color("#424054"), 1.0, true)
	draw_arc(center, 164.0, 0.0, TAU, 96, Color("#424054"), 1.0, true)

func _build_hud() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var title := "第 %d 层  /  %s" % [Expedition.floor_number, Expedition.KIND_NAMES[Expedition.current_kind]]
	_add_label(title, Vector2(40, 16), Vector2(304, 39), 25, GOLD)
	wave_label = _add_label("", Vector2(42, 58), Vector2(300, 26), 16, TEXT)
	health_label = _add_label("", Vector2(371, 19), Vector2(215, 34), 20, TEXT)
	status_label = _add_label("", Vector2(632, 19), Vector2(478, 34), 19, TEXT)
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(632, 59)
	experience_bar.size = Vector2(306, 13)
	experience_bar.show_percentage = false
	experience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#91bb78")
	fill.set_corner_radius_all(4)
	experience_bar.add_theme_stylebox_override("fill", fill)
	hud.add_child(experience_bar)
	_add_label("WASD / 方向键移动   ·   空格 / 左键攻击   ·   Esc 暂停", Vector2(42, 610), Vector2(1068, 30), 15, TEXT)

func _add_label(value: String, at: Vector2, area: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = area
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	hud.add_child(label)
	return label

func _update_health(current: float, maximum: float) -> void:
	health_label.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]

func _update_experience(level: int, current: int, required: int) -> void:
	status_label.text = "等级 %d    经验 %d / %d" % [level, current, required] if required > 0 else "等级 %d    已满级" % level
	experience_bar.max_value = maxf(1.0, required)
	experience_bar.value = current if required > 0 else 1.0

func _result(title: String, message: String, action: String) -> void:
	player.lock_combat()
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.76)
	dim.size = Vector2(1152, 648)
	hud.add_child(dim)
	var card := PanelContainer.new()
	card.position = Vector2(346, 171)
	card.size = Vector2(460, 306)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#272128")
	style.border_color = GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 23
	style.content_margin_bottom = 23
	card.add_theme_stylebox_override("panel", style)
	dim.add_child(card)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 16)
	card.add_child(contents)
	for value in [[title, 32, GOLD], [message, 18, TEXT]]:
		var label := Label.new()
		label.text = value[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", value[1])
		label.add_theme_color_override("font_color", value[2])
		if value[1] == 18:
			label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		contents.add_child(label)
	var button := Button.new()
	button.text = action
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func(): get_tree().change_scene_to_file(MAP))
	contents.add_child(button)
	button.grab_focus()
