extends Node

## Autoload: persists player identity + preferences to user://block_duel.cfg.
## No account system — a random guest identity is generated on first launch.

const PATH := "user://block_duel.cfg"

var player_id := ""
var display_name := ""
var session_token := ""
var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 1.0
var haptics_enabled := true
var debug_enabled := false

func _ready() -> void:
	load_all()

func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_generate_identity()
		save_all()
		return
	player_id = cfg.get_value("player", "id", "")
	display_name = cfg.get_value("player", "name", "")
	session_token = cfg.get_value("player", "token", "")
	master_volume = cfg.get_value("audio", "master", 1.0)
	music_volume = cfg.get_value("audio", "music", 0.7)
	sfx_volume = cfg.get_value("audio", "sfx", 1.0)
	haptics_enabled = cfg.get_value("ui", "haptics", true)
	debug_enabled = cfg.get_value("ui", "debug", false)
	if player_id.is_empty():
		_generate_identity()

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "id", player_id)
	cfg.set_value("player", "name", display_name)
	cfg.set_value("player", "token", session_token)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("ui", "haptics", haptics_enabled)
	cfg.set_value("ui", "debug", debug_enabled)
	cfg.save(PATH)

func save_token(token: String) -> void:
	session_token = token
	save_all()

func set_display_name(n: String) -> void:
	display_name = n.strip_edges().left(24)
	save_all()

func _generate_identity() -> void:
	player_id = "guest-" + _rand_hex(8)
	display_name = "Player %04d" % (randi() % 10000)

func _rand_hex(n: int) -> String:
	var s := ""
	for i in n:
		s += "0123456789abcdef"[randi() % 16]
	return s
