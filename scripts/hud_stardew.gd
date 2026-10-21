extends CanvasLayer
class_name StardewHUD

@onready var time_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/TopRowHBox/TimeLabel
@onready var hearts_container: HBoxContainer = $TopRightPlaque/MarginContainer/VBoxContainer/TopRowHBox/HeartsContainer
@onready var gold_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/StatsHBox/GoldLabel
@onready var diamond_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/StatsHBox/DiamondLabel
@onready var score_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/StatsHBox/ScoreLabel
@onready var hotbar_slots: HBoxContainer = $BottomHotbar/MarginContainer/HotbarSlots

var heart_full_texture: Texture2D = preload("res://sprites/Items/heart_full.png")
var heart_empty_texture: Texture2D = preload("res://sprites/Items/heart_empty.png")

var hour: int = 6
var minute: int = 10
var is_pm: bool = false
var time_accumulator: float = 0.0
var time_speed: float = 2.0
var gold_amount: int = 500
var diamond_amount: int = 0
var score_amount: int = 0
var active_slot_index: int = 0

var tools: Array = [
	{"name": "Espada de la Familia", "icon": "ESP", "color": Color(0.95, 0.4, 0.4)},
	{"name": "Regadera de Cobre", "icon": "REG", "color": Color(0.4, 0.7, 0.95)},
	{"name": "Azadón de Granja", "icon": "AZA", "color": Color(0.85, 0.65, 0.35)},
	{"name": "Hacha de Leñador", "icon": "HAC", "color": Color(0.75, 0.5, 0.3)},
	{"name": "Poción de Vida", "icon": "POC", "color": Color(0.85, 0.4, 0.85)}
]

func _ready() -> void:
	_update_clock_display()
	_update_gold_display()
	update_diamonds(0, 0)
	update_health(3, 3)
	_setup_hotbar()

func _process(delta: float) -> void:
	time_accumulator += delta
	if time_accumulator >= time_speed:
		time_accumulator = 0.0
		minute += 10
		if minute >= 60:
			minute = 0
			hour += 1
			if hour == 12:
				is_pm = not is_pm
			elif hour > 12:
				hour = 1
		_update_clock_display()

func _update_clock_display() -> void:
	var period = "pm" if is_pm else "am"
	var min_str = "%02d" % minute
	if time_label:
		time_label.text = "Vie. 19 | %d:%s %s" % [hour, min_str, period]

func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "%d G" % gold_amount

func update_diamonds(count: int, score: int) -> void:
	diamond_amount = count
	score_amount = score
	if diamond_label:
		diamond_label.text = str(diamond_amount)
	if score_label:
		score_label.text = "Pts: %d" % score_amount

func update_health(current: int, maximum: int = 3) -> void:
	if not hearts_container:
		return
	var heart_nodes = hearts_container.get_children()
	for i in range(heart_nodes.size()):
		var heart_rect = heart_nodes[i] as TextureRect
		if heart_rect:
			if i < current:
				heart_rect.texture = heart_full_texture
			else:
				heart_rect.texture = heart_empty_texture

func _setup_hotbar() -> void:
	for child in hotbar_slots.get_children():
		child.queue_free()
		
	for i in range(tools.size()):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(26, 26)
		slot.text = tools[i]["icon"]
		slot.tooltip_text = tools[i]["name"]
		slot.focus_mode = Control.FOCUS_NONE
		
		_apply_slot_style(slot, i == active_slot_index)
		
		var slot_idx = i
		slot.pressed.connect(func(): _select_slot(slot_idx))
		hotbar_slots.add_child(slot)

func _select_slot(index: int) -> void:
	active_slot_index = index
	for i in range(hotbar_slots.get_child_count()):
		var slot = hotbar_slots.get_child(i) as Button
		if slot:
			_apply_slot_style(slot, i == active_slot_index)

func _apply_slot_style(slot: Button, is_selected: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.85, 0.68) if not is_selected else Color(1.0, 0.95, 0.8)
	style.border_width_left = 2 if is_selected else 1
	style.border_width_top = 2 if is_selected else 1
	style.border_width_right = 2 if is_selected else 1
	style.border_width_bottom = 2 if is_selected else 1
	style.border_color = Color(0.85, 0.2, 0.2) if is_selected else Color(0.48, 0.28, 0.15)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	slot.add_theme_stylebox_override("normal", style)
	slot.add_theme_stylebox_override("hover", style)
	slot.add_theme_stylebox_override("pressed", style)
	slot.add_theme_font_size_override("font_size", 8)
	slot.add_theme_color_override("font_color", Color(0.3, 0.15, 0.05))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var idx = event.keycode - KEY_1
			if idx < tools.size():
				_select_slot(idx)
