extends Node3D
## The shared game world (greybox: a floor and a sun for now).
##
## Spawning rule: ONLY the host creates and removes Player nodes. The
## MultiplayerSpawner node in this scene watches the Players container on the
## host and automatically mirrors every spawn/despawn to all clients — that's
## Godot's built-in way to keep "who exists in the world" in sync.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TerrainScript = preload("res://scripts/terrain.gd")
const MapAuditScript = preload("res://scripts/map_audit.gd")

# Containers whose direct children get snapped onto the terrain at boot.
const SNAP_CONTAINERS: Array[String] = [
	"Buildings", "PlazaRing", "MarketLanes", "WestVillage", "FieldPosts",
]
# Nodes that intentionally do NOT snap.
const SNAP_SKIP: Array[String] = ["LighthouseSpit"]  # rock IN the water
# Lane strips that keep authored transforms (tilted or on the spit deck).
const LANE_SNAP_SKIP: Array[String] = ["EastLaneUp", "EastLaneDown", "CausewayRamp", "Jetty"]


func _ready() -> void:
	# Angle the sun so the greybox has readable shadows.
	$Sun.rotation_degrees = Vector3(-50, 30, 0)

	_snap_structures_to_terrain()

	if GameConfig.map_audit:
		_run_map_audit()

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


# ------------------------------------------- terrain foundation snapping ----

## Ground height including built-up surfaces (the lighthouse spit deck).
func _ground_at(x: float, z: float) -> float:
	if x > 59.0 and x < 69.0 and z > 44.0 and z < 66.0:
		return 0.3  # lighthouse spit deck sits proud of the water
	return TerrainScript.height_at(x, z)


## Every structure's base is set EXACTLY onto the ground under it, and the
## result is printed as the foundation audit — proof regenerates every boot.
func _snap_structures_to_terrain() -> void:
	print("[FoundationAudit] --- building base-Y vs ground-Y (delta = drift fixed) ---")
	for container_name in SNAP_CONTAINERS:
		for node in get_node(container_name).get_children():
			if node.name in SNAP_SKIP:
				print("[FoundationAudit] %-16s SKIPPED (intentional: in water)" % node.name)
				continue
			_snap_node(node)
	# Lane strips are visual ground markings: they float 2cm above ground.
	for lane in $Lanes.get_children():
		if lane.name in LANE_SNAP_SKIP:
			continue
		lane.position.y = _ground_at(lane.position.x, lane.position.z) + 0.02
	# Plaza furniture sits on the flat core but snaps for completeness.
	_snap_node($Bonfire)


func _snap_node(body: Node3D) -> void:
	var ground := _ground_at(body.position.x, body.position.z)
	var bottom := _bottom_offset(body)
	var old_y := body.position.y
	body.position.y = ground - bottom
	print("[FoundationAudit] %-16s ground=%6.2f base=%6.2f (moved %+.2f)"
			% [body.name, ground, body.position.y + bottom, body.position.y - old_y])


## The flow audit needs physics ready for its raycasts — wait two frames.
func _run_map_audit() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	MapAuditScript.run(self)


## Lowest point of the node's collision shapes, in the node's local space.
## (Box roots are often centered; building scenes are based at y=0 — this
## handles both without per-node bookkeeping.)
func _bottom_offset(body: Node3D) -> float:
	var lowest: float = 1e9
	for child in body.get_children():
		if child is CollisionShape3D and child.shape != null:
			var half: float = 0.0
			if child.shape is BoxShape3D:
				half = child.shape.size.y / 2.0
			elif child.shape is CylinderShape3D:
				half = child.shape.height / 2.0
			else:
				continue
			lowest = minf(lowest, child.position.y - half)
	return lowest if lowest < 1e8 else 0.0
