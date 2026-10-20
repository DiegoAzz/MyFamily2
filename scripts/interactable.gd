extends Area2D
class_name Interactable

signal interacted

@export var prompt_message: String = "[ACT] Interactuar"
@export var speaker_name: String = ""
@export var dialogue_lines: Array = []
@export var portrait_texture: Texture2D = null

var is_player_in_range: bool = false
var prompt_label: Label = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Capa del jugador
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_create_prompt_label()

func _create_prompt_label() -> void:
	prompt_label = Label.new()
	prompt_label.text = prompt_message
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-50, -28)
	prompt_label.size = Vector2(100, 20)
	
	# Estilo sutil de bocadillo
	prompt_label.add_theme_font_size_override("font_size", 10)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.visible = false
	add_child(prompt_label)

func _process(_delta: float) -> void:
	if not is_player_in_range:
		return
		
	# Chequear input de interacción (Espacio, Enter, o botón táctil ACT)
	if Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_E):
		trigger_interaction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func trigger_interaction() -> void:
	interacted.emit()
	
	if dialogue_lines.size() > 0:
		var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			dialogue_box.start_dialogue(speaker_name, dialogue_lines, portrait_texture)
