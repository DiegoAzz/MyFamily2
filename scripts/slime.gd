extends CharacterBody2D
class_name Slime

@export var speed: float = 30.0
@export var wander_time: float = 2.0
@export var max_hp: int = 2

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var move_direction: Vector2 = Vector2.ZERO
var timer: float = 0.0
var hp: int = 2
var is_dead: bool = false
var diamond_scene: PackedScene = preload("res://scenes/diamond.tscn")

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
	choose_new_direction()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	timer -= delta
	if timer <= 0.0:
		choose_new_direction()
	
	velocity = move_direction * speed
	if velocity.x != 0:
		sprite.flip_h = (velocity.x < 0)
	
	move_and_slide()
	
	# Dañar a jugadores cercanos al contacto
	_check_player_contact()

func _check_player_contact() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("take_damage"):
			if global_position.distance_to(p.global_position) <= 14.0:
				p.take_damage(1, global_position)

func choose_new_direction() -> void:
	timer = randf_range(1.5, 3.5)
	if randf() > 0.5:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	else:
		move_direction = Vector2.ZERO

func take_hit(damage: int, from_pos: Vector2) -> void:
	if is_dead:
		return
		
	hp -= damage
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_hit"):
			audio.play_hit()
	
	# Knockback
	var knock_dir = (global_position - from_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.UP
	velocity = knock_dir * 120.0
	move_and_slide()
	
	# Efecto visual de golpe
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.3), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)
	
	if hp <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	
	# Soltar diamante
	var diam = diamond_scene.instantiate()
	diam.global_position = global_position
	get_parent().add_child(diam)
	
	# Desvanecer slime
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	await tween.finished
	queue_free()
