extends HSlider
const TRACK := preload("res://assets/ui/parchment/slider_track.png")
const FILL := preload("res://assets/ui/parchment/slider_fill.png")
const THUMB := preload("res://assets/ui/parchment/slider_thumb.png")
func _ready() -> void:
	for state in ["slider","grabber_area","grabber_area_highlight"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var empty := ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
	for state in ["grabber","grabber_highlight","grabber_disabled"]: add_theme_icon_override(state,empty)
	value_changed.connect(func(_value: float): queue_redraw())
func _draw() -> void:
	var ratio := size.x/1200.0
	var height := 120*ratio
	var origin := Vector2(0,(size.y-height)/2)
	draw_texture_rect(TRACK,Rect2(origin,Vector2(size.x,height)),false)
	var fill_width := 1000*ratio*get_as_ratio()
	if fill_width>0:
		draw_texture_rect_region(FILL,Rect2(origin+Vector2(100,44)*ratio,Vector2(fill_width,32*ratio)),Rect2(0,0,1000*get_as_ratio(),32))
	var thumb_size := Vector2.ONE*112*ratio
	draw_texture_rect(THUMB,Rect2(origin+Vector2(100+1000*get_as_ratio(),60)*ratio-thumb_size/2,thumb_size),false)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_set_pointer(event.position.x)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		_set_pointer(event.position.x)
func _set_pointer(x: float) -> void:
	value = min_value+clampf((x-size.x/12.0)/(size.x*5.0/6.0),0,1)*(max_value-min_value)
	accept_event()
