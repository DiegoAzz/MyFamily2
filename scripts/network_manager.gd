extends Node

signal connection_status_changed(message: String)
signal room_created(code: String)
signal room_joined(code: String)
signal room_error(message: String)
signal player_joined_room(client_id: String)
signal player_left_room(client_id: String)
signal chat_message_received(sender: String, text: String)
signal diamond_collected_network(diamond_id: String)
signal game_won_event(winner_name: String, is_local_winner: bool, diamonds: int)
signal restart_game_event()

var socket: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var my_client_id: String = ""
var current_room_code: String = ""
var is_multiplayer_active: bool = false
var is_host: bool = false
var last_joined_code: String = ""

# Datos personalizados del jugador
var player_name: String = "Lucas"
var player_skin_id: int = 0

enum PendingAction { NONE, CREATE, JOIN }
var pending_action: PendingAction = PendingAction.NONE
var pending_join_code: String = ""
var connection_timeout_timer: float = 0.0
var auto_reconnect_timer: float = 0.0
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
	load_game_state()

func generate_code() -> String:
	return FRIENDLY_CODES[randi() % FRIENDLY_CODES.size()]

func get_relay_url() -> String:
	var target_url = "wss://godot.appzplay.online/ws"
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

func create_room(force_new: bool = false) -> void:
	# Si ya tenemos un código persistente y no estamos forzando uno nuevo, conservarlo
	if force_new or current_room_code.is_empty():
		current_room_code = generate_code()
		
	is_multiplayer_active = true
	is_host = true
	pending_action = PendingAction.CREATE
	save_game_state()
	
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_create_room()
	else:
		connect_to_relay()

func join_room(code: String) -> void:
	pending_action = PendingAction.JOIN
	pending_join_code = code.to_upper().strip_edges()
	current_room_code = pending_join_code
	last_joined_code = pending_join_code
	is_host = false
	save_game_state()
	
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

func ensure_multiplayer_connection() -> void:
	if not is_multiplayer_active or current_room_code.is_empty():
		return
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if is_host:
			pending_action = PendingAction.CREATE
		else:
			pending_action = PendingAction.JOIN
			pending_join_code = current_room_code
		connect_to_relay()

func start_solo_mode() -> void:
	is_multiplayer_active = false
	is_host = false
	pending_action = PendingAction.NONE
	save_game_state()
	# En solitario desconectamos red
	socket.close()
	is_connected_to_server = false
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()

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
		auto_reconnect_timer = 0.0
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
			
		# Reconexión automática si el multijugador está activo
		if is_multiplayer_active and not current_room_code.is_empty():
			auto_reconnect_timer += delta
			if auto_reconnect_timer >= 3.0:
				auto_reconnect_timer = 0.0
				ensure_multiplayer_connection()

func _handle_message(data: Dictionary) -> void:
	var type = str(data.get("type", ""))
	
	match type:
		"room_created":
			current_room_code = str(data.get("code", current_room_code))
			is_multiplayer_active = true
			is_host = true
			save_game_state()
			room_created.emit(current_room_code)
			connection_status_changed.emit("¡Sala lista en línea! Código: " + current_room_code)
			
		"room_joined":
			current_room_code = str(data.get("code", current_room_code))
			is_multiplayer_active = true
			is_host = false
			save_game_state()
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
			
		"chat":
			var sender = str(data.get("sender", "Amigo"))
			var text = str(data.get("text", ""))
			if not text.is_empty():
				chat_message_received.emit(sender, text)
				
		"collect_diamond":
			var did = str(data.get("id", ""))
			if not did.is_empty():
				diamond_collected_network.emit(did)
				for d in get_tree().get_nodes_in_group("diamonds"):
					if "diamond_id" in d and d.diamond_id == did and not d.is_collected:
						d.collect(null)
						
		"player_hit":
			var target_id = str(data.get("target_id", ""))
			var from_x = float(data.get("from_x", 0))
			var from_y = float(data.get("from_y", 0))
			var dmg = int(data.get("damage", 1))
			var from_pos = Vector2(from_x, from_y)
			
			if target_id == my_client_id:
				for p in get_tree().get_nodes_in_group("player"):
					if is_instance_valid(p) and p.has_method("take_damage"):
						p.take_damage(dmg, from_pos)
			elif target_id in remote_players and is_instance_valid(remote_players[target_id]):
				remote_players[target_id].take_hit(dmg, from_pos)
				
		"tree_chopped":
			var tid = str(data.get("tree_id", ""))
			if not tid.is_empty():
				for tree in get_tree().get_nodes_in_group("trees"):
					if "tree_id" in tree and tree.tree_id == tid and not tree.is_chopped:
						tree.chop_down()
						
		"crop_planted":
			var pid = str(data.get("plot_id", ""))
			var ctype = int(data.get("crop_type", 0))
			for plot in get_tree().get_nodes_in_group("crop_plots"):
				if "plot_id" in plot and plot.plot_id == pid:
					plot.crop_type = ctype
					plot.plant_crop(false)
					
		"crop_harvested":
			var pid = str(data.get("plot_id", ""))
			for plot in get_tree().get_nodes_in_group("crop_plots"):
				if "plot_id" in plot and plot.plot_id == pid:
					plot.harvest_crop(false)
					
		"quest_progress":
			var qid = str(data.get("quest_id", ""))
			var cur = int(data.get("current", 0))
			var q_mgr = get_tree().get_first_node_in_group("quest_manager")
			if q_mgr and q_mgr.has_method("set_progress_from_net"):
				q_mgr.set_progress_from_net(qid, cur)
				
		"game_won":
			var winner_name = str(data.get("winner_name", "Un Jugador"))
			var winner_id = str(data.get("winner_id", ""))
			var diamonds_count = int(data.get("diamonds", 5))
			var is_me = (winner_id == my_client_id)
			game_won_event.emit(winner_name, is_me, diamonds_count)
			
		"restart_game":
			restart_game_event.emit()

