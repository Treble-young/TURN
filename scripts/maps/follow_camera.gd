class_name BattleFollowCamera
extends Camera2D

var target: Node2D
var world_bounds := Rect2()
var base_zoom: float = 1.0
var follow_speed: float = 8.0
var _initialized: bool = false

func configure(player: Node2D, bounds: Rect2, requested_zoom: float, smoothing: float) -> void:
	target = player
	world_bounds = bounds.abs()
	base_zoom = maxf(0.05, requested_zoom)
	follow_speed = maxf(0.0, smoothing)
	_update_zoom()
	global_position = _clamped_center(target.global_position)
	_initialized = true
	enabled = true
	make_current()
	force_update_scroll()

func _update_zoom() -> void:
	var viewport_size := get_viewport_rect().size
	# A small room must still cover the viewport; larger rooms use base zoom.
	var fit := maxf(viewport_size.x / maxf(1.0, world_bounds.size.x), viewport_size.y / maxf(1.0, world_bounds.size.y))
	zoom = Vector2.ONE * maxf(base_zoom, fit)

func _clamped_center(point: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / zoom * 0.5
	var low := world_bounds.position + half_view
	var high := world_bounds.end - half_view
	var center := world_bounds.get_center()
	return Vector2(
		center.x if high.x <= low.x else clampf(point.x, low.x, high.x),
		center.y if high.y <= low.y else clampf(point.y, low.y, high.y)
	)

func _process(delta: float) -> void:
	if not _initialized or not is_instance_valid(target):
		return
	_update_zoom()
	var desired := _clamped_center(target.global_position)
	global_position = desired if follow_speed == 0.0 else global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	# Re-clamp after smoothing, including when the window changes size.
	global_position = _clamped_center(global_position)
