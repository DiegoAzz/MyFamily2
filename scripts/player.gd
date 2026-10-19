extends CharacterBody2D
class_name Player

@export var max_speed: float = 110.0
@export var acceleration: float = 800.0
@export var friction: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

enum State { IDLE, WALK, ATTACK }
var current_state: State = State.IDLE

var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	play_animation("idle_down")

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE, State.WALK:
			handle_movement(delta)
			check_attack_input()
		State.ATTACK:
			# Durante el ataque desaceleramos suavemente
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()

func get_input_vector() -> Vector2:
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1.0
		dir = dir.normalized()
	return dir

func handle_movement(delta: float) -> void:
	var input_vector = get_input_vector()

	if input_vector != Vector2.ZERO:
		current_state = State.WALK
		facing_direction = input_vector
		velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
		update_walk_animation(input_vector)
	else:
		current_state = State.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		update_idle_animation()

	move_and_slide()

func check_attack_input() -> void:
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		start_attack()

func start_attack() -> void:
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	
	if abs(facing_direction.x) > abs(facing_direction.y):
		sprite.flip_h = (facing_direction.x < 0)
		play_animation("attack_side")
	elif facing_direction.y < 0:
		play_animation("attack_up")
	else:
		play_animation("attack_down")

func _on_animation_finished(anim_name: StringName) -> void:
	if "attack" in anim_name:
		current_state = State.IDLE
		update_idle_animation()

func update_walk_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		sprite.flip_h = (dir.x < 0)
		play_animation("walk_side")
	elif dir.y < 0:
		sprite.flip_h = false
		play_animation("walk_up")
	else:
		sprite.flip_h = false
		play_animation("walk_down")

func update_idle_animation() -> void:
	if abs(facing_direction.x) > abs(facing_direction.y):
		sprite.flip_h = (facing_direction.x < 0)
		play_animation("idle_side")
	elif facing_direction.y < 0:
		sprite.flip_h = false
		play_animation("idle_up")
	else:
		sprite.flip_h = false
		play_animation("idle_down")

func play_animation(anim_name: String) -> void:
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
