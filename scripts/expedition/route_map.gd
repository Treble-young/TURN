extends Control

const UI := preload("res://scripts/expedition/expedition_ui.gd")
const ARENA := "res://scenes/expedition/arena.tscn"
const VISIT := "res://scenes/expedition/node_visit.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const HEADER_HEIGHT := 70.0
const SIDEBAR_WIDTH := 322.0
const MAP_HEIGHT := 1040.0
const ROW_GAP := 170.0
const INK := Color("#533727")
const ROUTE_OFFSETS := [Vector2(0, 0), Vector2(-18, 9), Vector2(12, -5), Vector2(8, -9), Vector2(-10, 5)]
const KIND_MARKS := ["战", "险", "王", "商", "歇", "遇", "愿"]
const KIND_COLORS := ["#623a31", "#863a2b", "#572b38", "#45584a", "#405866", "#585274", "#7c572c"]

var scroll: ScrollContainer
var canvas: Control
var details: VBoxContainer
var selected := Vector2i(-1, -1)
var node_buttons: Dictionary = {}
var header_stats: Label
var inventory: Label
var paper_texture: NoiseTexture2D

func _ready() -> void:
	if Expedition.maps.is_empty():
		get_tree().change_scene_to_file.bind(MAIN_MENU).call_deferred()
		return
	if Expedition.node_pending:
		var scene := ARENA if Expedition.is_battle(Expedition.current_kind) else VISIT
		get_tree().change_scene_to_file.bind(scene).call_deferred()
		return
	theme = UI.make_theme()
	_build_header()
	_build_canvas()
	_build_sidebar()
	_build_nodes()
	_update_details()
	_scroll_to_frontier.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BACKGROUND)
	draw_line(Vector2(0, HEADER_HEIGHT - 1), Vector2(size.x, HEADER_HEIGHT - 1), UI.BORDER)

func _build_header() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 26
	row.offset_right = -26
	row.offset_top = 0
	row.offset_bottom = HEADER_HEIGHT
	var heading := UI.label("远征路线", 26, UI.GOLD)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size.x = 22
	row.add_child(gap)
	header_stats = UI.label("", 16)
	header_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(header_stats)

func _build_canvas() -> void:
	scroll = ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = HEADER_HEIGHT
	scroll.offset_right = -SIDEBAR_WIDTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 11
	bar.add_theme_stylebox_override("scroll", UI.box(Color("#392c29"), UI.BORDER, 0))
	bar.add_theme_stylebox_override("grabber", UI.box(Color("#ac8157"), UI.BORDER, 1))
	bar.add_theme_stylebox_override("grabber_highlight", UI.box(Color("#d1a870"), UI.BORDER, 1))
	canvas = Control.new()
	canvas.custom_minimum_size.y = MAP_HEIGHT
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(canvas)
	canvas.draw.connect(_draw_map)
	canvas.resized.connect(_position_nodes)
	var noise := FastNoiseLite.new()
	noise.seed = 41
	noise.frequency = 0.015
	noise.fractal_octaves = 5
	var tones := Gradient.new()
	tones.colors = PackedColorArray([Color("#c5a073"), Color("#e7c694")])
	paper_texture = NoiseTexture2D.new()
	paper_texture.width = 832
	paper_texture.height = int(MAP_HEIGHT)
	paper_texture.color_ramp = tones
	paper_texture.noise = noise
	paper_texture.changed.connect(canvas.queue_redraw)

func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -SIDEBAR_WIDTH
	panel.offset_top = HEADER_HEIGHT
	var style := UI.box(UI.PANEL, UI.BORDER, 1, 0)
	UI.set_margins(style, 23, 22)
	panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 13)
	panel.add_child(body)
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	body.add_child(details)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(space)
	body.add_child(HSeparator.new())
	body.add_child(UI.label("随身物品", 17, UI.GOLD))
	inventory = UI.label("", 15, UI.SOFT)
	body.add_child(inventory)

