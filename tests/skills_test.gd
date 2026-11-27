extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	var catalog = load("res://scripts/upgrades/skill_catalog.gd")
	assert(catalog.SKILLS.size() == 23)
	for id in ["light_blade","light_range","light_pierce"]: assert(not e.ITEMS.has(id))
	for seed_value in range(40):
		e.start_run(seed_value)
		for turn in range(24):
			e.pending_upgrades += 1
			var choices = e.next_upgrade_choices()
			assert(choices.size() == 3 and choices == e.next_upgrade_choices())
			var types := {}
			for id in choices:
				assert(not types.has(catalog.SKILLS[id].type))
				types[catalog.SKILLS[id].type] = true
			assert(e.choose_upgrade(choices[0]))
			assert(not e.choose_upgrade(choices[0]))
			assert(e.skill(choices[0]) <= catalog.SKILLS[choices[0]].max)
	e.start_run(4)
	e.current_kind = e.Kind.BATTLE
	e.node_pending = true
	set_meta("battle_map_override","res://scenes/maps/levels/f1_level_01.tscn")
	change_scene_to_file("res://scenes/expedition/arena.tscn")
	await scene_changed
	var arena = current_scene
	arena.set_process(false)
	var p = arena.player
	p.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	arena.progress.add_experience(52)
	assert(e.pending_upgrades == 2)
	await process_frame
	var picker
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/upgrades/upgrade_picker.gd"): picker = child
	await process_frame
	await process_frame
	assert(not picker.choosing and not paused)
	picker.begin()
	assert(picker.choosing and paused)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skill-picker.png")
	picker._choose(e.upgrade_choices[0])
	assert(paused and e.pending_upgrades == 1)
	picker._choose(e.upgrade_choices[0])
	assert(not paused and e.pending_upgrades == 0)
	for id in catalog.SKILLS: e.upgrades[id] = catalog.SKILLS[id].max
	p.refresh_skills()
	assert(is_equal_approx(p.max_charge_time,1.05) and p.shadow_target_limit == 5)
	assert(p.skill_form_duration() == 20)
	p.opening_ready = true
	assert(p.consume_opening() == 2 and p.consume_opening() == 1)
	var enemy = get_nodes_in_group("enemies")[0]
	enemy.stats.max_health = 9999
	enemy.health = 9999
	p.deal_skill_hit(enemy,10,false)
	assert(enemy.form_mark == 0)
	var hp: float = enemy.health
	p.deal_skill_hit(enemy,10,true)
	assert(is_equal_approx(enemy.health,hp-10-p.attack_damage*0.8) and enemy.form_mark == -1)
	enemy.apply_movement_slow(0.3,3)
	assert(is_equal_approx(enemy.movement_slow_fraction,0.3))
	p.current_form = p.Form.SHADOW
	p.health = 50
	enemy.health = 1
	p.deal_skill_hit(enemy,10,true)
	assert(p.health == 51)
	var foe = get_nodes_in_group("enemies")[1]
	foe.is_boss = false
	p._finish_transformation()
	assert(foe.stun_remaining == 4 and p.health == 55 and p.opening_ready)
	e.upgrades["light_long"] = 5
	e.upgrades["light_short"] = 0
	assert(p.skill_form_duration() == 30)
	p.current_form = p.Form.SHADOW
	e.upgrades["shadow_long"] = 0
	assert(p.skill_form_duration() == 10)
	assert(e.skill("pierce") == 3)
	p.current_form = p.Form.LIGHT
	p.charge_time = p.max_charge_time
	p._light_shot_damage = 100
	p._spawn_light_blade()
	var blade = get_nodes_in_group("player_projectiles").back()
	assert(blade.hits_left == 4 and is_zero_approx(blade.damage_decay))
	print("PASS: 23 skills, 40 seeded full runs of distinct-type choices/caps, multi-level pause UI, effects and timers, mark/kill-heal/stun/opening, relic removal")
	e.start_run(1)
	assert(e.upgrades.is_empty() and e.pending_upgrades == 0)
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	quit()
