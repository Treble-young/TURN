extends CanvasLayer
## 持久覆盖层，在完全遮黑后切换场景；波形只使用时间，不消耗游戏随机数。
var busy := false
var surface: Control

class TideSurface extends Control:
	var progress := 0.0
	var revealing := false
	func _ready() -> void:
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform bool revealing = false;
uniform float feather = 0.03858;
void fragment() {
	float x = UV.x;
	float t = progress;
	float wave = sin(x*8.7+t*2.8)*0.030 + sin(x*19.3-t*3.1+1.2)*0.020
		+ sin(x*37.1+t*4.6+2.3)*0.012 + sin(x*71.7-t*2.1)*0.006;
	float edge = mix(1.18, -0.18, t) + wave;
	float alpha = smoothstep(-feather, feather, UV.y-edge);
	COLOR = vec4(0.0, 0.0, 0.0, revealing ? 1.0-alpha : alpha);
}
"""
		var ink := ShaderMaterial.new()
		ink.shader = shader
		material = ink
	func _draw() -> void:
		material.set_shader_parameter("feather", 25.0 / maxf(1.0, size.y))
		material.set_shader_parameter("progress", progress)
		material.set_shader_parameter("revealing", revealing)
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = TideSurface.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	surface.hide()

func _input(_event: InputEvent) -> void:
	if busy: get_viewport().set_input_as_handled()

func change_scene(path: String) -> void:
	if busy: return
	busy = true
	surface.progress = 0.0
	surface.revealing = false
	surface.show()
	await _sweep(0.42)
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		await get_tree().scene_changed
		await get_tree().process_frame
	else:
		push_error("节点场景加载失败：" + path)
	surface.revealing = true
	surface.progress = 0.0
	await _sweep(0.42)
	surface.hide()
	busy = false

func _sweep(duration: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(value: float):
		surface.progress = value
		surface.queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
