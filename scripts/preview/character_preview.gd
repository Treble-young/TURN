extends Node2D

var health_label: Label
var spawn_timer: float = 3.0
var game_over: bool = false
var experience_label: Label
var experience_bar: ProgressBar
var level_notice: Label
var level_notice_time: float = 0.0

func _ready() -> void:
	y_sort_enabled = true
	health_label = Label.new()
	health_label.position = Vector2(32, 94)
	$UI.add_child(health_label)
	$Player.health_changed.connect(_update_health)
	$Player.died.connect(_show_game_over)
	_update_health($Player.health, $Player.max_health)
	_build_experience_ui()
	for location in [Vector2(200, 300), Vector2(930, 300), Vector2(280, 560)]:
		_spawn("goblin", location)
	_spawn("slime_large", Vector2(850, 550))

func _process(delta: float) -> void:
	level_notice_time = maxf(0.0, level_notice_time - delta)
	level_notice.visible = level_notice_time > 0.0
	if $Player.is_dead:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = 3.0
		if get_tree().get_nodes_in_group("enemies").size() < 25:
			var angle := randf() * TAU
			_spawn("slime_large" if randf() < 0.25 else "goblin", $Player.position + Vector2.from_angle(angle) * 400.0)

func _spawn(kind: String, location: Vector2) -> void:
	var enemy := load("res://scenes/enemies/%s.tscn" % kind).instantiate() as EclipseEnemy
	enemy.position = location
	add_child(enemy)

func _update_health(current: float, maximum: float) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]

func _show_game_over() -> void:
	if game_over:
		return
	game_over = true
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(center)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	center.add_child(list)
	var label := Label.new()
	label.text = "GAME OVER"
	label.add_theme_font_size_override("font_size", 36)
	list.add_child(label)
	var retry := Button.new()
	retry.text = "RETRY"
	retry.custom_minimum_size = Vector2(260, 48)
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	list.add_child(retry)
	var main_menu := Button.new()
	main_menu.text = "MAIN MENU"
	main_menu.custom_minimum_size.y = 48
	main_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	list.add_child(main_menu)
	retry.grab_focus()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("171d29"))
	for x in range(0, 1153, 48):
		draw_line(Vector2(x, 0), Vector2(x, 648), Color("222c3c"))
	for y in range(0, 649, 48):
		draw_line(Vector2(0, y), Vector2(1152, y), Color("222c3c"))

func _build_experience_ui() -> void:
	experience_label = Label.new()
	experience_label.position = Vector2(32, 124)
	$UI.add_child(experience_label)
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(32, 154)
	experience_bar.size = Vector2(280, 16)
	experience_bar.show_percentage = false
	experience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("8cda50")
	fill.set_corner_radius_all(4)
	experience_bar.add_theme_stylebox_override("fill", fill)
	$UI.add_child(experience_bar)
	level_notice = Label.new()
	level_notice.position = Vector2(32, 182)
	level_notice.add_theme_color_override("font_color", Color("e5c68b"))
	level_notice.add_theme_font_size_override("font_size", 24)
	level_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(level_notice)
	$Player.experience_progress.experience_changed.connect(_update_experience)
	$Player.leveled_up.connect(func(level: int):
		level_notice.text = "LEVEL UP!  Lv. %d" % level
		level_notice_time = 2.0
	)
	_update_experience($Player.experience_progress.level, $Player.experience_progress.experience, $Player.experience_progress.experience_required())

func _update_experience(level: int, current: int, required: int) -> void:
	if required == 0:
		experience_label.text = "Lv. %d / %d    MAX" % [level, $Player.experience_progress.max_level]
		experience_bar.max_value = 1
		experience_bar.value = 1
	else:
		experience_label.text = "Lv. %d / %d    EXP %d / %d" % [level, $Player.experience_progress.max_level, current, required]
		experience_bar.max_value = required
		experience_bar.value = current
