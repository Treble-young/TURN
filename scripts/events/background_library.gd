extends Resource

## 数组第一个元素对应 background_1，依此类推。
@export var backgrounds: Array[Texture2D] = []

func get_background(number: int) -> Texture2D:
	return backgrounds[number - 1] if number >= 1 and number <= backgrounds.size() else null
