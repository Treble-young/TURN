extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(1)
	e.upgrades = {"pierce":2,"slow":3,"light_damage":3,"full_charge":2}
	var p = load("res://scenes/characters/player.tscn").instantiate()
	root.add_child(p)
	p.set_physics_process(false)
	p.current_form = p.Form.LIGHT
	p.refresh_skills()
	p.is_charging = true
	p.charge_time = p.max_charge_time
	p._release_light_swing()
	assert(is_equal_approx(p._light_shot_damage,p.attack_damage*3*1.3*1.5))
	var enemies := []
	for i in range(3):
		var enemy = load("res://scenes/enemies/enemy.tscn").instantiate()
		enemy.stats = load("res://assets/enemies/goblin.tres").duplicate()
		enemy.stats.max_health = 1000
		enemy.position = Vector2(100+i*100,130)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	for level in range(3):
		for enemy in enemies: enemy.health = 1000
		var blade = load("res://scripts/projectiles/light_blade.gd").new()
		blade.owner_player = p
		blade.damage = 100
		blade.damage_decay = 0.2-0.1*level
		blade.slow_fraction = 0.3
		blade.hits_left = 3
		blade.position = Vector2(0,100)
		root.add_child(blade)
		blade.set_physics_process(false)
		blade._physics_process(1)
		for i in range(3):
			assert(is_equal_approx(1000-enemies[i].health,100*pow(1-blade.damage_decay,i)))
			assert(is_equal_approx(enemies[i].movement_slow_fraction,0.3))
	print("PASS: swept multi-hit damage decay 20/10/0 percent; slow; full-charge and light damage multipliers")
	quit()
