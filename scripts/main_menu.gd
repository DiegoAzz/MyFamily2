extends Control

@onready var main_panel: Control = $MainPanel
@onready var create_panel: Control = $CreatePanel
@onready var join_panel: Control = $JoinPanel

# Botones del menú principal
@onready var resume_btn: Button = $MainPanel/VBoxContainer/ResumeBtn
@onready var solo_btn: Button = $MainPanel/VBoxContainer/SoloBtn
@onready var host_btn: Button = $MainPanel/VBoxContainer/HostBtn
@onready var join_menu_btn: Button = $MainPanel/VBoxContainer/JoinMenuBtn

# Selector de nombre y personaje
@onready var player_name_input: LineEdit = $MainPanel/VBoxContainer/ProfileBox/NameBox/PlayerNameInput
@onready var prev_skin_btn: Button = $MainPanel/VBoxContainer/ProfileBox/SkinBox/SkinSelectorHBox/PrevSkinBtn
@onready var next_skin_btn: Button = $MainPanel/VBoxContainer/ProfileBox/SkinBox/SkinSelectorHBox/NextSkinBtn
@onready var skin_name_label: Label = $MainPanel/VBoxContainer/ProfileBox/SkinBox/SkinSelectorHBox/SkinNamePanel/SkinNameLabel

const SKIN_NAMES = [
	"Lucas (Clásico)",
	"Mateo (Rojo)",
	"Clara (Verde)",
	"Leo (Azul)",
	"Luna (Púrpura)",
	"Sol (Dorado)"
]
var current_skin_id: int = 0

# Elementos de Crear Sala
@onready var create_status_label: Label = $CreatePanel/VBoxContainer/StatusLabel
@onready var room_code_label: Label = $CreatePanel/VBoxContainer/CodeContainer/CodePanel/RoomCodeLabel
@onready var copy_code_btn: Button = $CreatePanel/VBoxContainer/CodeContainer/CopyCodeBtn
@onready var players_label: Label = $CreatePanel/VBoxContainer/PlayersLabel
@onready var start_game_btn: Button = $CreatePanel/VBoxContainer/StartGameBtn
@onready var new_code_btn: Button = $CreatePanel/VBoxContainer/NewCodeBtn
@onready var retry_create_btn: Button = $CreatePanel/VBoxContainer/RetryBtn
@onready var back_from_create_btn: Button = $CreatePanel/VBoxContainer/BackBtn

# Elementos de Unirse a Sala
@onready var code_input: LineEdit = $JoinPanel/VBoxContainer/CodeInput
@onready var confirm_join_btn: Button = $JoinPanel/VBoxContainer/ConfirmJoinBtn
@onready var join_status_label: Label = $JoinPanel/VBoxContainer/StatusLabel
@onready var retry_join_btn: Button = $JoinPanel/VBoxContainer/RetryBtn
@onready var back_from_join_btn: Button = $JoinPanel/VBoxContainer/BackBtn

var net_mgr: Node = null

