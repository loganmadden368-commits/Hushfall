extends Node
## LobbyManager — autoload that handles hosting and joining Steam lobbies,
## and wires Steam's relay networking into Godot's multiplayer system.
##
## How the pieces fit together:
##  - A Steam LOBBY is just a meeting point: a list of players + some metadata,
##    hosted on Valve's servers. It carries no game traffic itself.
##  - The actual game connection is SteamMultiplayerPeer: the host opens a
##    "listen socket" on Steam's network, joiners connect to the host's
##    Steam ID, and Valve relays the traffic (no port forwarding, no IPs).
##  - Once `multiplayer.multiplayer_peer` is set, Godot's normal high-level
##    multiplayer (RPCs, MultiplayerSpawner, MultiplayerSynchronizer) works
##    over Steam. That's what Milestones 3-4 build on.
##
## Flow when HOSTING:  host_lobby() -> Steam makes the lobby ->
##   _on_lobby_created() -> tag the lobby + open the host socket.
## Flow when JOINING:  find_lobbies()/join_lobby() -> Steam puts us in the
##   lobby -> _on_lobby_joined() -> connect to the lobby owner's Steam ID.

# Every Hushfall dev lobby is tagged with this key/value. Since App ID 480
# (Spacewar) is shared by thousands of devs worldwide, this tag is how we
# find OUR lobbies and nobody else's when searching.
const LOBBY_KEY: String = "game"
const LOBBY_VALUE: String = "hushfall_dev"

## Emitted with an Array of { id, name, member_count } after a lobby search.
signal lobby_list_updated(lobbies: Array)
## Emitted when we're in a lobby and networking is up (host or client).
signal lobby_entered
## Emitted when creating/joining fails, with a human-readable reason.
signal lobby_join_failed(reason: String)
## Emitted whenever the lobby's member list changes.
signal members_changed

var lobby_id: int = 0            # 0 = not in a lobby
var is_host: bool = false
var members: Array[Dictionary] = []  # each: { "steam_id": int, "name": String }


func _ready() -> void:
	# Steam signals (these only fire because SteamManager pumps run_callbacks).
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.join_requested.connect(_on_join_requested)

	# Godot multiplayer signals — prove the actual game connection works.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# ---------------------------------------------------------------- hosting ---

func host_lobby() -> void:
	if lobby_id != 0:
		return  # already in a lobby
	print("[LobbyManager] Creating lobby...")
	# PUBLIC so our lobby browser can find it without being Steam friends.
	# (Random Spacewar users could theoretically see it too — harmless in dev;
	# we'll switch to friends-only + invites when we have a real App ID.)
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, GameConfig.max_players)


func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != Steam.RESULT_OK:
		lobby_join_failed.emit("Lobby creation failed (Steam result %s)" % result)
		return

	lobby_id = new_lobby_id
	is_host = true

	# Tag the lobby so find_lobbies() on other clients can filter for it.
	Steam.setLobbyData(lobby_id, LOBBY_KEY, LOBBY_VALUE)
	Steam.setLobbyData(lobby_id, "name", "%s's lobby" % SteamManager.steam_username)

	# Open the host side of the game connection over Steam's network.
	# The 0 is a "virtual port" — like a port number but inside Steam's
	# network. Host and clients just need to use the same one.
	var peer := SteamMultiplayerPeer.new()
	var error := peer.create_host(0)
	if error != OK:
		lobby_join_failed.emit("create_host failed (error %s)" % error)
		return
	multiplayer.multiplayer_peer = peer

	print("[LobbyManager] Hosting lobby ", lobby_id)
	_refresh_members()
	lobby_entered.emit()


# ---------------------------------------------------------------- joining ---

## Search Steam for open Hushfall dev lobbies. Results arrive async in
## _on_lobby_match_list and are emitted via lobby_list_updated.
func find_lobbies() -> void:
	Steam.addRequestLobbyListStringFilter(LOBBY_KEY, LOBBY_VALUE, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()


func _on_lobby_match_list(found_lobbies: Array) -> void:
	var results: Array = []
	for found_id in found_lobbies:
		results.append({
			"id": found_id,
			"name": Steam.getLobbyData(found_id, "name"),
			"member_count": Steam.getNumLobbyMembers(found_id),
		})
	print("[LobbyManager] Lobby search found %d lobby/lobbies" % results.size())
	lobby_list_updated.emit(results)


func join_lobby(target_lobby_id: int) -> void:
	print("[LobbyManager] Joining lobby ", target_lobby_id, "...")
	Steam.joinLobby(target_lobby_id)


## Fires when we accept an invite (or click "Join game" on a friend) in the
## Steam client while the game is running — the second way into a lobby.
func _on_join_requested(target_lobby_id: int, friend_id: int) -> void:
	print("[LobbyManager] Steam invite accepted (from %s)" % Steam.getFriendPersonaName(friend_id))
	join_lobby(target_lobby_id)


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_join_failed.emit("Couldn't enter lobby (response %s)" % response)
		return

	# The host also gets this callback for its own lobby — networking is
	# already set up in _on_lobby_created, so nothing more to do.
	if is_host:
		return

	lobby_id = joined_lobby_id

	# Connect the game connection to whoever owns the lobby (the host),
	# using their Steam ID — no IP addresses anywhere.
	var host_steam_id: int = Steam.getLobbyOwner(joined_lobby_id)
	var peer := SteamMultiplayerPeer.new()
	var error := peer.create_client(host_steam_id, 0)  # same virtual port as host
	if error != OK:
		lobby_join_failed.emit("create_client failed (error %s)" % error)
		return
	multiplayer.multiplayer_peer = peer

	print("[LobbyManager] Joined lobby ", lobby_id, " — connecting to host...")
	_refresh_members()
	lobby_entered.emit()


# ---------------------------------------------------------------- leaving ---

func leave_lobby() -> void:
	if lobby_id == 0:
		return
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	is_host = false
	members.clear()
	multiplayer.multiplayer_peer = null  # tears down the game connection
	print("[LobbyManager] Left lobby.")


# ---------------------------------------------------------- member list -----

## Someone joined/left/disconnected from the lobby.
## chat_state tells us what happened (1 = entered, 2 = left, etc.) — for now
## we just rebuild the whole member list either way.
func _on_lobby_chat_update(_which_lobby: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	var who: String = Steam.getFriendPersonaName(changed_id)
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("[LobbyManager] %s joined the lobby" % who)
	else:
		print("[LobbyManager] %s left the lobby" % who)
	_refresh_members()


func _refresh_members() -> void:
	members.clear()
	for i in Steam.getNumLobbyMembers(lobby_id):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		members.append({
			"steam_id": member_steam_id,
			"name": Steam.getFriendPersonaName(member_steam_id),
		})
	members_changed.emit()


# ------------------------------------------------- godot multiplayer log ----

# These two firing is the REAL success signal for Milestone 2: it means the
# game connection over Steam's relay is up, not just the lobby listing.
func _on_peer_connected(peer_peer_id: int) -> void:
	print("[LobbyManager] ✅ Game connection UP with peer ", peer_peer_id)


func _on_peer_disconnected(peer_peer_id: int) -> void:
	print("[LobbyManager] Game connection lost with peer ", peer_peer_id)
