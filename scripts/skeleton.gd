extends CharacterBody2D
class_name SkeletonEnemy

@export var speed: float = 38.0
@export var detection_range: float = 110.0
@export var max_hp: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var player: Node2D = null
var hp: int = 3
var is_dead: bool = false
var diamond_scene: PackedScene = preload("res://scenes/diamond.tscn")

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
		
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_range and dist > 10.0:
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
	_check_player_contact()

func _check_player_contact() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("take_damage"):
			if global_position.distance_to(p.global_position) <= 15.0:
				p.take_damage(1, global_position)

func take_hit(damage: int, from_pos: Vector2) -> void:
	if is_dead:
		return
		
	hp -= damage
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_hit"):
			audio.play_hit()
	
	# Empujón / Knockback
	var knock_dir = (global_position - from_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.UP
	velocity = knock_dir * 130.0
	move_and_slide()
	
	# Efecto visual
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.8, 0.3, 0.3), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	if hp <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	
	# Soltar 2 diamantes como premio por derrotar al esqueleto
	for i in range(2):
		var diam = diamond_scene.instantiate()
		diam.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_parent().add_child(diam)
		
	# Desvanecer
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()
