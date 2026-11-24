@tool
extends Node2D

const TILESET := preload("res://assets/maps/shared_tileset.tres")

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	_caption("新版基础地块", Vector2(20, 25), font)
	var bases := TileMapLayer.new()
	bases.tile_set = TILESET
	bases.position = Vector2(20, 90)
	add_child(bases)
	for row in range(5):
		for col in range(4):
			bases.set_cell(Vector2i(col, row), 0, Vector2i(col, row))
	for group in range(3):
		var origin := Vector2(310 + group * 270, 90)
		_caption(["草地 / 泥土", "草地 / 沼泽", "岩石 / 熔岩"][group], origin - Vector2(0, 65), font)
		var patch := TileMapLayer.new()
		patch.tile_set = TILESET
		patch.position = origin
		patch.scale = Vector2.ONE * 0.75
		add_child(patch)
		for y in range(5):
			for x in range(5):
				patch.set_cell(Vector2i(x, y), 0, [Vector2i(0, 1), Vector2i(0, 3), Vector2i(3, 4)][group])
		for y in range(1, 4):
			for x in range(1, 4):
				var coord := Vector2i.ZERO
				if y == 1 and x == 1: coord = Vector2i(3, 1)
				elif y == 1 and x == 3: coord = Vector2i(0, 1)
				elif y == 3 and x == 1: coord = Vector2i(2, 1)
				elif y == 3 and x == 3: coord = Vector2i(1, 1)
				elif y == 1: coord = Vector2i(0, 0)
				elif x == 3: coord = Vector2i(1, 0)
				elif y == 3: coord = Vector2i(2, 0)
				elif x == 1: coord = Vector2i(3, 0)
				else:
					patch.set_cell(Vector2i(x, y), 0, Vector2i(2, 4) if group == 2 else Vector2i.ZERO)
					continue
				patch.set_cell(Vector2i(x, y), 1, coord + Vector2i(0, group * 2))
	_caption("过渡瓦片调色板（24 张）", Vector2(310, 370), font)
	var palette := TileMapLayer.new()
	palette.position = Vector2(310, 420)
	palette.tile_set = TILESET
	add_child(palette)
	for index in range(24):
		palette.set_cell(Vector2i(index % 12, index / 12), 1, Vector2i(index % 4, index / 4))
	if not Engine.is_editor_hint():
		add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())

func _caption(value: String, at: Vector2, font: Font) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 23)
	add_child(label)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("#242820"))
