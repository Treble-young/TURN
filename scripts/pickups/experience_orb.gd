class_name ExperienceOrb
extends Node2D

@export var experience_value: int = 1
@export var attraction_radius: float = 160.0
@export var collect_radius: float = 18.0
@export var min_speed: float = 80.0
@export var max_speed: float = 650.0
var target: EclipsePlayer
var attracted: bool = false
var collected: bool = false

func _ready() -> void:
	add_to_group("experience_pickups")
	target = get_tree().get_first_node_in_group("player") as EclipsePlayer
	$AnimatedSprite2D.play(&"glow")

func attraction_speed(distance: float) -> float:
	var proximity := 1.0 - clampf(distance / attraction_radius, 0.0, 1.0)
	return lerpf(min_speed, max_speed, proximity * proximity)

func _physics_process(delta: float) -> void:
	if collected or not is_instance_valid(target) or target.is_dead:
		return
	var destination := target.global_position + Vector2(0, -12)
	var distance := global_position.distance_to(destination)
	if distance <= attraction_radius * target.experience_attraction_multiplier:
		attracted = true
	if not attracted:
		return
	global_position = global_position.move_toward(destination, attraction_speed(distance) * delta)
	if global_position.distance_to(destination) <= collect_radius:
		collected = true
		target.gain_experience(experience_value)
		queue_free()
