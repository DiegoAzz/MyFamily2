extends CharacterBody2D
class_name RemotePlayer

@export var player_name: String = "Hermano"
@export var skin_id: int = 0
@export var client_id: String = ""
@export var current_health: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var name_label: Label = $NameTagBadge/Margin/NameLabel

var target_position: Vector2 = Vector2.ZERO

const SKIN_COLORS = [
	Color(1.0, 1.0, 1.0, 1.0),       # 0: Granjero Clásico
	Color(1.35, 0.8, 0.8, 1.0),      # 1: Mateo (Rojo)
	Color(0.8, 1.3, 0.85, 1.0),      # 2: Clara (Verde)
	Color(0.8, 0.95, 1.4, 1.0),      # 3: Leo (Azul)
	Color(1.25, 0.85, 1.35, 1.0),    # 4: Luna (Púrpura)
	Color(1.35, 1.25, 0.75, 1.0)     # 5: Sol (Dorado)
]

func _ready() -> void:
	add_to_group("remote_players")
	update_name_and_skin(player_name, skin_id)
	if anim_player.has_animation("idle_down"):
		anim_player.play("idle_down")

func _physics_process(delta: float) -> void:
	if target_position != Vector2.ZERO:
		global_position = global_position.lerp(target_position, 15.0 * delta)

func update_name_and_skin(new_name: String, new_skin: int) -> void:
	player_name = new_name
	skin_id = new_skin
	if name_label:
		name_label.text = player_name
	if new_skin >= 0 and new_skin < SKIN_COLORS.size():
		sprite.modulate = SKIN_COLORS[new_skin]

func update_remote_state(new_pos: Vector2, anim_name: String, flip_horizontal: bool) -> void:
	target_position = new_pos
	sprite.flip_h = flip_horizontal
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func take_hit(damage: int, from_pos: Vector2) -> void:
	current_health = max(0, current_health - damage)
	
	# Empujón visual
	var knock_dir = (global_position - from_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.DOWN
	global_position += knock_dir * 12.0
	target_position = global_position
	
	# Parpadeo rojo de impacto
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 0.3, 0.3), 0.1)
	var base_col = SKIN_COLORS[skin_id] if (skin_id >= 0 and skin_id < SKIN_COLORS.size()) else Color(1, 1, 1)
	tween.tween_property(sprite, "modulate", base_col, 0.15)
	
	_spawn_damage_text("-1 Vida")

func _spawn_damage_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.scale = Vector2(0.5, 0.5)
	label.global_position = global_position + Vector2(-15, -16)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 12.0, 0.8)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.8)
	label_tween.chain().tween_callback(label.queue_free)
