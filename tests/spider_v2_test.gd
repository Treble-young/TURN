extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(2)
	e.current_kind = e.Kind.BOSS
	e.node_pending = true
	set_meta("battle_map_override","res://scenes/maps/levels/f1_boss.tscn")
	change_scene_to_file("res://scenes/expedition/arena.tscn")
	await scene_changed
	var arena = current_scene
	arena.set_process(false)
	arena.player.set_physics_process(false)
	var boss = get_nodes_in_group("enemies")[0]
	boss.set_physics_process(false)
	assert(boss.health==1024 and boss.stats.damage==20 and boss.stats.move_speed==55 and boss.stats.experience_reward==24)
	assert(is_equal_approx(boss.sprite.scale.x,.99))
	assert(boss.web_cooldown==6 and boss.egg_cooldown==14)
	assert(boss.melee_contact(boss.global_position+Vector2(-200,-106),105,Vector2.RIGHT))
	assert(boss.blade_contact(boss.global_position+Vector2(-200,-200),Vector2.RIGHT,400,18)>=0)
	assert(boss.blade_contact(boss.global_position+Vector2(-200,-250),Vector2.RIGHT,400,18)<0)
	assert(boss.get_node("CollisionShape2D").shape.radius==42)
	boss.take_damage(400)
	assert(boss.health==624 and boss.sprite.animation!=&"web")
	boss.web_cooldown = 0
	boss._physics_process(0)
	assert(boss.sprite.animation==&"web" and boss.web_cooldown==18)
	boss._animation_finished()
	assert(arena.player.web_health==60)
	var spiders := 0
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.stats.display_name=="小蜘蛛":
			spiders+=1
			assert(enemy.health==112 and enemy.stats.damage==3 and enemy.stats.experience_reward==0)
	assert(spiders==0)
	boss.egg_cooldown = 0
	boss._physics_process(0)
	assert(boss.spell==&"eggs" and boss.egg_cooldown==24)
	boss._animation_finished()
	var eggs := []
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.stats.display_name=="白色虫卵":
			eggs.append(enemy)
			assert(enemy.health==48 and enemy.landing_point.distance_to(boss.global_position)>=220)
	assert(eggs.size()==3)
	boss.take_damage(9999)
	assert(boss.is_dead)
	boss._animation_finished()
	await process_frame
	var counts := {}
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		counts[enemy.stats.display_name] = counts.get(enemy.stats.display_name,0)+1
	assert(counts.get("小蜘蛛",0)==3 and counts.get("白色虫卵",0)==8)
	var egg = eggs[0]
	egg._physics_process(10.27)
	assert(not egg.is_queued_for_deletion())
	egg._physics_process(.02)
	assert(egg.is_queued_for_deletion())
	# Same resource in normal/elite/boss nodes: only elite multiplies health/damage.
	for kind in [e.Kind.BATTLE,e.Kind.ELITE,e.Kind.BOSS]:
		e.current_kind = kind
		arena._spawn("goblin",Vector2(400,300))
		var enemy = arena.get_child(arena.get_child_count()-1)
		enemy.set_physics_process(false)
		assert(is_equal_approx(enemy.health,56*(1.25 if kind==e.Kind.ELITE else 1.0)))
		assert(is_equal_approx(enemy.stats.damage,6*(1.25 if kind==e.Kind.ELITE else 1.0)))
		assert(enemy.stats.experience_reward==4)
	print("PASS: boss base stats/size, no HP gates, timed web and eggs, central separated egg landing, offspring/death/hatch, elite 1.25 and boss 1.0 multipliers")
	quit()
