class_name BattleFollowCamera
extends Camera2D

var target: Node2D
var world_bounds := Rect2()
var base_zoom: float = 1.0
var follow_speed: float = 8.0
var _initialized: bool = false

func configure(player: Node2D, bounds: Rect2, requested_zoom: float, smoothing: float, edge_margin: Vector2 = Vector2(120,180)) -> void:
	target = player
	world_bounds = bounds.abs().grow_individual(maxf(0,edge_margin.x),maxf(0,edge_margin.y),maxf(0,edge_margin.x),maxf(0,edge_margin.y))
	base_zoom = maxf(0.05, requested_zoom)
	follow_speed = maxf(0.0, smoothing)
	_update_zoom()
	global_position = _protect_target(_clamped_center(target.global_position))
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
	global_position = _protect_target(_clamped_center(global_position))

func _protect_target(center: Vector2) -> Vector2:
	# Sprite anchors sit near the feet. Reserve space above for the whole body
	# and leave the top HUD clear, even during smoothing or a sudden resize.
	var half_view := get_viewport_rect().size / zoom * 0.5
	var extent := Rect2(target.global_position + Vector2(-65,-155),Vector2(130,180))
	var inset := Vector2(24,24) / zoom
	var low := extent.end - half_view + inset
	var high := extent.position + half_view - inset
	high.y -= 105.0 / zoom.y
	return Vector2(
		(low.x+high.x)*0.5 if high.x < low.x else clampf(center.x,low.x,high.x),
		(low.y+high.y)*0.5 if high.y < low.y else clampf(center.y,low.y,high.y)
	)
