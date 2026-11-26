extends SceneTree
func _initialize() -> void: check.call_deferred()
func spawn(kind: String, pos: Vector2):
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.stats = load("res://assets/enemies/"+kind+".tres")
	enemy.position = pos
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func check() -> void:
	root.get_node("Expedition").start_run(4)
	var map = load("res://scenes/maps/levels/f1_level_01.tscn").instantiate()
	root.add_child(map)
	var p = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(p)
	p.set_physics_process(false)
	p.position = Vector2(600,350)
	var necro = spawn("necromancer",Vector2(300,350))
	var yeti = spawn("yeti",Vector2(500,350))
	var golem = spawn("golem",Vector2(800,350))
	assert(necro.stats.experience_reward == 7 and yeti.stats.experience_reward == 8 and golem.stats.experience_reward == 8)
	necro._process_special(8.9)
	assert(necro.sprite.animation == &"attack" and necro.velocity == Vector2.ZERO)
	necro._animation_finished()
	necro._process_special(0.2)
	assert(necro.sprite.animation == &"summon")
	necro.sprite.frame = 4
	var skeletons := []
	for enemy in get_nodes_in_group("enemies"):
		if enemy.stats.display_name == "骷髅": skeletons.append(enemy)
	assert(skeletons.size() == 3)
	necro.sprite.frame = 5
	assert(get_nodes_in_group("enemies").size() == 6)
	for enemy in skeletons:
		enemy.set_physics_process(false)
		assert(enemy.stats.experience_reward == 0 and enemy.sprite.animation == &"spawn")
		var hp: float = p.health
		enemy.sprite.frame = 4
		assert(p.health == hp)
	yeti._process_special(0)
	assert(yeti.spell == &"ranged" and yeti.velocity == Vector2.ZERO)
	yeti.sprite.frame = 4
	var projectile = root.get_child(root.get_child_count()-1)
	assert(projectile.damage == 8 and projectile.slow_duration == 3)
	yeti._animation_finished()
	yeti._process_special(0)
	assert(yeti.velocity.x > 0)
	yeti.position = p.position-Vector2(40,0)
	yeti._process_special(0)
	assert(yeti.spell == &"attack")
	yeti.sprite.frame = 4
	assert(p.health == 88 and p.slow_remaining == 3)
	p._hurt_timer = 0
	p.take_damage(8,true,3)
	assert(p.slow_remaining == 6)
	p.take_damage(8,true,3)
	assert(p.slow_remaining == 6)
	p._hurt_timer = 0
	p.set_shield(20)
	p.take_damage(8,true,3)
	assert(p.slow_remaining == 6)
	assert(golem.sprite.sprite_frames.get_frame_count(&"attack") == 16)
	golem.position = p.position+Vector2(40,0)
	golem.is_attacking = true
	golem.sprite.play(&"attack")
	golem.sprite.frame = 8
	assert(not golem.attack_hit)
	golem.sprite.frame = 9
	assert(golem.attack_hit)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/four-enemies-preview.png")
	print("PASS: 3-skeleton summon/one-shot/spawn guard, XP, yeti range selection/approach, slow duration stacking/invulnerability/shield, golem hit frame")
	quit()
