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
var attacks_since_heal := 0
var heal_cooldown := 0.0
var healing := false
var exploded := false
var summon_cooldown := 3.0
var ranged_cooldown := 0.0
var spell := &""
var is_boss := false
var stun_remaining := 0.0
var movement_slow_remaining := 0.0
var movement_slow_fraction := 0.0
var form_mark := -1
var bounds_map: Node2D

func _ready() -> void:
	stats = stats.duplicate() as EnemyStats
	stats.max_health *= Expedition.ENEMY_MULTIPLIERS[Expedition.difficulty] * Expedition.enemy_health_modifier()
	stats.damage *= Expedition.ENEMY_MULTIPLIERS[Expedition.difficulty]
	stats.ranged_damage *= Expedition.ENEMY_MULTIPLIERS[Expedition.difficulty]
	summon_cooldown = stats.summon_interval
	health = stats.max_health
	heal_cooldown = stats.heal_interval if stats.is_shaman else 0.0
	sprite.sprite_frames = load(stats.frames_path)
	sprite.scale = Vector2.ONE * stats.visual_scale
	sprite.offset = stats.frame_origin
	if stats.display_name == "哥布林": sprite.offset.y = -225
	var shape := CircleShape2D.new()
	shape.radius = stats.body_radius
	$CollisionShape2D.shape = shape
	sprite.animation_finished.connect(_animation_finished)
	sprite.animation_changed.connect(_fit_animation_size)
	sprite.frame_changed.connect(_frame_changed)
	sprite.play(&"move")
	_build_health_bar()
	bounds_map = get_tree().get_first_node_in_group("battle_bounds")
	_constrain_to_map()
	target = get_tree().get_first_node_in_group("player")
	if is_instance_valid(target) and target.is_transforming:
		target.freeze_enemy(self)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	movement_slow_remaining = maxf(0, movement_slow_remaining - delta)
	if movement_slow_remaining <= 0: movement_slow_fraction = 0
	if stun_remaining > 0:
		stun_remaining = maxf(0, stun_remaining - delta)
		velocity = Vector2.ZERO
		sprite.pause()
		return
	if not sprite.is_playing(): sprite.play()
	cooldown = maxf(0.0, cooldown - delta)
	if not is_instance_valid(target) or target.is_dead:
		velocity = Vector2.ZERO
		sprite.pause()
		return
	if stats.is_necromancer or stats.is_yeti:
		_process_special(delta)
		return
	if stats.is_shaman:
		_process_shaman(delta)
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
		velocity = difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
		sprite.flip_h = difference.x > 0.0
		sprite.play(&"move")
	move_and_slide()
	_constrain_to_map()

func _frame_changed() -> void:
	if stats.is_necromancer or stats.is_yeti:
		_special_frame()
		return
	if sprite.animation == &"spawn": return
	if stats.is_shaman:
		_shaman_frame()
		return
	if is_dead and stats.explosion_multiplier > 0 and sprite.frame >= 6:
		_explode()
	var release_frame := 2 if stats.throws_stones else stats.hit_frame
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

func take_damage(amount: float, shadow_damage: bool = false) -> void:
	if is_dead or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	health_bar.update_health(health, stats.max_health)
	_show_damage_number(amount, shadow_damage)
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

func _show_damage_number(amount: float, shadow_damage: bool = false) -> void:
	var number := DAMAGE_NUMBER.new()
	number.amount = amount
	number.ink = Color("#c18aff") if shadow_damage else Color("#ffe069")
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
	elif sprite.animation in [&"attack", &"heal", &"summon", &"ranged", &"spawn"]:
		healing = false
		is_attacking = false
		sprite.play(&"move")

func _drop_experience() -> void:
	if stats.experience_reward <= 0:
		return
	var orb := preload("res://scenes/pickups/experience_orb.tscn").instantiate() as ExperienceOrb
	orb.experience_value = stats.experience_reward
	orb.position = position + Vector2(0, -8)
	get_parent().add_child.call_deferred(orb)

