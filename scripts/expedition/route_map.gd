extends Control

const ARENA := "res://scenes/expedition/arena.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const PAPER := Rect2(22, 77, 753, 549)
const INK := Color("#533727")
const GOLD := Color("#e8bd72")
const TEXT := Color("#f6e5c6")
const SOFT := Color("#c8ad89")
const ROUTE_OFFSETS := [Vector2(0, 0), Vector2(-10, 9), Vector2(10, -5), Vector2(6, -7), Vector2(-8, 3)]
const KIND_MARKS := ["战", "险", "王", "商", "歇", "遇", "愿"]
const KIND_COLORS := ["#623a31", "#863a2b", "#572b38", "#45584a", "#405866", "#585274", "#7c572c"]

var layout: Control
var paper_texture: NoiseTexture2D

func _ready() -> void:
	theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	theme.default_font = font
	theme.default_font_size = 17
	_prepare_paper()
	_refresh()

func _prepare_paper() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.018
	noise.fractal_octaves = 5
	var tones := Gradient.new()
	tones.colors = PackedColorArray([Color("#c5a073"), Color("#e7c694")])
	paper_texture = NoiseTexture2D.new()
	paper_texture.width = 768
	paper_texture.height = 560
	paper_texture.color_ramp = tones
	paper_texture.noise = noise
	paper_texture.changed.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1b1718"))
	draw_line(Vector2(22, 65), Vector2(1130, 65), Color("#584033"))
	draw_rect(Rect2(790, 77, 340, 549), Color("#2b2120"))
	draw_rect(Rect2(790, 77, 340, 549), Color("#674837"), false)
	draw_rect(PAPER, Color("#d3a973"))
	if paper_texture:
		draw_texture_rect(paper_texture, PAPER, false)
	draw_rect(PAPER.grow(-9), Color("#8c613e"), false, 2.0)
	draw_rect(PAPER.grow(-13), Color("#aa7d50"), false)
	if Expedition.maps.is_empty():
		return
	var rows := Expedition.current_map()
	for row in range(1, rows.size()):
		for from_lane in rows[row - 1].size():
			for to_lane in rows[row].size():
				if Expedition.has_route(from_lane, row, to_lane):
					_draw_link(row, from_lane, to_lane)

func _draw_link(row: int, from_lane: int, to_lane: int) -> void:
	var from := _point(row - 1, from_lane)
	var destination := _point(row, to_lane)
	var previous := Expedition.visited.has(Vector2i(row - 1, from_lane))
	var followed := previous and Expedition.visited.has(Vector2i(row, to_lane))
	var next := previous and Expedition.can_reach(row, to_lane) and Expedition.gold >= Expedition.travel_cost(row, to_lane)
	var color := Color("#a17a54")
	var thickness := 1.5
	if followed:
		color = Color("#5e3b2c")
		thickness = 3.0
	elif next:
		color = Color("#744125")
		thickness = 2.5
	var lift := Vector2(0.0, (from.y - destination.y) * 0.55)
	var sway := Vector2.ZERO
	if absf(from.x - destination.x) < 44.0:
		sway.x = 38.0 if (row + from_lane) % 2 == 0 else -38.0
	var curve := Curve2D.new()
	curve.bake_interval = 4.0
	curve.add_point(from, Vector2.ZERO, sway - lift)
	curve.add_point(destination, sway + lift)
	if row < Expedition.STAGE_COUNT - 1 and from_lane != to_lane:
		var length := curve.get_baked_length()
		var offset := 0.0
		while offset < length:
			var end := minf(offset + 6.0, length)
			draw_line(curve.sample_baked(offset), curve.sample_baked(end), color, thickness, true)
			offset += 12.0
	else:
		draw_polyline(curve.get_baked_points(), color, thickness, true)

func _point(row: int, lane_index: int) -> Vector2:
	var y := 547.0 - row * 84.0
	if row == Expedition.STAGE_COUNT - 1:
		return Vector2(380.0, y)
	var offset: Vector2 = ROUTE_OFFSETS[(row + lane_index + Expedition.floor_number - 1) % ROUTE_OFFSETS.size()]
	return Vector2(174.0 + lane_index * 206.0, y) + offset

