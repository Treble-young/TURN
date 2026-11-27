extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var target := Node2D.new()
	root.add_child(target)
	var camera = load("res://scripts/maps/follow_camera.gd").new()
	root.add_child(camera)
	var bounds := Rect2(40,107,1072,498)
	for viewport_size in [Vector2i(1152,648),Vector2i(800,600),Vector2i(1600,900)]:
		root.size = viewport_size
		for room in [bounds,Rect2(0,0,4000,3000)]:
			camera.configure(target,room,1,8)
			assert(camera.world_bounds.size == room.size+Vector2(240,360))
			for point in [room.position,room.position+Vector2(room.size.x,0),room.end,room.position+Vector2(0,room.size.y)]:
				target.position = point
				camera._process(0.001)
				var half = camera.get_viewport_rect().size / camera.zoom * 0.5
				var upper = target.position+Vector2(-65,-155)-camera.global_position+half
				var lower = target.position+Vector2(65,25)-camera.global_position+half
				assert(upper.x >= 0 and upper.y >= 105/camera.zoom.y-0.01)
				assert(lower.x <= half.x*2 and lower.y <= half.y*2)
	print("PASS: character fully visible at all corners, small/large rooms, 3 window sizes, abrupt movement and smoothing")
	quit()
