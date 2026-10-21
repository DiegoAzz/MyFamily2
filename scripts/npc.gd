extends CharacterBody2D
class_name VillageNPC

@export var npc_name: String = "Clara"
@export var portrait: Texture2D = null
@export var dialogue_lines: Array = []

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var interactable: Node = $Interactable

func _ready() -> void:
	add_to_group("npcs")
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
		
	if interactable:
		interactable.speaker_name = npc_name
		interactable.portrait_texture = portrait
		interactable.prompt_message = "[ACT] Hablar con " + npc_name
		if dialogue_lines.size() > 0:
			interactable.dialogue_lines = dialogue_lines
		else:
			interactable.dialogue_lines = [
				"¡Bienvenido de vuelta a casa! Pensé que no volverías al valle tras la partida del abuelo.",
				"Esta granja guarda los mejores recuerdos de nuestra familia... pero las cosas se han vuelto peligrosas últimamente.",
				"Una extraña niebla púrpura cubrió el bosque cruzando el río, y criaturas viscosas y esqueletos han invadido el camino.",
				"He dejado unas herramientas y notas en el cofre junto a la casa. ¡Ten mucho cuidado si decides cruzar el puente!",
				"Nuestra familia cuenta contigo para recuperar la armonía del valle."
			]
