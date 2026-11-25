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
var shared_header: Control
var backpack_button: Button
var backpack: PanelContainer
var backpack_items: VBoxContainer
var paper_style: StyleBoxTexture
var tracking_drag := false
var dragging := false
var drag_origin := Vector2.ZERO
var drag_scroll_origin := 0

func _ready() -> void:
	MusicManager.set_context(&"non_combat")
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
	_build_backpack()
	_build_nodes()
	_update_details()
	_scroll_to_frontier.call_deferred()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BACKGROUND)
	draw_line(Vector2(0, HEADER_HEIGHT - 1), Vector2(size.x, HEADER_HEIGHT - 1), UI.BORDER)

func _build_header() -> void:
	shared_header = preload("res://scripts/ui/expedition_header.gd").new()
	add_child(shared_header)
	backpack_button = shared_header.backpack_button
	shared_header.backpack_pressed.connect(_toggle_backpack)

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

func _build_backpack() -> void:
	backpack = PanelContainer.new()
	add_child(backpack)
	backpack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	backpack.offset_left = -411
	backpack.offset_right = -26
	backpack.offset_top = HEADER_HEIGHT + 8
	backpack.offset_bottom = HEADER_HEIGHT + 390
	var style := UI.box(UI.PANEL, UI.GOLD, 1, 6)
	UI.set_margins(style, 18, 14)
	backpack.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	backpack.add_child(body)
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	var title := UI.label("随身物品", 23, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	var close_button := UI.action("关闭", backpack.hide)
	close_button.custom_minimum_size = Vector2(58, 30)
	title_row.add_child(close_button)
	body.add_child(HSeparator.new())
	var item_scroll := ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(item_scroll)
	backpack_items = VBoxContainer.new()
	backpack_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_items.add_theme_constant_override("separation", 9)
	item_scroll.add_child(backpack_items)
	backpack.z_index = 20
	backpack.hide()

func _toggle_backpack() -> void:
	backpack.visible = not backpack.visible
	_refresh_backpack()

func _refresh_backpack() -> void:
	var total := 0
	for count: int in Expedition.relics.values():
		total += count
	backpack_button.tooltip_text = "遗物槽位：%d / %d" % [total, Expedition.relic_capacity]
	if not backpack.visible:
		return
	for child in backpack_items.get_children():
		backpack_items.remove_child(child)
		child.queue_free()
	preload("res://scripts/ui/relic_slots.gd").populate(backpack_items)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var on_scrollbar := scroll.get_v_scroll_bar().get_global_rect().has_point(event.position)
			var on_backpack := backpack.visible and backpack.get_global_rect().has_point(event.position)
			if backpack.visible and not on_backpack and not backpack_button.get_global_rect().has_point(event.position):
				backpack.hide()
			tracking_drag = scroll.get_global_rect().has_point(event.position) and not on_scrollbar and not on_backpack
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
	for crossing: Vector2i in Expedition.lateral_crossings[Expedition.floor_number - 1]:
		_draw_link(crossing.x, crossing.y, crossing.y + 1, true)

func _draw_link(row: int, from_lane: int, to_lane: int, lateral: bool = false) -> void:
	var from_row := row if lateral else row - 1
	var from := _point(from_row, from_lane)
	var destination := _point(row, to_lane)
	var from_index := Expedition.visited.find(Vector2i(from_row, from_lane))
	var to_index := Expedition.visited.find(Vector2i(row, to_lane))
	# 同排可经过两个节点，只有访问顺序相邻的两端才算走过这条连线。
	var followed := from_index >= 0 and to_index >= 0 and (to_index == from_index + 1 or (lateral and from_index == to_index + 1))
	var next := Expedition.stage == from_row and Expedition.lane == from_lane and Expedition.can_reach(row, to_lane)
	if lateral and Expedition.stage == row and Expedition.lane == to_lane:
		next = Expedition.can_reach(row, from_lane)
	var crosses := row < Expedition.STAGE_COUNT - 1 and from_lane != to_lane
	var color := Color("#44736a") if lateral else (Color("#906135") if crosses else Color("#a17a54"))
	var thickness := 1.8
	if followed:
		color = Color("#553627")
		thickness = 3.8
	elif next:
		color = Color("#285d50") if lateral else Color("#744125")
		thickness = 2.8
	var lift := Vector2(0.0, (from.y - destination.y) * 0.50)
	var sway := Vector2.ZERO
	if absf(from.x - destination.x) < 65.0:
		sway.x = 55.0 if (row + from_lane) % 2 == 0 else -55.0
	if lateral:
		sway.y = -61.0
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
	shared_header.refresh()
	_refresh_backpack()
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
		var restore := roundi(Expedition.rest_heal_amount(true))
		var limit := roundi(Expedition.REST_HEAL_FRACTION * 100.0)
		var outcome := "当前可恢复 %d 点生命。" % restore if restore > 0 else "当前生命已满。"
		details.add_child(UI.label("休息可恢复最大生命值的 %d%%。\n%s" % [limit, outcome], 16, UI.GOLD))
		if Expedition.relics.has("camp_kit"):
			details.add_child(UI.label("营火药囊：入场额外恢复最多 %d 点生命，上面已计入。" % int(Expedition.REST_ENTRY_BONUS), 15, UI.SOFT))
	travel_controls.show()
	if Expedition.visited.has(selected):
		travel_controls.add_child(UI.label("已经过此节点", 16, UI.SOFT))
	elif not Expedition.can_reach(selected.x, selected.y):
		travel_controls.add_child(UI.label("当前路线无法抵达此节点", 16, UI.SOFT))
	else:
		var action := "确认换列并进入" if selected.x == Expedition.stage else "确认前往"
		travel_controls.add_child(UI.action(action, _confirm_node))

func _preview_battle(kind: int) -> void:
	var library = load("res://assets/maps/map_library.tres")
	var level = library.definition_for(Expedition.floor_number, selected.x, selected.y)
	if level != null:
		details.add_child(UI.label(level.display_name, 20, UI.GOLD))
	var waves := ENCOUNTER.waves_for(kind, Expedition.floor_number, selected.x, selected.y)
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
	if TideTransition.busy or not Expedition.enter_node(selected.x, selected.y):
		return
	var scene := ARENA if Expedition.is_battle(Expedition.current_kind) else VISIT
	if Expedition.current_kind in [Expedition.Kind.ENCOUNTER, Expedition.Kind.SHOP]:
		scene = "res://scenes/events/story_event.tscn"
	TideTransition.change_scene(scene)

func _new_run() -> void:
	Expedition.start_run(-1, Expedition.difficulty)
	selected = Vector2i(-1, -1)
	_build_nodes()
	_update_details()
	_scroll_to_frontier.call_deferred()