func _ready() -> void:
	net_mgr = get_node_or_null("/root/NetworkManager")
	if not net_mgr:
		net_mgr = get_tree().get_first_node_in_group("network_manager")
		
	if net_mgr:
		net_mgr.room_created.connect(_on_room_created)
		net_mgr.room_joined.connect(_on_room_joined)
		net_mgr.room_error.connect(_on_room_error)
		net_mgr.player_joined_room.connect(_on_player_joined_room)
		net_mgr.connection_status_changed.connect(_on_net_status_changed)
		
	resume_btn.pressed.connect(_on_resume_pressed)
	solo_btn.pressed.connect(_on_solo_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_menu_btn.pressed.connect(_on_join_menu_pressed)
	
	copy_code_btn.pressed.connect(_on_copy_code_pressed)
	start_game_btn.pressed.connect(_on_enter_world)
	new_code_btn.pressed.connect(_on_new_code_pressed)
	retry_create_btn.pressed.connect(_on_retry_create_pressed)
	back_from_create_btn.pressed.connect(_on_back_pressed)
	
	confirm_join_btn.pressed.connect(_on_confirm_join_pressed)
	retry_join_btn.pressed.connect(_on_confirm_join_pressed)
	back_from_join_btn.pressed.connect(_on_back_pressed)
	code_input.text_submitted.connect(func(_t): _on_confirm_join_pressed())
	code_input.text_changed.connect(_on_code_input_changed)

	# Configuración de nombre y selector de personaje
	if net_mgr:
		if not net_mgr.player_name.is_empty():
			player_name_input.text = net_mgr.player_name
		current_skin_id = net_mgr.player_skin_id
	
	_update_skin_display()
	
	player_name_input.text_changed.connect(_on_player_name_changed)
	prev_skin_btn.pressed.connect(_on_prev_skin_pressed)
	next_skin_btn.pressed.connect(_on_next_skin_pressed)

	show_main_panel()

func _update_skin_display() -> void:
	if current_skin_id < 0 or current_skin_id >= SKIN_NAMES.size():
		current_skin_id = 0
	skin_name_label.text = SKIN_NAMES[current_skin_id]
	if net_mgr:
		net_mgr.player_skin_id = current_skin_id
		net_mgr.save_game_state()

func _on_prev_skin_pressed() -> void:
	current_skin_id -= 1
	if current_skin_id < 0:
		current_skin_id = SKIN_NAMES.size() - 1
	_update_skin_display()

func _on_next_skin_pressed() -> void:
	current_skin_id = (current_skin_id + 1) % SKIN_NAMES.size()
	_update_skin_display()

func _on_player_name_changed(new_name: String) -> void:
	var clean_name = new_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Lucas"
	if net_mgr:
		net_mgr.player_name = clean_name
		net_mgr.save_game_state()

func show_main_panel() -> void:
	main_panel.visible = true
	create_panel.visible = false
	join_panel.visible = false
	
	# Verificar si hay una partida persistente o activa para mostrar el botón de Continuar
	if net_mgr and not net_mgr.current_room_code.is_empty():
		resume_btn.text = "▶ Continuar Granja (Sala: " + net_mgr.current_room_code + ")"
		resume_btn.visible = true
	else:
		resume_btn.visible = false

func show_create_panel() -> void:
	main_panel.visible = false
	create_panel.visible = true
	join_panel.visible = false
	retry_create_btn.visible = false
	start_game_btn.disabled = false
	
	if net_mgr and not net_mgr.current_room_code.is_empty():
		room_code_label.text = net_mgr.current_room_code
		create_status_label.text = "Sala activa y persistente."
	else:
		if net_mgr:
			net_mgr.create_room()
		room_code_label.text = net_mgr.current_room_code if net_mgr else "VALE"
		create_status_label.text = "Conectando al servidor en línea..."
		
	players_label.text = "Jugadores en sala: Tú (Host)\nEsperando a tu amigo... (o entra ya a la granja)"

func show_join_panel() -> void:
	main_panel.visible = false
	create_panel.visible = false
	join_panel.visible = true
	
	# Persistencia: Pre-rellenar con el último código usado si existe
	if net_mgr and not net_mgr.last_joined_code.is_empty():
		code_input.text = net_mgr.last_joined_code
	elif net_mgr and not net_mgr.current_room_code.is_empty():
		code_input.text = net_mgr.current_room_code
	else:
		code_input.text = ""
		
	join_status_label.text = "Introduce el código de 4 letras que te dio tu amigo"
	confirm_join_btn.disabled = false
	retry_join_btn.visible = false

func _on_solo_pressed() -> void:
	if net_mgr:
		net_mgr.start_solo_mode()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_host_pressed() -> void:
	if net_mgr:
		net_mgr.create_room(false)
	show_create_panel()

func _on_new_code_pressed() -> void:
	if net_mgr:
		net_mgr.create_room(true)
		room_code_label.text = net_mgr.current_room_code
		create_status_label.text = "Nuevo código generado. Conectando..."

func _on_join_menu_pressed() -> void:
	show_join_panel()

func _on_back_pressed() -> void:
	# Al volver al menú no destruimos la sala para permitir que persista
	show_main_panel()

func _on_retry_create_pressed() -> void:
	retry_create_btn.visible = false
	create_status_label.text = "Reintentando conexión con el servidor..."
	if net_mgr:
		net_mgr.retry_connection()

func _on_room_created(code: String) -> void:
	room_code_label.text = code
	create_status_label.text = "¡Sala lista en línea!"
	players_label.text = "Jugadores en sala: Tú (Host)\nEsperando a tu amigo... (o entra ya a la granja)"
	start_game_btn.disabled = false
	retry_create_btn.visible = false

func _on_player_joined_room(client_id: String) -> void:
	players_label.text = "¡Tu amigo (Jugador #" + client_id.substr(0, 3) + ") ha entrado a la sala!\n¡Ya pueden jugar juntos!"
	start_game_btn.disabled = false

func _on_copy_code_pressed() -> void:
	var code = room_code_label.text.strip_edges()
	if code.is_empty() or code == "...":
		return
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard.writeText('" + code + "');")
	copy_code_btn.text = "¡Copiado!"
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func():
		if is_instance_valid(copy_code_btn):
			copy_code_btn.text = "Copiar Código"
	)

func _on_code_input_changed(new_text: String) -> void:
	var uppercase_text = new_text.to_upper().strip_edges()
	if code_input.text != uppercase_text:
		code_input.text = uppercase_text
		code_input.caret_column = uppercase_text.length()

func _on_confirm_join_pressed() -> void:
	var code = code_input.text.to_upper().strip_edges()
	if code.length() < 3:
		join_status_label.text = "El código debe tener al menos 3 o 4 letras (Ej: VALE o PATO)"
		return
	join_status_label.text = "Conectando y buscando la sala " + code + "..."
	confirm_join_btn.disabled = true
	retry_join_btn.visible = false
	if net_mgr:
		net_mgr.join_room(code)

func _on_room_joined(code: String) -> void:
	join_status_label.text = "¡Entraste a la sala " + code + "! Cargando la granja..."
	var timer = get_tree().create_timer(0.4)
	timer.timeout.connect(_on_enter_world)

func _on_room_error(msg: String) -> void:
	confirm_join_btn.disabled = false
	join_status_label.text = msg
	create_status_label.text = msg
	if create_panel.visible:
		retry_create_btn.visible = true
	if join_panel.visible:
		retry_join_btn.visible = true

func _on_net_status_changed(msg: String) -> void:
	if join_panel.visible:
		join_status_label.text = msg
	elif create_panel.visible:
		create_status_label.text = msg

func _on_resume_pressed() -> void:
	if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
		if net_mgr.has_method("ensure_multiplayer_connection"):
			net_mgr.ensure_multiplayer_connection()
	_on_enter_world()

func _on_enter_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")
