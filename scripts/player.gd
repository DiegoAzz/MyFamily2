extends CharacterBody2D
class_name Player

@export var max_speed: float = 110.0
@export var acceleration: float = 800.0
@export var friction: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

enum State { IDLE, WALK, ATTACK, DEAD }
var current_state: State = State.IDLE

enum Direction { DOWN, UP, LEFT, RIGHT }
var current_dir: Direction = Direction.DOWN

var network_sync_timer: float = 0.0

# Sistema de vidas, combate y puntuación
var max_health: int = 3
var current_health: int = 3
var diamonds: int = 0
var score: int = 0
var is_invulnerable: bool = false
var is_dead: bool = false
var respawn_point: Vector2 = Vector2(0, 15)

const SKIN_COLORS = [
	Color(1.0, 1.0, 1.0, 1.0),       # 0: Granjero Clásico
	Color(1.35, 0.8, 0.8, 1.0),      # 1: Mateo (Rojo)
	Color(0.8, 1.3, 0.85, 1.0),      # 2: Clara (Verde)
	Color(0.8, 0.95, 1.4, 1.0),      # 3: Leo (Azul)
	Color(1.25, 0.85, 1.35, 1.0),    # 4: Luna (Púrpura)
	Color(1.35, 1.25, 0.75, 1.0)     # 5: Sol (Dorado)
]

func _ready() -> void:
	add_to_group("player")
	
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

	# Restaurar posición y datos del jugador si existen
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.has_method("load_game_state"):
		var data = net_mgr.load_game_state()
		if data.has("pos_x") and data.has("pos_y"):
			var saved_p = Vector2(data["pos_x"], data["pos_y"])
			if saved_p != Vector2.ZERO:
				# Prevenir que el jugador reaparezca dentro de las paredes de la fachada exterior de la casa
				if saved_p.y >= -95.0 and saved_p.y <= -45.0 and abs(saved_p.x) < 50.0:
					saved_p.y = 15.0
				global_position = saved_p

	# Aplicar nombre de jugador en la etiqueta bonita
	if has_node("NameTagBadge/Margin/NameLabel"):
		var p_name = net_mgr.player_name if net_mgr and not net_mgr.player_name.is_empty() else "Tú"
		$NameTagBadge/Margin/NameLabel.text = p_name

	# Aplicar tinte del personaje según el selector de skins
	var s_id = net_mgr.player_skin_id if net_mgr else 0
	if s_id >= 0 and s_id < SKIN_COLORS.size():
		sprite.modulate = SKIN_COLORS[s_id]

	update_animation(false)
	_update_hud()

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
		var net_mgr = null
		if Engine.has_singleton("NetworkManager") or has_node("/root/NetworkManager"):
			net_mgr = get_node_or_null("/root/NetworkManager")
		if not net_mgr:
			net_mgr = get_tree().get_first_node_in_group("network_manager")
			
		if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
			net_mgr.broadcast_my_state(global_position, anim_player.current_animation, sprite.flip_h)

func is_chat_active() -> bool:
	var chat = get_tree().get_first_node_in_group("chat_box")
	if chat and "is_chat_open" in chat and chat.is_chat_open:
		return true
	return false

func get_input_vector() -> Vector2:
	if is_dead or not is_inside_tree():
		return Vector2.ZERO
	# Si hay un diálogo abierto o el chat está activo, congelar movimiento
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box and "is_active" in dialogue_box and dialogue_box.is_active:
		return Vector2.ZERO
	if is_chat_active():
		return Vector2.ZERO

	# 1. Entrada por acciones estándar o teclado
	var ui_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if ui_vector != Vector2.ZERO:
		return ui_vector

	var dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
		
	if dir != Vector2.ZERO:
		return dir.normalized()

	# 2. Joystick táctil en pantalla para móviles:
	var touch_ctrls = get_tree().get_first_node_in_group("touch_controls")
	if touch_ctrls and touch_ctrls.has_node("HUD/VirtualJoystick"):
		var joy = touch_ctrls.get_node("HUD/VirtualJoystick")
		if joy and "output" in joy and joy.output != Vector2.ZERO:
			return joy.output

	return Vector2.ZERO

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
	var dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box and "is_active" in dialogue_box and dialogue_box.is_active:
		return
	if is_chat_active():
		return

	# Atacar SOLAMENTE cuando se pulsa la tecla Espacio, J, o el botón dedicado ATK
	# NUNCA atacar por tocar cualquier parte de la pantalla o el joystick
	var atk_pressed = false
	if InputMap.has_action("attack") and Input.is_action_just_pressed("attack"):
		atk_pressed = true
	elif Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J):
		atk_pressed = true
		
	if atk_pressed:
		start_attack()

