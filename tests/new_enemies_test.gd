extends SceneTree
func _initialize() -> void: check.call_deferred()
func spawn(kind: String, where: Vector2):
	var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
	enemy.stats = load("res://assets/enemies/" + kind + ".tres")
	enemy.position = where
	root.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(3, e.Difficulty.HARD)
	var player = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(player)
	player.position = Vector2(600,350)
	player.set_physics_process(false)
	var shaman = spawn("shaman", Vector2(300,350))
	var ally = spawn("goblin", Vector2(220,380))
	var other = spawn("beetle", Vector2(800,350))
	ally.health = 5
	other.health = 10
	assert(shaman.stats.experience_reward == 6 and other.stats.experience_reward == 5)
	assert(shaman._heal_target() == ally)
	shaman._process_shaman(0)
	assert(shaman.is_attacking)
	shaman.sprite.set_frame_and_progress(4,0)
	assert(shaman.attacks_since_heal == 1)
	shaman.sprite.set_frame_and_progress(5,0)
	assert(shaman.attacks_since_heal == 1)
	shaman._animation_finished()
	shaman.cooldown = 0
	shaman._process_shaman(0)
	shaman.sprite.set_frame_and_progress(4,0)
	assert(shaman.attacks_since_heal == 2)
	shaman._animation_finished()
	shaman.heal_cooldown = 0
	shaman._process_shaman(0)
	assert(shaman.healing and shaman.sprite.animation == &"heal")
	shaman.sprite.set_frame_and_progress(4,0)
	assert(is_equal_approx(ally.health,5+6*1.2*4) and other.health == 10)
	assert(shaman.attacks_since_heal == 0)
	shaman._animation_finished()
	shaman.global_position = player.global_position - Vector2(200,0)
	shaman.cooldown = 10
	shaman._process_shaman(0)
	assert(shaman.velocity.x < 0)
	shaman.global_position = player.global_position - Vector2(450,0)
	shaman._process_shaman(0)
	assert(shaman.velocity.x > 0)
	other.position = player.position + Vector2(51,0)
	other.take_damage(999)
	var hp: float = player.health
	other.sprite.set_frame_and_progress(6,0)
	assert(player.health == hp and other.exploded)
	var near = spawn("beetle",player.position+Vector2(49,0))
	near.take_damage(999)
	near.sprite.set_frame_and_progress(6,0)
	assert(is_equal_approx(player.health,hp-5*1.2*2))
	near._explode()
	assert(is_equal_approx(player.health,hp-12))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/new-enemies-preview.png")
	print("PASS: two attacks then lowest-HP ally heal, scaled heal, kiting, 50px death explosion boundary, damage scaling, one-shot guard, XP and animation imports")
	quit()

