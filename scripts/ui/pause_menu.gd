extends CanvasLayer

var panel: Control
var resume_button: Button
var window_options: OptionButton
var volume_sliders: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_menu()
	panel.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if panel.visible:
			resume_game()
		elif not get_tree().paused:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	panel.show()
	get_tree().paused = true
	resume_button.grab_focus()

func resume_game() -> void:
	Settings.save_settings()
	panel.hide()
	get_tree().paused = false
	get_viewport().gui_release_focus()

func _build_menu() -> void:
	panel = Control.new()
	panel.name = "PauseOverlay"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	theme.default_font = font
	theme.default_font_size = 20
	panel.theme = theme
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.03, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 480
	var style := StyleBoxFlat.new()
	style.bg_color = Color("202333")
	style.border_color = Color("bc9d65")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	card.add_child(list)
	var title := Label.new()
	title.text = "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("e5c68b"))
	list.add_child(title)
	for entry in [["总音量", "Master"], ["背景音乐音量", "Music"], ["游戏音量", "SFX"]]:
		_add_volume_row(list, entry[0], entry[1])
	var window_label := Label.new()
	window_label.text = "窗口大小"
	list.add_child(window_label)
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
	list.add_child(window_options)
	if Settings.is_editor_embedded():
		var hint := Label.new()
		hint.text = "当前为编辑器内嵌预览，窗口设置将在独立运行时生效。\n测试窗口大小：关闭“下次运行时嵌入游戏”后重新运行。"
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color("e5c68b"))
		list.add_child(hint)
	resume_button = Button.new()
	resume_button.text = "继续游戏（Esc）"
	resume_button.custom_minimum_size.y = 46
	resume_button.pressed.connect(resume_game)
	list.add_child(resume_button)
	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size.y = 46
	quit_button.pressed.connect(func():
		Settings.save_settings()
		get_tree().quit()
	)
	list.add_child(quit_button)

func _add_volume_row(list: VBoxContainer, label_text: String, bus: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var percent := Label.new()
	percent.text = "%d%%" % roundi(Settings.volumes[bus] * 100)
	row.add_child(label)
	row.add_child(percent)
	list.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = Settings.volumes[bus] * 100
	slider.custom_minimum_size.y = 22
	slider.value_changed.connect(func(value: float):
		Settings.set_volume(bus, value / 100.0)
		percent.text = "%d%%" % roundi(value)
	)
	volume_sliders[bus] = slider
	list.add_child(slider)
