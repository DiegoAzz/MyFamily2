extends StaticBody2D
class_name ChoppableTree

@export var tree_id: String = ""
@export var is_small: bool = false
@export var is_clue_tree: bool = false
@export var clue_quest_id: String = ""
@export var max_hits: int = 3
@export var wood_yield: int = 3
@export var score_yield: int = 60

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var stump_sprite: Sprite2D = $StumpSprite

var hits_taken: int = 0
var is_chopped: bool = false
var respawn_timer: float = 0.0
const RESPAWN_TIME: float = 50.0

var oak_big_texture = preload("res://sprites/Outdoor decoration/Oak_Tree.png")
var oak_small_texture = preload("res://sprites/Outdoor decoration/Oak_Tree_Small.png")
var diamond_scene = preload("res://scenes/diamond.tscn")

func _ready() -> void:
	add_to_group("trees")
	if tree_id.is_empty():
		tree_id = "tree_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
		
	if is_small:
		sprite.texture = oak_small_texture
		sprite.region_enabled = true
		# Frame 1 de Oak_Tree_Small.png (32x48) es el árbol completo y perfectamente centrado
		sprite.region_rect = Rect2(32, 0, 32, 48)
		collision.position = Vector2(0, 4)
		if collision.shape is CircleShape2D:
			(collision.shape as CircleShape2D).radius = 6.0
		stump_sprite.position = Vector2(0, 4)
	else:
		sprite.texture = oak_big_texture
		sprite.region_enabled = false
		collision.position = Vector2(0, 18)
		if collision.shape is CircleShape2D:
			(collision.shape as CircleShape2D).radius = 8.0
		stump_sprite.position = Vector2(0, 18)
		
	stump_sprite.visible = false

func _process(delta: float) -> void:
	if is_chopped:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			regrow()

func take_hit(damage: int, from_pos: Vector2) -> void:
	if is_chopped:
		return
		
	hits_taken += damage
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_chop"):
			audio.play_chop()
	
	# Efecto de tambaleo / sacudida al golpear el tronco
	var hit_dir = 1.0 if from_pos.x < global_position.x else -1.0
	var shake_tween = create_tween()
	shake_tween.tween_property(sprite, "rotation_degrees", 5.0 * hit_dir, 0.05)
	shake_tween.tween_property(sprite, "rotation_degrees", -4.0 * hit_dir, 0.05)
	shake_tween.tween_property(sprite, "rotation_degrees", 2.0 * hit_dir, 0.05)
	shake_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.05)
	
	# Destello blanco de madera
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(1.6, 1.4, 1.0), 0.06)
	flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.08)
	
	var remaining = max_hits - hits_taken
	if remaining > 0:
		_spawn_floating_text("¡Tac! (" + str(remaining) + ")", Color(0.95, 0.85, 0.5))
	else:
		chop_down(from_pos)

func chop_down(from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_chopped:
		return
	is_chopped = true
	respawn_timer = RESPAWN_TIME
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_tree_fall"):
			audio.play_tree_fall()
	
	# Notificar a la red si multijugador está activo
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
		if net_mgr.socket and net_mgr.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			net_mgr.socket.send_text(JSON.stringify({
				"type": "tree_chopped",
				"tree_id": tree_id
			}))
			
	# Animación de caída del árbol
	var fall_dir = 1.0 if from_pos.x < global_position.x else -1.0
	var fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(sprite, "rotation_degrees", 75.0 * fall_dir, 0.5)
	fall_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	fall_tween.tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.5)
	
	# Mostrar tocón de madera
	stump_sprite.visible = true
	stump_sprite.modulate.a = 0.0
	var stump_tween = create_tween()
	stump_tween.tween_property(stump_sprite, "modulate:a", 1.0, 0.3)
	
	# Otorgar recompensas al jugador local cercano
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if is_instance_valid(p) and p.global_position.distance_to(global_position) < 55.0:
			if "score" in p:
				p.score += score_yield
				if p.has_method("_update_hud"):
					p._update_hud()
					
	# Recompensas de Diamante
	if is_clue_tree:
		var d = diamond_scene.instantiate()
		d.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(10, 20))
		get_parent().add_child(d)
		_spawn_floating_text("+Madera! +¡DIAMANTE DE PISTA!", Color(0.2, 0.95, 1.0))
		if not clue_quest_id.is_empty():
			var q_mgr = get_tree().get_first_node_in_group("quest_manager")
			if q_mgr and q_mgr.has_method("add_progress"):
				q_mgr.add_progress(clue_quest_id, 1)
	elif randf() < 0.35:
		var d = diamond_scene.instantiate()
		d.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(10, 20))
		get_parent().add_child(d)
		_spawn_floating_text("+Madera! +¡DIAMANTE!", Color(0.3, 0.9, 1.0))
	else:
		_spawn_floating_text("+3 Madera! +" + str(score_yield) + " Pts", Color(0.85, 0.65, 0.3))
		
	# Reducir colisión al tamaño del tocón
	collision.position = Vector2(0, 12 if is_small else 24)
	if collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = 5.0

func regrow() -> void:
	is_chopped = false
	hits_taken = 0
	stump_sprite.visible = false
	sprite.rotation_degrees = 0.0
	sprite.scale = Vector2(0.1, 0.1)
	sprite.modulate.a = 1.0
	
	# Animación de rebrote suave
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Restaurar colisión
	if is_small:
		collision.position = Vector2(0, 4)
		if collision.shape is CircleShape2D:
			(collision.shape as CircleShape2D).radius = 6.0
	else:
		collision.position = Vector2(0, 18)
		if collision.shape is CircleShape2D:
			(collision.shape as CircleShape2D).radius = 8.0

func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = Vector2(25, 6)
	label.global_position = global_position + Vector2(-15, -10)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 16.0, 0.9)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.9)
	label_tween.chain().tween_callback(label.queue_free)
