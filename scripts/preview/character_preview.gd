extends Node2D

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color("171d29"))
	for x in range(0, 1153, 48):
		draw_line(Vector2(x, 0), Vector2(x, 648), Color("222c3c"))
	for y in range(0, 649, 48):
		draw_line(Vector2(0, y), Vector2(1152, y), Color("222c3c"))
