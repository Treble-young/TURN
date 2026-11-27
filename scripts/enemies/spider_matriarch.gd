extends EclipseEnemy

signal offspring_requested(kind: String, destination: Vector2, origin: Vector2)

const WEB_THRESHOLDS := [0.75, 0.50, 0.25]
const WEB_HEALTH := 36.0
const EGG_COUNT := 5
const EGG_SCATTER_RADIUS := 80.0
var next_web := 0

func take_damage(amount: float, shadow_damage: bool = false) -> void:
	if is_dead or amount <= 0.0 or sprite.animation == &"web":
		return
	if next_web < WEB_THRESHOLDS.size():
		var threshold := stats.max_health * float(WEB_THRESHOLDS[next_web])
		var until_threshold := health - threshold
		# Gate a heavy hit at the next threshold so it never skips a silk phase.
		if amount >= until_threshold:
			super.take_damage(until_threshold, shadow_damage)
			next_web += 1
			velocity = Vector2.ZERO
			if is_instance_valid(target):
				sprite.flip_h = target.global_position.x > global_position.x
			_begin_special(&"web")
			return
	super.take_damage(amount, shadow_damage)
	if is_dead:
		health_bar.hide()

func _frame_changed() -> void:
	if sprite.animation != &"web":
		super._frame_changed()

func _animation_finished() -> void:
	if sprite.animation == &"web":
		if is_instance_valid(target) and not target.is_dead:
			_flash_silk()
			target.bind_with_web(WEB_HEALTH)
			var away := global_position.direction_to(target.global_position).orthogonal()
			if away.is_zero_approx():
				away = Vector2.RIGHT
			for side: int in [-1, 1]:
				var spot := global_position + away * (58.0 * side)
				offspring_requested.emit("spiderling", spot, spot)
		is_attacking = false
		sprite.play(&"move")
		return
	if sprite.animation == &"die":
		# Eggs join the enemy group before the boss leaves it, so there is no false clear.
		for index in EGG_COUNT:
			var direction := Vector2.from_angle(TAU * index / EGG_COUNT + 0.24)
			var distance := EGG_SCATTER_RADIUS - (index % 3) * 8.0
			offspring_requested.emit("spider_egg", global_position + direction * distance, global_position)
		hide()
	super._animation_finished()

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
