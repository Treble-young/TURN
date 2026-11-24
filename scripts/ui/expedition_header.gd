extends Control

signal backpack_pressed

const UI := preload("res://scripts/expedition/expedition_ui.gd")
const TEXTURES := {
	"health": preload("res://assets/ui/stats/health.png"),
	"attack": preload("res://assets/ui/stats/attack.png"),
	"gold": preload("res://assets/ui/stats/gold.png"),
	"level": preload("res://assets/ui/stats/level.png"),
}
const DIGITS := preload("res://assets/ui/stats/digits.png")
const WIDTH := 1152.0
const HEIGHT := 70.0
var regions: Dictionary
var font: Font
var backpack_button: Button
var inventory: PanelContainer
var last_values: Array = []

func _ready() -> void:
	name = "ExpeditionHeader"
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = HEIGHT
	theme = UI.make_theme()
	font = theme.default_font
	regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/stats/regions.json"))
	backpack_button = UI.action("背包", _open_backpack)
	add_child(backpack_button)
	resized.connect(_layout)
	_layout()
	refresh()

func _process(_delta: float) -> void:
	var values := [Expedition.floor_number, Expedition.health, Expedition.max_health(), Expedition.damage(Expedition.level), Expedition.gold, Expedition.level, Expedition.experience, Expedition.relics.hash()]
	if values != last_values:
		last_values = values
		refresh()

func refresh() -> void:
	queue_redraw()

func _layout() -> void:
	var ratio := minf(1.0, size.x / WIDTH)
	backpack_button.position = Vector2((size.x - WIDTH * ratio) * 0.5 + 1045 * ratio, 17)
	backpack_button.scale = Vector2.ONE * ratio
	backpack_button.size = Vector2(85, 36)

func _region(value: Array) -> Rect2:
	return Rect2(value[0], value[1], value[2], value[3])

func _icon(id: String, x: float) -> void:
	var source := _region(regions[id])
	var scale_factor := 36.0 / maxf(source.size.x, source.size.y)
	var target := source.size * scale_factor
	draw_texture_rect_region(TEXTURES[id], Rect2(Vector2(x, 35) + (Vector2(36, 0) - target) * 0.5, target), source)

func _number_width(value: String, height: float) -> float:
	var result := 0.0
	for character in value:
		if character.is_valid_int():
			var source := _region(regions.digits[int(character)])
			result += source.size.x / source.size.y * height + 2
		else:
			result += 11
	return result

func _number(value: String, position: Vector2, height: float = 27) -> float:
	var x := position.x
	for character in value:
		if character.is_valid_int():
			var source := _region(regions.digits[int(character)])
			var target := Vector2(source.size.x / source.size.y * height, height)
			draw_texture_rect_region(DIGITS, Rect2(Vector2(x, position.y), target), source)
			x += target.x + 2
		else:
			draw_string(font, Vector2(x, position.y + height - 3), character, HORIZONTAL_ALIGNMENT_LEFT, -1, int(height), UI.TEXT)
			x += 11
	return x

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#30221b"))
	draw_line(Vector2(0, HEIGHT - 1), Vector2(size.x, HEIGHT - 1), Color("#a3794d"))
	if regions.is_empty(): return
	var ratio := minf(1.0, size.x / WIDTH)
	draw_set_transform(Vector2((size.x - WIDTH * ratio) * 0.5, (HEIGHT - HEIGHT * ratio) * 0.5), 0, Vector2.ONE * ratio)
	draw_string(font, Vector2(20, 44), "第", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, UI.TEXT)
	var floor_end := _number("%d/%d" % [Expedition.floor_number, Expedition.FLOOR_COUNT], Vector2(47, 21))
	draw_string(font, Vector2(floor_end + 3, 44), "层", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, UI.TEXT)
	_icon("health", 175)
	_number("%d/%d" % [roundi(Expedition.health), roundi(Expedition.max_health())], Vector2(217, 22), 25)
	_icon("attack", 395)
	_number(str(roundi(Expedition.damage(Expedition.level))), Vector2(439, 22), 25)
	_icon("gold", 525)
	_number(str(Expedition.gold), Vector2(568, 22), 25)
	_icon("level", 685)
	_number(str(Expedition.level), Vector2(728, 22), 25)
	var progress := ExperienceProgress.new()
	progress.level = Expedition.level
	var required := progress.experience_required()
	progress.free()
	var bar := Rect2(790, 22, 230, 27)
	draw_style_box(UI.box(Color("#49362d"), Color("#b58d55"), 1, 7), bar)
	var fraction := clampf(float(Expedition.experience) / required, 0, 1) if required > 0 else 1.0
	if fraction > 0:
		draw_style_box(UI.box(Color("#c6a365"), Color.TRANSPARENT, 0, 5), Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * fraction, bar.size.y - 4)))
	var caption := "%d/%d" % [Expedition.experience, required]
	_number(caption, Vector2(bar.get_center().x - _number_width(caption, 20) * 0.5, 25), 20)
	draw_set_transform(Vector2.ZERO)

func _open_backpack() -> void:
	if backpack_pressed.get_connections().size() > 0:
		backpack_pressed.emit()
		return
	if is_instance_valid(inventory):
		inventory.queue_free()
		inventory = null
		return
	inventory = PanelContainer.new()
	inventory.position = Vector2(maxf(12, size.x - 410), 78)
	inventory.size = Vector2(385, 390)
	inventory.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.GOLD, 1, 6))
	add_child(inventory)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inventory.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	list.add_child(UI.label("随身物品", 23, UI.GOLD))
	if Expedition.relics.is_empty(): list.add_child(UI.label("还没有获得物品"))
	for id: String in Expedition.relics:
		var item: Dictionary = Expedition.ITEMS[id]
		list.add_child(UI.label("%s ×%d\n%s" % [item.name, Expedition.relics[id], item.effect], 16))
	list.add_child(UI.action("关闭", _open_backpack))
