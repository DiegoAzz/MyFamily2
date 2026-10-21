extends Control
class_name TouchActionButton

signal pressed
signal released

@export var action_name: String = "ui_accept"
@export var label_text: String = "ATK"
@export var base_color: Color = Color(0.88, 0.3, 0.28, 0.65)
@export var pressed_color: Color = Color(1.0, 0.45, 0.4, 0.9)
@export var radius: float = 30.0

var is_pressed: bool = false
var active_touch: int = -1

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 10, radius * 2 + 10)
	_set_pressed(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED or what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_pressed:
			_set_pressed(false)
		active_touch = -1

func _process(_delta: float) -> void:
	if active_touch == 998 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		active_touch = -1
		if is_pressed:
			_set_pressed(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_set_pressed(true)
			get_viewport().set_input_as_handled()
			
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and active_touch == -1:
			active_touch = 998
			_set_pressed(true)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if active_touch == -1:
		return
		
	if event is InputEventScreenTouch and event.index == active_touch and not event.pressed:
		active_touch = -1
		_set_pressed(false)
		get_viewport().set_input_as_handled()
		
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and active_touch == 998:
		active_touch = -1
		_set_pressed(false)
		get_viewport().set_input_as_handled()

func _set_pressed(val: bool) -> void:
	is_pressed = val
	if is_pressed:
		Input.action_press(action_name)
		pressed.emit()
		if action_name == "attack":
			var players = get_tree().get_nodes_in_group("player")
			for p in players:
				if is_instance_valid(p) and p.has_method("start_attack") and not p.is_chat_active():
					p.start_attack()
		elif action_name == "interact":
			for obj in get_tree().get_nodes_in_group("interactables"):
				if is_instance_valid(obj) and obj.has_method("trigger_interaction"):
					if "is_player_inside" in obj and obj.is_player_inside:
						obj.trigger_interaction()
	else:
		Input.action_release(action_name)
		released.emit()
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var col = pressed_color if is_pressed else base_color
	var r = radius if not is_pressed else radius * 0.92
	
	# Sombra
	draw_circle(center + Vector2(0, 3), r, Color(0, 0, 0, 0.3))
	
	# Botón principal
	draw_circle(center, r, col)
	draw_arc(center, r, 0, TAU, 32, Color(1, 1, 1, 0.7 if is_pressed else 0.4), 2.5, true)
	
	# Texto
	var font = ThemeDB.fallback_font
	var font_size = 15
	var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center - Vector2(text_size.x / 2.0, -text_size.y / 3.0)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