func start_attack() -> void:
	if is_dead or current_state == State.ATTACK:
		return
	if is_chat_active():
		return
	current_state = State.ATTACK
	velocity = Vector2.ZERO
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_attack"):
			audio.play_attack()
	
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

	# Detectar enemigos frente al jugador y aplicar daño
	var hit_offset = Vector2.ZERO
	match current_dir:
		Direction.DOWN: hit_offset = Vector2(0, 16)
		Direction.UP: hit_offset = Vector2(0, -16)
		Direction.RIGHT: hit_offset = Vector2(16, 0)
		Direction.LEFT: hit_offset = Vector2(-16, 0)
	var attack_pos = global_position + hit_offset
	
	# 1. Detectar monstruos frente al jugador y aplicar daño
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_hit"):
			if enemy.global_position.distance_to(attack_pos) <= 26.0 or enemy.global_position.distance_to(global_position) <= 20.0:
				enemy.take_hit(1, global_position)

	# 2. PvP: Detectar a otros jugadores conectados (RemotePlayer) y aplicar daño
	var net_mgr = get_node_or_null("/root/NetworkManager")
	for remote_p in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(remote_p):
			var dist = remote_p.global_position.distance_to(attack_pos)
			if dist <= 28.0 or remote_p.global_position.distance_to(global_position) <= 22.0:
				if remote_p.has_method("take_hit"):
					remote_p.take_hit(1, global_position)
				if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
					if "client_id" in remote_p and not remote_p.client_id.is_empty():
						net_mgr.send_player_hit(remote_p.client_id, 1, global_position)

	# 3. Talar árboles frente al jugador
	for tree in get_tree().get_nodes_in_group("trees"):
		if is_instance_valid(tree) and tree.has_method("take_hit") and not tree.is_chopped:
			var trunk_pos = tree.global_position + Vector2(0, 4 if ("is_small" in tree and tree.is_small) else 18)
			if trunk_pos.distance_to(attack_pos) <= 32.0 or trunk_pos.distance_to(global_position) <= 26.0:
				tree.take_hit(1, global_position)

func take_damage(amount: int, from_pos: Vector2) -> void:
	if is_invulnerable or current_health <= 0:
		return
		
	is_invulnerable = true
	current_health = max(0, current_health - amount)
	_update_hud()
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_hit"):
			audio.play_hit()
	
	# Empujón / Knockback
	var knock_dir = (global_position - from_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.DOWN
	velocity = knock_dir * 140.0
	move_and_slide()
	
	# Parpadeo de daño rojo
	var tween = create_tween()
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var s_id = net_mgr.player_skin_id if net_mgr else 0
	var orig_color = SKIN_COLORS[s_id] if (s_id >= 0 and s_id < SKIN_COLORS.size()) else Color(1, 1, 1)
	
	tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 0.4), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.15)
	tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 0.4), 0.15)
	tween.tween_property(sprite, "modulate", orig_color, 0.15)
	
	if current_health <= 0:
		die_and_respawn()
	else:
		# Período de gracia de 0.8s
		get_tree().create_timer(0.8).timeout.connect(func(): is_invulnerable = false)

func die_and_respawn() -> void:
	current_state = State.DEAD
	is_dead = true
	velocity = Vector2.ZERO
	
	# Mensaje flotante de caída
	var label = Label.new()
	label.text = "¡Has caído! Reapareciendo en la granja..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.global_position = global_position + Vector2(-90, -30)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 20.0, 1.5)
	label_tween.tween_property(label, "modulate:a", 0.0, 1.5)
	label_tween.chain().tween_callback(label.queue_free)
	
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		global_position = respawn_point
		current_health = max_health
		current_state = State.IDLE
		is_dead = false
		is_invulnerable = false
		_update_hud()
	)

func add_diamond(count: int, points: int) -> void:
	diamonds += count
	score += points
	_update_hud()

func _update_hud() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var root = get_tree().current_scene
		if root and root.has_node("StardewHUD"):
			hud = root.get_node("StardewHUD")
	if hud:
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)
		if hud.has_method("update_diamonds"):
			hud.update_diamonds(diamonds, score)

func _on_animation_finished(anim_name: StringName) -> void:
	if "attack" in anim_name:
		current_state = State.IDLE
		update_animation(false)

func spawn_floating_text(text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.scale = Vector2(0.6, 0.6)
	label.pivot_offset = Vector2(40, 7)
	label.global_position = global_position + Vector2(-30, -28)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 18.0, 1.2)
	label_tween.tween_property(label, "modulate:a", 0.0, 1.2)
	label_tween.chain().tween_callback(label.queue_free)

func play_animation(anim_name: String) -> void:
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
