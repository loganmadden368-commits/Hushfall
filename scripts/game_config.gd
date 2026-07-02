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

# --- Proximity voice dials (THE core balance levers of the whole game:
#     outbuildings must sit out of voice range of the plaza) ---
var voice_max_distance: float = 25.0  # meters; beyond this a voice is silent
var voice_unit_size: float = 6.0      # falloff curve: higher = carries farther

# How the mic activates: "push_to_talk" (hold V), "toggle" (tap V on/off),
# or "open" (always transmitting while in a lobby; V still toggles the solo
# echo test). The shipped game will likely default to open — proximity
# voice being always-on is core to the design.
var voice_mode: String = "toggle"


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
	voice_max_distance = config.get_value("voice", "voice_max_distance", voice_max_distance)
	voice_unit_size = config.get_value("voice", "voice_unit_size", voice_unit_size)
	voice_mode = config.get_value("voice", "voice_mode", voice_mode)
	if voice_mode not in ["push_to_talk", "toggle", "open"]:
		push_warning("[GameConfig] Unknown voice_mode '%s' — using 'toggle'." % voice_mode)
		voice_mode = "toggle"
	print("[GameConfig] Loaded. max_players = ", max_players, ", voice_mode = ", voice_mode)
