extends Area2D
class_name HouseBed

var last_heal_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
		
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_heal_time < 2.0:
		return
	last_heal_time = now
	
	if "current_health" in body and "max_health" in body:
		if body.current_health < body.max_health:
			body.current_health = body.max_health
			if body.has_method("_update_hud"):
				body._update_hud()
			if body.has_method("spawn_floating_text"):
				body.spawn_floating_text("¡Descansaste en la cama! Vidas al maximo (3/3)", Color(0.4, 1.0, 0.6))
		else:
			if body.has_method("spawn_floating_text"):
				body.spawn_floating_text("La cama esta muy comoda y tibia", Color(0.9, 0.9, 0.5))
