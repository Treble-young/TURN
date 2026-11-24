extends RefCounted

const UI := preload("res://scripts/expedition/expedition_ui.gd")

static func populate(parent: VBoxContainer, on_select: Callable = Callable()) -> void:
	parent.add_child(UI.label("遗物槽位 %d / %d" % [Expedition.used_relic_slots(), Expedition.relic_capacity], 17, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	var entries: Array[String] = []
	for id: String in Expedition.relics:
		for _copy in int(Expedition.relics[id]): entries.append(id)
	for index in range(Expedition.relic_capacity):
		var id := entries[index] if index < entries.size() else ""
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(102, 69)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_font_size_override("font_size", 15)
		slot.text = "%d\n%s" % [index + 1, "空槽位" if id.is_empty() else Expedition.ITEMS[id]["name"]]
		slot.tooltip_text = "空槽位" if id.is_empty() else Expedition.ITEMS[id]["effect"]
		if on_select.is_valid() and not id.is_empty():
			slot.pressed.connect(on_select.bind(id))
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			slot.mouse_filter = Control.MOUSE_FILTER_PASS
			slot.focus_mode = Control.FOCUS_NONE
		grid.add_child(slot)
