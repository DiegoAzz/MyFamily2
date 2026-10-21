extends CanvasLayer
class_name VictoryPopup

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBox/TitleLabel
@onready var winner_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBox/WinnerLabel
@onready var desc_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBox/DescLabel
@onready var diamonds_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBox/DiamondsLabel
@onready var continue_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBox/HBoxButtons/ContinueBtn
@onready var restart_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBox/HBoxButtons/RestartBtn

var is_showing: bool = false

func _ready() -> void:
	visible = false
	continue_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.focus_mode = Control.FOCUS_NONE
	continue_btn.pressed.connect(close_popup)
	restart_btn.pressed.connect(_on_restart_pressed)
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		net_mgr.game_won_event.connect(_on_game_won)
		net_mgr.restart_game_event.connect(_on_network_restart)

func _on_game_won(winner_name: String, is_local_winner: bool, diamonds_count: int) -> void:
	show_victory(winner_name, is_local_winner, diamonds_count)

func show_victory(winner_name: String, is_local_winner: bool, diamonds_count: int) -> void:
	visible = true
	is_showing = true
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_victory"):
			audio.play_victory()
			
	if is_local_winner:
		title_label.text = "* * * ¡¡VICTORIA ABSOLUTA!! * * *"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		winner_label.text = "¡¡HAS GANADO LA PARTIDA!!"
		winner_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		desc_label.text = "¡Eres el gran campeon del Valle! Encontraste los " + str(diamonds_count) + " diamantes primero."
	else:
		title_label.text = "* * * ¡¡TENEMOS UN GANADOR!! * * *"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		winner_label.text = "¡" + winner_name + " HA GANADO LA PARTIDA!"
		winner_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		desc_label.text = "¡" + winner_name + " fue mas rapido talando y descubrio los diamantes primero!"
		
	diamonds_label.text = "Diamantes obtenidos: " + str(diamonds_count) + " / 5"
	
	# Animación de entrada
	panel.scale = Vector2(0.5, 0.5)
	panel.pivot_offset = panel.size * 0.5
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	backdrop.modulate.a = 0.0
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.3)

func close_popup() -> void:
	visible = false
	is_showing = false

func _on_restart_pressed() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.has_method("broadcast_restart_game"):
		net_mgr.broadcast_restart_game()
	else:
		_on_network_restart()

func _on_network_restart() -> void:
	close_popup()
	
	# Reiniciar jugador local
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("reset_diamond_hunt"):
			p.reset_diamond_hunt()
			
	# Hacer rebrotar árboles talados
	for tree in get_tree().get_nodes_in_group("trees"):
		if is_instance_valid(tree) and tree.has_method("regrow"):
			tree.regrow()
			
	# Reiniciar pistas del quest manager
	var q_mgr = get_tree().get_first_node_in_group("quest_manager")
	if q_mgr and q_mgr.has_method("reset_quests"):
		q_mgr.reset_quests()
