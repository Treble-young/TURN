extends CanvasLayer
const UI := preload("res://scripts/expedition/expedition_ui.gd")
const SHEET := preload("res://assets/events/choices.png")
const PAPER := preload("res://assets/ui/route/background.png")
var experience_gained := 0
var stage: Control
var cards: HBoxContainer
var next_button: Button
var picker: Node
func _ready() -> void:
	layer = 90
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.06,0.04,0.04,0.92)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	root.add_child(stage)
	stage.size = Vector2(1152,648)
	root.resized.connect(_layout)
	_layout()
	var title := UI.label("战斗胜利",34,UI.GOLD)
	title.position = Vector2(50,28)
	title.size = Vector2(500,45)
	stage.add_child(title)
	var detail := UI.label("拾取经验 %d · 当前等级 %d" % [experience_gained,Expedition.level],18)
	detail.position = Vector2(52,80)
	detail.size = Vector2(700,30)
	stage.add_child(detail)
	cards = HBoxContainer.new()
	cards.position = Vector2(70,135)
	cards.add_theme_constant_override("separation",25)
	stage.add_child(cards)
	picker = null
	for child in get_parent().get_children():
		if child.get_script() == preload("res://scripts/upgrades/upgrade_picker.gd"): picker = child
	if picker != null: picker.completed.connect(_refresh)
	next_button = _button("继续前进", _continue)
	next_button.position = Vector2(820,555)
	next_button.size = Vector2(260,260.0*177/735)
	stage.add_child(next_button)
	_refresh()
func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ratio := minf(viewport_size.x/1152, viewport_size.y/648)
	stage.scale = Vector2.ONE*ratio
	stage.position = (viewport_size-Vector2(1152,648)*ratio)/2
func _style(region: Rect2) -> StyleBoxTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SHEET
	texture.region = region
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(210,210.0*177/735)
	button.add_theme_stylebox_override("normal",_style(Rect2(21,113,735,177)))
	button.add_theme_stylebox_override("hover",_style(Rect2(779,113,735,177)))
	button.add_theme_stylebox_override("pressed",_style(Rect2(21,338,735,177)))
	button.add_theme_stylebox_override("disabled",_style(Rect2(779,338,735,177)))
	for state in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state,Color("#452b17"))
	button.pressed.connect(callback)
	return button
func _card(title: String, icon: Texture2D, text: String, action: String, callback: Callable, disabled: bool, skip: bool = false) -> void:
	var card := Control.new()
	card.custom_minimum_size = Vector2(290,395)
	cards.add_child(card)
	var art := TextureRect.new()
	art.texture = PAPER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picture := Node2D.new()
	card.add_child(picture)
	var ratio := minf(120.0/icon.get_width(),120.0/icon.get_height())
	var icon_size := icon.get_size()*ratio
	picture.draw.connect(func(): picture.draw_texture_rect(icon,Rect2(Vector2(85,35)+(Vector2(120,120)-icon_size)/2,icon_size),false))
	var heading := UI.label(title,25,Color("#452b17"))
	heading.position = Vector2(20,165)
	heading.size = Vector2(250,36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(heading)
	var description := UI.label(text,17,Color("#452b17"))
	description.position = Vector2(25,210)
	description.size = Vector2(240,83)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(description)
	var button := _button(action,callback,disabled)
	button.position = Vector2(40,300)
	button.size = button.custom_minimum_size
	card.add_child(button)
	if skip:
		var leave := Button.new()
		leave.text = "放弃此遗物"
		leave.position = Vector2(70,355)
		leave.size = Vector2(150,28)
		leave.pressed.connect(_skip_relic)
		card.add_child(leave)
func _refresh() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var reward: Dictionary = Expedition.battle_rewards
	_card("金币", preload("res://assets/ui/stats/gold.png"), "× %d" % reward.gold, "已领取" if reward.gold_claimed else "领取金币", _gold, reward.gold_claimed)
	var id: String = reward.relic
	var received: bool = reward.relic_claimed
	var relic_icon: Texture2D = preload("res://assets/ui/route/treasure.tres") if id.is_empty() else UI.relic_icon(id)
	var description := "本场未掉落遗物" if id.is_empty() else str(Expedition.ITEMS[id].name)+"\n"+str(Expedition.ITEMS[id].effect)
	if not id.is_empty() and not received and not Expedition.can_receive_relic(id): description += "\n背包已满或已持有唯一遗物"
	_card("遗物",relic_icon,description,"已处理" if received else "领取遗物",_relic,received or not Expedition.can_receive_relic(id),not received)
	_card("升级",preload("res://assets/ui/stats/level.png"),"可选择强化 × %d" % Expedition.pending_upgrades,"选择强化" if Expedition.pending_upgrades > 0 else "已完成",_upgrade,Expedition.pending_upgrades <= 0)
	next_button.disabled = not reward.gold_claimed or not reward.relic_claimed or Expedition.pending_upgrades > 0
	next_button.tooltip_text = "请领取金币、领取或放弃遗物，并完成强化选择。" if next_button.disabled else ""
func _gold() -> void:
	Expedition.claim_battle_gold()
	_refresh()
func _relic() -> void:
	Expedition.claim_battle_relic()
	_refresh()
func _skip_relic() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定放弃这件遗物？"
	stage.add_child(dialog)
	dialog.confirmed.connect(func():
		Expedition.skip_battle_relic()
		_refresh()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
func _upgrade() -> void:
	if picker != null: picker.begin()
func _continue() -> void:
	if next_button.disabled: return
	get_tree().change_scene_to_file("res://scenes/expedition/route_map.tscn")
