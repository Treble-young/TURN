extends CanvasLayer

signal closed
@export var main_menu_mode: bool = false

var panel: Control
var resume_button: Button
var seed_value: Label
var window_options: OptionButton
var volume_sliders: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_menu()
	panel.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if main_menu_mode and not panel.visible:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if panel.visible:
			resume_game()
		elif not get_tree().paused:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	seed_value.text = "种子：%d" % Expedition.run_seed if not main_menu_mode and not Expedition.maps.is_empty() else "种子：开始游戏时确定"
	panel.show()
	get_tree().paused = true
	resume_button.grab_focus()

func resume_game() -> void:
	Settings.save_settings()
	panel.hide()
	get_tree().paused = false
	get_viewport().gui_release_focus()
	closed.emit()

func _build_menu() -> void:
	panel = Control.new()
	panel.name = "PauseOverlay"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.theme = preload("res://scripts/ui/parchment_theme.gd").make()
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.02,0.035,0.7)
	panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Control.new()
	panel.add_child(stage)
	stage.size = Vector2(1152,648)
	var layout := func():
		var viewport_size := get_viewport().get_visible_rect().size
		var ratio := minf(viewport_size.x/1152,viewport_size.y/648)
		stage.scale = Vector2.ONE*ratio
		stage.position = (viewport_size-Vector2(1152,648)*ratio)/2
	panel.resized.connect(layout)
	layout.call()
	var paper := TextureRect.new()
	paper.texture = preload("res://assets/ui/parchment/card.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.position = Vector2(351,24)
	paper.size = Vector2(450,600)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(paper)
	var card := ScrollContainer.new()
	card.position = Vector2(396,78)
	card.size = Vector2(360,510)
	stage.add_child(card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(list)
	var title := Label.new()
	title.text = "选项设置" if main_menu_mode else "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#63401e"))
	list.add_child(title)
	for entry in [["总音量", "Master"], ["背景音乐音量", "Music"], ["游戏音量", "SFX"]]:
		_add_volume_row(list, entry[0], entry[1])
	var window_label := Label.new()
	window_label.text = "窗口大小"
	var window_row := HBoxContainer.new()
	window_label.custom_minimum_size.x = 105
	window_row.add_child(window_label)
	list.add_child(window_row)
	window_options = OptionButton.new()
	window_options.custom_minimum_size.y = 40
	for size in Settings.WINDOW_SIZES:
		window_options.add_item("%d × %d" % [size.x, size.y])
	window_options.add_item("全屏")
	window_options.select(Settings.window_size_index)
	window_options.item_selected.connect(func(index: int):
		Settings.apply_window_size(index)
		Settings.save_settings()
	)
	window_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_row.add_child(window_options)
	seed_value = Label.new()
	seed_value.name = "RunSeed"
	seed_value.text = "种子：开始游戏时确定"
	seed_value.add_theme_font_size_override("font_size", 16)
	seed_value.add_theme_color_override("font_color", Color("#63401e"))
	list.add_child(seed_value)
	if Settings.is_editor_embedded():
		var hint := Label.new()
		hint.text = "当前为编辑器内嵌预览，窗口设置将在独立运行时生效。\n测试窗口大小：关闭“下次运行时嵌入游戏”后重新运行。"
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color("#63401e"))
		list.add_child(hint)
	resume_button = Button.new()
	resume_button.text = "返回（Esc）" if main_menu_mode else "继续游戏（Esc）"
	resume_button.custom_minimum_size.y = 60
	resume_button.pressed.connect(resume_game)
	list.add_child(resume_button)
	var main_menu_button := Button.new()
	main_menu_button.name = "ReturnToMainMenu"
	main_menu_button.visible = not main_menu_mode
	main_menu_button.text = "返回主界面"
	main_menu_button.custom_minimum_size.y = 60
	main_menu_button.pressed.connect(_return_to_main_menu)
	list.add_child(main_menu_button)
	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size.y = 60
	quit_button.pressed.connect(func():
		Settings.save_settings()
		get_tree().quit()
	)
	list.add_child(quit_button)

func _return_to_main_menu() -> void:
	Settings.save_settings()
	var tree := get_tree()
	var result := tree.change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if result == OK:
		tree.paused = false
	else:
		push_error("Unable to return to main menu: %s" % error_string(result))

func _add_volume_row(list: VBoxContainer, label_text: String, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 105
	label.add_theme_font_size_override("font_size",16)
	var percent := Label.new()
	percent.text = "%d%%" % roundi(Settings.volumes[bus]*100)
	percent.custom_minimum_size.x = 44
	percent.add_theme_font_size_override("font_size",16)
	var slider := preload("res://scripts/ui/parchment_slider.gd").new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = Settings.volumes[bus]*100
	slider.custom_minimum_size = Vector2(150,32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float):
		Settings.set_volume(bus,value/100)
		percent.text = "%d%%" % roundi(value))
	volume_sliders[bus] = slider
	row.add_child(label)
	row.add_child(slider)
	row.add_child(percent)
	list.add_child(row)
