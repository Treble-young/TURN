extends EclipseEnemy

const HEART_FRAMES := preload("res://assets/enemies/succubus_heart_frames.tres")
const HEART_BOLT := preload("res://scripts/projectiles/shaman_bolt.gd")
const VULNERABILITY_DURATION := 5.0

func _ready() -> void:
	super._ready()
	sprite.animation_changed.connect(_face_target_on_cast)

func _face_target_on_cast() -> void:
	if sprite.animation == &"attack" and is_instance_valid(target):
		sprite.flip_h = target.global_position.x > global_position.x

func _frame_changed() -> void:
	if sprite.animation != &"attack" or is_dead or not is_attacking or attack_hit or sprite.frame < stats.hit_frame:
		return
	attack_hit = true
	if not is_instance_valid(target) or target.is_dead:
		return
	sprite.flip_h = target.global_position.x > global_position.x
	var bolt := HEART_BOLT.new()
	bolt.frames = HEART_FRAMES
	bolt.speed = 290.0
	bolt.damage = stats.damage
	bolt.vulnerability_duration = VULNERABILITY_DURATION
	bolt.destination = target.global_position + STONE_ORIGIN_OFFSET
	bolt.position = position + Vector2(19 if sprite.flip_h else -19, -38)
	get_parent().add_child(bolt)