func _process_shaman(delta: float) -> void:
	heal_cooldown = maxf(0, heal_cooldown - delta)
	var difference := target.global_position - global_position
	var distance := difference.length()
	velocity = Vector2.ZERO
	if distance < stats.retreat_distance:
		velocity = -difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
	elif distance > stats.attack_range:
		velocity = difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
	if not is_attacking:
		if attacks_since_heal >= 2 and heal_cooldown <= 0 and is_instance_valid(_heal_target()):
			healing = true
			is_attacking = true
			attack_hit = false
			sprite.play(&"heal")
		elif distance <= stats.attack_range and cooldown <= 0 and (attacks_since_heal < 2 or not is_instance_valid(_heal_target())):
			healing = false
			is_attacking = true
			attack_hit = false
			cooldown = stats.attack_interval
			sprite.flip_h = difference.x > 0
			sprite.play(&"attack")
		else:
			sprite.flip_h = difference.x > 0
			sprite.play(&"move")
	if is_attacking: velocity = Vector2.ZERO
	move_and_slide()
	_constrain_to_map()

func _heal_target() -> EclipseEnemy:
	var result: EclipseEnemy
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally == self or not ally is EclipseEnemy or ally.is_dead or ally.health >= ally.stats.max_health: continue
		if result == null or ally.health < result.health: result = ally
	return result

func _shaman_frame() -> void:
	if is_dead or not is_attacking or attack_hit or sprite.frame < 4: return
	attack_hit = true
	if healing:
		var ally := _heal_target()
		if is_instance_valid(ally):
			ally.health = minf(ally.stats.max_health, ally.health + stats.damage * stats.heal_multiplier)
			ally.health_bar.update_health(ally.health, ally.stats.max_health)
			var effect := AnimatedSprite2D.new()
			effect.sprite_frames = preload("res://assets/enemies/heal_effect_frames.tres")
			effect.sprite_frames = effect.sprite_frames.duplicate()
			effect.sprite_frames.set_animation_loop(&"play", false)
			effect.scale = Vector2.ONE * 0.28
			effect.position = ally.position + Vector2(0, -40)
			get_parent().add_child(effect)
			effect.animation_finished.connect(effect.queue_free)
			effect.play(&"play")
		attacks_since_heal = 0
		heal_cooldown = stats.heal_interval
	else:
		if not is_instance_valid(target) or target.is_dead: return
		var bolt := preload("res://scripts/projectiles/shaman_bolt.gd").new()
		bolt.destination = target.global_position + STONE_ORIGIN_OFFSET
		bolt.damage = stats.damage
		get_parent().add_child(bolt)
		bolt.global_position = global_position + Vector2(0, -30)
		attacks_since_heal += 1

func _explode() -> void:
	if exploded: return
	exploded = true
	if is_instance_valid(target) and not target.is_dead and global_position.distance_to(target.global_position) <= stats.explosion_radius:
		target.take_damage(stats.damage * stats.explosion_multiplier)

func _constrain_to_map() -> void:
	if not is_instance_valid(bounds_map): return
	var bounds: Rect2 = bounds_map.arena_bounds.abs()
	var radius := stats.body_radius
	var low := bounds.position + Vector2.ONE * radius
	var high := bounds.end - Vector2.ONE * radius
	var center := bounds_map.to_local(to_global($CollisionShape2D.position))
	var clamped := Vector2(clampf(center.x, minf(low.x, high.x), maxf(low.x, high.x)), clampf(center.y, minf(low.y, high.y), maxf(low.y, high.y)))
	if bounds.size.x < radius * 2: clamped.x = bounds.get_center().x
	if bounds.size.y < radius * 2: clamped.y = bounds.get_center().y
	global_position += bounds_map.to_global(clamped) - bounds_map.to_global(center)

func _process_special(delta: float) -> void:
	summon_cooldown = maxf(0, summon_cooldown - delta)
	ranged_cooldown = maxf(0, ranged_cooldown - delta)
	var difference := target.global_position - global_position
	var distance := difference.length()
	velocity = Vector2.ZERO
	if not is_attacking:
		if stats.is_necromancer:
			if summon_cooldown <= 0:
				_begin_special(&"summon")
				summon_cooldown = stats.summon_interval
			elif distance <= stats.attack_range and cooldown <= 0:
				_begin_special(&"attack")
				cooldown = stats.attack_interval
			elif distance < 300: velocity = -difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
			elif distance > stats.attack_range: velocity = difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
		else:
			if distance <= stats.attack_range:
				if cooldown <= 0:
					_begin_special(&"attack")
					cooldown = stats.attack_interval
			elif distance <= stats.ranged_range and ranged_cooldown <= 0:
				_begin_special(&"ranged")
				ranged_cooldown = stats.ranged_interval
			if not is_attacking: velocity = difference.normalized() * stats.move_speed * (1.0 - movement_slow_fraction)
		if not is_attacking: sprite.play(&"move")
		sprite.flip_h = difference.x > 0
	move_and_slide()
	_constrain_to_map()

