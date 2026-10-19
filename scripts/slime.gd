extends CharacterBody2D
class_name Slime

@export var speed: float = 30.0
@export var wander_time: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var move_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0

func _ready() -> void:
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
	choose_new_direction()

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		choose_new_direction()
	
	velocity = move_direction * speed
	if velocity.x != 0:
		sprite.flip_h = (velocity.x < 0)
	
	move_and_slide()

func choose_new_direction() -> void:
	timer = randf_range(1.5, 3.5)
	# 50% de probabilidad de detenerse a descansar
	if randf() > 0.5:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	else:
		move_direction = Vector2.ZERO
