extends CanvasLayer
class_name MultiplayerMenu

@onready var toggle_btn: Button = $ToggleBtn
@onready var panel: PanelContainer = $PanelContainer
@onready var url_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/UrlInput
@onready var join_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/JoinBtn
@onready var host_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/HostBtn
@onready var disconnect_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/DisconnectBtn
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var network_manager: Node = null

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(func(): panel.visible = not panel.visible)
	
	join_btn.pressed.connect(_on_join_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	
	# Buscar NetworkManager
	network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager and network_manager.has_signal("connection_status_changed"):
		network_manager.connection_status_changed.connect(_on_status_changed)

func _on_status_changed(msg: String) -> void:
	status_label.text = msg

func _on_join_pressed() -> void:
	if network_manager:
		var target_url = url_input.text.strip_edges()
		if target_url.is_empty():
			target_url = "ws://179.236.70.251:8080"
		network_manager.join_server(target_url)

func _on_host_pressed() -> void:
	if network_manager:
		network_manager.start_host(8080)

func _on_disconnect_pressed() -> void:
	if network_manager:
		network_manager.disconnect_network()
