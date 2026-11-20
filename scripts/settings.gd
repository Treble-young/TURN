extends Node

const SAVE_PATH := "user://settings.cfg"
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var volumes := {"Master": 1.0, "Music": 1.0, "SFX": 1.0}
var window_size_index: int = 1
var _window_request: int = 0

func is_editor_embedded() -> bool:
	# Editor embedding uses a native child window, not Window.is_embedded().
	var arguments := OS.get_cmdline_args()
	return get_window().is_embedded() or "--wid" in arguments

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for bus in volumes:
			var value = config.get_value("audio", bus, 1.0)
			if value is float or value is int:
				volumes[bus] = clampf(float(value), 0.0, 1.0)
		window_size_index = clampi(int(config.get_value("display", "window_size_index", 1)), 0, WINDOW_SIZES.size())
	for bus in volumes:
		_apply_volume(bus)
	apply_window_size(window_size_index)

## Future music players use bus Music; gameplay audio players use bus SFX.
func set_volume(bus: String, value: float) -> void:
	if not volumes.has(bus):
		return
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	save_settings()

func _apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value: float = volumes[bus]
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, is_zero_approx(value))

func apply_window_size(index: int) -> void:
	# The entry after the five window sizes represents fullscreen.
	window_size_index = clampi(index, 0, WINDOW_SIZES.size())
	_window_request += 1
	if DisplayServer.get_name() == "headless":
		return
	if is_editor_embedded():
		return
	_apply_native_window.call_deferred(_window_request)

func _apply_native_window(request: int) -> void:
	if request != _window_request:
		return
	if window_size_index == WINDOW_SIZES.size():
		get_window().mode = Window.MODE_FULLSCREEN
		return
	get_window().mode = Window.MODE_WINDOWED
	# Let the OS finish leaving fullscreen/maximized before setting the size.
	await get_tree().process_frame
	if request != _window_request:
		return
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var requested := WINDOW_SIZES[window_size_index]
	var available := usable.size - Vector2i(32, 64)
	var fit_scale := minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
	get_window().size = Vector2i(Vector2(requested) * fit_scale)
	get_window().position = usable.position + Vector2i(Vector2(usable.size - get_window().size) * 0.5)

func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in volumes:
		config.set_value("audio", bus, volumes[bus])
	config.set_value("display", "window_size_index", window_size_index)
	var result := config.save(SAVE_PATH)
	if result != OK:
		push_warning("Unable to save settings: %s" % error_string(result))
