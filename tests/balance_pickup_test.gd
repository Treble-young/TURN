extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(4)
	e.relics["soul_lantern"] = 1
	e.current_kind = e.Kind.BATTLE
	e.node_pending = true
	set_meta("battle_map_override","res://scenes/maps/levels/f1_level_01.tscn")
	change_scene_to_file("res://scenes/expedition/arena.tscn")
	await scene_changed
	var arena = current_scene
	arena.set_process(false)
	var p = arena.player
	p.set_physics_process(false)
	assert(p.experience_bonus_percent == 25 and p.experience_attraction_multiplier == 1)
	for percent in [100,80,50]:
		p.experience_efficiency_percent = percent
		p.experience_remainder = 0
		var before: int = arena.progress.total_experience
		for i in range(8): p.gain_experience(1)
		assert(arena.progress.total_experience-before == [10,8,5][[100,80,50].find(percent)])
	var golem = load("res://scenes/enemies/enemy.tscn").instantiate()
	golem.stats = load("res://assets/enemies/golem.tres")
	arena.add_child(golem)
	golem.set_physics_process(false)
	assert(golem.stats.max_health == 512)
	var normal_height: float = 265*golem.sprite.scale.y
	var normal_foot: float = (318+golem.sprite.offset.y)*golem.sprite.scale.y
	golem.sprite.play(&"attack")
	assert(is_equal_approx(217*golem.sprite.scale.y,normal_height))
	assert(is_equal_approx((270+golem.sprite.offset.y)*golem.sprite.scale.y,normal_foot))
	for enemy in get_nodes_in_group("enemies"): enemy.free()
	var orb = load("res://scenes/pickups/experience_orb.tscn").instantiate()
	orb.position = Vector2(1000,500)
	arena.add_child(orb)
	orb.set_physics_process(false)
	arena.wave_index = arena.waves.size()-1
	arena._process(0)
	assert(arena.collecting and not p.combat_locked)
	Input.action_press("move_right")
	var pos: Vector2 = p.position
	p._physics_process(0.01)
	Input.action_release("move_right")
	assert(p.velocity.x > 0)
	p.position = orb.position+Vector2(0,12)
	orb._physics_process(0)
	assert(orb.collected)
	await process_frame
	arena._process(0)
	assert(arena.finished and p.combat_locked)
	print("PASS: lantern XP bonus/remainder at all difficulties; movement until final XP pickup; golem height and foot alignment")
	quit()
