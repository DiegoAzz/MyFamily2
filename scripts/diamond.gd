extends Area2D
class_name CollectibleDiamond

@export var diamond_id: String = ""
@export var point_value: int = 100

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var initial_y: float = 0.0
var time_passed: float = 0.0
var is_collected: bool = false

func _ready() -> void:
	initial_y = position.y
	time_passed = randf() * 10.0 # Desfasar animaciones
	if diamond_id.is_empty():
		diamond_id = "diam_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
	add_to_group("diamonds")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	time_passed += delta
	# Flotación suave estilo gema mágica
	sprite.position.y = sin(time_passed * 3.5) * 2.5

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		collect(body)

func collect(collector: Node2D = null) -> void:
	if is_collected:
		return
	is_collected = true
	collision.set_deferred("disabled", true)
	
	if collector and collector.has_method("add_diamond"):
		collector.add_diamond(1, point_value)
		
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_diamond"):
			audio.play_diamond()
		
	# Efecto visual de recolección (crece y se desvanece)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "position:y", sprite.position.y - 14.0, 0.3)
	
	# Mostrar número flotante
	_spawn_floating_text("+1 Diamante!")
	
	# Avanzar misión de diamantes
	var q_mgr = get_tree().get_first_node_in_group("quest_manager")
	if q_mgr and q_mgr.has_method("add_progress"):
		q_mgr.add_progress("diamonds", 1)
	
	# Sincronizar en red si multijugador está activo
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
		if net_mgr.socket and net_mgr.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			net_mgr.socket.send_text(JSON.stringify({
				"type": "collect_diamond",
				"id": diamond_id,
				"collector_id": net_mgr.my_client_id
			}))
			
	await tween.finished
	queue_free()

func _spawn_floating_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.global_position = global_position + Vector2(-30, -20)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 18.0, 0.8)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.8)
	label_tween.chain().tween_callback(label.queue_free)
