class_name EclipsePlayer
extends CharacterBody2D

signal attack_started
signal attack_finished

@export var move_speed: float = 240.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_attacking: bool = false
var facing_direction: Vector2 = Vector2.LEFT

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(&"idle")

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	if not is_attacking:
		if not direction.is_zero_approx():
			facing_direction = direction
			if absf(direction.x) > 0.01:
				sprite.flip_h = direction.x > 0.0
		if Input.is_action_just_pressed("attack"):
			attack()
		else:
			_play_animation(&"run" if not direction.is_zero_approx() else &"idle")

## Public entry point for a future automatic weapon controller.
func attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	_play_animation(&"attack")
	attack_started.emit()

func _play_animation(animation_name: StringName) -> void:
	# Use a common ground anchor despite different source framing.
	match animation_name:
		&"run":
			sprite.scale = Vector2.ONE * 0.38
			sprite.offset = Vector2(-222, -389)
		&"attack":
			sprite.scale = Vector2.ONE * 0.32
			sprite.offset = Vector2(-222, -384)
		_:
			sprite.scale = Vector2.ONE * 0.30
			sprite.offset = Vector2(-222, -419)
	# AnimatedSprite2D flips around the origin; compensate for non-centered frames.
	if sprite.flip_h:
		sprite.offset.x = -444.0 - sprite.offset.x
	sprite.play(animation_name)

func _on_animation_finished() -> void:
	if sprite.animation == &"attack":
		is_attacking = false
		_play_animation(&"run" if velocity.length_squared() > 0.01 else &"idle")
		attack_finished.emit()
