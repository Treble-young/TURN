extends Node2D

static var shared_font: SystemFont
var ink := Color("#ffe069")
var amount := 0.0
var drift := 0.0
var caption := ""

func _ready() -> void:
	add_to_group("damage_numbers")
	z_index = 100
	if shared_font == null:
		shared_font = SystemFont.new()
		shared_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
		shared_font.font_weight = 700
	if caption.is_empty():
		caption = str(roundi(amount)) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(drift, -48), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.28).set_delay(0.47)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var text_size := shared_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	var origin := Vector2(-text_size.x * 0.5, 0)
	draw_string_outline(shared_font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color("#301b15"))
	draw_string(shared_font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
