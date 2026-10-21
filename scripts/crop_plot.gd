extends Area2D
class_name CropPlot

enum CropType { CARROT, PUMPKIN, STRAWBERRY }
enum State { EMPTY, GROWING, MATURE }

@export var plot_id: String = ""
@export var crop_type: CropType = CropType.CARROT
@export var growth_time: float = 12.0

var current_state: State = State.EMPTY
var growth_timer: float = 0.0
var is_player_inside: bool = false
var prompt_label: Label = null

var tex_dirt = preload("res://sprites/Crops/crop_watered_dirt.png")
var tex_sprout = preload("res://sprites/Crops/crop_sprout.png")
var tex_carrot = preload("res://sprites/Crops/crop_carrot.png")
var tex_pumpkin = preload("res://sprites/Crops/crop_pumpkin.png")
var tex_strawberry = preload("res://sprites/Crops/crop_strawberry.png")

@onready var dirt_sprite: Sprite2D = $DirtSprite
@onready var plant_sprite: Sprite2D = $PlantSprite

func _ready() -> void:
	add_to_group("crop_plots")
	add_to_group("interactables")
	
	if plot_id.is_empty():
		plot_id = "plot_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Inicializar visual
	_update_visuals()

func _process(delta: float) -> void:
	if current_state == State.GROWING:
		growth_timer -= delta
		if growth_timer <= 0.0:
			current_state = State.MATURE
			_update_visuals()
			_spawn_floating_text("¡Cultivo listo para cosechar!", Color(1.0, 0.9, 0.4))
			
	# Interacción con teclado en PC cuando el jugador está encima
	if is_player_inside:
		var interact_pressed = false
		if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
			interact_pressed = true
		elif Input.is_key_pressed(KEY_E):
			interact_pressed = true
		if interact_pressed:
			trigger_interaction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = true
		_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		_hide_prompt()

func trigger_interaction() -> void:
	match current_state:
		State.EMPTY:
			plant_crop()
		State.GROWING:
			var remaining = int(ceil(growth_timer))
			_spawn_floating_text("Creciendo... (" + str(remaining) + "s)", Color(0.6, 0.9, 0.5))
		State.MATURE:
			harvest_crop()

func plant_crop(notify_net: bool = true) -> void:
	current_state = State.GROWING
	growth_timer = growth_time
	_update_visuals()
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_chop"):
			audio.play_chop()
			
	var c_name = _get_crop_name()
	_spawn_floating_text("Sembraste " + c_name + "!", Color(0.5, 1.0, 0.5))
	
	if notify_net:
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
			if net_mgr.socket and net_mgr.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
				net_mgr.socket.send_text(JSON.stringify({
					"type": "crop_planted",
					"plot_id": plot_id,
					"crop_type": int(crop_type)
				}))

func harvest_crop(notify_net: bool = true) -> void:
	current_state = State.EMPTY
	growth_timer = 0.0
	_update_visuals()
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_harvest"):
			audio.play_harvest()
			
	var gold_gain = 30
	var score_gain = 50
	match crop_type:
		CropType.CARROT:
			gold_gain = 30
			score_gain = 50
		CropType.PUMPKIN:
			gold_gain = 60
			score_gain = 90
		CropType.STRAWBERRY:
			gold_gain = 45
			score_gain = 70
			
	var c_name = _get_crop_name()
	_spawn_floating_text("¡Cosechaste " + c_name + "! (+" + str(gold_gain) + " G)", Color(1.0, 0.88, 0.2))
	
	# Aplicar recompensas al jugador
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			if "score" in p:
				p.score += score_gain
			if p.has_method("_update_hud"):
				p._update_hud()
				
	# Avanzar misión de la historia
	var q_mgr = get_tree().get_first_node_in_group("quest_manager")
	if q_mgr and q_mgr.has_method("add_progress"):
		q_mgr.add_progress("crops", 1)
		
	if notify_net:
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
			if net_mgr.socket and net_mgr.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
				net_mgr.socket.send_text(JSON.stringify({
					"type": "crop_harvested",
					"plot_id": plot_id
				}))

func _get_crop_name() -> String:
	match crop_type:
		CropType.CARROT: return "Zanahoria"
		CropType.PUMPKIN: return "Calabaza"
		CropType.STRAWBERRY: return "Fresa Silvestre"
	return "Cultivo"

func _update_visuals() -> void:
	if not is_instance_valid(dirt_sprite) or not is_instance_valid(plant_sprite):
		return
	dirt_sprite.texture = tex_dirt
	match current_state:
		State.EMPTY:
			plant_sprite.visible = false
		State.GROWING:
			plant_sprite.visible = true
			plant_sprite.texture = tex_sprout
			plant_sprite.scale = Vector2(0.85, 0.85)
		State.MATURE:
			plant_sprite.visible = true
			match crop_type:
				CropType.CARROT: plant_sprite.texture = tex_carrot
				CropType.PUMPKIN: plant_sprite.texture = tex_pumpkin
				CropType.STRAWBERRY: plant_sprite.texture = tex_strawberry
			plant_sprite.scale = Vector2(1.1, 1.1)
			
	if is_player_inside:
		_show_prompt()

func _show_prompt() -> void:
	_hide_prompt()
	prompt_label = Label.new()
	match current_state:
		State.EMPTY:
			prompt_label.text = "[ACT] Sembrar " + _get_crop_name()
		State.GROWING:
			prompt_label.text = "Creciendo..."
		State.MATURE:
			prompt_label.text = "[ACT] Cosechar " + _get_crop_name()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 8)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.scale = Vector2(0.65, 0.65)
	prompt_label.position = Vector2(-30, -22)
	add_child(prompt_label)

func _hide_prompt() -> void:
	if is_instance_valid(prompt_label):
		prompt_label.queue_free()
		prompt_label = null

func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.scale = Vector2(0.6, 0.6)
	label.pivot_offset = Vector2(35, 7)
	label.global_position = global_position + Vector2(-25, -16)
	get_parent().add_child(label)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 18.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)
