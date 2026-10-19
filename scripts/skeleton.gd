extends CharacterBody2D
class_name SkeletonEnemy

@export var speed: float = 35.0
@export var detection_range: float = 90.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var player: Node2D = null

func _ready() -> void:
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(_delta: float) -> void:
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_range and dist > 12.0:
			var dir = (player.global_position - global_position).normalized()
			velocity = dir * speed
			if velocity.x != 0:
				sprite.flip_h = (velocity.x < 0)
			if anim_player.has_animation("walk") and anim_player.current_animation != "walk":
				anim_player.play("walk")
		else:
			velocity = Vector2.ZERO
			if anim_player.has_animation("idle") and anim_player.current_animation != "idle":
				anim_player.play("idle")
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()