func _refresh() -> void:
	if is_instance_valid(layout):
		remove_child(layout)
		layout.queue_free()
	layout = Control.new()
	add_child(layout)
	_build_header()
	if not Expedition.maps.is_empty():
		_build_map()
	_build_panel()
	queue_redraw()

func _build_header() -> void:
	_place_label("ECLIPSE  /  远征路线", Vector2(23, 10), Vector2(320, 48), 24, GOLD)
	var values := "生命 %d / %d     金币 %d     等级 %d     累计经验 %d" % [
		roundi(Expedition.health), roundi(Expedition.max_health()), Expedition.gold, Expedition.level, Expedition.total_experience,
	]
	_place_label(values, Vector2(529, 12), Vector2(600, 44), 19, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

func _build_map() -> void:
	var floor_title := "第 %d 层" % Expedition.floor_number
	_place_label(floor_title, Vector2(49, 100), Vector2(137, 38), 26, INK)
	for floor_index in Expedition.FLOOR_COUNT:
		var color := Color("#a07954")
		if floor_index + 1 == Expedition.floor_number:
			color = INK
		_place_label(str(floor_index + 1), Vector2(563 + 34 * floor_index, 103), Vector2(25, 28), 16, color, HORIZONTAL_ALIGNMENT_CENTER)
	var rows := Expedition.current_map()
	for row in rows.size():
		for lane_index in rows[row].size():
			var kind: int = rows[row][lane_index]
			var center := _point(row, lane_index)
			var cost := Expedition.travel_cost(row, lane_index)
			var reachable := Expedition.can_reach(row, lane_index)
			var visited := Expedition.visited.has(Vector2i(row, lane_index))
			var enabled := reachable and Expedition.gold >= cost
			var button := Button.new()
			button.text = KIND_MARKS[kind]
			button.position = center - Vector2(24, 24)
			button.size = Vector2(48, 48)
			button.disabled = not enabled
			button.tooltip_text = Expedition.KIND_NAMES[kind]
			if visited:
				button.tooltip_text += " · 已经过"
			elif reachable and cost > 0:
				button.tooltip_text += " · 改道消耗 %d 金币" % cost
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.add_theme_font_size_override("font_size", 21)
			var tint := Color(KIND_COLORS[kind])
			button.add_theme_stylebox_override("normal", _style(tint, GOLD, 2, 24))
			button.add_theme_stylebox_override("hover", _style(tint.lightened(0.19), Color("#fff0b5"), 3, 24))
			button.add_theme_stylebox_override("pressed", _style(tint.darkened(0.2), GOLD, 2, 24))
			var muted_tint := tint.lerp(Color("#e3bb87"), 0.72)
			button.add_theme_stylebox_override("disabled", _style(tint if visited else muted_tint, INK if visited else Color("#9f7653"), 1, 24))
			button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("#fff2c7"), 2, 24))
			button.add_theme_color_override("font_color", TEXT)
			button.add_theme_color_override("font_disabled_color", TEXT if visited else INK)
			button.pressed.connect(_enter.bind(row, lane_index))
			layout.add_child(button)
			var caption: String = Expedition.KIND_NAMES[kind]
			if reachable and cost > 0:
				caption += " · %d 金" % cost
			var label := _place_label(caption, center + Vector2(-88, 24), Vector2(176, 23), 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
			label.add_theme_color_override("font_outline_color", Color("#d7b481"))
			label.add_theme_constant_override("outline_size", 4)

func _build_panel() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(811, 95)
	panel.size = Vector2(298, 0)
	panel.add_theme_constant_override("separation", 10)
	layout.add_child(panel)
	if not Expedition.active:
		_panel_text(panel, "远征完成" if Expedition.won else "远征结束", 27, GOLD)
		_panel_text(panel, "你击败了五层的首领。" if Expedition.won else "你在第 %d 层倒下。" % Expedition.floor_number)
		_panel_text(panel, "等级 %d · 累计经验 %d · 金币 %d" % [Expedition.level, Expedition.total_experience, Expedition.gold])
		_action(panel, "开始新的远征", _new_run)
		_action(panel, "返回主菜单", func(): get_tree().change_scene_to_file(MAIN_MENU))
	elif not Expedition.node_pending:
		_panel_text(panel, "选择下一步", 26, GOLD)
		_panel_text(panel, "沿连线前进。直行免费，切换到相邻路线需 %d 金币。已走过的节点无法返回。" % Expedition.SWITCH_COST)
		_panel_text(panel, "实线通往同一路线或首领，虚线通往相邻路线。", 15, SOFT)
		if not Expedition.report.is_empty():
			_panel_text(panel, Expedition.report, 16, GOLD)
	else:
		_panel_text(panel, Expedition.KIND_NAMES[Expedition.current_kind], 26, GOLD)
		match Expedition.current_kind:
			Expedition.Kind.SHOP:
				for id in Expedition.offers:
					_item_action(panel, id, true)
				if not Expedition.report.is_empty():
					_panel_text(panel, Expedition.report, 15, GOLD)
				_action(panel, "离开商人", _leave_shop)
			Expedition.Kind.REST:
				_panel_text(panel, "营火还温着。休息可以回复 35% 最大生命。")
				_action(panel, "休息并继续", _rest)
			Expedition.Kind.ENCOUNTER:
				_panel_text(panel, "一位旅人愿意分你一些药膏。山崖下也挂着一个钱袋。")
				_action(panel, "接受药膏 · 回复 8 生命", _encounter.bind(false))
				_action(panel, "下崖取钱袋 · +18 金币 / −12 生命", _encounter.bind(true), Expedition.health <= 12.0)
			Expedition.Kind.WISH:
				_panel_text(panel, "石龛里浮出两件物品。你可以带走一件。")
				for id in Expedition.offers:
					_item_action(panel, id, false)
	_build_inventory()

func _build_inventory() -> void:
	var items := PackedStringArray()
	for id in Expedition.relics:
		items.append("%s ×%d" % [Expedition.ITEMS[id]["name"], Expedition.relics[id]])
	_place_label("随身物品", Vector2(812, 486), Vector2(260, 29), 17, GOLD)
	var list := _place_label("  ·  ".join(items) if not items.is_empty() else "还没有物品", Vector2(812, 522), Vector2(294, 78), 16, SOFT)
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _place_label(value: String, at: Vector2, area: Vector2, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = at
	label.size = area
	label.text = value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(label)
	return label

func _panel_text(panel: VBoxContainer, value: String, font_size: int = 17, color: Color = TEXT) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)

func _action(panel: VBoxContainer, value: String, act: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = value
	button.disabled = disabled
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style(Color("#4c3429"), Color("#946741"), 1, 4))
	button.add_theme_stylebox_override("hover", _style(Color("#684831"), GOLD, 1, 4))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, GOLD, 2, 4))
	button.add_theme_color_override("font_color", TEXT)
	button.pressed.connect(act)
	panel.add_child(button)

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result

func _item_action(panel: VBoxContainer, id: String, for_sale: bool) -> void:
	var item: Dictionary = Expedition.ITEMS[id]
	if for_sale:
		_action(panel, "%s · %d 金币" % [item["name"], item["price"]], _buy.bind(id), Expedition.gold < item["price"])
	else:
		_action(panel, "领取%s" % item["name"], _wish.bind(id))
	_panel_text(panel, item["effect"], 14, SOFT)

func _enter(row: int, lane_index: int) -> void:
	if not Expedition.enter_node(row, lane_index):
		return
	if Expedition.is_battle(Expedition.current_kind):
		get_tree().change_scene_to_file(ARENA)
	else:
		_refresh()

func _buy(id: String) -> void:
	Expedition.buy(id)
	_refresh()

func _leave_shop() -> void:
	Expedition.complete_shop()
	_refresh()

func _rest() -> void:
	Expedition.complete_rest()
	_refresh()

func _encounter(risk: bool) -> void:
	Expedition.complete_encounter(risk)
	_refresh()

func _wish(id: String) -> void:
	Expedition.complete_wish(id)
	_refresh()

func _new_run() -> void:
	Expedition.start_run()
	_refresh()
