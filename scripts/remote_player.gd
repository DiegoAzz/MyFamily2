extends CharacterBody2D
class_name RemotePlayer

@export var player_name: String = "Hermano"
@export var skin_id: int = 0

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
