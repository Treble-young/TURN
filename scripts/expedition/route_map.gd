extends Control

const UI := preload("res://scripts/expedition/expedition_ui.gd")
const ENCOUNTER := preload("res://scripts/expedition/battle_encounter.gd")
const ARENA := "res://scenes/expedition/arena.tscn"
const VISIT := "res://scenes/expedition/node_visit.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const HEADER_HEIGHT := 70.0
const SIDEBAR_WIDTH := 322.0
const MAP_HEIGHT := 1200.0
const MAP_VERTICAL_PADDING := 175.0
const ROW_GAP := 170.0
const DRAG_THRESHOLD := 8.0
const INK := Color("#533727")
const ROUTE_OFFSETS := [Vector2(0, 0), Vector2(-18, 9), Vector2(12, -5), Vector2(8, -9), Vector2(-10, 5)]
const ROUTE_BACKGROUND = preload("res://assets/ui/route/background.png")
const NODE_ICONS = [
	preload("res://assets/ui/route/battle.tres"),
	preload("res://assets/ui/route/elite.tres"),
	preload("res://assets/ui/route/boss.tres"),
	preload("res://assets/ui/route/shop.tres"),
	preload("res://assets/ui/route/rest.tres"),
	preload("res://assets/ui/route/encounter.tres"),
	preload("res://assets/ui/route/treasure.tres"),
]

var scroll: ScrollContainer
var canvas: Control
var sidebar: PanelContainer
var close_preview: Button
var preview_scroll: ScrollContainer
var details: VBoxContainer
var travel_controls: VBoxContainer
var selected := Vector2i(-1, -1)
var node_buttons: Dictionary = {}
var header_stats: Label
var inventory: Label
var paper_style: StyleBoxTexture
var tracking_drag := false
var dragging := false
var drag_origin := Vector2.ZERO
var drag_scroll_origin := 0

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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.follow_focus = true
	scroll.mouse_default_cursor_shape = Control.CURSOR_DRAG
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
	paper_style = StyleBoxTexture.new()
	paper_style.texture = ROUTE_BACKGROUND
	# Preserve the supplied scroll corners while expanding the blank center.
	paper_style.set_texture_margin(SIDE_LEFT, 64)
	paper_style.set_texture_margin(SIDE_RIGHT, 64)
	paper_style.set_texture_margin(SIDE_TOP, 90)
	paper_style.set_texture_margin(SIDE_BOTTOM, 90)

func _build_sidebar() -> void:
	sidebar = PanelContainer.new()
	add_child(sidebar)
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -SIDEBAR_WIDTH
	sidebar.offset_top = HEADER_HEIGHT
	var style := UI.box(UI.PANEL, UI.BORDER, 1, 0)
	UI.set_margins(style, 23, 22)
	sidebar.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 13)
	sidebar.add_child(body)
	close_preview = UI.action("关闭", _close_preview)
	close_preview.custom_minimum_size = Vector2(62, 29)
	close_preview.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(close_preview)
	preview_scroll = ScrollContainer.new()
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	preview_scroll.add_child(details)
	travel_controls = VBoxContainer.new()
	travel_controls.add_theme_constant_override("separation", 6)
	body.add_child(travel_controls)
	body.add_child(HSeparator.new())
	body.add_child(UI.label("随身物品", 17, UI.GOLD))
	inventory = UI.label("", 15, UI.SOFT)
	body.add_child(inventory)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var on_scrollbar := scroll.get_v_scroll_bar().get_global_rect().has_point(event.position)
			tracking_drag = scroll.get_global_rect().has_point(event.position) and not on_scrollbar
			dragging = false
			drag_origin = event.position
			drag_scroll_origin = scroll.scroll_vertical
		else:
			tracking_drag = false
			# Keep the drag flag until node buttons have processed this release.
			if dragging:
				_finish_drag.call_deferred()
	elif event is InputEventMouseMotion and tracking_drag:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			tracking_drag = false
			dragging = false
			return
		var delta: Vector2 = event.position - drag_origin
		if dragging or delta.length() >= DRAG_THRESHOLD:
			dragging = true
			scroll.scroll_vertical = drag_scroll_origin - roundi(delta.y)

func _finish_drag() -> void:
	if not tracking_drag:
		dragging = false

func _draw_map() -> void:
	var area := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_style_box(paper_style, area)
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
	var next := previous and Expedition.can_reach(row, to_lane)
	var crosses := row < Expedition.STAGE_COUNT - 1 and from_lane != to_lane
	var color := Color("#906135") if crosses else Color("#a17a54")
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
	var length := curve.get_baked_length()
	var offset := 0.0
	while offset < length:
		var dash_end := minf(offset + 8.0, length)
		canvas.draw_line(curve.sample_baked(offset), curve.sample_baked(dash_end), color, thickness, true)
		offset += 15.0

func _point(row: int, lane_index: int) -> Vector2:
	var y := MAP_HEIGHT - MAP_VERTICAL_PADDING - row * ROW_GAP
	if row == Expedition.STAGE_COUNT - 1:
		return Vector2(canvas.size.x * 0.5, y)
	var shift: Vector2 = ROUTE_OFFSETS[(row + lane_index + Expedition.floor_number - 1) % ROUTE_OFFSETS.size()]
	return Vector2(canvas.size.x * (0.17 + lane_index * 0.33), y) + shift

