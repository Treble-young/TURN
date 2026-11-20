class_name EclipseEnemy
extends CharacterBody2D

@export var stats: EnemyStats
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var health: float
var is_dead: bool = false
var is_attacking: bool = false
var cooldown: float = 0.0
var attack_hit: bool = false
var target: Node2D

func _ready() -> void:
	health = stats.max_health
	sprite.sprite_frames = load(stats.frames_path)
	sprite.scale = Vector2.ONE * stats.visual_scale
	sprite.offset = Vector2(-128, -225 if stats.display_name == "哥布林" else -224)
	var shape := CircleShape2D.new()
	shape.radius = stats.body_radius
	$CollisionShape2D.shape = shape
	sprite.animation_finished.connect(_animation_finished)
	sprite.frame_changed.connect(_frame_changed)
	sprite.play(&"move")
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	cooldown = maxf(0.0, cooldown - delta)
	if not is_instance_valid(target) or target.is_dead:
		velocity = Vector2.ZERO
		sprite.pause()
		return
	var difference := target.global_position - global_position
	if is_attacking:
		velocity = Vector2.ZERO
	elif difference.length() <= stats.attack_range:
		velocity = Vector2.ZERO
		if cooldown <= 0.0:
			is_attacking = true
			attack_hit = false
			cooldown = stats.attack_interval
			sprite.play(&"attack")
	else:
		velocity = difference.normalized() * stats.move_speed
		sprite.flip_h = difference.x > 0.0
		sprite.play(&"move")
	move_and_slide()

func _frame_changed() -> void:
	if is_dead or not is_attacking or attack_hit or sprite.frame < 1:
		return
	attack_hit = true
	if is_instance_valid(target) and not target.is_dead:
		if global_position.distance_to(target.global_position) <= stats.attack_range + 12.0:
			target.take_damage(stats.damage)

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0:
		is_dead = true
		is_attacking = false
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0
		$CollisionShape2D.set_deferred("disabled", true)
		sprite.play(&"die")
	else:
		sprite.modulate = Color(1.8, 0.65, 0.65)
		get_tree().create_timer(0.12, false).timeout.connect(func():
			if is_instance_valid(sprite): sprite.modulate = Color.WHITE
		)

func _animation_finished() -> void:
	if sprite.animation == &"die":
		if not stats.split_stats_path.is_empty():
			for side in [-1, 1]:
				var child := load("res://scenes/enemies/enemy.tscn").instantiate() as EclipseEnemy
				child.stats = load(stats.split_stats_path)
				child.position = position + Vector2(side * (child.stats.body_radius + 4), 0)
				get_parent().add_child(child)
		queue_free()
	elif sprite.animation == &"attack":
		is_attacking = false
		sprite.play(&"move")
