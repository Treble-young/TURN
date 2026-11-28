extends Control

const GAME_SCENE := "res://scenes/expedition/route_map.tscn"

@onready var start_button: Button = $Center/Menu/Buttons/StartGame
var difficulty_dialog: Control
var options_menu: CanvasLayer

func _ready() -> void:
	MusicManager.set_context(&"non_combat")
	_apply_theme()
	start_button.grab_focus()
	options_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	options_menu.main_menu_mode = true
	add_child(options_menu)
	options_menu.closed.connect(func(): $Center/Menu/Buttons/Options.grab_focus())
	$Center/Menu/Buttons/Options.pressed.connect(func(): options_menu.pause_game())
	difficulty_dialog = Control.new()
	difficulty_dialog.set_script(preload("res://scripts/ui/difficulty_dialog.gd"))
	add_child(difficulty_dialog)
	difficulty_dialog.confirmed.connect(_start_expedition)
	difficulty_dialog.canceled.connect(_close_difficulty)
	resized.connect(queue_redraw)

func _apply_theme() -> void:
	theme = preload("res://scripts/ui/parchment_theme.gd").make()
	$Background.hide()
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/ui/parchment/main_background.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop,0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Center/Menu.custom_minimum_size.x = 360
	for button in $Center/Menu/Buttons.get_children(): button.custom_minimum_size = Vector2(360,60)
	$Center/Menu/Title.add_theme_color_override("font_color",Color("#fff0c9"))
	$Center/Menu/Title.add_theme_color_override("font_outline_color",Color("#352136"))
	$Center/Menu/Title.add_theme_constant_override("outline_size",8)
	$Center/Menu/Subtitle.add_theme_color_override("font_color",Color("#f4e3c8"))

func _on_start_game_pressed() -> void:
	for name in ["StartGame", "Options", "QuitGame"]:
		$Center/Menu/Buttons.get_node(name).disabled = true
	difficulty_dialog.open()

func _close_difficulty() -> void:
	for name in ["StartGame", "Options", "QuitGame"]:
		$Center/Menu/Buttons.get_node(name).disabled = false
	start_button.grab_focus()

func _start_expedition(seed_value: int, difficulty: int) -> void:
	start_button.disabled = true
	Expedition.start_run(seed_value, difficulty)
	var result := get_tree().change_scene_to_file(GAME_SCENE)
	if result != OK:
		start_button.disabled = false
		difficulty_dialog.confirm_button.disabled = false
		push_error("Unable to open game scene: %s" % error_string(result))

func _on_quit_game_pressed() -> void:
	get_tree().quit()