func _draw_map() -> void:
	var area := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(area, Color("#d3a973"))
	canvas.draw_texture_rect(paper_texture, area, false)
	canvas.draw_rect(area.grow(-13), Color("#916b48"), false, 1.0)
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
	var paid := row < Expedition.STAGE_COUNT - 1 and from_lane != to_lane
	var color := Color("#906135") if paid else Color("#a17a54")
	var thickness := 1.8
	if followed:
		color = Color("#553627")
		thickness = 3.8
	elif next:
		color = Color("#744125")
		thickness = 2.8
	var lift := Vector2(0.0, (from.y - destination.y) * 0.50)
	var sway := Vector2.ZERO
	if absf(from.x - destination.x) < 65.0:
		sway.x = 55.0 if (row + from_lane) % 2 == 0 else -55.0
	var curve := Curve2D.new()
	curve.bake_interval = 4.0
	curve.add_point(from, Vector2.ZERO, sway - lift)
	curve.add_point(destination, sway + lift)
	if paid:
		var length := curve.get_baked_length()
		var offset := 0.0
		while offset < length:
			var dash_end := minf(offset + 8.0, length)
			canvas.draw_line(curve.sample_baked(offset), curve.sample_baked(dash_end), color, thickness, true)
			offset += 15.0
	else:
		canvas.draw_polyline(curve.get_baked_points(), color, thickness, true)

func _point(row: int, lane_index: int) -> Vector2:
	var y := MAP_HEIGHT - 94.0 - row * ROW_GAP
	if row == Expedition.STAGE_COUNT - 1:
		return Vector2(canvas.size.x * 0.5, y)
	var shift: Vector2 = ROUTE_OFFSETS[(row + lane_index + Expedition.floor_number - 1) % ROUTE_OFFSETS.size()]
	return Vector2(canvas.size.x * (0.20 + lane_index * 0.30), y) + shift

func _build_nodes() -> void:
	for button: Button in node_buttons.values():
		canvas.remove_child(button)
		button.queue_free()
	node_buttons.clear()
	var rows := Expedition.current_map()
	for row in rows.size():
		for lane_index in rows[row].size():
			var kind: int = rows[row][lane_index]
			var button := Button.new()
			button.text = KIND_MARKS[kind]
			button.tooltip_text = Expedition.KIND_NAMES[kind]
			button.size = Vector2(62, 62)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.add_theme_font_size_override("font_size", 24)
			button.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#fff2c7"), 2, 31))
			button.pressed.connect(_select_node.bind(row, lane_index))
			canvas.add_child(button)
			node_buttons[Vector2i(row, lane_index)] = button
			var caption: String = Expedition.KIND_NAMES[kind]
			if Expedition.has_crossing(row, lane_index):
				caption += "  ·  可换线"
			var label := UI.label(caption, 16, INK)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_outline_color", Color("#debc8a"))
			label.add_theme_constant_override("outline_size", 6)
			label.size = Vector2(164, 26)
			button.add_child(label)
			label.position = Vector2(-51, 65)
	_position_nodes()
	_style_nodes()

func _position_nodes() -> void:
	for key: Vector2i in node_buttons:
		var button: Button = node_buttons[key]
		button.position = _point(key.x, key.y) - Vector2(31, 31)
	canvas.queue_redraw()

func _style_nodes() -> void:
	var rows := Expedition.current_map()
	for key: Vector2i in node_buttons:
		var button: Button = node_buttons[key]
		var kind: int = rows[key.x][key.y]
		var tint := Color(KIND_COLORS[kind])
		var reachable := Expedition.can_reach(key.x, key.y) and Expedition.gold >= Expedition.travel_cost(key.x, key.y)
		var visited := Expedition.visited.has(key)
		var fill := tint if reachable or visited else tint.lerp(Color("#e3bb87"), 0.72)
		var border := UI.GOLD if reachable else Color("#9f7653")
		var width := 2
		if selected == key:
			border = Color("#fff0bd")
			width = 4
		button.add_theme_stylebox_override("normal", UI.box(fill, border, width, 31))
		button.add_theme_stylebox_override("hover", UI.box(fill.lightened(0.10), Color("#fff0bd"), 3, 31))
		button.add_theme_stylebox_override("pressed", UI.box(fill.darkened(0.12), Color("#fff0bd"), 3, 31))
		var font_color := UI.TEXT if reachable or visited else INK
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_focus_color", font_color)

