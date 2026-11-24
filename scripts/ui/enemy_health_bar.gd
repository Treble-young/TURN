extends Node2D

var width := 48.0
var fraction := 1.0

func update_health(current: float, maximum: float) -> void:
	fraction = clampf(current / maxf(0.001, maximum), 0.0, 1.0)
	visible = current > 0.0
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(-width * 0.5, -3, width, 7)
	draw_rect(bounds.grow(1), Color("#221b19"))
	draw_rect(bounds, Color("#442328"))
	if fraction > 0:
		draw_rect(Rect2(bounds.position + Vector2.ONE, Vector2((width - 2) * fraction, 5)), Color("#cf504a"))
	draw_rect(bounds, Color("#d5ba88"), false, 1)
