extends Control
## Main scene for Milestone 1: just shows whether Steam connected.
## The real work happens in SteamManager (the autoload) — by the time this
## scene's _ready() runs, autoloads have already run theirs, so we can simply
## read the result.


func _ready() -> void:
	if SteamManager.steam_ready:
		$StatusLabel.text = (
			"✅ Steam connected!\n\n"
			+ "Logged in as: %s\n" % SteamManager.steam_username
			+ "Steam ID: %s\n\n" % SteamManager.steam_id
			+ "(Milestone 1 complete — details also printed in the Output panel)"
		)
	else:
		$StatusLabel.text = (
			"❌ Steam failed to initialize.\n\n"
			+ "Check that the Steam client is running and logged in,\n"
			+ "then check the editor's Output panel for the error message."
		)
