class_name LightBlade
extends Node2D

const NORMAL = preload("res://assets/projectiles/light_blade.png")
const ENHANCED = preload("res://assets/projectiles/light_blade_enhanced.png")
var direction := Vector2.RIGHT
var damage_decay := 0.0
var slow_fraction := 0.0
var damage: float = 18.0
var enhanced: bool = false
var speed: float = 600.0
var remaining_distance: float = 650.0
var hits_left: int = 1
var size_multiplier: float = 1.0
var hit_targets: Array[Node] = []
var owner_player: Node

func _ready() -> void:
	add_to_group("player_projectiles")
	hits_left = maxi(1, hits_left)
	var sprite := Sprite2D.new()
	sprite.texture = ENHANCED if enhanced else NORMAL
	sprite.scale = Vector2.ONE * (0.09 if enhanced else 0.065) * size_multiplier
	sprite.rotation = direction.angle()
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not is_instance_valid(owner_player) or owner_player.is_dead or owner_player.combat_locked:
		queue_free()
		return
	if owner_player.is_transforming:
		return
	var previous := global_position
	var step := minf(speed * delta, remaining_distance)
	var wall_query := PhysicsRayQueryParameters2D.create(previous, previous + direction * step, 4)
	wall_query.hit_from_inside = true
	var wall_hit := get_world_2d().direct_space_state.intersect_ray(wall_query)
	if not wall_hit.is_empty():
		step = previous.distance_to(wall_hit.position)
	global_position += direction * step
	remaining_distance -= step
	# Sort swept-circle intersections so the first physical contact wins,
	# regardless of enemy spawn order. This also avoids fast-shot tunneling.
	var contacts: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_dead or enemy in hit_targets:
			continue
		var center: Vector2 = enemy.global_position + Vector2(0, -30)
		var radius: float = enemy.stats.body_radius + (27.0 if enhanced else 18.0) * size_multiplier
		var offset := center - previous
		var along := offset.dot(direction)
		var perpendicular_squared := maxf(0.0, offset.length_squared() - along * along)
		if perpendicular_squared > radius * radius:
			continue
		var half_chord := sqrt(radius * radius - perpendicular_squared)
		var entry := maxf(0.0, along - half_chord)
		if along + half_chord >= 0.0 and entry <= step:
			contacts.append({"enemy": enemy, "distance": entry})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary): return a.distance < b.distance)
	for contact in contacts:
		var enemy = contact.enemy
		hit_targets.append(enemy)
		if owner_player.has_method("deal_skill_hit"): owner_player.deal_skill_hit(enemy, damage, false)
		else: enemy.take_damage(damage)
		if slow_fraction > 0 and not enemy.is_dead:
			enemy.apply_movement_slow(slow_fraction,3.0)
		damage *= 1.0 - damage_decay
		hits_left -= 1
		if hits_left <= 0:
			queue_free()
			return
	if remaining_distance <= 0 or not wall_hit.is_empty():
		queue_free()
