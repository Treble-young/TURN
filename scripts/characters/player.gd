class_name EclipsePlayer
extends CharacterBody2D

signal attack_started
signal attack_finished
signal health_changed(current: float, maximum: float)
signal died
signal leveled_up(new_level: int)
signal form_changed(new_form: int)

enum Form { SHADOW, LIGHT }
const SHADOW_FRAMES = preload("res://assets/characters/hero/shadow/shadow_frames.tres")
const LIGHT_FRAMES = preload("res://assets/characters/hero/light/light_frames.tres")
const TRANSITION_FRAMES = preload("res://assets/characters/hero/transitions/transitions_frames.tres")
var is_transforming: bool = false
var _frozen_enemies: Dictionary = {}
@export var form_duration: float = 20.0
@export var combo_grace_duration: float = 0.18
var current_form: Form = Form.SHADOW
var form_remaining: float = 20.0
var combo_stage: int = 0
var _combo_queued: bool = false
var _combo_grace: float = 0.0
var _form_label: Label

@export var move_speed: float = 240.0
@export var max_health: float = 100.0
@export var attack_damage: float = 18.0
@export var attack_range: float = 105.0
@export var hurt_invulnerability: float = 0.6
var health: float
var is_dead: bool = false
var _hurt_timer: float = 0.0
var _attack_hit: bool = false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var experience_progress: ExperienceProgress = $ExperienceProgress
var is_attacking: bool = false
var facing_direction: Vector2 = Vector2.LEFT
var facing_right: bool = false

