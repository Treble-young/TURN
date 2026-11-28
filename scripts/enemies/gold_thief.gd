extends EclipseEnemy

signal caught(amount: int)

const GOLD_BOUNTY := 12
const HITS_AT_BASE_DAMAGE := 2.25
var travel_direction := 1.0
var left_edge: float
var right_edge: float

func _ready() -> void:
	super._ready()
	if is_instance_valid(target):
		# Scale against the attack on entry rather than the floor/difficulty multipliers.
		stats.max_health = maxf(1.0, target.attack_damage * HITS_AT_BASE_DAMAGE * Expedition.enemy_health_modifier())
		health = stats.max_health
		health_bar.update_health(health, stats.max_health)
	var bounds: Rect2 = bounds_map.arena_bounds if is_instance_valid(bounds_map) else Rect2(40, 107, 1072, 498)
	var inset := minf(stats.body_radius, bounds.size.x * 0.25)
	left_edge = bounds.position.x + inset
	right_edge = bounds.end.x - inset
	global_position.x = left_edge
	sprite.flip_h = true
	# The runner follows its configured lane without being blocked by the combat crowd.
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(target) or target.is_dead:
		return
	movement_slow_remaining = maxf(0.0, movement_slow_remaining - delta)
	if movement_slow_remaining <= 0.0:
		movement_slow_fraction = 0.0
	if stun_remaining > 0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
		sprite.pause()
		return
	if not sprite.is_playing():
		sprite.play()
	if sprite.animation == &"turn":
		return
	var destination := right_edge if travel_direction > 0.0 else left_edge
	global_position.x = move_toward(global_position.x, destination, stats.move_speed * (1.0 - movement_slow_fraction) * delta)
	if is_equal_approx(global_position.x, destination):
		if travel_direction > 0.0:
			sprite.play(&"turn")
		else:
			queue_free()

func _animation_finished() -> void:
	if sprite.animation == &"turn":
		travel_direction = -1.0
		sprite.flip_h = false
		sprite.play(&"move")
	else:
		super._animation_finished()

func take_damage(amount: float, shadow_damage: bool = false) -> void:
	if is_dead or is_queued_for_deletion():
		return
	super.take_damage(amount, shadow_damage)
	if is_dead:
		caught.emit(GOLD_BOUNTY)
		var notice := DAMAGE_NUMBER.new()
		notice.caption = "+%d 金币" % GOLD_BOUNTY
		notice.position = position + Vector2(0, -75)
		get_parent().add_child(notice)
