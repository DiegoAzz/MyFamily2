extends Area2D
class_name LevelPortal

@export var target_position: Vector2 = Vector2.ZERO
@export var level_name: String = ""
@export var level_subtitle: String = ""
@export var portal_color: Color = Color(0.3, 0.9, 1.0)
@export var sound_type: String = "door" # "door" or "diamond"

static var last_portal_time: float = -999.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
		
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_portal_time < 0.8:
		return
	last_portal_time = now
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio:
			if sound_type == "diamond" and audio.has_method("play_diamond"):
				audio.play_diamond()
			elif audio.has_method("play_door"):
				audio.play_door()
				
	body.global_position = target_position
	body.velocity = Vector2.ZERO
	
	if not level_name.is_empty():
		var banner = get_tree().get_first_node_in_group("level_banner")
		if banner and banner.has_method("show_banner"):
			banner.show_banner(level_name, level_subtitle, portal_color)
		elif body.has_method("spawn_floating_text"):
			body.spawn_floating_text(level_name, portal_color)
