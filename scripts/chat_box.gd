extends CanvasLayer
class_name InGameChat

@onready var toggle_btn: Button = $ChatContainer/ToggleBtn
@onready var chat_panel: PanelContainer = $ChatContainer/ChatPanel
@onready var close_btn: Button = $ChatContainer/ChatPanel/Margin/VBox/HeaderHBox/CloseBtn
@onready var messages_box: VBoxContainer = $ChatContainer/ChatPanel/Margin/VBox/MessagesScroll/MessagesVBox
@onready var message_input: LineEdit = $ChatContainer/ChatPanel/Margin/VBox/InputHBox/MessageInput
@onready var send_btn: Button = $ChatContainer/ChatPanel/Margin/VBox/InputHBox/SendBtn

var net_mgr: Node = null
var unread_count: int = 0
var is_chat_open: bool = false
const MAX_MESSAGES: int = 25

func _ready() -> void:
	# Desactivar foco de teclado en botones para que la barra espaciadora NUNCA active el chat
	toggle_btn.focus_mode = Control.FOCUS_NONE
	send_btn.focus_mode = Control.FOCUS_NONE
	if close_btn:
		close_btn.focus_mode = Control.FOCUS_NONE
	message_input.focus_mode = Control.FOCUS_CLICK
	
	net_mgr = get_node_or_null("/root/NetworkManager")
	if not net_mgr:
		net_mgr = get_tree().get_first_node_in_group("network_manager")
		
	if net_mgr and net_mgr.has_signal("chat_message_received"):
		net_mgr.chat_message_received.connect(_on_chat_message_received)
		
	toggle_btn.pressed.connect(toggle_chat)
	if close_btn:
		close_btn.pressed.connect(close_chat)
	send_btn.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(func(_t): _on_send_pressed())
	
	# Inicialmente cerrado
	chat_panel.visible = false
	_update_toggle_btn()
	
	add_chat_entry("Sistema", "¡Bienvenidos a la Granja! Toca 'Chat' para hablar.", Color(0.9, 0.8, 0.4))

func toggle_chat() -> void:
	if is_chat_open:
		close_chat()
	else:
		open_chat()

func open_chat() -> void:
	is_chat_open = true
	chat_panel.visible = true
	unread_count = 0
	_update_toggle_btn()

func close_chat() -> void:
	is_chat_open = false
	chat_panel.visible = false
	message_input.release_focus()
	_update_toggle_btn()

func _update_toggle_btn() -> void:
	if unread_count > 0 and not is_chat_open:
		toggle_btn.text = "Chat (%d)" % unread_count
		toggle_btn.modulate = Color(1.3, 1.2, 0.5)
	else:
		toggle_btn.text = "Chat"
		toggle_btn.modulate = Color(1.0, 1.0, 1.0)

func _on_send_pressed() -> void:
	var text = message_input.text.strip_edges()
	if text.is_empty():
		return
		
	message_input.text = ""
	message_input.release_focus()
	
	if net_mgr and net_mgr.has_method("send_chat_message"):
		net_mgr.send_chat_message(text)
	else:
		var my_name = "Tú"
		if net_mgr and "player_name" in net_mgr and not net_mgr.player_name.is_empty():
			my_name = net_mgr.player_name
		add_chat_entry(my_name, text, Color(0.4, 0.9, 0.5))

func _on_chat_message_received(sender: String, text: String) -> void:
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_chat"):
			audio.play_chat()
			
	var color = Color(0.4, 0.9, 0.5)
	if net_mgr and sender == net_mgr.player_name:
		color = Color(0.3, 0.8, 1.0)
	elif sender == "Sistema":
		color = Color(0.9, 0.8, 0.4)
	else:
		color = Color(1.0, 0.85, 0.4)
		
	add_chat_entry(sender, text, color)
	
	if not is_chat_open:
		unread_count += 1
		_update_toggle_btn()

func add_chat_entry(sender: String, message: String, color: Color) -> void:
	var lbl = RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", 8)
	
	var col_hex = color.to_html(false)
	lbl.text = "[color=#%s][b]%s:[/b][/color] %s" % [col_hex, sender, message]
	
	messages_box.add_child(lbl)
	
	while messages_box.get_child_count() > MAX_MESSAGES:
		var first = messages_box.get_child(0)
		messages_box.remove_child(first)
		first.queue_free()
		
	await get_tree().process_frame
	var scroll = $ChatContainer/ChatPanel/Margin/VBox/MessagesScroll
	if scroll:
		scroll.scroll_vertical = 99999
