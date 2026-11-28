extends RefCounted

const GOLD := Color("#e8bd72")
const TEXT := Color("#f6e5c6")
const SOFT := Color("#c8ad89")
const BACKGROUND := Color("#20191a")
const PANEL := Color("#2b2120")
const BORDER := Color("#674837")
const RELIC_ICONS := preload("res://assets/ui/relics/icons.png")
const RELIC_ICON_SIZE := 128
const RELIC_ICON_COLUMNS := 4

static func relic_icon(id: String) -> Texture2D:
	if Expedition.ITEMS[id].has("icon_path"): return load(Expedition.ITEMS[id].icon_path)
	var index: int = Expedition.ITEMS[id]["icon"]
	@warning_ignore("integer_division")
	var cell := Vector2i(index % RELIC_ICON_COLUMNS, index / RELIC_ICON_COLUMNS)
	var result := AtlasTexture.new()
	result.atlas = RELIC_ICONS
	result.region = Rect2(Vector2(cell * RELIC_ICON_SIZE), Vector2.ONE * RELIC_ICON_SIZE)
	result.filter_clip = true
	return result

static func make_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	result.default_font = font
	result.default_font_size = 17
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color("#fff1d0"))
	result.set_color("font_disabled_color", "Button", Color("#aa927e"))
	result.set_stylebox("normal", "Button", box(Color("#4c3429"), Color("#946741"), 1))
	result.set_stylebox("hover", "Button", box(Color("#684831"), GOLD, 1))
	result.set_stylebox("pressed", "Button", box(Color("#3a2921"), GOLD, 1))
	result.set_stylebox("disabled", "Button", box(Color("#35302d"), Color("#584735"), 1))
	result.set_stylebox("focus", "Button", box(Color.TRANSPARENT, GOLD, 2))
	return result

static func box(fill: Color, border: Color, width: int, radius: int = 4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result

static func set_margins(style: StyleBoxFlat, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical

static func label(value: String, font_size: int = 17, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func action(value: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.disabled = disabled
	button.custom_minimum_size.y = 43
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button
