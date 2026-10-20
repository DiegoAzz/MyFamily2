extends CanvasLayer
class_name MultiplayerMenu

@onready var toggle_btn: Button = $ToggleBtn
@onready var panel: PanelContainer = $PanelContainer
@onready var url_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/UrlInput
@onready var join_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/JoinBtn
@onready var disconnect_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/DisconnectBtn
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

var network_manager: Node = null

func _ready() -> void:
	panel.visible = false
	toggle_btn.pressed.connect(func(): panel.visible = not panel.visible)
	
	join_btn.pressed.connect(_on_join_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	
	# Ocultar o desactivar el host button en web porque los navegadores no pueden abrir puertos
	if $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer.has_node("HostBtn"):
		$PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/HostBtn.visible = false
	
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
			network_manager.auto_connect()
		else:
			network_manager.connect_to_url(target_url)

func _on_disconnect_pressed() -> void:
	if network_manager:
		network_manager.disconnect_network()