func _build_nodes() -> void:
	for button: Button in node_buttons.values():
		canvas.remove_child(button)
		button.queue_free()
	node_buttons.clear()
	var rows := Expedition.current_map()
	for row in rows.size():
		for lane_index in rows[row].size():
			if not Expedition.node_exists_at(row, lane_index):
				continue
			var kind: int = rows[row][lane_index]
			var button := Button.new()
			var icon := TextureRect.new()
			icon.name = "NodeIcon"
			icon.texture = NODE_ICONS[kind]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(6.8, 6.8)
			icon.size = Vector2(48.4, 48.4)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			button.tooltip_text = Expedition.KIND_NAMES[kind]
			button.size = Vector2(62, 62)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.add_theme_font_size_override("font_size", 24)
			button.add_theme_stylebox_override("focus", UI.box(Color.TRANSPARENT, Color("#fff2c7"), 2, 31))
			button.pressed.connect(_select_node.bind(row, lane_index))
			canvas.add_child(button)
			node_buttons[Vector2i(row, lane_index)] = button
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

		var reachable := Expedition.can_reach(key.x, key.y)
		var visited := Expedition.visited.has(key)
		var fill := Color("#efcf95") if reachable else (Color("#c9ab78") if visited else Color("#dac29c"))
		button.get_node("NodeIcon").modulate = Color.WHITE if reachable or visited else Color(0.72, 0.72, 0.72, 0.8)
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
	if dragging:
		return
	selected = Vector2i(row, lane_index)
	_style_nodes()
	_update_details()

func _close_preview() -> void:
	selected = Vector2i(-1, -1)
	_style_nodes()
	_update_details()

func _update_details() -> void:
	header_stats.text = "第 %d / %d 层      生命 %d / %d      金币 %d      等级 %d      经验 %d      种子 %d" % [
		Expedition.floor_number, Expedition.FLOOR_COUNT, roundi(Expedition.health), roundi(Expedition.max_health()),
		Expedition.gold, Expedition.level, Expedition.total_experience, Expedition.run_seed,
	]
	inventory.text = UI.inventory_text()
	for section in [details, travel_controls]:
		for child in section.get_children():
			section.remove_child(child)
			child.queue_free()
	preview_scroll.scroll_vertical = 0
	travel_controls.hide()
	var show_sidebar := selected.x >= 0 or not Expedition.active
	sidebar.visible = show_sidebar
	scroll.offset_right = -SIDEBAR_WIDTH if show_sidebar else 0
	close_preview.visible = Expedition.active
	if not Expedition.active:
		details.add_child(UI.label("远征完成" if Expedition.won else "远征结束", 27, UI.GOLD))
		details.add_child(UI.label("你击败了五层的首领。" if Expedition.won else "你在第 %d 层倒下。" % Expedition.floor_number))
		details.add_child(UI.label("等级 %d · 累计经验 %d" % [Expedition.level, Expedition.total_experience]))
		details.add_child(UI.action("开始新的远征", _new_run))
		details.add_child(UI.action("返回主菜单", func(): get_tree().change_scene_to_file(MAIN_MENU)))
	elif show_sidebar:
		_preview_node()

func _preview_node() -> void:
	var kind: int = Expedition.current_map()[selected.x][selected.y]
	details.add_child(UI.label(Expedition.KIND_NAMES[kind], 27, UI.GOLD))
	details.add_child(UI.label(Expedition.KIND_DETAILS[kind]))
	if Expedition.is_battle(kind):
		_preview_battle(kind)
	elif kind == Expedition.Kind.REST:
		var restore := roundi(Expedition.rest_heal_amount())
		var limit := roundi(Expedition.REST_HEAL_FRACTION * 100.0)
		var outcome := "当前可恢复 %d 点生命。" % restore if restore > 0 else "当前生命已满。"
		details.add_child(UI.label("回复量按最大生命值的 %d%% 计算。\n%s" % [limit, outcome], 16, UI.GOLD))
	travel_controls.show()
	if Expedition.visited.has(selected):
		travel_controls.add_child(UI.label("已经过此节点", 16, UI.SOFT))
	elif not Expedition.can_reach(selected.x, selected.y):
		travel_controls.add_child(UI.label("当前路线无法抵达此节点", 16, UI.SOFT))
	else:
		travel_controls.add_child(UI.action("确认前往", _confirm_node))

func _preview_battle(kind: int) -> void:
	var waves := ENCOUNTER.waves_for(kind, Expedition.floor_number)
	var rows := PackedStringArray()
	for index in waves.size():
		rows.append("第 %d 波　%s" % [index + 1, ENCOUNTER.wave_summary(waves[index])])
	details.add_child(UI.label("敌人编成", 16, UI.GOLD))
	details.add_child(UI.label("\n".join(rows), 16))
	var splits := ENCOUNTER.split_summary(waves)
	if not splits.is_empty():
		details.add_child(UI.label("分裂增援：%s" % splits, 15, UI.SOFT))
	details.add_child(UI.label("战斗地图", 16, UI.GOLD))
	var frame := PanelContainer.new()
	frame.custom_minimum_size.y = 82
	frame.add_theme_stylebox_override("panel", UI.box(UI.BACKGROUND, UI.BORDER, 1))
	details.add_child(frame)
	var thumbnail := ENCOUNTER.battlefield_preview(kind, Expedition.floor_number, selected)
	if thumbnail:
		var preview := TextureRect.new()
		preview.texture = thumbnail
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(preview)
	else:
		var placeholder := UI.label("地图预览待更新", 15, UI.SOFT)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(placeholder)

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
