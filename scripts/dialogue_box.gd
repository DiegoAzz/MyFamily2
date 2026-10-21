extends CanvasLayer
class_name DialogueBox

signal dialogue_finished

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TextContainer/SpeakerName
@onready var dialogue_text_label: RichTextLabel = $PanelContainer/MarginContainer/HBoxContainer/TextContainer/DialogueText
@onready var portrait_rect: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/PortraitContainer/Portrait
@onready var indicator: Label = $PanelContainer/MarginContainer/HBoxContainer/TextContainer/Indicator
@onready var close_btn: Button = $CloseBtn

var current_dialogue_lines: Array = []
var current_line_index: int = 0
var is_active: bool = false
var text_typing_speed: float = 0.02
var is_typing: bool = false
var full_current_text: String = ""
var active_tween: Tween = null

func _ready() -> void:
	visible = false
	panel.custom_minimum_size = Vector2(500, 110)
	panel.gui_input.connect(_on_panel_gui_input)
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func _on_panel_gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		advance_dialogue()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	close_dialogue()

func start_dialogue(speaker: String, lines: Array, portrait: Texture2D = null) -> void:
	current_dialogue_lines = lines
	current_line_index = 0
	is_active = true
	visible = true
	
	speaker_name_label.text = speaker
	if portrait:
		portrait_rect.texture = portrait
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false
		
	# Pausar control del jugador mientras habla
	var player = get_tree().get_first_node_in_group("player")
	if player and "current_state" in player:
		player.velocity = Vector2.ZERO
		player.current_state = 0 # IDLE
		
	_set_touch_controls_visible(false)
	show_current_line()

func _set_touch_controls_visible(active: bool) -> void:
	var touch_ctrls = get_tree().get_first_node_in_group("touch_controls")
	if touch_ctrls:
		touch_ctrls.visible = active
		if not active and touch_ctrls.has_node("HUD/VirtualJoystick"):
			var joy = touch_ctrls.get_node("HUD/VirtualJoystick")
			if joy and joy.has_method("_reset_stick"):
				joy._reset_stick()

func show_current_line() -> void:
	if current_line_index >= current_dialogue_lines.size():
		close_dialogue()
		return
		
	full_current_text = current_dialogue_lines[current_line_index]
	dialogue_text_label.text = ""
	is_typing = true
	indicator.visible = false
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	# Efecto máquina de escribir
	active_tween = create_tween()
	var duration = full_current_text.length() * text_typing_speed
	active_tween.tween_method(_type_text, 0, full_current_text.length(), duration)
	active_tween.finished.connect(func():
		is_typing = false
		indicator.visible = true
	)

func _type_text(length: int) -> void:
	dialogue_text_label.text = full_current_text.substr(0, length)

func advance_dialogue() -> void:
	if not is_active:
		return
		
	if is_typing:
		# Si está escribiendo, autocompletar la línea de inmediato
		if active_tween and active_tween.is_valid():
			active_tween.kill()
		is_typing = false
		dialogue_text_label.text = full_current_text
		indicator.visible = true
	else:
		# Pasar a la siguiente línea
		current_line_index += 1
		show_current_line()

func close_dialogue() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	is_typing = false
	is_active = false
	visible = false
	_set_touch_controls_visible(true)
	dialogue_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	# NUNCA usar la acción de ataque para avanzar diálogos
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance_dialogue()
		get_viewport().set_input_as_handled()
	elif (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		advance_dialogue()
		get_viewport().set_input_as_handled()
