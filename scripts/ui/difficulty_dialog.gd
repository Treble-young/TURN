extends Control

signal confirmed(seed_value: int, difficulty: int)
signal canceled

var selected_difficulty: int = 0
var seed_field: LineEdit
var seed_error: Label
var confirm_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.03, 0.06, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 590
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f0d9ae")
	style.border_color = Color("#67402a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	card.add_child(list)
	var title := Label.new()
	title.text = "选择难度"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	list.add_child(title)
	var group := ButtonGroup.new()
	var descriptions := [
		"标准\n适合新手或第一次游玩",
		"困难\n具有一定挑战性\n敌人生命 +20%，伤害 +20%，经验获取效率 -20%",
		"噩梦\n适合非常熟练的玩家\n敌人生命 +50%，伤害 +50%，经验获取效率 -50%",
	]
	for index in range(3):
		var button := Button.new()
		button.name = "Difficulty%d" % index
		button.text = descriptions[index]
		button.add_theme_font_size_override("font_size", 17)
		button.custom_minimum_size.y = 80
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = index == 0
		button.pressed.connect(func(): selected_difficulty = index)
		list.add_child(button)
	var seed_label := Label.new()
	seed_label.text = "地图种子（留空随机）"
	seed_label.add_theme_font_size_override("font_size", 16)
	list.add_child(seed_label)
	seed_field = LineEdit.new()
	seed_field.name = "Seed"
	seed_field.placeholder_text = "地图种子（留空随机）"
	seed_field.max_length = 10
	seed_field.custom_minimum_size.y = 40
	seed_field.tooltip_text = "输入 0 至 4294967295 的整数，可重现地图和换线点。"
	seed_field.text_changed.connect(func(_text: String): seed_error.hide())
	seed_field.text_submitted.connect(func(_text: String): _confirm())
	list.add_child(seed_field)
	seed_error = Label.new()
	seed_error.text = "种子请输入 0 至 4294967295 的整数。"
	seed_error.add_theme_font_size_override("font_size", 14)
	seed_error.add_theme_color_override("font_color", Color("ffab87"))
	seed_error.hide()
	list.add_child(seed_error)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	list.add_child(actions)
	var back := Button.new()
	back.text = "返回"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.custom_minimum_size.y = 44
	back.pressed.connect(_cancel)
	actions.add_child(back)
	confirm_button = Button.new()
	confirm_button.text = "开启远征"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_confirm)
	actions.add_child(confirm_button)
	hide()

func open() -> void:
	confirm_button.disabled = false
	seed_error.hide()
	show()
	seed_field.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()

func _cancel() -> void:
	hide()
	canceled.emit()

func _confirm() -> void:
	if confirm_button.disabled:
		return
	var source := seed_field.text.strip_edges()
	var seed_value := -1
	if not source.is_empty():
		if not source.is_valid_int() or source.to_int() < 0 or source.to_int() > 4294967295:
			seed_error.show()
			seed_field.grab_focus()
			return
		seed_value = source.to_int()
	confirm_button.disabled = true
	confirmed.emit(seed_value, selected_difficulty)
