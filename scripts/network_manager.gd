extends Node
class_name NetworkManager

signal connection_status_changed(message: String)

var peer: WebSocketMultiplayerPeer = null
var remote_players: Dictionary = {}
var remote_player_scene: PackedScene = preload("res://scenes/remote_player.tscn")

var is_connected_to_server: bool = false
var is_host: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_host(port: int = 8080) -> Error:
	peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		is_connected_to_server = true
		connection_status_changed.emit("Servidor Host activo en puerto %d" % port)
	else:
		connection_status_changed.emit("Error al crear Host: %s" % error_string(err))
	return err

func join_server(server_url: String) -> Error:
	peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_client(server_url)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		connection_status_changed.emit("Conectando a %s..." % server_url)
	else:
		connection_status_changed.emit("Error al conectar: %s" % error_string(err))
	return err

func disconnect_network() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	
	# Eliminar jugadores remotos
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()
	
	is_connected_to_server = false
	is_host = false
	connection_status_changed.emit("Desconectado")

func _on_peer_connected(id: int) -> void:
	connection_status_changed.emit("¡Jugador conectado! (ID: %d)" % id)
	_spawn_remote_player(id)

func _on_peer_disconnected(id: int) -> void:
	connection_status_changed.emit("Jugador desconectado (ID: %d)" % id)
	if id in remote_players:
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
		remote_players.erase(id)

func _on_connected_to_server() -> void:
	is_connected_to_server = true
	var my_id = multiplayer.get_unique_id()
	connection_status_changed.emit("¡Conectado al servidor con éxito! (Tu ID: %d)" % my_id)

func _on_connection_failed() -> void:
	is_connected_to_server = false
	connection_status_changed.emit("Fallo de conexión con el servidor")

func _on_server_disconnected() -> void:
	disconnect_network()
	connection_status_changed.emit("Servidor desconectado")

func _spawn_remote_player(id: int) -> void:
	if id in remote_players and is_instance_valid(remote_players[id]):
		return
		
	var world_entities = get_tree().get_first_node_in_group("world_entities")
	if not world_entities:
		world_entities = get_tree().current_scene
		
	var new_remote = remote_player_scene.instantiate()
	new_remote.name = "RemotePlayer_%d" % id
	if "player_name" in new_remote:
		new_remote.player_name = "Hermano (ID: %d)" % id
	world_entities.add_child(new_remote)
	remote_players[id] = new_remote

# Enviar estado local a los demás jugadores
func broadcast_my_state(pos: Vector2, anim_name: String, flip_h: bool) -> void:
	if is_connected_to_server and multiplayer.multiplayer_peer:
		rpc("sync_player_state", pos, anim_name, flip_h)

@rpc("any_peer", "unreliable")
func sync_player_state(pos: Vector2, anim_name: String, flip_h: bool) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0 or sender_id == multiplayer.get_unique_id():
		return
		
	if sender_id not in remote_players or not is_instance_valid(remote_players[sender_id]):
		_spawn_remote_player(sender_id)
		
	if sender_id in remote_players and is_instance_valid(remote_players[sender_id]):
		remote_players[sender_id].update_remote_state(pos, anim_name, flip_h)
