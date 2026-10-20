extends CanvasLayer
class_name StardewHUD

@onready var date_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/DateLabel
@onready var time_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/TimeLabel
@onready var gold_label: Label = $TopRightPlaque/MarginContainer/VBoxContainer/GoldLabel
@onready var hotbar_slots: HBoxContainer = $BottomHotbar/MarginContainer/HotbarSlots

var hour: int = 6
var minute: int = 10
var is_pm: bool = false
var time_accumulator: float = 0.0
var time_speed: float = 2.0 # Cada 2 segundos avanza 10 minutos de juego
var gold_amount: int = 500
var active_slot_index: int = 0

# Herramientas del hotbar
var tools: Array = [
	{"name": "Espada de la Familia", "icon": "⚔️"},
	{"name": "Regadera de Cobre", "icon": "💧"},
	{"name": "Azadón de Granja", "icon": "⛏️"},
	{"name": "Hacha de Leñador", "icon": "🪓"},
	{"name": "Semillas de Trigo", "icon": "🌱"},
	{"name": "Manzana Silvestre", "icon": "🍎"},
	{"name": "Poción de Vida", "icon": "🧪"}
]

func _ready() -> void:
	_update_clock_display()
	_update_gold_display()
	_setup_hotbar()

func _process(delta: float) -> void:
	# Simular el avance del tiempo estilo Stardew Valley
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
	time_label.text = "%d:%s %s" % [hour, min_str, period]
	date_label.text = "Vie. 19"

func _update_gold_display() -> void:
	gold_label.text = "%d G" % gold_amount

func _setup_hotbar() -> void:
	# Limpiar slots existentes si hay
	for child in hotbar_slots.get_children():
		child.queue_free()
		
	for i in range(tools.size()):
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(36, 36)
		slot.text = tools[i]["icon"]
		slot.tooltip_text = tools[i]["name"]
		slot.focus_mode = Control.FOCUS_NONE
		
		# Estilo de botón tipo ranura de madera
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
	style.border_width_left = 3 if is_selected else 2
	style.border_width_top = 3 if is_selected else 2
	style.border_width_right = 3 if is_selected else 2
	style.border_width_bottom = 3 if is_selected else 2
	style.border_color = Color(0.85, 0.2, 0.2) if is_selected else Color(0.48, 0.28, 0.15)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	slot.add_theme_stylebox_override("normal", style)
	slot.add_theme_stylebox_override("hover", style)
	slot.add_theme_stylebox_override("pressed", style)
	slot.add_theme_font_size_override("font_size", 16)

func _unhandled_input(event: InputEvent) -> void:
	# Permitir seleccionar slots con los números del 1 al 7
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var idx = event.keycode - KEY_1
			if idx < tools.size():
				_select_slot(idx)
