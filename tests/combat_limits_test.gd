extends SceneTree
func _initialize() -> void: check.call_deferred()
func spawn(kind: String, spot: Vector2):
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.stats = load("res://assets/enemies/"+kind+".tres")
	enemy.position = spot
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(6)
	var map = load("res://scenes/maps/levels/f1_level_01.tscn").instantiate()
	root.add_child(map)
	var p = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(p)
	p.set_physics_process(false)
	p.position = Vector2(500,350)
	p.facing_right = true
	p.current_form = p.Form.SHADOW
	var enemies := []
	for i in range(5): enemies.append(spawn("goblin",Vector2(515+i*8,350)))
	p.is_attacking = true
	p.combo_stage = 1
	p._attack_hit = false
	p.sprite.frame = 2
	p._on_attack_frame()
	var hit := 0
	for enemy in enemies:
		if enemy.health < enemy.stats.max_health: hit += 1
	assert(hit == 3)
	assert(enemies[3].health == enemies[3].stats.max_health)
	var shaman = spawn("shaman",Vector2(400,350))
	shaman._process_shaman(0)
	assert(shaman.is_attacking and shaman.velocity == Vector2.ZERO)
	shaman.is_attacking = false
	shaman.attacks_since_heal = 2
	shaman.heal_cooldown = 0
	shaman._process_shaman(0)
	assert(shaman.healing and shaman.velocity == Vector2.ZERO)
	shaman.is_attacking = false
	shaman.cooldown = 10
	shaman.heal_cooldown = 10
	shaman._process_shaman(0)
	assert(shaman.velocity.x < 0)
	for enemy in enemies+[shaman]:
		for spot in [Vector2(-100,-100),Vector2(9000,9000)]:
			enemy.global_position = spot
			enemy._constrain_to_map()
			var center = map.to_local(enemy.to_global(enemy.get_node("CollisionShape2D").position))
			assert(center.x >= map.arena_bounds.position.x + enemy.stats.body_radius)
			assert(center.y >= map.arena_bounds.position.y + enemy.stats.body_radius)
			assert(center.x <= map.arena_bounds.end.x - enemy.stats.body_radius)
			assert(center.y <= map.arena_bounds.end.y - enemy.stats.body_radius)
	print("PASS: shadow 3-target nearest cap; shaman stationary attacks/heals and retreat between casts; enemy collider boundaries")
	quit()
