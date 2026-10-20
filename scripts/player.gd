extends CharacterBody2D
class_name Player

@export var max_speed: float = 110.0
@export var acceleration: float = 800.0
@export var friction: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

enum State { IDLE, WALK, ATTACK }
var current_state: State = State.IDLE

enum Direction { DOWN, UP, LEFT, RIGHT }
var current_dir: Direction = Direction.DOWN

var network_sync_timer: float = 0.0

func _ready() -> void:
	# Configurar acciones de ataque e interacción sin interferir con toques en pantalla
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var ev_space = InputEventKey.new()
		ev_space.physical_keycode = KEY_SPACE
		InputMap.action_add_event("attack", ev_space)
		var ev_j = InputEventKey.new()
		ev_j.physical_keycode = KEY_J
		InputMap.action_add_event("attack", ev_j)
		
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev_e = InputEventKey.new()
		ev_e.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev_e)
		var ev_enter = InputEventKey.new()
		ev_enter.physical_keycode = KEY_ENTER
		InputMap.action_add_event("interact", ev_enter)

	update_animation(false)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE, State.WALK:
			handle_movement(delta)
			check_attack_input()
		State.ATTACK:
			# Durante el ataque desaceleramos suavemente
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			
	# Sincronización multijugador en red (20 Hz)
	network_sync_timer += delta
	if network_sync_timer >= 0.05:
		network_sync_timer = 0.0
		var net_mgr = get_tree().get_first_node_in_group("network_manager")
		if net_mgr and "is_connected_to_server" in net_mgr and net_mgr.is_connected_to_server:
			net_mgr.broadcast_my_state(global_position, anim_player.current_animation, sprite.flip_h)

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

	# Integración con el joystick táctil en pantalla para móviles:
	if dir == Vector2.ZERO:
		var touch_ctrls = get_tree().get_first_node_in_group("touch_controls")
		if touch_ctrls and touch_ctrls.has_node("HUD/VirtualJoystick"):
			var joy = touch_ctrls.get_node("HUD/VirtualJoystick")
			if joy and "output" in joy and joy.output != Vector2.ZERO:
				dir = joy.output

	return dir

func handle_movement(delta: float) -> void:
	var input_vector = get_input_vector()

	if input_vector != Vector2.ZERO:
		current_state = State.WALK
		update_direction(input_vector)
		velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
		update_animation(true)
	else:
		current_state = State.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		update_animation(false)

	move_and_slide()

func update_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			current_dir = Direction.RIGHT
		else:
			current_dir = Direction.LEFT
	else:
		if dir.y > 0:
			current_dir = Direction.DOWN
		else:
			current_dir = Direction.UP

func update_animation(is_moving: bool) -> void:
	match current_dir:
		Direction.DOWN:
			sprite.flip_h = false
			play_animation("walk_down" if is_moving else "idle_down")
		Direction.UP:
			sprite.flip_h = false
			play_animation("walk_up" if is_moving else "idle_up")
		Direction.RIGHT:
			sprite.flip_h = false
			play_animation("walk_side" if is_moving else "idle_side")
		Direction.LEFT:
			sprite.flip_h = true
			play_animation("walk_side" if is_moving else "idle_side")

func check_attack_input() -> void:
	# Atacar SOLAMENTE cuando se pulsa la tecla Espacio, J, o el botón dedicado ATK
	# NUNCA atacar por tocar cualquier parte de la pantalla o el joystick
	if Input.is_action_just_pressed("attack"):
		start_attack()

func start_attack() -> void:
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	
	match current_dir:
		Direction.DOWN:
			sprite.flip_h = false
			play_animation("attack_down")
		Direction.UP:
			sprite.flip_h = false
			play_animation("attack_up")
		Direction.RIGHT:
			sprite.flip_h = false
			play_animation("attack_side")
		Direction.LEFT:
			sprite.flip_h = true
			play_animation("attack_side")

func _on_animation_finished(anim_name: StringName) -> void:
	if "attack" in anim_name:
		current_state = State.IDLE
		update_animation(false)

func play_animation(anim_name: String) -> void:
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