func broadcast_game_won(winner_name: String, diamonds_count: int = 5) -> void:
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN and is_multiplayer_active:
		var packet = {
			"type": "game_won",
			"winner_name": winner_name,
			"winner_id": my_client_id,
			"diamonds": diamonds_count
		}
		socket.send_text(JSON.stringify(packet))
	# Emitir también localmente
	game_won_event.emit(winner_name, true, diamonds_count)

func broadcast_restart_game() -> void:
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN and is_multiplayer_active:
		var packet = {
			"type": "restart_game"
		}
		socket.send_text(JSON.stringify(packet))
	restart_game_event.emit()

func send_player_hit(target_id: String, damage: int, from_pos: Vector2) -> void:
	if not is_multiplayer_active or target_id.is_empty():
		return
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var packet = {
			"type": "player_hit",
			"target_id": target_id,
			"from_id": my_client_id,
			"from_x": round(from_pos.x),
			"from_y": round(from_pos.y),
			"damage": damage
		}
		socket.send_text(JSON.stringify(packet))

func send_chat_message(text: String) -> void:
	var clean_text = text.strip_edges()
	if clean_text.is_empty():
		return
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN and is_multiplayer_active:
		var packet = {
			"type": "chat",
			"sender": player_name,
			"text": clean_text
		}
		socket.send_text(JSON.stringify(packet))
	# Emitir también localmente para que el remitente vea su propio mensaje
	chat_message_received.emit(player_name, clean_text)

func broadcast_my_state(pos: Vector2, anim_name: String, flip_h: bool) -> void:
	if not is_multiplayer_active:
		return
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = JSON.stringify({
			"type": "state",
			"id": my_client_id,
			"name": player_name,
			"skin": player_skin_id,
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
		
	var sender_name = str(data.get("name", "Hermano #" + sender_id.substr(0, 3)))
	var sender_skin = int(data.get("skin", 0))
		
	if sender_id not in remote_players or not is_instance_valid(remote_players[sender_id]):
		var world_entities = get_tree().get_first_node_in_group("world_entities")
		if not world_entities:
			world_entities = get_tree().current_scene
		if not world_entities:
			return
			
		var remote = remote_player_scene.instantiate()
		remote.name = "Remote_" + sender_id
		world_entities.add_child(remote)
		remote.global_position = Vector2(data.get("x", 0), data.get("y", 0))
		remote.client_id = sender_id
		if remote.has_method("update_name_and_skin"):
			remote.update_name_and_skin(sender_name, sender_skin)
		remote_players[sender_id] = remote
		
	var p = remote_players[sender_id]
	if is_instance_valid(p):
		if p.has_method("update_name_and_skin") and (p.player_name != sender_name or p.skin_id != sender_skin):
			p.update_name_and_skin(sender_name, sender_skin)
		if p.has_method("update_remote_state"):
			var pos = Vector2(data.get("x", 0), data.get("y", 0))
			var anim = data.get("anim", "idle_down")
			var flip = data.get("flip", false)
			p.update_remote_state(pos, anim, flip)

func _remove_remote_player(client_id: String) -> void:
	if client_id in remote_players:
		if is_instance_valid(remote_players[client_id]):
			remote_players[client_id].queue_free()
		remote_players.erase(client_id)

func leave_room_and_reset() -> void:
	socket.close()
	is_connected_to_server = false
	current_room_code = ""
	is_multiplayer_active = false
	is_host = false
	pending_action = PendingAction.NONE
	save_game_state()
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()

# ================= PERSISTENCIA LOCAL (user://savegame.json) =================
func save_game_state(pos: Vector2 = Vector2.ZERO) -> void:
	var save_dict = {
		"room_code": current_room_code,
		"is_host": is_host,
		"is_multiplayer": is_multiplayer_active,
		"last_joined_code": last_joined_code,
		"player_name": player_name,
		"player_skin_id": player_skin_id,
		"pos_x": pos.x if pos != Vector2.ZERO else 0.0,
		"pos_y": pos.y if pos != Vector2.ZERO else 15.0
	}
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict))
		file.close()

func load_game_state() -> Dictionary:
	if not FileAccess.file_exists("user://savegame.json"):
		return {}
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data and typeof(data) == TYPE_DICTIONARY:
			current_room_code = str(data.get("room_code", ""))
			is_host = bool(data.get("is_host", false))
			is_multiplayer_active = bool(data.get("is_multiplayer", false))
			last_joined_code = str(data.get("last_joined_code", ""))
			player_name = str(data.get("player_name", "Lucas"))
			player_skin_id = int(data.get("player_skin_id", 0))
			return data
	return {}
