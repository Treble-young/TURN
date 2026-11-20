extends Node2D

var health_label: Label
var spawn_timer: float = 3.0
var game_over: bool = false

func _ready() -> void:
	y_sort_enabled = true
	health_label = Label.new()
	health_label.position = Vector2(32, 94)
	$UI.add_child(health_label)
	$Player.health_changed.connect(_update_health)
	$Player.died.connect(_show_game_over)
	_update_health($Player.health, $Player.max_health)
	for location in [Vector2(200, 300), Vector2(930, 300), Vector2(280, 560)]:
		_spawn("goblin", location)
	_spawn("slime_large", Vector2(850, 550))

func _process(delta: float) -> void:
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
