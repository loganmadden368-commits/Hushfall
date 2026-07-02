extends Node
## GameConfig — an autoload that loads all "playtest dial" values from
## config/gameplay.cfg so we can tune the game without touching code.
##
## Golden rule from the design doc: balance values (lantern density, hush
## rules, ghost flicker, win thresholds...) live in editable config, never
## hardcoded. Every new dial gets: (1) a variable here with a sane default,
## (2) an entry in config/gameplay.cfg. The .cfg file wins if present.

const CONFIG_PATH: String = "res://config/gameplay.cfg"

# --- Lobby dials ---
var max_players: int = 12  # Design doc: 8-12 players per match.

# --- Player movement dials ("movement feel" is an open design question) ---
var move_speed: float = 5.0        # meters per second
var mouse_sensitivity: float = 0.002  # radians of turn per pixel of mouse


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	if error != OK:
		push_warning("[GameConfig] Couldn't load %s (error %s) — using defaults." % [CONFIG_PATH, error])
		return

	# get_value(section, key, default) — if the key is missing from the file,
	# the default (our current value) is kept.
	max_players = config.get_value("lobby", "max_players", max_players)
	move_speed = config.get_value("player", "move_speed", move_speed)
	mouse_sensitivity = config.get_value("player", "mouse_sensitivity", mouse_sensitivity)
	print("[GameConfig] Loaded. max_players = ", max_players)
