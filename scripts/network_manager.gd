extends Node

signal connection_status_changed(message: String)
signal room_created(code: String)
signal room_joined(code: String)
signal room_error(message: String)
signal player_joined_room(client_id: String)
signal player_left_room(client_id: String)

var socket: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var my_client_id: String = ""
var current_room_code: String = ""
var is_multiplayer_active: bool = false
var is_host: bool = false

enum PendingAction { NONE, CREATE, JOIN }
var pending_action: PendingAction = PendingAction.NONE
var pending_join_code: String = ""
var connection_timeout_timer: float = 0.0
const MAX_CONNECTION_WAIT: float = 6.0

var remote_players: Dictionary = {}
var remote_player_scene: PackedScene = preload("res://scenes/remote_player.tscn")

const FRIENDLY_CODES = [
	"VALE", "CASA", "LUNA", "SOLO", "RANA", "PATO", "GATO", "FLOR",
	"ARBO", "BOSQ", "ISLA", "MAYO", "AZUL", "ROJO", "VIDA", "AMOR",
	"PAZ", "ARTE", "RIOS", "LAGO", "CIEL", "FARO", "NUBE", "ESTA"
]

func _ready() -> void:
	my_client_id = str(randi() % 90000 + 10000)

func generate_code() -> String:
	return FRIENDLY_CODES[randi() % FRIENDLY_CODES.size()]

func get_relay_url() -> String:
	var target_url = "wss://3pgipgqc7cmxhtxs92fqlcj2.179.236.70.251.sslip.io/ws"
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("window.location.host")
		var proto = "wss://" if JavaScriptBridge.eval("window.location.protocol") == "https:" else "ws://"
		if host:
			target_url = proto + str(host) + "/ws"
	return target_url

func connect_to_relay() -> void:
	var url = get_relay_url()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	connection_timeout_timer = 0.0
	socket.close()
	var err = socket.connect_to_url(url)
	if err == OK:
		connection_status_changed.emit("Conectando con el servidor en línea...")
	else:
		connection_status_changed.emit("Error al iniciar conexión: %s" % error_string(err))
		room_error.emit("No se pudo iniciar la conexión: " + error_string(err))

func create_room() -> void:
	# Generar el código inmediatamente para que el jugador NUNCA vea la pantalla vacía
	if current_room_code.is_empty():
		current_room_code = generate_code()
	is_multiplayer_active = true
	is_host = true
	pending_action = PendingAction.CREATE
	
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_create_room()
	else:
		connect_to_relay()

func join_room(code: String) -> void:
	pending_action = PendingAction.JOIN
	pending_join_code = code.to_upper().strip_edges()
	current_room_code = pending_join_code
	
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_join_room()
	else:
		connect_to_relay()

func retry_connection() -> void:
	socket.close()
	is_connected_to_server = false
	if is_host and not current_room_code.is_empty():
		pending_action = PendingAction.CREATE
	elif not pending_join_code.is_empty():
		pending_action = PendingAction.JOIN
	connect_to_relay()

func start_solo_mode() -> void:
	is_multiplayer_active = false
	current_room_code = ""
	is_host = false
	pending_action = PendingAction.NONE
	disconnect_network()

func _send_create_room() -> void:
	pending_action = PendingAction.NONE
	var req = {
		"type": "create_room",
		"code": current_room_code,
		"clientId": my_client_id
	}
	socket.send_text(JSON.stringify(req))

func _send_join_room() -> void:
	pending_action = PendingAction.NONE
	var req = {
		"type": "join_room",
		"code": pending_join_code,
		"clientId": my_client_id
	}
	socket.send_text(JSON.stringify(req))

