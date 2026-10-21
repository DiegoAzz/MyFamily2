extends Area2D
class_name HouseDoor

@export var target_position: Vector2 = Vector2.ZERO
@export var transition_message: String = ""
@export var is_exit: bool = false

static var last_teleport_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
		
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_teleport_time < 0.8:
		return
	last_teleport_time = now
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_door"):
			audio.play_door()
			
	body.global_position = target_position
	body.velocity = Vector2.ZERO
	
	if is_exit:
		if "current_dir" in body:
			body.current_dir = 0 # DOWN
	else:
		if "current_dir" in body:
			body.current_dir = 1 # UP
			
	if not transition_message.is_empty() and body.has_method("spawn_floating_text"):
		body.spawn_floating_text(transition_message, Color(1.0, 0.9, 0.4))
