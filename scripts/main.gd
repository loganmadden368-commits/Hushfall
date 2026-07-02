extends Control
## Main menu for Milestone 2: host a lobby, find lobbies, join one, and see
## who's in it. All the actual Steam work lives in the LobbyManager autoload —
## this script is only UI: buttons in, labels out.
##
## The %Name syntax fetches nodes marked "unique name in owner" in the scene,
## so this script doesn't break if we rearrange the layout later.


func _ready() -> void:
	if not SteamManager.steam_ready:
		%StatusLabel.text = "❌ Steam failed to initialize — check the Output panel."
		%HostButton.disabled = true
		%FindButton.disabled = true
		return

	%StatusLabel.text = "Steam OK — logged in as %s" % SteamManager.steam_username

	# Buttons -> LobbyManager
	%HostButton.pressed.connect(_on_host_pressed)
	%FindButton.pressed.connect(_on_find_pressed)
	%LeaveButton.pressed.connect(_on_leave_pressed)

	# LobbyManager -> UI
	LobbyManager.lobby_entered.connect(_on_lobby_entered)
	LobbyManager.lobby_join_failed.connect(_on_lobby_join_failed)
	LobbyManager.lobby_list_updated.connect(_on_lobby_list_updated)
	LobbyManager.members_changed.connect(_update_member_list)


func _on_host_pressed() -> void:
	%StatusLabel.text = "Creating lobby..."
	LobbyManager.host_lobby()


func _on_find_pressed() -> void:
	%StatusLabel.text = "Searching for Hushfall lobbies..."
	LobbyManager.find_lobbies()


func _on_leave_pressed() -> void:
	LobbyManager.leave_lobby()
	%StatusLabel.text = "Left lobby. Steam OK — logged in as %s" % SteamManager.steam_username
	%LeaveButton.visible = false
	%HostButton.disabled = false
	%FindButton.disabled = false
	%MembersLabel.text = ""


func _on_lobby_entered() -> void:
	# In (or hosting) a lobby -> leave the menu and load the game world.
	# call_deferred: never yank the scene out from under a signal handler.
	%StatusLabel.text = "✅ In lobby %s — loading world..." % LobbyManager.lobby_id
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


func _on_lobby_join_failed(reason: String) -> void:
	%StatusLabel.text = "❌ " + reason


func _on_lobby_list_updated(lobbies: Array) -> void:
	_clear_lobby_buttons()
	if lobbies.is_empty():
		%StatusLabel.text = "No Hushfall lobbies found. (Is a host running and IN a lobby?)"
		return
	%StatusLabel.text = "Found %d lobby/lobbies — click one to join:" % lobbies.size()
	for lobby_info in lobbies:
		var join_button := Button.new()
		join_button.text = "%s  (%d inside)" % [lobby_info["name"], lobby_info["member_count"]]
		# .bind() bakes this lobby's id into the signal connection, so each
		# button joins its own lobby.
		join_button.pressed.connect(LobbyManager.join_lobby.bind(lobby_info["id"]))
		%LobbyList.add_child(join_button)


func _clear_lobby_buttons() -> void:
	for child in %LobbyList.get_children():
		child.queue_free()


func _update_member_list() -> void:
	var lines: PackedStringArray = ["Players in lobby (%d):" % LobbyManager.members.size()]
	for member in LobbyManager.members:
		lines.append("  • " + member["name"])
	%MembersLabel.text = "\n".join(lines)
