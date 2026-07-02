extends Node
## SteamManager — an "autoload" (singleton) that starts Steam when the game
## launches and keeps it running.
##
## An autoload is a node Godot creates automatically before the main scene
## loads, and it stays alive for the whole session. Any script can reach it
## by name: `SteamManager.steam_ready`, `SteamManager.steam_username`, etc.
## All of our Steam plumbing (and later, lobby + voice code) will hang off
## this one place.

# Steam App ID 480 is "Spacewar", Valve's free public test app.
# We use it for ALL development. Only when we're ready to publish do we
# register a real App ID (and pay the $100 Steam Direct fee).
const APP_ID: int = 480

# Set to true once Steam has initialized successfully.
var steam_ready: bool = false

# Filled in after a successful init.
var steam_id: int = 0          # Your unique 64-bit Steam ID
var steam_username: String = ""  # Your Steam display name


func _init() -> void:
	# Tell the OS which Steam app we are BEFORE Steam initializes.
	# This is what lets Steam recognize the game when we run it from the
	# Godot editor (where there's no steam_appid.txt sitting next to the
	# editor's .exe). Belt-and-suspenders alongside steamInitEx(APP_ID) below.
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))


func _ready() -> void:
	_initialize_steam()


func _process(_delta: float) -> void:
	# Steam delivers its events (lobby joins, invites, voice data...) through
	# "callbacks", but only when we ask. Pumping this every frame is required
	# for anything Steam-related to actually happen. Forgetting this line is
	# the #1 classic GodotSteam bug: everything compiles, nothing ever fires.
	if steam_ready:
		Steam.run_callbacks()


func _initialize_steam() -> void:
	# steamInitEx returns a Dictionary: { "status": int, "verbal": String }.
	# status 0 (STEAM_API_INIT_RESULT_OK) means success; anything else is an
	# error, and "verbal" holds a human-readable explanation.
	var result: Dictionary = Steam.steamInitEx(APP_ID)

	if result["status"] == Steam.STEAM_API_INIT_RESULT_OK:
		steam_ready = true
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		print("=========================================")
		print("[SteamManager] Steam initialized OK")
		print("[SteamManager] Logged in as: ", steam_username)
		print("[SteamManager] Steam ID:     ", steam_id)
		print("[SteamManager] App ID:       ", APP_ID, " (Spacewar test app)")
		print("=========================================")
	else:
		# Most common cause by far: the Steam client isn't running/logged in.
		push_error(
			"[SteamManager] Steam failed to initialize. status=%s — %s. " % [result["status"], result["verbal"]]
			+ "Is the Steam client running and logged in?"
		)
