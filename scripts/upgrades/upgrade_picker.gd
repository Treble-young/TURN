extends CanvasLayer
signal completed
var panel: Control
var choosing := false
func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
func begin() -> void:
	if not choosing and Expedition.pending_upgrades > 0 and not get_tree().paused:
		_open()
func _open() -> void:
	choosing = true
	get_tree().paused = true
	panel = Control.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04,0.03,0.07,0.94)
	panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	box.theme = preload("res://scripts/expedition/expedition_ui.gd").make_theme()
	center.add_child(box)
	var title := Label.new()
	title.text = "选择强化 · 剩余 %d 次" % Expedition.pending_upgrades
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",28)
	box.add_child(title)
	for id in Expedition.next_upgrade_choices():
		var info: Dictionary = Expedition.SKILLS.SKILLS[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(minf(720, get_viewport().get_visible_rect().size.x - 48),110)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s · %s  %d → %d / %d\n%s" % [Expedition.SKILLS.TYPES[info.type],info.name,Expedition.skill(id),Expedition.skill(id)+1,info.max,info.description]
		button.pressed.connect(_choose.bind(id))
		box.add_child(button)
	box.get_child(1).grab_focus()
func _choose(id: String) -> void:
	if not choosing or not Expedition.choose_upgrade(id): return
	get_parent().player.refresh_skills()
	remove_child(panel)
	panel.queue_free()
	choosing = false
	if Expedition.pending_upgrades > 0: _open()
	else:
		get_tree().paused = false
		completed.emit()
func _exit_tree() -> void:
	if choosing: get_tree().paused = false
