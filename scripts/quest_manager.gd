extends Node
class_name QuestManager

signal quest_updated(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String, title: String)
signal all_quests_completed

var quests: Dictionary = {
	"crops": {
		"title": "🌾 El Huerto Familiar",
		"desc": "Siembra y cosecha 4 cultivos en la tierra arada",
		"current": 0,
		"target": 4,
		"reward_gold": 150,
		"reward_score": 100,
		"completed": false
	},
	"wood": {
		"title": "🪓 Madera para las Cabañas",
		"desc": "Tala 3 árboles para reparar las cabañas del valle",
		"current": 0,
		"target": 3,
		"reward_gold": 200,
		"reward_score": 150,
		"completed": false
	},
	"diamonds": {
		"title": "💎 Los Tesoros del Valle",
		"desc": "Encuentra y recoge 4 diamantes mágicos",
		"current": 0,
		"target": 4,
		"reward_gold": 300,
		"reward_score": 200,
		"completed": false
	},
	"monsters": {
		"title": "⚔️ Guardianes del Río",
		"desc": "Derrota 2 monstruos (Slimes o Esqueletos)",
		"current": 0,
		"target": 2,
		"reward_gold": 250,
		"reward_score": 150,
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
				p.spawn_floating_text("🏆 ¡Misión cumplida: " + q["title"] + "! (+" + str(q["reward_gold"]) + " G)", Color(1.0, 0.9, 0.2))
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
				p.spawn_floating_text("👑 ¡VALLE ESPERANZA RESTAURADO! ¡El Legado del Abuelo triunfó!", Color(1.0, 0.95, 0.3))
