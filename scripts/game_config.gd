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

# --- Map flow dials (checked by the boot map audit) ---
var walk_tier_near_max_s: float = 9.0
var walk_tier_mid_max_s: float = 14.0
var walk_tier_far_max_s: float = 22.0
var walk_trip_ceiling_s: float = 25.0

# Chokepoint lantern positions (see config/gameplay.cfg [lanterns]).
var lantern_positions: Array[Vector3] = []

# --- Style dials (Part 3 stylized blockout) ---
var palette: Dictionary = {}          # name -> Color, from [style] hex dials
var night_preview: bool = true
var dressing_density: String = "medium"

# --- Debug ---
var map_audit: bool = true


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

	walk_tier_near_max_s = config.get_value("map", "walk_tier_near_max_s", walk_tier_near_max_s)
	walk_tier_mid_max_s = config.get_value("map", "walk_tier_mid_max_s", walk_tier_mid_max_s)
	walk_tier_far_max_s = config.get_value("map", "walk_tier_far_max_s", walk_tier_far_max_s)
	walk_trip_ceiling_s = config.get_value("map", "walk_trip_ceiling_s", walk_trip_ceiling_s)
	map_audit = config.get_value("debug", "map_audit", map_audit)

	# Style palette: every key in [style] holding a 6-digit hex string.
	night_preview = config.get_value("style", "night_preview", night_preview)
	dressing_density = config.get_value("style", "dressing_density", dressing_density)
	if config.has_section("style"):
		for key in config.get_section_keys("style"):
			var value = config.get_value("style", key)
			if value is String and value.is_valid_html_color():
				palette[key] = Color(value)

	# Lantern positions come as "x,y,z|x,y,z|..."
	lantern_positions.clear()
	var lantern_string: String = config.get_value("lanterns", "choke_positions", "")
	for entry in lantern_string.split("|", false):
		var parts := entry.split(",")
		if parts.size() == 3:
			lantern_positions.append(Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float()))

	print("[GameConfig] Loaded. max_players = ", max_players, ", voice_mode = ", voice_mode)
