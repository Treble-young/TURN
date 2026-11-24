extends Control

const UI := preload("res://scripts/expedition/expedition_ui.gd")
const MAP := "res://scenes/expedition/route_map.tscn"
const INTRO := [
	"", "", "",
	"商人摊开货物。看看有没有合你心意的物品。",
	"营火还温着。休息可以恢复生命值。",
	"一位旅人愿意分你一些药膏。山崖下也挂着一个钱袋。",
	"石龛里浮出两件物品。你可以带走一件。",
]
const ACCENTS := ["", "", "", "#9a9a63", "#8b9da9", "#a18fa9", "#d2a366"]

var kind: int
var body: VBoxContainer

func _ready() -> void:
	kind = Expedition.current_kind
	if not Expedition.node_pending or kind < Expedition.Kind.SHOP or kind > Expedition.Kind.WISH:
		get_tree().change_scene_to_file.bind(MAP).call_deferred()
		return
	if kind == Expedition.Kind.ENCOUNTER:
		get_tree().change_scene_to_file.bind("res://scenes/events/story_event.tscn").call_deferred()
		return
	MusicManager.set_context(&"non_combat")
	theme = UI.make_theme()
	add_child(preload("res://scripts/ui/expedition_header.gd").new())
	add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 70
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 610
	var card := UI.box(UI.PANEL, Color(ACCENTS[kind]), 1, 8)
	UI.set_margins(card, 33, 25)
	panel.add_theme_stylebox_override("panel", card)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 11)
	panel.add_child(body)
	_refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BACKGROUND)
	if kind < Expedition.Kind.SHOP or kind > Expedition.Kind.WISH:
		return
	var accent := Color(ACCENTS[kind])
	accent.a = 0.20
	var center := size * 0.5
	draw_arc(center, 335, 0, TAU, 120, accent, 1.0, true)
	draw_arc(center, 356, 0, TAU, 120, accent, 1.0, true)
	draw_rect(Rect2(19, 19, size.x - 38, size.y - 38), UI.BORDER, false)

func _refresh() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(UI.label(Expedition.KIND_NAMES[kind], 38, Color(ACCENTS[kind])))
	body.add_child(HSeparator.new())
	if not Expedition.node_pending:
		body.add_child(UI.label(Expedition.report, 17, UI.GOLD))
		body.add_child(UI.action("返回路线图", _return_to_map))
		return
	body.add_child(UI.label(INTRO[kind]))
	if Expedition.pilgrim_entry_healed > 0.0:
		body.add_child(UI.label("旅露圣杯 · 已恢复 %s 点生命" % str(snappedf(Expedition.pilgrim_entry_healed, 0.01)), 16, UI.GOLD))
	match kind:
		Expedition.Kind.SHOP:
			if Expedition.relics.has("merchant_pass"):
				body.add_child(UI.label("行商契约生效 · 商品七折", 16, UI.GOLD))
			for id in Expedition.offers:
				_item_row(id, true)
			if not Expedition.report.is_empty():
				body.add_child(UI.label(Expedition.report, 15, UI.GOLD))
			body.add_child(UI.action("离开商人", _leave_shop))
		Expedition.Kind.REST:
			if Expedition.relics.has("traveler_ink"):
				body.add_child(UI.label("旅人墨契 · 已获得 %d 金币" % Expedition.TRAVELER_GOLD, 16, UI.GOLD))
			if Expedition.rest_entry_healed > 0.0:
				body.add_child(UI.label("营火药囊已恢复 %d 点生命。" % roundi(Expedition.rest_entry_healed), 16, UI.GOLD))
			body.add_child(UI.label("本次休息可恢复 %d 点生命。" % roundi(Expedition.rest_heal_amount()), 16, UI.GOLD))
			body.add_child(UI.action("休息", _rest))
			body.add_child(UI.action("整理背包 · 遗物槽位 +1", _organize))
			body.add_child(UI.label("休息与整理背包只能选择一项。", 15, UI.SOFT))
		Expedition.Kind.ENCOUNTER:
			body.add_child(UI.action("接受药膏 · 回复 8 生命", _encounter.bind(false)))
			var insufficient_life := Expedition.health <= 12.0
			var risk := UI.action("下崖取钱袋 · +18 金币 / −12 生命", _encounter.bind(true), insufficient_life)
			risk.tooltip_text = "生命不足" if insufficient_life else ""
			body.add_child(risk)
		Expedition.Kind.WISH:
			for id in Expedition.offers:
				_item_row(id, false)
			body.add_child(UI.action("放弃领取，继续前进", _leave_wish))

func _item_row(id: String, for_sale: bool) -> void:
	var item: Dictionary = Expedition.ITEMS[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = UI.relic_icon(id)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var name: String = item["name"]
	if item.get("rare", false):
		name += " · 稀有"
	var description := UI.label("%s\n%s" % [name, item["effect"]], 16)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(description)
	var price := Expedition.shop_price(id)
	var blocked := not Expedition.can_receive_relic(id)
	var button := UI.action("购买 · %d 金币" % price, _buy.bind(id), blocked or Expedition.gold < price) if for_sale else UI.action("领取", _wish.bind(id), blocked)
	if blocked: button.tooltip_text = "背包已满或已持有该唯一遗物"
	button.custom_minimum_size.x = 142
	row.add_child(button)
	body.add_child(row)

func _buy(id: String) -> void:
	if Expedition.buy(id):
		_refresh()

func _leave_shop() -> void:
	Expedition.complete_shop()
	_return_to_map()

func _rest() -> void:
	Expedition.complete_rest()
	_refresh()

func _organize() -> void:
	if Expedition.organize_backpack(): _refresh()

func _leave_wish() -> void:
	Expedition.leave_wish()
	_refresh()

func _encounter(risk: bool) -> void:
	Expedition.complete_encounter(risk)
	_refresh()

func _wish(id: String) -> void:
	Expedition.complete_wish(id)
	_refresh()

func _return_to_map() -> void:
	if not Expedition.node_pending:
		get_tree().change_scene_to_file(MAP)
