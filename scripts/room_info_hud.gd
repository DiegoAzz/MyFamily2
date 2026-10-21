extends CanvasLayer

@onready var room_label: Label = $Margin/HBoxContainer/RoomBadge/Margin/RoomLabel
@onready var menu_btn: Button = $Margin/HBoxContainer/MenuBtn

func _ready() -> void:
	menu_btn.pressed.connect(_on_menu_pressed)
	update_hud()

func update_hud() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if not net_mgr:
		net_mgr = get_tree().get_first_node_in_group("network_manager")
		
	if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
		room_label.text = "Sala: " + str(net_mgr.current_room_code) + " | En línea"
	else:
		room_label.text = "Modo Solitario"

func _on_menu_pressed() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var player = get_tree().get_first_node_in_group("player")
	if net_mgr and player:
		net_mgr.save_game_state(player.global_position)
	# No destruimos la sala ni la conexión: se mantiene activa para que al pulsar 'Continuar' no se pierda nada
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
