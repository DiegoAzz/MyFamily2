extends Control

@onready var main_panel: Control = $MainPanel
@onready var create_panel: Control = $CreatePanel
@onready var join_panel: Control = $JoinPanel

# Botones del menú principal
@onready var solo_btn: Button = $MainPanel/VBoxContainer/SoloBtn
@onready var host_btn: Button = $MainPanel/VBoxContainer/HostBtn
@onready var join_menu_btn: Button = $MainPanel/VBoxContainer/JoinMenuBtn

# Elementos de Crear Sala
@onready var create_status_label: Label = $CreatePanel/VBoxContainer/StatusLabel
@onready var room_code_label: Label = $CreatePanel/VBoxContainer/CodeContainer/RoomCodeLabel
@onready var copy_code_btn: Button = $CreatePanel/VBoxContainer/CodeContainer/CopyCodeBtn
@onready var players_label: Label = $CreatePanel/VBoxContainer/PlayersLabel
@onready var start_game_btn: Button = $CreatePanel/VBoxContainer/StartGameBtn
@onready var back_from_create_btn: Button = $CreatePanel/VBoxContainer/BackBtn

# Elementos de Unirse a Sala
@onready var code_input: LineEdit = $JoinPanel/VBoxContainer/CodeInput
@onready var confirm_join_btn: Button = $JoinPanel/VBoxContainer/ConfirmJoinBtn
@onready var join_status_label: Label = $JoinPanel/VBoxContainer/StatusLabel
@onready var back_from_join_btn: Button = $JoinPanel/VBoxContainer/BackBtn

var net_mgr: Node = null

func _ready() -> void:
	show_main_panel()
	
	net_mgr = get_node_or_null("/root/NetworkManager")
	if not net_mgr:
		net_mgr = get_tree().get_first_node_in_group("network_manager")
		
	if net_mgr:
		net_mgr.room_created.connect(_on_room_created)
		net_mgr.room_joined.connect(_on_room_joined)
		net_mgr.room_error.connect(_on_room_error)
		net_mgr.player_joined_room.connect(_on_player_joined_room)
		net_mgr.connection_status_changed.connect(_on_net_status_changed)
		
	solo_btn.pressed.connect(_on_solo_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_menu_btn.pressed.connect(_on_join_menu_pressed)
	
	copy_code_btn.pressed.connect(_on_copy_code_pressed)
	start_game_btn.pressed.connect(_on_enter_world)
	back_from_create_btn.pressed.connect(_on_back_pressed)
	
	confirm_join_btn.pressed.connect(_on_confirm_join_pressed)
	back_from_join_btn.pressed.connect(_on_back_pressed)
	code_input.text_submitted.connect(func(_t): _on_confirm_join_pressed())
	code_input.text_changed.connect(_on_code_input_changed)

func show_main_panel() -> void:
	main_panel.visible = true
	create_panel.visible = false
	join_panel.visible = false

func show_create_panel() -> void:
	main_panel.visible = false
	create_panel.visible = true
	join_panel.visible = false
	room_code_label.text = "..."
	create_status_label.text = "Conectando al servidor y generando código..."
	players_label.text = "👥 Esperando código de sala..."
	start_game_btn.disabled = true

func show_join_panel() -> void:
	main_panel.visible = false
	create_panel.visible = false
	join_panel.visible = true
	code_input.text = ""
	join_status_label.text = "Introduce el código de 4 letras que te dio tu amigo"
	confirm_join_btn.disabled = false

func _on_solo_pressed() -> void:
	if net_mgr:
		net_mgr.start_solo_mode()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_host_pressed() -> void:
	show_create_panel()
	if net_mgr:
		net_mgr.create_room()

func _on_join_menu_pressed() -> void:
	show_join_panel()

func _on_back_pressed() -> void:
	if net_mgr:
		net_mgr.disconnect_network()
	show_main_panel()

func _on_room_created(code: String) -> void:
	room_code_label.text = code
	create_status_label.text = "¡Sala creada con éxito!"
	players_label.text = "👥 Jugadores en sala: Tú (Host)\nEsperando a tu amigo... (o pulsa abajo para entrar)"
	start_game_btn.disabled = false

func _on_player_joined_room(client_id: String) -> void:
	players_label.text = "🎉 ¡Tu amigo (Jugador #" + client_id.substr(0, 3) + ") ha entrado a la sala!\n¡Ya pueden jugar juntos!"
	start_game_btn.disabled = false

func _on_copy_code_pressed() -> void:
	var code = room_code_label.text.strip_edges()
	if code.is_empty() or code == "...":
		return
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard.writeText('" + code + "');")
	copy_code_btn.text = "✅ ¡Copiado!"
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func():
		if is_instance_valid(copy_code_btn):
			copy_code_btn.text = "📋 Copiar Código"
	)

func _on_code_input_changed(new_text: String) -> void:
	var uppercase_text = new_text.to_upper().strip_edges()
	if code_input.text != uppercase_text:
		code_input.text = uppercase_text
		code_input.caret_column = uppercase_text.length()

func _on_confirm_join_pressed() -> void:
	var code = code_input.text.to_upper().strip_edges()
	if code.length() < 3:
		join_status_label.text = "⚠️ El código debe tener al menos 3 o 4 letras (Ej: VALE)"
		return
	join_status_label.text = "Conectando y buscando la sala " + code + "..."
	confirm_join_btn.disabled = true
	if net_mgr:
		net_mgr.join_room(code)

func _on_room_joined(code: String) -> void:
	join_status_label.text = "✅ ¡Entraste a la sala " + code + "! Cargando la granja..."
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(_on_enter_world)

func _on_room_error(msg: String) -> void:
	confirm_join_btn.disabled = false
	join_status_label.text = "❌ " + msg
	create_status_label.text = "❌ " + msg

func _on_net_status_changed(msg: String) -> void:
	if join_panel.visible:
		join_status_label.text = msg
	elif create_panel.visible and room_code_label.text == "...":
		create_status_label.text = msg

func _on_enter_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
