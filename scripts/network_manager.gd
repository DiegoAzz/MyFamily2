extends Node

signal connection_status_changed(message: String)

var socket: WebSocketPeer = WebSocketPeer.new()
var is_connected_to_server: bool = false
var my_client_id: String = ""
var remote_players: Dictionary = {}
var remote_player_scene: PackedScene = preload("res://scenes/remote_player.tscn")

func _ready() -> void:
	my_client_id = str(randi() % 90000 + 10000)
	auto_connect()

func auto_connect() -> void:
	var target_url = "wss://3pgipgqc7cmxhtxs92fqlcj2.179.236.70.251.sslip.io/ws"
	if OS.has_feature("web"):
		var host = JavaScriptBridge.eval("window.location.host")
		var proto = "wss://" if JavaScriptBridge.eval("window.location.protocol") == "https:" else "ws://"
		if host:
			target_url = proto + str(host) + "/ws"
			
	connect_to_url(target_url)

func connect_to_url(url: String) -> void:
	socket.close()
	var err = socket.connect_to_url(url)
	if err == OK:
		connection_status_changed.emit("Conectando a la sala...")
	else:
		connection_status_changed.emit("Error: %s" % error_string(err))

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			connection_status_changed.emit("¡Conectado! Sala Multijugador Activa")
			
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var text = packet.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data and typeof(data) == TYPE_DICTIONARY:
				_handle_remote_data(data)
				
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_server:
			is_connected_to_server = false
			connection_status_changed.emit("Desconectado de la sala")

func broadcast_my_state(pos: Vector2, anim_name: String, flip_h: bool) -> void:
	if is_connected_to_server and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = JSON.stringify({
			"id": my_client_id,
			"x": round(pos.x),
			"y": round(pos.y),
			"anim": anim_name,
			"flip": flip_h
		})
		socket.send_text(msg)

func _handle_remote_data(data: Dictionary) -> void:
	var sender_id = str(data.get("id", ""))
	if sender_id.is_empty() or sender_id == my_client_id:
		return
		
	if sender_id not in remote_players or not is_instance_valid(remote_players[sender_id]):
		var world_entities = get_tree().get_first_node_in_group("world_entities")
		if not world_entities:
			world_entities = get_tree().current_scene
		var remote = remote_player_scene.instantiate()
		remote.name = "Remote_" + sender_id
		if "player_name" in remote:
			remote.player_name = "Hermano #" + sender_id.substr(0, 3)
		world_entities.add_child(remote)
		remote_players[sender_id] = remote
		
	var p = remote_players[sender_id]
	if is_instance_valid(p) and p.has_method("update_remote_state"):
		var pos = Vector2(data.get("x", 0), data.get("y", 0))
		var anim = data.get("anim", "idle_down")
		var flip = data.get("flip", false)
		p.update_remote_state(pos, anim, flip)

func disconnect_network() -> void:
	socket.close()
	is_connected_to_server = false
	for id in remote_players.keys():
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()
	connection_status_changed.emit("Desconectado")
