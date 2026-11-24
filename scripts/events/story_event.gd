extends Control

const UI := preload("res://scripts/expedition/expedition_ui.gd")
const MAP := "res://scenes/expedition/route_map.tscn"
const DESIGN_SIZE := Vector2(1152, 648)
const BUTTON_SHEET := preload("res://assets/events/choices.png")
const DIALOG := preload("res://assets/events/dialog.png")
const CHOICE_SIZE := Vector2(420, 420.0 * 177.0 / 735.0)

var event: StoryEventDefinition
var stage: Control
var choices: VBoxContainer
var narrative: Label
var shared_header: Control

func _ready() -> void:
	if not Expedition.active or not Expedition.node_pending or Expedition.current_kind != Expedition.Kind.ENCOUNTER:
		get_tree().change_scene_to_file.bind(MAP).call_deferred()
		return
	event = Expedition.current_story_event()
	if event == null:
		push_error("当前层数没有可用事件，请检查 assets/events/catalog.tres")
		return
	MusicManager.set_context(&"non_combat")
	theme = UI.make_theme()
	var backdrop := TextureRect.new()
	backdrop.texture = event.background
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = DESIGN_SIZE
	add_child(stage)
	_picture(event.background, Rect2(0, 0, 1152, 648))
	var portrait := _picture(event.portrait, Rect2(105, 72, 435, 580), true)
	var portrait_clip := Control.new()
	portrait_clip.size = Vector2(555, 440)
	portrait_clip.clip_contents = true
	portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait_clip)
	portrait.reparent(portrait_clip, false)
	choices = VBoxContainer.new()
	choices.position = Vector2(680, 82)
	choices.size = Vector2(CHOICE_SIZE.x, CHOICE_SIZE.y * 3 + 20)
	choices.add_theme_constant_override("separation", 10)
	stage.add_child(choices)
	# The supplied dialogue art includes the speaker tab and transparent margins.
	var dialog_size := Vector2(1132, 1132.0 * DIALOG.get_height() / DIALOG.get_width()) * 0.8
	# Account for the transparent bottom margin in the supplied art: the visible
	# parchment edge ends about 25 design pixels above the screen bottom.
	var dialog_position := Vector2((DESIGN_SIZE.x - dialog_size.x) * 0.5, DESIGN_SIZE.y - dialog_size.y + 12)
	_picture(DIALOG, Rect2(dialog_position, dialog_size), true)
	var speaker := _label(event.npc_name, Rect2(dialog_position + Vector2(62, 62) * 0.8, Vector2(230, 36) * 0.8), 27)
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative = _label(event.story, Rect2(dialog_position + Vector2(56, 155) * 0.8, Vector2(1010, 167) * 0.8), 24)
	narrative.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	shared_header = preload("res://scripts/ui/expedition_header.gd").new()
	add_child(shared_header)
	add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())
	resized.connect(_layout)
	_layout()
	_refresh_choices()

func _layout() -> void:
	if stage == null: return
	var ratio := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	stage.scale = Vector2.ONE * ratio
	stage.position = (size - DESIGN_SIZE * ratio) * 0.5

func _picture(texture: Texture2D, rect: Rect2, keep_aspect: bool = false) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	picture.position = rect.position
	picture.size = rect.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(picture)
	return picture

func _label(text: String, rect: Rect2, font_size: int) -> Label:
	var label := UI.label(text, font_size, Color("#452b17"))
	label.position = rect.position
	label.size = rect.size
	stage.add_child(label)
	return label

func _style(region: Rect2) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = BUTTON_SHEET
	atlas.region = region
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.texture_margin_left = 0
	style.texture_margin_right = 0
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = CHOICE_SIZE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _style(Rect2(21, 113, 735, 177)))
	button.add_theme_stylebox_override("hover", _style(Rect2(779, 113, 735, 177)))
	button.add_theme_stylebox_override("pressed", _style(Rect2(21, 338, 735, 177)))
	button.add_theme_stylebox_override("disabled", _style(Rect2(779, 338, 735, 177)))
	button.add_theme_stylebox_override("focus", _style(Rect2(779, 113, 735, 177)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#452b17"))
	button.add_theme_color_override("font_disabled_color", Color("#796c5d"))
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	choices.add_child(button)
	return button

func _refresh_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	shared_header.refresh()
	if not Expedition.node_pending:
		narrative.text = Expedition.report
		_button("继续旅途", func(): get_tree().change_scene_to_file(MAP))
		return
	for index in event.choices.size():
		var choice := event.choices[index]
		var allowed := Expedition.can_choose_event(index)
		var button := _button(choice.text, _choose.bind(index), not allowed)
		if not allowed:
			button.tooltip_text = "金币不足" if Expedition.gold < choice.gold_cost else "已持有此遗物或生命不足"
		elif not choice.relic_id.is_empty():
			button.tooltip_text = Expedition.ITEMS[choice.relic_id]["effect"]

func _choose(index: int) -> void:
	if not Expedition.choose_event(index): return
	if Expedition.is_battle(Expedition.current_kind):
		for button in choices.get_children(): button.disabled = true
		get_tree().change_scene_to_file("res://scenes/expedition/arena.tscn")
	else:
		_refresh_choices()
