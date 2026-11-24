extends SceneTree

const OUTPUT := "res://assets/tiles/updated/"

func _initialize() -> void:
	var base := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT + "source_sheet.png"))
	var transition := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT + "transition_sheet.png"))
	var columns := [Vector2i(20, 280), Vector2i(294, 554), Vector2i(569, 828), Vector2i(843, 1101)]
	var rows := [Vector2i(54, 313), Vector2i(329, 587), Vector2i(602, 849), Vector2i(865, 1091), Vector2i(1109, 1350)]
	var base_atlas := Image.create(256, 320, false, Image.FORMAT_RGBA8)
	for y in range(5):
		for x in range(4):
			var col: Vector2i = columns[x]
			var row: Vector2i = rows[y]
			var cell := base.get_region(Rect2i(col.x, row.x, col.y - col.x, row.y - row.x))
			cell.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			base_atlas.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(x * 64, y * 64))
	base_atlas.save_png(OUTPUT + "base_tiles.png")
	var transition_columns := [Vector2i(20, 252), Vector2i(272, 503), Vector2i(523, 752), Vector2i(772, 1005)]
	var transition_rows := [Vector2i(40, 276), Vector2i(295, 520), Vector2i(539, 762), Vector2i(781, 997), Vector2i(1016, 1240), Vector2i(1258, 1481)]
	var transitions := Image.create(256, 384, false, Image.FORMAT_RGBA8)
	for y in range(6):
		for x in range(4):
			var col: Vector2i = transition_columns[x]
			var row: Vector2i = transition_rows[y]
			var cell := transition.get_region(Rect2i(col.x, row.x, col.y - col.x, row.y - row.x))
			cell.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			transitions.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(x * 64, y * 64))
	transitions.save_png(OUTPUT + "transitions.png")
	print("Prepared base_tiles.png (20 cells) and transitions.png (24 cells).")
	quit()
