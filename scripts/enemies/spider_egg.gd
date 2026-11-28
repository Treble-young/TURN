extends EclipseEnemy

signal offspring_requested(kind: String, destination: Vector2, origin: Vector2)

const SCATTER_TIME := 0.28
var launch_origin := Vector2.INF
var landing_point: Vector2
var age := 0.0

func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	landing_point = global_position
	if launch_origin == Vector2.INF:
		launch_origin = landing_point
	global_position = launch_origin

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	age += delta
	var flight := clampf(age / SCATTER_TIME, 0.0, 1.0)
	global_position = launch_origin.lerp(landing_point, flight)
	sprite.position.y = -sin(PI * flight) * 18.0 if flight < 1.0 else 0.0
	if age >= SCATTER_TIME + stats.hatch_time:
		offspring_requested.emit("spiderling", landing_point, landing_point)
		queue_free()