func _ready() -> void:
	health = max_health
	form_remaining = maxf(0.1, form_duration)
	var hud := CanvasLayer.new()
	add_child(hud)
	_form_label = Label.new()
	_form_label.position = Vector2(940, 78)
	_form_label.add_theme_font_size_override("font_size", 16)
	_form_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_form_label)
	experience_progress.leveled_up.connect(func(new_level: int): leveled_up.emit(new_level))
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_attack_frame)
	_play_animation(&"idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	if is_transforming:
		velocity = Vector2.ZERO
		_form_label.text = "TURN..."
		return
	_advance_form(_delta)
	if is_transforming:
		return
	if not is_attacking and _combo_grace > 0:
		_combo_grace = maxf(0.0, _combo_grace - _delta)
		if _combo_grace == 0.0:
			combo_stage = 0
	_form_label.text = "%s  %.1fs" % ["SHADOW" if current_form == Form.SHADOW else "LIGHT", form_remaining]
	if current_form == Form.SHADOW and combo_stage < 3 and ((is_attacking and sprite.frame >= 2) or _combo_grace > 0.0):
		_form_label.text += "  CHAIN!"
	_form_label.modulate = Color("d69dff") if current_form == Form.SHADOW else Color("ffe0a2")
	_hurt_timer = maxf(0.0, _hurt_timer - _delta)
	sprite.modulate = Color(1, 0.6, 0.6) if _hurt_timer > 0 else Color.WHITE
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	if not is_attacking:
		if not direction.is_zero_approx():
			facing_direction = direction
			if absf(direction.x) > 0.01:
				facing_right = direction.x > 0.0
	if Input.is_action_just_pressed("attack"):
		attack()
	elif not is_attacking:
		_play_animation(&"run" if not direction.is_zero_approx() else &"idle")

## Public entry point for a future automatic weapon controller.
func attack() -> void:
	if is_dead or is_transforming:
		return
	if is_attacking:
		if current_form == Form.SHADOW and combo_stage < 3 and sprite.frame >= 2:
			_combo_queued = true
		return
	combo_stage = combo_stage + 1 if current_form == Form.SHADOW and _combo_grace > 0.0 and combo_stage < 3 else 1
	_start_attack_stage()

func _start_attack_stage() -> void:
	is_attacking = true
	_attack_hit = false
	_combo_queued = false
	_combo_grace = 0.0
	_play_animation(&"attack")
	attack_started.emit()

func _advance_form(delta: float) -> void:
	if is_transforming or is_dead:
		return
	form_remaining = maxf(0.0, form_remaining - delta)
	if form_remaining <= 0.0:
		_begin_transformation()

func _begin_transformation() -> void:
	is_transforming = true
	is_attacking = false
	combo_stage = 0
	_combo_queued = false
	_combo_grace = 0.0
	velocity = Vector2.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		freeze_enemy(enemy)
	sprite.modulate = Color.WHITE
	sprite.sprite_frames = TRANSITION_FRAMES
	sprite.scale = Vector2.ONE * 0.43
	sprite.offset = Vector2(-157, -300)
	sprite.play(&"shadow_turn_to_light" if current_form == Form.SHADOW else &"light_turn_to_shadow")

func freeze_enemy(enemy: Node) -> void:
	if not _frozen_enemies.has(enemy):
		_frozen_enemies[enemy] = enemy.process_mode
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _restore_enemies() -> void:
	for enemy in _frozen_enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = _frozen_enemies[enemy]
	_frozen_enemies.clear()

func _finish_transformation() -> void:
	current_form = Form.LIGHT if current_form == Form.SHADOW else Form.SHADOW
	is_transforming = false
	form_remaining = maxf(0.1, form_duration)
	_restore_enemies()
	_play_animation(&"idle")
	form_changed.emit(current_form)

func _exit_tree() -> void:
	_restore_enemies()

func _play_animation(animation_name: StringName) -> void:
	if current_form == Form.SHADOW:
		var side := "right" if facing_right else "left"
		sprite.sprite_frames = SHADOW_FRAMES
		match animation_name:
			&"run":
				sprite.scale = Vector2.ONE * (0.42 if facing_right else 0.40)
				sprite.offset = Vector2(-240 if facing_right else -222, -380)
			&"attack":
				sprite.scale = Vector2.ONE * 0.55
				sprite.offset = Vector2(-181, -304 if facing_right else -325)
			&"die":
				sprite.scale = Vector2.ONE * 0.50
				sprite.offset = Vector2(-222, -370)
			_:
				sprite.scale = Vector2.ONE * (0.33 if facing_right else 0.55)
				sprite.offset = Vector2(-235 if facing_right else -222, -400 if facing_right else -352)
		var name := "attack_%d_%s" % [combo_stage, side] if animation_name == &"attack" else "%s_%s" % [animation_name, side]
		sprite.play(StringName(name))
		return
	sprite.sprite_frames = LIGHT_FRAMES
	match animation_name:
		&"run":
			sprite.scale = Vector2.ONE * (0.44 if facing_right else 0.40)
			sprite.offset = Vector2(-240 if facing_right else -222, -375 if facing_right else -393)
		&"attack":
			sprite.scale = Vector2.ONE * 0.50
			sprite.offset = Vector2(-198, -335 if facing_right else -350)
		&"die":
			sprite.scale = Vector2.ONE * (0.48 if facing_right else 0.50)
			sprite.offset = Vector2(-222, -377 if facing_right else -362)
		_:
			sprite.scale = Vector2.ONE * (0.35 if facing_right else 0.52)
			sprite.offset = Vector2(-235 if facing_right else -222, -390 if facing_right else -354)
	sprite.play(StringName("%s_%s" % [animation_name, "right" if facing_right else "left"]))

func _on_animation_finished() -> void:
	if is_transforming:
		_finish_transformation()
		return
	if is_dead:
		if String(sprite.animation).begins_with("die"):
			died.emit()
		return
	if String(sprite.animation).begins_with("attack"):
		if current_form == Form.SHADOW and _combo_queued and combo_stage < 3:
			combo_stage += 1
			_start_attack_stage()
			return
		_combo_grace = combo_grace_duration if current_form == Form.SHADOW and combo_stage < 3 else 0.0
		is_attacking = false
		_play_animation(&"run" if velocity.length_squared() > 0.01 else &"idle")
		attack_finished.emit()

func _on_attack_frame() -> void:
	if is_dead or not is_attacking or _attack_hit or sprite.frame < (2 if current_form == Form.SHADOW else 6):
		return
	_attack_hit = true
	var direction := Vector2.RIGHT if facing_right else Vector2.LEFT
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length() <= attack_range + enemy.stats.body_radius and (offset.length() < 25 or direction.dot(offset.normalized()) >= 0.0):
			enemy.take_damage(attack_damage * ([1.0, 1.1, 1.5][clampi(combo_stage - 1, 0, 2)] if current_form == Form.SHADOW else 1.0))

func take_damage(amount: float) -> void:
	if is_dead or is_transforming or _hurt_timer > 0 or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	_hurt_timer = hurt_invulnerability
	health_changed.emit(health, max_health)
	if health <= 0:
		is_dead = true
		_combo_queued = false
		_combo_grace = 0.0
		is_attacking = false
		velocity = Vector2.ZERO
		sprite.modulate = Color.WHITE
		collision_layer = 0
		collision_mask = 0
		_play_animation(&"die")

func gain_experience(amount: int) -> void:
	if not is_dead:
		experience_progress.add_experience(amount)