func _process(delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_CONNECTING:
		connection_timeout_timer += delta
		if connection_timeout_timer > MAX_CONNECTION_WAIT:
			connection_timeout_timer = 0.0
			socket.close()
			var msg = "El servidor en línea tarda en responder. Puedes reintentar."
			connection_status_changed.emit(msg)
			room_error.emit(msg)
			
	elif state == WebSocketPeer.STATE_OPEN:
		connection_timeout_timer = 0.0
		if not is_connected_to_server:
			is_connected_to_server = true
			connection_status_changed.emit("¡Conectado al servidor en línea!")
			if pending_action == PendingAction.CREATE:
				_send_create_room()
			elif pending_action == PendingAction.JOIN:
				_send_join_room()
				
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var text = packet.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data and typeof(data) == TYPE_DICTIONARY:
				_handle_message(data)
				
	elif state == WebSocketPeer.STATE_CLOSED:
		connection_timeout_timer = 0.0
		if is_connected_to_server:
			is_connected_to_server = false
			connection_status_changed.emit("Desconectado del servidor")
		elif pending_action != PendingAction.NONE:
			var msg = "No se pudo conectar al servidor en línea. Pulsa Reintentar."
			connection_status_changed.emit(msg)
			room_error.emit(msg)
			pending_action = PendingAction.NONE

func _handle_message(data: Dictionary) -> void:
	var type = str(data.get("type", ""))
	
	match type:
		"room_created":
			current_room_code = str(data.get("code", current_room_code))
			is_multiplayer_active = true
			is_host = true
			room_created.emit(current_room_code)
			connection_status_changed.emit("¡Sala lista en línea! Código: " + current_room_code)
			
		"room_joined":
			current_room_code = str(data.get("code", current_room_code))
			is_multiplayer_active = true
			is_host = false
			room_joined.emit(current_room_code)
			connection_status_changed.emit("¡Te has unido a la sala: " + current_room_code + "!")
			
		"player_joined":
			var pid = str(data.get("clientId", ""))
			player_joined_room.emit(pid)
			connection_status_changed.emit("¡Tu amigo ha entrado a la sala!")
			
		"player_left":
			var pid = str(data.get("clientId", ""))
			_remove_remote_player(pid)
			player_left_room.emit(pid)
			connection_status_changed.emit("Un jugador ha salido")
			
		"error":
			var msg = str(data.get("message", "Error de conexión"))
			room_error.emit(msg)
			connection_status_changed.emit(msg)
			
		"state":
			_handle_player_state(data)

func broadcast_my_state(pos: Vector2, anim_name: String, flip_h: bool) -> void:
	if not is_multiplayer_active:
		return
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = JSON.stringify({
			"type": "state",
			"id": my_client_id,
			"x": round(pos.x),
			"y": round(pos.y),
			"anim": anim_name,
			"flip": flip_h
		})
		socket.send_text(msg)

func _handle_player_state(data: Dictionary) -> void:
	if not is_multiplayer_active:
		return
	var sender_id = str(data.get("id", ""))
	if sender_id.is_empty() or sender_id == my_client_id:
		return
		
	if sender_id not in remote_players or not is_instance_valid(remote_players[sender_id]):
		var world_entities = get_tree().get_first_node_in_group("world_entities")
		if not world_entities:
			world_entities = get_tree().current_scene
		if not world_entities:
			return
			
		var remote = remote_player_scene.instantiate()
		remote.name = "Remote_" + sender_id
		if "player_name" in remote:
			remote.player_name = "Hermano #" + sender_id.substr(0, 3)
		world_entities.add_child(remote)
		remote.global_position = Vector2(data.get("x", 0), data.get("y", 0))
		remote_players[sender_id] = remote
		
	var p = remote_players[sender_id]
	if is_instance_valid(p) and p.has_method("update_remote_state"):
		var pos = Vector2(data.get("x", 0), data.get("y", 0))
		var anim = data.get("anim", "idle_down")
		var flip = data.get("flip", false)
		p.update_remote_state(pos, anim, flip)

func _remove_remote_player(client_id: String) -> void:
	if client_id in remote_players:
		if is_instance_valid(remote_players[client_id]):
			remote_players[client_id].queue_free()
		remote_players.erase(client_id)

func disconnect_network() -> void:
	socket.close()
	is_connected_to_server = false
	current_room_code = ""
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()
