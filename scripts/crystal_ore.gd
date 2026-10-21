extends StaticBody2D
class_name CrystalOre

@export var ore_id: String = ""
@export var max_hits: int = 2
@export var crystal_color: Color = Color(0.3, 0.95, 1.0)
@export var diamond_points: int = 150

var hits: int = 0
var is_broken: bool = false
var diamond_scene = preload("res://scenes/diamond.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("mineable")
	if ore_id.is_empty():
		ore_id = "ore_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
	sprite.modulate = crystal_color

func take_hit(damage: int, _from_pos: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return
	hits += damage
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_chop"):
			audio.play_chop()
			
	# Tambaleo de cristal al ser golpeado
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 12.0, 0.05)
	tween.tween_property(sprite, "rotation_degrees", -12.0, 0.05)
	tween.tween_property(sprite, "rotation_degrees", 0.0, 0.05)
	
	# Destello
	var flash = create_tween()
	flash.tween_property(sprite, "modulate", Color(1.8, 1.8, 2.0), 0.05)
	flash.tween_property(sprite, "modulate", crystal_color, 0.08)
	
	if hits >= max_hits:
		break_crystal()

func break_crystal() -> void:
	if is_broken:
		return
	is_broken = true
	collision.set_deferred("disabled", true)
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_diamond"):
			audio.play_diamond()
			
	var d = diamond_scene.instantiate()
	d.global_position = global_position
	get_parent().add_child(d)
	
	_spawn_floating_text("+¡CRISTAL MINADO!", crystal_color)
	
	# Animación de rotura
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.25)
	t.tween_property(sprite, "modulate:a", 0.0, 0.25)
	
	# Rebrote / Regeneración de cristal tras 40 segundos
	await get_tree().create_timer(40.0).timeout
	if is_instance_valid(self):
		regrow()

func regrow() -> void:
	is_broken = false
	hits = 0
	collision.set_deferred("disabled", false)
	sprite.scale = Vector2(0.1, 0.1)
	sprite.modulate = crystal_color
	var t = create_tween()
	t.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.global_position = global_position + Vector2(-30, -16)
	get_parent().add_child(label)
	
	var label_tween = label.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", label.position.y - 14.0, 0.8)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.8)
	label_tween.chain().tween_callback(label.queue_free)
