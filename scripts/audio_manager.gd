extends Node

var bgm_player: AudioStreamPlayer = null
var sfx_players: Array[AudioStreamPlayer] = []
const NUM_SFX_PLAYERS: int = 6
var next_sfx_idx: int = 0

var bgm_music: AudioStreamWAV = preload("res://audio/music_peaceful_farm.wav")
var sfx_chop: AudioStreamWAV = preload("res://audio/sfx_chop.wav")
var sfx_tree_fall: AudioStreamWAV = preload("res://audio/sfx_tree_fall.wav")
var sfx_diamond: AudioStreamWAV = preload("res://audio/sfx_diamond.wav")
var sfx_attack: AudioStreamWAV = preload("res://audio/sfx_attack.wav")
var sfx_hit: AudioStreamWAV = preload("res://audio/sfx_hit.wav")
var sfx_chat: AudioStreamWAV = preload("res://audio/sfx_chat.wav")
var sfx_door: AudioStreamWAV = preload("res://audio/sfx_door.wav")
var sfx_harvest: AudioStreamWAV = preload("res://audio/sfx_harvest.wav")

var is_user_interacted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Configurar bucle en la música armónica
	if bgm_music:
		bgm_music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = bgm_music
	bgm_player.volume_db = -9.0 # Nivel suave, relajante y armonioso
	add_child(bgm_player)
	
	for i in range(NUM_SFX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		sfx_players.append(p)
		
	play_bgm()

func _input(event: InputEvent) -> void:
	if not is_user_interacted:
		if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
			is_user_interacted = true
			if not bgm_player.playing:
				bgm_player.play()

func play_bgm() -> void:
	if not bgm_player.playing:
		bgm_player.play()

func play_sfx(stream: AudioStream, volume_db: float = -4.0, pitch_scale: float = 1.0) -> void:
	if not stream or sfx_players.is_empty():
		return
	var player = sfx_players[next_sfx_idx]
	next_sfx_idx = (next_sfx_idx + 1) % NUM_SFX_PLAYERS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func play_chop() -> void:
	play_sfx(sfx_chop, -3.0, randf_range(0.95, 1.08))

func play_tree_fall() -> void:
	play_sfx(sfx_tree_fall, -2.0, 1.0)

func play_diamond() -> void:
	play_sfx(sfx_diamond, -3.0, randf_range(0.98, 1.05))

func play_attack() -> void:
	play_sfx(sfx_attack, -6.0, randf_range(0.95, 1.1))

func play_hit() -> void:
	play_sfx(sfx_hit, -3.0, randf_range(0.92, 1.05))

func play_chat() -> void:
	play_sfx(sfx_chat, -4.0, 1.0)

func play_door() -> void:
	play_sfx(sfx_door, -3.0, 1.0)

func play_harvest() -> void:
	play_sfx(sfx_harvest, -3.0, randf_range(0.96, 1.05))
