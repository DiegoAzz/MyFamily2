extends CanvasLayer
class_name LevelBanner

@onready var panel: PanelContainer = $Control/PanelContainer
@onready var title_lbl: Label = $Control/PanelContainer/Margin/VBox/TitleLabel
@onready var subtitle_lbl: Label = $Control/PanelContainer/Margin/VBox/SubtitleLabel

var active_tween: Tween = null

func _ready() -> void:
	add_to_group("level_banner")
	panel.modulate.a = 0.0
	panel.position.y = -50.0

func show_banner(title: String, subtitle: String, border_color: Color = Color(0.3, 0.9, 1.0)) -> void:
	title_lbl.text = title
	subtitle_lbl.text = subtitle
	
	var sb = panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).border_color = border_color
		
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween()
	panel.position.y = -50.0
	panel.modulate.a = 0.0
	
	# Deslizar hacia abajo y aparecer
	active_tween.parallel().tween_property(panel, "position:y", 18.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# Mantener en pantalla
	active_tween.tween_interval(2.2)
	
	# Desvanecer hacia arriba
	active_tween.parallel().tween_property(panel, "position:y", -40.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.4)
