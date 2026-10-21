extends CanvasLayer
class_name QuestUI

@onready var toggle_btn: Button = $Margin/ToggleBtn
@onready var panel: PanelContainer = $Margin/Panel
@onready var close_btn: Button = $Margin/Panel/Margin/VBox/Header/CloseBtn
@onready var quest_list_vbox: VBoxContainer = $Margin/Panel/Margin/VBox/Scroll/QuestListVBox

var is_open: bool = false
var quest_mgr: Node = null

func _ready() -> void:
	toggle_btn.focus_mode = Control.FOCUS_NONE
	close_btn.focus_mode = Control.FOCUS_NONE
	
	toggle_btn.pressed.connect(toggle_ui)
	close_btn.pressed.connect(close_ui)
	
	panel.visible = false
	
	quest_mgr = get_tree().get_first_node_in_group("quest_manager")
	if quest_mgr:
		quest_mgr.quest_updated.connect(func(_qid, _c, _t): _render_quests())
		quest_mgr.quest_completed.connect(func(_qid, _t): _render_quests())
		
	_render_quests()

func toggle_ui() -> void:
	if is_open:
		close_ui()
	else:
		open_ui()

func open_ui() -> void:
	is_open = true
	panel.visible = true
	_render_quests()

func close_ui() -> void:
	is_open = false
	panel.visible = false

func _render_quests() -> void:
	if not quest_mgr or not is_instance_valid(quest_list_vbox):
		return
		
	for c in quest_list_vbox.get_children():
		c.queue_free()
		
	var all_done = true
	for qid in quest_mgr.quests.keys():
		var q = quest_mgr.quests[qid]
		if not q["completed"]:
			all_done = false
			
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		if q["completed"]:
			card_style.bg_color = Color(0.18, 0.32, 0.18, 0.9)
			card_style.border_color = Color(0.4, 0.8, 0.4, 1.0)
		else:
			card_style.bg_color = Color(0.2, 0.14, 0.1, 0.85)
			card_style.border_color = Color(0.65, 0.45, 0.22, 0.8)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_right = 4
		card_style.corner_radius_bottom_left = 4
		card.add_theme_stylebox_override("panel", card_style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		margin.add_child(vbox)
		
		var top_hbox = HBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = q["title"]
		title_lbl.add_theme_font_size_override("font_size", 9)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if not q["completed"] else Color(0.6, 1.0, 0.6))
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_hbox.add_child(title_lbl)
		
		var status_lbl = Label.new()
		status_lbl.text = "✓ ¡Completada!" if q["completed"] else ("%d / %d" % [q["current"], q["target"]])
		status_lbl.add_theme_font_size_override("font_size", 8)
		status_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7) if q["completed"] else Color(1.0, 0.8, 0.3))
		top_hbox.add_child(status_lbl)
		vbox.add_child(top_hbox)
		
		var desc_lbl = Label.new()
		desc_lbl.text = q["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 7)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
		vbox.add_child(desc_lbl)
		
		quest_list_vbox.add_child(card)
		
	if all_done:
		toggle_btn.text = "🏆 ¡Misiones (4/4)!"
		toggle_btn.modulate = Color(1.3, 1.2, 0.4)
	else:
		toggle_btn.text = "📜 Misiones"
		toggle_btn.modulate = Color(1.0, 1.0, 1.0)
