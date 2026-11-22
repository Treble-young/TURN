class_name EclipsePlayer
extends CharacterBody2D

signal attack_started
signal attack_finished
signal health_changed(current: float, maximum: float)
signal died
signal leveled_up(new_level: int)

@export var move_speed: float = 240.0
@export var max_health: float = 100.0
@export var attack_damage: float = 18.0
@export var attack_range: float = 105.0
@export var hurt_invulnerability: float = 0.6
var health: float
var is_dead: bool = false
var _hurt_timer: float = 0.0
var _attack_hit: bool = false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var experience_progress: ExperienceProgress = $ExperienceProgress
var is_attacking: bool = false
var facing_direction: Vector2 = Vector2.LEFT
var facing_right: bool = false

func _ready() -> void:
	health = max_health
	experience_progress.leveled_up.connect(func(new_level: int): leveled_up.emit(new_level))
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_attack_frame)
	_play_animation(&"idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	_hurt_timer = maxf(0.0, _hurt_timer - _delta)
	sprite.modulate = Color(1, 0.6, 0.6) if _hurt_timer > 0 else Color.WHITE
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	if not is_attacking:
		if not direction.is_zero_approx():
			facing_direction = direction
			if absf(direction.x) > 0.01:
				facing_right = direction.x > 0.0
		if Input.is_action_just_pressed("attack"):
			attack()
		else:
			_play_animation(&"run" if not direction.is_zero_approx() else &"idle")

## Public entry point for a future automatic weapon controller.
func attack() -> void:
	if is_attacking or is_dead:
		return
	is_attacking = true
	_attack_hit = false
	_play_animation(&"attack")
	attack_started.emit()

func _play_animation(animation_name: StringName) -> void:
	# Use a common ground anchor despite different source framing.
	match animation_name:
		&"run":
			sprite.scale = Vector2.ONE * 0.38
			sprite.offset = Vector2(-222, -389)
		&"attack":
			sprite.scale = Vector2.ONE * 0.42
			sprite.offset = Vector2(-222, -356)
		&"die":
			sprite.scale = Vector2.ONE * 0.38
			sprite.offset = Vector2(-222, -384)
		_:
			sprite.scale = Vector2.ONE * 0.30
			sprite.offset = Vector2(-222, -419)
	# Dedicated right-facing sheets have their own framing and source scale.
	if facing_right:
		match animation_name:
			&"run":
				sprite.scale = Vector2.ONE * 0.34
				sprite.offset = Vector2(-250, -387)
			&"attack":
				sprite.scale = Vector2.ONE * 0.35
				sprite.offset = Vector2(-222, -392)
			&"die":
				sprite.scale = Vector2.ONE * 0.38
				sprite.offset = Vector2(-222, -384)
			_:
				sprite.scale = Vector2.ONE * 0.30
				sprite.offset = Vector2(-235, -425)
		animation_name = StringName(String(animation_name) + "_right")
	sprite.play(animation_name)

func _on_animation_finished() -> void:
	if is_dead:
		if sprite.animation in [&"die", &"die_right"]:
			died.emit()
		return
	if sprite.animation in [&"attack", &"attack_right"]:
		is_attacking = false
		_play_animation(&"run" if velocity.length_squared() > 0.01 else &"idle")
		attack_finished.emit()

func _on_attack_frame() -> void:
	if is_dead or not is_attacking or _attack_hit or sprite.frame < 3:
		return
	_attack_hit = true
	var direction := Vector2.RIGHT if facing_right else Vector2.LEFT
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() <= attack_range + enemy.stats.body_radius and (offset.length() < 25 or direction.dot(offset.normalized()) >= 0.0):
			enemy.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if is_dead or _hurt_timer > 0 or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	_hurt_timer = hurt_invulnerability
	health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		sprite.modulate = Color.WHITE
		collision_layer = 0
		collision_mask = 0
		_play_animation(&"die")

func gain_experience(amount: int) -> void:
	if not is_dead:
		experience_progress.add_experience(amount)
