extends Node
class_name QuestManager

signal quest_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String, title: String)
signal all_quests_completed

var quests: Dictionary = {
	"clue_river": {
		"title": "Pista 1: El Roble del Rio",
		"desc": "Junto al rio y el muelle al sur, un viejo roble esconde un diamante brillante.",
		"current": 0,
		"target": 1,
		"reward_gold": 150,
		"reward_score": 100,
		"completed": false
	},
	"clue_cabin": {
		"title": "Pista 2: La Cabana del Bosque",
		"desc": "En el bosque profundo al este, junto a la cabana de madera solitaria.",
		"current": 0,
		"target": 1,
		"reward_gold": 200,
		"reward_score": 150,
		"completed": false
	},
	"clue_corral": {
		"title": "Pista 3: La Cerca del Corral",
		"desc": "Al oeste, detras de las ovejas y cerdos, entre los arboles altos del fondo.",
		"current": 0,
		"target": 1,
		"reward_gold": 200,
		"reward_score": 150,
		"completed": false
	},
	"clue_north": {
		"title": "Pista 4: El Monte Norteno",
		"desc": "En la colina norte tras la casa familiar, un arbol frondoso guarda su secreto.",
		"current": 0,
		"target": 1,
		"reward_gold": 250,
		"reward_score": 150,
		"completed": false
	},
	"clue_crossroad": {
		"title": "Pista 5: El Cruce del Valle",
		"desc": "Cerca del letrero central de caminos, donde se cruzan las veredas.",
		"current": 0,
		"target": 1,
		"reward_gold": 300,
		"reward_score": 200,
		"completed": false
	}
}

func _ready() -> void:
	add_to_group("quest_manager")

func add_progress(quest_id: String, amount: int = 1, notify_net: bool = true) -> void:
	if not quests.has(quest_id):
		return
	var q = quests[quest_id]
	if q["completed"]:
		return
		
	q["current"] = min(q["target"], q["current"] + amount)
	quest_updated.emit(quest_id, q["current"], q["target"])
	
	if q["current"] >= q["target"]:
		_complete_quest(quest_id)
		
	if notify_net:
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr and "is_multiplayer_active" in net_mgr and net_mgr.is_multiplayer_active:
			if net_mgr.socket and net_mgr.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
				net_mgr.socket.send_text(JSON.stringify({
					"type": "quest_progress",
					"quest_id": quest_id,
					"current": q["current"]
				}))

func set_progress_from_net(quest_id: String, val: int) -> void:
	if not quests.has(quest_id):
		return
	var q = quests[quest_id]
	q["current"] = min(q["target"], val)
	quest_updated.emit(quest_id, q["current"], q["target"])
	if q["current"] >= q["target"] and not q["completed"]:
		_complete_quest(quest_id)

func _complete_quest(quest_id: String) -> void:
	var q = quests[quest_id]
	q["completed"] = true
	
	if Engine.has_singleton("AudioManager") or has_node("/root/AudioManager"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_diamond"):
			audio.play_diamond()
			
	quest_completed.emit(quest_id, q["title"])
	
	# Premiar al jugador local
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			if "score" in p:
				p.score += q["reward_score"]
			if p.has_method("spawn_floating_text"):
				p.spawn_floating_text("¡Mision cumplida: " + q["title"] + "! (+" + str(q["reward_gold"]) + " G)", Color(1.0, 0.9, 0.2))
			if p.has_method("_update_hud"):
				p._update_hud()
				
	# Verificar si todas están completas
	var all_done = true
	for k in quests.keys():
		if not quests[k]["completed"]:
			all_done = false
			break
	if all_done:
		all_quests_completed.emit()
		for p in players:
			if is_instance_valid(p) and p.has_method("spawn_floating_text"):
				p.spawn_floating_text("¡TODAS LAS PISTAS DESCUBIERTAS! ¡EL TESORO DEL VALLE ES TUYO!", Color(1.0, 0.95, 0.3))

func reset_quests() -> void:
	for k in quests.keys():
		quests[k]["current"] = 0
		quests[k]["completed"] = false
		quest_updated.emit(k, 0, quests[k]["target"])
