@tool
extends Node2D

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var visual_size := Vector2(96, 96):
	set(value):
		visual_size = value
		queue_redraw()
@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		_refresh_collision()
@export var footprint := Vector2(48, 24):
	set(value):
		footprint = value
		_refresh_collision()
var _body: StaticBody2D

func _ready() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	var collision := CollisionShape2D.new()
	_body.add_child(collision)
	add_child(_body)
	_refresh_collision()

func _refresh_collision() -> void:
	if is_instance_valid(_body):
		var shape := RectangleShape2D.new()
		shape.size = footprint.abs().max(Vector2.ONE)
		var collision := _body.get_child(0) as CollisionShape2D
		collision.shape = shape
		collision.position = Vector2(0, -footprint.y * 0.5)
		collision.set_deferred("disabled", not blocks_movement)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y), visual_size)
	if texture:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, Color("8b7355"))
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2(-footprint.x * 0.5, -footprint.y), footprint), Color(0.3, 1, 0.5, 0.6), false, 2)
