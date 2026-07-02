extends Node3D
## The shared game world (greybox: a floor and a sun for now).
##
## Spawning rule: ONLY the host creates and removes Player nodes. The
## MultiplayerSpawner node in this scene watches the Players container on the
## host and automatically mirrors every spawn/despawn to all clients — that's
## Godot's built-in way to keep "who exists in the world" in sync.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")


func _ready() -> void:
	# Angle the sun so the greybox has readable shadows.
	$Sun.rotation_degrees = Vector3(-50, 30, 0)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		# Spawn the host's own avatar, plus anyone already connected
		# (players who joined the lobby while we were still in the menu).
		_spawn_player(multiplayer.get_unique_id())
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		var player := $Players.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()  # spawner mirrors the removal to clients too


func _spawn_player(peer_id: int) -> void:
	if $Players.has_node(str(peer_id)):
		return  # already spawned

	var player := PLAYER_SCENE.instantiate()
	# The name IS the ownership system — player.gd reads it to decide whose
	# input drives this capsule. Must be set before add_child().
	player.name = str(peer_id)

	# Stand new arrivals in a circle so they don't spawn inside each other.
	var angle: float = $Players.get_child_count() * (TAU / 12.0)
	player.position = Vector3(cos(angle) * 3.0, 1.0, sin(angle) * 3.0)

	$Players.add_child(player)
	print("[World] Spawned avatar for peer ", peer_id)
