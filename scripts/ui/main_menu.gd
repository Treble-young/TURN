extends Control

const GAME_SCENE := "res://scenes/expedition/route_map.tscn"

@onready var start_button: Button = $Center/Menu/Buttons/StartGame

func _ready() -> void:
	_apply_theme()
	start_button.grab_focus()
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.28)
	draw_circle(center, 125.0, Color("242438"))
	draw_arc(center, 126.0, 0.0, TAU, 128, Color("bc9d65"), 2.0, true)
	draw_circle(center + Vector2(40, -20), 113.0, Color("11131f"))
	var line_y := size.y - 48.0
	draw_line(Vector2(size.x * 0.25, line_y), Vector2(size.x * 0.75, line_y), Color("353347"), 1.0)

func _apply_theme() -> void:
	var menu_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	menu_theme.default_font = font
	menu_theme.default_font_size = 21
	var colors := {
		"normal": Color("202333"),
		"hover": Color("34364b"),
		"pressed": Color("454054"),
		"disabled": Color("191c29"),
		"focus": Color(0, 0, 0, 0)
	}
	for state in colors:
		var style := StyleBoxFlat.new()
		style.bg_color = colors[state]
		style.set_corner_radius_all(6)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.border_color = Color("e5c68b") if state == "focus" else Color("575068")
		menu_theme.set_stylebox(state, "Button", style)
	menu_theme.set_color("font_color", "Button", Color("f0e9dd"))
	menu_theme.set_color("font_hover_color", "Button", Color("ffe0a2"))
	menu_theme.set_color("font_focus_color", "Button", Color("ffe0a2"))
	menu_theme.set_color("font_disabled_color", "Button", Color("737384"))
	theme = menu_theme

func _on_start_game_pressed() -> void:
	start_button.disabled = true
	Expedition.start_run()
	var result := get_tree().change_scene_to_file(GAME_SCENE)
	if result != OK:
		start_button.disabled = false
		push_error("Unable to open game scene: %s" % error_string(result))

func _on_quit_game_pressed() -> void:
	get_tree().quit()