func _begin_special(action: StringName) -> void:
	spell = action
	is_attacking = true
	attack_hit = false
	sprite.play(action)

func _special_frame() -> void:
	if is_dead or not is_attacking or attack_hit or sprite.frame < 4: return
	attack_hit = true
	if spell == &"summon":
		for offset in [Vector2(-40,30),Vector2(0,45),Vector2(40,30)]:
			var child := load("res://scenes/enemies/enemy.tscn").instantiate() as EclipseEnemy
			child.stats = load("res://assets/enemies/skeleton.tres").duplicate()
			var floor_scale := 1.0 + 0.13 * (Expedition.floor_number - 1)
			var hard := Expedition.current_kind == Expedition.Kind.ELITE
			child.stats.max_health *= floor_scale * (1.25 if hard else 1.0)
			child.stats.damage *= floor_scale * (1.25 if hard else 1.0)
			get_parent().add_child(child)
			child.global_position = global_position + offset
			child._constrain_to_map()
			child.is_attacking = true
			child.sprite.play(&"spawn")
		return
	if not is_instance_valid(target) or target.is_dead: return
	if stats.is_yeti and spell == &"attack":
		if global_position.distance_to(target.global_position) <= stats.attack_range + 12:
			target.take_damage(stats.damage, false, 3.0)
	else:
		var bolt := preload("res://scripts/projectiles/shaman_bolt.gd").new()
		if stats.is_yeti:
			bolt.frames = preload("res://assets/enemies/snowball_frames.tres")
			bolt.slow_duration = 3.0
			bolt.speed *= 1.25
			bolt.damage = stats.ranged_damage
		else: bolt.damage = stats.damage
		bolt.destination = target.global_position + STONE_ORIGIN_OFFSET
		get_parent().add_child(bolt)
		bolt.global_position = global_position + Vector2(0,-30)

func _fit_animation_size() -> void:
	# 巨像的攻击图是4行，移动图是3行；用首帧共同站姿校准身体大小与脚底。
	if stats.frames_path != "res://assets/enemies/golem_frames.tres": return
	var ratio := 265.0 / 217.0 if sprite.animation == &"attack" else 1.0
	sprite.scale = Vector2.ONE * stats.visual_scale * ratio
	sprite.offset = stats.frame_origin
	if sprite.animation == &"attack":
		sprite.offset.y = -270.0 + (318.0 + stats.frame_origin.y) / ratio

func apply_movement_slow(fraction: float, duration: float) -> void:
	movement_slow_fraction = maxf(movement_slow_fraction, fraction)
	movement_slow_remaining = maxf(movement_slow_remaining, duration)

func melee_contact(origin: Vector2, reach: float, forward: Vector2) -> bool:
	if stats.hurt_radii == Vector2.ZERO:
		var offset := global_position-origin
		return offset.length()<=reach+stats.body_radius and (offset.length()<25 or forward.dot(offset.normalized())>=0)
	var offset := to_global(stats.hurt_offset)-origin
	var radii := stats.hurt_radii + Vector2.ONE*reach
	return (offset/radii).length_squared()<=1 and forward.dot(offset)+stats.hurt_radii.x>=0

func blade_contact(origin: Vector2, direction: Vector2, step: float, blade_radius: float) -> float:
	var radii := stats.hurt_radii
	if radii == Vector2.ZERO: radii = Vector2.ONE*stats.body_radius
	radii += Vector2.ONE*blade_radius
	var offset := (to_global(stats.hurt_offset)-origin)/radii
	var ray := direction/radii
	var a := ray.length_squared()
	var b := offset.dot(ray)
	var discriminant := b*b-a*(offset.length_squared()-1)
	if discriminant<0: return -1
	var entry := maxf(0,(b-sqrt(discriminant))/a)
	return entry if (b+sqrt(discriminant))/a>=0 and entry<=step else -1
