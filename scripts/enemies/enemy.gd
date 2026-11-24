class_name EclipseEnemy
extends CharacterBody2D

const SPLIT_OFFSETS := [-1, 1]
const STONE_PROJECTILE := preload("res://scripts/projectiles/goblin_stone.gd")
const STONE_ORIGIN_OFFSET := Vector2(0, -8)
const HEALTH_BAR := preload("res://scripts/ui/enemy_health_bar.gd")
const DAMAGE_NUMBER := preload("res://scripts/ui/damage_number.gd")
static var head_positions: Dictionary = {}

@export var stats: EnemyStats
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var health: float
var is_dead: bool = false
var is_attacking: bool = false
var cooldown: float = 0.0
var attack_hit: bool = false
var target: Node2D
var health_bar: Node2D
var damage_number_index := 0

func _ready() -> void:
	stats = stats.duplicate() as EnemyStats
	stats.max_health *= Expedition.ENEMY_MULTIPLIERS[Expedition.difficulty] * Expedition.enemy_health_modifier()
	stats.damage *= Expedition.ENEMY_MULTIPLIERS[Expedition.difficulty]
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
	_build_health_bar()
	target = get_tree().get_first_node_in_group("player")
	if is_instance_valid(target) and target.is_transforming:
		target.freeze_enemy(self)

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
			if stats.throws_stones:
				sprite.flip_h = difference.x > 0.0
			sprite.play(&"attack")
	else:
		velocity = difference.normalized() * stats.move_speed
		sprite.flip_h = difference.x > 0.0
		sprite.play(&"move")
	move_and_slide()

func _frame_changed() -> void:
	var release_frame := 2 if stats.throws_stones else 1
	if is_dead or not is_attacking or attack_hit or sprite.frame < release_frame:
		return
	attack_hit = true
	if not is_instance_valid(target) or target.is_dead:
		return
	if stats.throws_stones:
		_throw_stone(target.global_position + STONE_ORIGIN_OFFSET)
	elif global_position.distance_to(target.global_position) <= stats.attack_range + 12.0:
		target.take_damage(stats.damage)

func _throw_stone(aim_point: Vector2) -> void:
	var origin := global_position + STONE_ORIGIN_OFFSET
	sprite.flip_h = aim_point.x > origin.x
	var stone := STONE_PROJECTILE.new()
	stone.destination = aim_point
	stone.damage = stats.damage
	get_parent().add_child(stone)
	stone.global_position = origin

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	health_bar.update_health(health, stats.max_health)
	_show_damage_number(amount)
	if health <= 0:
		is_dead = true
		_drop_experience()
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

func _build_health_bar() -> void:
	# Cache the visible silhouette, not the padded frame rectangle. Different
	# slime sizes share this result while retaining their own visual scale.
	if not head_positions.has(stats.frames_path):
		var head_y := 256.0
		for frame in sprite.sprite_frames.get_frame_count(&"move"):
			var image := sprite.sprite_frames.get_frame_texture(&"move", frame).get_image()
			var bounds := image.get_used_rect()
			# Ignore the sheet's faint alpha speckles and glow around the figure.
			for y in range(bounds.position.y, bounds.end.y):
				var solid_pixels := 0
				for x in range(bounds.position.x, bounds.end.x):
					if image.get_pixel(x, y).a >= 0.6: solid_pixels += 1
					if solid_pixels >= 6: break
				if solid_pixels >= 6:
					head_y = minf(head_y, y)
					break
		head_positions[stats.frames_path] = head_y
	health_bar = HEALTH_BAR.new()
	health_bar.name = "HealthBar"
	health_bar.width = clampf(stats.body_radius * 2 + 16, 40, 76)
	health_bar.position = Vector2(0, (sprite.offset.y + float(head_positions[stats.frames_path])) * stats.visual_scale - 12)
	health_bar.z_index = 20
	add_child(health_bar)
	health_bar.update_health(health, stats.max_health)

func _show_damage_number(amount: float) -> void:
	var number := DAMAGE_NUMBER.new()
	number.amount = amount
	var spread := float(damage_number_index % 3 - 1)
	number.drift = spread * 18
	number.position = position + health_bar.position + Vector2(spread * 10, -9 - (damage_number_index % 2) * 9)
	damage_number_index += 1
	# A sibling survives the enemy's death animation and queue_free.
	get_parent().add_child(number)

func _animation_finished() -> void:
	if sprite.animation == &"die":
		if not stats.split_stats_path.is_empty():
			for side in SPLIT_OFFSETS:
				var child := load("res://scenes/enemies/enemy.tscn").instantiate() as EclipseEnemy
				child.stats = load(stats.split_stats_path)
				child.position = position + Vector2(side * (child.stats.body_radius + 4), 0)
				get_parent().add_child(child)
		queue_free()
	elif sprite.animation == &"attack":
		is_attacking = false
		sprite.play(&"move")

func _drop_experience() -> void:
	if stats.experience_reward <= 0:
		return
	var orb := preload("res://scenes/pickups/experience_orb.tscn").instantiate() as ExperienceOrb
	orb.experience_value = stats.experience_reward
	orb.position = position + Vector2(0, -8)
	get_parent().add_child.call_deferred(orb)
