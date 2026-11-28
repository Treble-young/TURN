extends RefCounted
const ROOT := "res://assets/ui/parchment/"
static func style(file: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = load(ROOT+file)
	result.modulate_color = tint
	result.content_margin_left = 24
	result.content_margin_right = 24
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result
static func make() -> Theme:
	var theme := preload("res://scripts/expedition/expedition_ui.gd").make_theme()
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var tint := Color("#fff0c8") if state in ["hover","focus"] else (Color("#d5bd95") if state=="pressed" else Color("#b4aa9a") if state=="disabled" else Color.WHITE)
			theme.set_stylebox(state,type,style("button_long.png",tint))
		for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
			theme.set_color(state,type,Color("#452b17"))
		theme.set_color("font_disabled_color",type,Color("#796e5b"))
	theme.set_color("font_color","Label",Color("#452b17"))
	theme.set_stylebox("panel","PopupMenu",preload("res://scripts/expedition/expedition_ui.gd").box(Color("#f0d8ab"),Color("#63401e"),2))
	theme.set_color("font_color","PopupMenu",Color("#452b17"))
	for state in ["normal","focus","read_only"]:
		theme.set_stylebox(state,"LineEdit",preload("res://scripts/expedition/expedition_ui.gd").box(Color("#fff0cb"),Color("#77512c"),2))
	theme.set_color("font_color","LineEdit",Color("#452b17"))
	theme.set_color("font_placeholder_color","LineEdit",Color("#96754d"))
	theme.set_color("caret_color","LineEdit",Color("#452b17"))
	return theme