func _scroll_to_frontier() -> void:
	var row := mini(Expedition.stage + 1, Expedition.STAGE_COUNT - 1)
	var target := MAP_HEIGHT if Expedition.stage < 0 else _point(row, 0).y - scroll.size.y * 0.57
	scroll.scroll_vertical = roundi(target)

func _select_node(row: int, lane_index: int) -> void:
	selected = Vector2i(row, lane_index)
	_style_nodes()
	_update_details()

func _update_details() -> void:
	header_stats.text = "第 %d / %d 层      生命 %d / %d      金币 %d      等级 %d      经验 %d      种子 %d" % [
		Expedition.floor_number, Expedition.FLOOR_COUNT, roundi(Expedition.health), roundi(Expedition.max_health()),
		Expedition.gold, Expedition.level, Expedition.total_experience, Expedition.run_seed,
	]
	inventory.text = UI.inventory_text()
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	if not Expedition.active:
		details.add_child(UI.label("远征完成" if Expedition.won else "远征结束", 27, UI.GOLD))
		details.add_child(UI.label("你击败了五层的首领。" if Expedition.won else "你在第 %d 层倒下。" % Expedition.floor_number))
		details.add_child(UI.label("等级 %d · 累计经验 %d" % [Expedition.level, Expedition.total_experience]))
		details.add_child(UI.action("开始新的远征", _new_run))
		details.add_child(UI.action("返回主菜单", func(): get_tree().change_scene_to_file(MAIN_MENU)))
	elif selected.x < 0:
		details.add_child(UI.label("选择下一步", 27, UI.GOLD))
		details.add_child(UI.label("滚轮查看地图。点选节点可查看详情，再确认是否前往。"))
		details.add_child(UI.label("实线免费。少数节点可沿虚线改道，花费 %d 金币。" % Expedition.SWITCH_COST, 15, UI.SOFT))
		if not Expedition.report.is_empty():
			details.add_child(UI.label(Expedition.report, 16, UI.GOLD))
	else:
		_preview_node()

func _preview_node() -> void:
	var kind: int = Expedition.current_map()[selected.x][selected.y]
	details.add_child(UI.label(Expedition.KIND_NAMES[kind], 27, UI.GOLD))
	details.add_child(UI.label(Expedition.KIND_DETAILS[kind]))
	if Expedition.has_crossing(selected.x, selected.y):
		details.add_child(UI.label("离开此节点时可付费换线。", 15, UI.SOFT))
	if Expedition.visited.has(selected):
		details.add_child(UI.label("已经过此节点", 16, UI.SOFT))
	elif not Expedition.can_reach(selected.x, selected.y):
		details.add_child(UI.label("当前路线无法抵达此节点", 16, UI.SOFT))
	else:
		var cost := Expedition.travel_cost(selected.x, selected.y)
		var affordable := Expedition.gold >= cost
		details.add_child(UI.label("换线费用 · %d 金币" % cost if cost > 0 else "前往费用 · 免费", 16, UI.GOLD))
		if not affordable:
			details.add_child(UI.label("金币不足", 15, UI.SOFT))
		details.add_child(UI.action("确认前往", _confirm_node, not affordable))

func _confirm_node() -> void:
	if not Expedition.enter_node(selected.x, selected.y):
		return
	var scene := ARENA if Expedition.is_battle(Expedition.current_kind) else VISIT
	get_tree().change_scene_to_file(scene)

func _new_run() -> void:
	Expedition.start_run()
	selected = Vector2i(-1, -1)
	_build_nodes()
	_update_details()
	_scroll_to_frontier.call_deferred()
