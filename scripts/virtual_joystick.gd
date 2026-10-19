extends Control
class_name MobileJoystick

@export var max_distance: float = 45.0
@export var deadzone: float = 0.15

var output: Vector2 = Vector2.ZERO
var touch_index: int = -1
var stick_pos: Vector2 = Vector2.ZERO
var is_active: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(130, 130)

func _gui_input(event: InputEvent) -> void:
	var center = size / 2.0
	
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			is_active = true
			_update_stick(event.position - center)
		elif not event.pressed and event.index == touch_index:
			_reset_stick()
			
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_stick(event.position - center)
		
	# Soporte para mouse en desktop / pruebas
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and touch_index == -1:
			touch_index = 999
			is_active = true
			_update_stick(event.position - center)
		elif not event.pressed and touch_index == 999:
			_reset_stick()
			
	elif event is InputEventMouseMotion and touch_index == 999:
		_update_stick(event.position - center)

func _update_stick(offset: Vector2) -> void:
	if offset.length() > max_distance:
		stick_pos = offset.normalized() * max_distance
	else:
		stick_pos = offset
		
	var norm = stick_pos / max_distance
	if norm.length() < deadzone:
		output = Vector2.ZERO
	else:
		output = norm
		
	queue_redraw()

func _reset_stick() -> void:
	touch_index = -1
	is_active = false
	stick_pos = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	
	# Circulo base
	var base_color = Color(0.12, 0.15, 0.22, 0.45) if not is_active else Color(0.18, 0.24, 0.35, 0.6)
	var border_color = Color(0.85, 0.9, 1.0, 0.3) if not is_active else Color(1.0, 0.85, 0.3, 0.7)
	draw_circle(center, max_distance + 8, base_color)
	draw_arc(center, max_distance + 8, 0, TAU, 32, border_color, 2.0, true)
	
	# Indicadores direccionales sutiles (cruceta suave)
	var cross_color = Color(1.0, 1.0, 1.0, 0.15)
	draw_line(center - Vector2(max_distance - 5, 0), center + Vector2(max_distance - 5, 0), cross_color, 1.5)
	draw_line(center - Vector2(0, max_distance - 5), center + Vector2(0, max_distance - 5), cross_color, 1.5)
	
	# Palanca / Stick
	var stick_center = center + stick_pos
	var stick_color = Color(0.9, 0.95, 1.0, 0.75) if not is_active else Color(1.0, 0.85, 0.3, 0.9)
	draw_circle(stick_center, 18, stick_color)
	draw_arc(stick_center, 18, 0, TAU, 24, Color(0.1, 0.1, 0.1, 0.4), 1.5, true)
