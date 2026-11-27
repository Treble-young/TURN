extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	e.start_run(4)
	e.current_kind = e.Kind.BOSS
	e.node_pending = true
	set_meta("battle_map_override","res://scenes/maps/levels/f1_level_01.tscn")
	change_scene_to_file("res://scenes/expedition/arena.tscn")
	await scene_changed
	var arena = current_scene
	arena.set_process(false)
	arena.player.set_physics_process(false)
	var picker
	for child in arena.get_children():
		if child.get_script() == load("res://scripts/upgrades/upgrade_picker.gd"): picker = child
	var hp: float = arena.player.health
	arena.progress.add_experience(52)
	await process_frame
	await process_frame
	assert(e.pending_upgrades == 2 and not paused and not picker.choosing)
	assert(arena.player.max_health == 108 and arena.player.attack_damage == 22 and arena.player.health == hp)
	var before_gold: int = e.gold
	arena._victory()
	await process_frame
	await process_frame
	assert(e.gold == before_gold and e.relics.is_empty())
	var reward = arena.get_child(arena.get_child_count()-1)
	assert(reward.cards.get_child_count() == 3 and reward.next_button.disabled)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/reward-cards-preview.png")
	reward._gold()
	assert(e.gold == before_gold+e.battle_rewards.gold)
	assert(not e.claim_battle_gold())
	reward._relic()
	assert(e.used_relic_slots() == 1 and not e.claim_battle_relic())
	reward._upgrade()
	assert(paused and picker.choosing)
	picker._choose(e.upgrade_choices[0])
	assert(e.pending_upgrades == 1 and paused)
	picker._choose(e.upgrade_choices[0])
	assert(e.pending_upgrades == 0 and not paused and not reward.next_button.disabled)
	# Full-bag rewards remain pending and can be explicitly discarded.
	e.battle_rewards.relic_claimed = false
	e.relic_capacity = 1
	assert(not e.claim_battle_relic())
	e.skip_battle_relic()
	assert(e.battle_rewards.relic_claimed)
	print("PASS: in-battle stats only/no heal or popup; 3 reward cards; separate single-use claims; multi-level settlement upgrades; full bag skip; continue guard")
	for child in root.get_node("MusicManager").get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	quit()
