extends CharacterBody2D
class_name RemotePlayer

@export var player_name: String = "Jugador 2"

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var name_label: Label = $NameLabel

var target_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	name_label.text = player_name
	if anim_player.has_animation("idle_down"):
		anim_player.play("idle_down")

func _physics_process(delta: float) -> void:
	# Interpolar suavemente hacia la posición remota recibida
	if target_position != Vector2.ZERO:
		global_position = global_position.lerp(target_position, 15.0 * delta)

func update_remote_state(new_pos: Vector2, anim_name: String, flip_horizontal: bool) -> void:
	target_position = new_pos
	sprite.flip_h = flip_horizontal
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
