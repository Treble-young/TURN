extends EclipseEnemy
signal offspring_requested(kind: String, destination: Vector2, origin: Vector2)
const WEB_HEALTH := 60.0
var web_cooldown := 6.0
var egg_cooldown := 14.0
var egg_rng := RandomNumberGenerator.new()
func _ready() -> void:
	super._ready()
	egg_rng.seed = hash("spider:%d:%d" % [Expedition.run_seed,Expedition.floor_number])
func _physics_process(delta: float) -> void:
	if is_dead: return
	if stun_remaining <= 0:
		web_cooldown = maxf(0,web_cooldown-delta)
		egg_cooldown = maxf(0,egg_cooldown-delta)
	if not is_attacking and stun_remaining <= 0 and is_instance_valid(target) and not target.is_dead:
		if web_cooldown <= 0:
			web_cooldown = 18.0
			_begin_special(&"web")
		elif egg_cooldown <= 0:
			egg_cooldown = 24.0
			# Use the supplied casting animation for egg launch as well.
			_begin_special(&"web")
			spell = &"eggs"
		if is_attacking:
			velocity = Vector2.ZERO
			sprite.flip_h = target.global_position.x > global_position.x
	super._physics_process(delta)
func take_damage(amount: float, shadow_damage: bool = false) -> void:
	if is_dead or amount <= 0 or sprite.animation == &"web": return
	super.take_damage(amount,shadow_damage)
	if is_dead: health_bar.hide()
func _frame_changed() -> void:
	if sprite.animation != &"web": super._frame_changed()
func _animation_finished() -> void:
	if sprite.animation == &"web":
		if spell == &"eggs":
			_emit_eggs()
		elif is_instance_valid(target) and not target.is_dead:
			_flash_silk()
			target.bind_with_web(WEB_HEALTH)
		is_attacking = false
		sprite.play(&"move")
		return
	if sprite.animation == &"die":
		_emit_spiders(3)
		_emit_eggs(5)
		hide()
	super._animation_finished()
func _emit_spiders(count: int) -> void:
	for index in count:
		var direction := Vector2.from_angle(TAU*index/count)
		var spot := global_position + direction*100
		offspring_requested.emit("spiderling",spot,spot)
func _emit_eggs(count: int = 3) -> void:
	var bounds: Rect2 = bounds_map.arena_bounds if is_instance_valid(bounds_map) else Rect2(40,107,1072,498)
	var origin := bounds_map.global_position if is_instance_valid(bounds_map) else Vector2.ZERO
	bounds.position += origin
	var center_area := bounds.grow_individual(-bounds.size.x*.18,-bounds.size.y*.18,-bounds.size.x*.18,-bounds.size.y*.18)
	var chosen: Array[Vector2] = []
	for index in count:
		var best := bounds.get_center()
		var best_score := -INF
		for attempt in 100:
			var spot := Vector2(egg_rng.randf_range(center_area.position.x,center_area.end.x),egg_rng.randf_range(center_area.position.y,center_area.end.y))
			var separation := spot.distance_to(global_position)
			for previous in chosen: separation = minf(separation,spot.distance_to(previous)*3)
			if separation > best_score:
				best_score = separation
				best = spot
			if separation >= 240: break
		chosen.append(best)
		offspring_requested.emit("spider_egg",best,global_position)

func _flash_silk() -> void:
	var cast := Line2D.new()
	cast.width = 3.0
	cast.default_color = Color("#ede0c6")
	cast.antialiased = true
	cast.z_index = 2
	var from := Vector2(36 if sprite.flip_h else -36, -38)
	var to := to_local(target.global_position) + Vector2(0, -43)
	cast.points = PackedVector2Array([from, from.lerp(to, 0.5) + Vector2(0, -10), to])
	add_child(cast)
	var flash := create_tween()
	flash.tween_property(cast, "modulate:a", 0.0, 0.20)
	flash.tween_callback(cast.queue_free)
