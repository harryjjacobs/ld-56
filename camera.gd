extends Camera2D

@export var zoom_min = 0.5
@export var zoom_max = 2.0
@export var zoom_speed = Vector2(0.2, 0.2)

var panning = false

func _unhandled_input(event) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = (zoom - zoom_speed).clampf(zoom_min, zoom_max)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = (zoom + zoom_speed).clampf(zoom_min, zoom_max)
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				panning = true
		else:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				panning = false
	elif event is InputEventMouseMotion:
		if panning:
			offset -= event.relative / zoom
			offset = offset.clamp(-Vector2(640, 360), Vector2(640, 360))
