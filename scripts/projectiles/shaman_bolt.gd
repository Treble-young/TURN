extends Node2D

const FRAMES := preload("res://assets/enemies/shaman_bolt_frames.tres")
const SPEED := 325.0
const PLAYER_AND_TERRAIN_MASK := 1 | 4

var destination: Vector2
var damage := 0.0
var sprite: AnimatedSprite2D
@onready var player := get_tree().get_first_node_in_group("player") as EclipsePlayer

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.play(&"play")
	sprite.position.y = -12.0
	sprite.scale = Vector2.ONE * 0.15
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_dead or player.combat_locked:
		queue_free()
		return
	if player.is_transforming:
		return
	if global_position.is_equal_approx(destination):
		queue_free()
		return

	# A swept test covers the whole segment even if the frame takes longer.
	var end := global_position.move_toward(destination, SPEED * delta)
	var query := PhysicsRayQueryParameters2D.create(global_position, end, PLAYER_AND_TERRAIN_MASK)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider == player:
			player.take_damage(damage, true)
		queue_free()
		return

	global_position = end
	sprite.rotation = (destination - global_position).angle() + PI
	if global_position.is_equal_approx(destination):
		queue_free()
