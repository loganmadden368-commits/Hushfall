extends Node3D
## The shared game world (greybox: a floor and a sun for now).
##
## Spawning rule: ONLY the host creates and removes Player nodes. The
## MultiplayerSpawner node in this scene watches the Players container on the
## host and automatically mirrors every spawn/despawn to all clients — that's
## Godot's built-in way to keep "who exists in the world" in sync.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TerrainScript = preload("res://scripts/terrain.gd")
const PathNetScript = preload("res://scripts/path_network.gd")
const MapAuditScript = preload("res://scripts/map_audit.gd")
const PlazaDressingScript = preload("res://scripts/plaza_dressing.gd")
const VillageDressingScript = preload("res://scripts/village_dressing.gd")
const PierBuilderScript = preload("res://scripts/pier_builder.gd")
const RouteWalkerScript = preload("res://scripts/route_walker.gd")
const ScreenshotTourScript = preload("res://scripts/screenshot_tour.gd")

const WATER_SHADER := "
shader_type spatial;
uniform vec3 deep_color : source_color = vec3(0.07, 0.12, 0.2);
uniform vec3 crest_color : source_color = vec3(0.16, 0.24, 0.34);
void vertex() {
	VERTEX.y += sin(VERTEX.x * 0.35 + TIME * 0.8) * 0.05
			+ cos(VERTEX.z * 0.3 + TIME * 0.6) * 0.05;
}
void fragment() {
	float band = sin(UV.x * 90.0 + TIME * 0.15) * sin(UV.y * 70.0 - TIME * 0.12);
	ALBEDO = mix(deep_color, crest_color, smoothstep(0.72, 0.95, band));
	ROUGHNESS = 0.3;
	SPECULAR = 0.4;
}"

# Bodies that intentionally do not seat on terrain.
const SEAT_SKIP: Array[String] = ["LighthouseSpit"]  # rock IN the water


func _ready() -> void:
	# Angle the sun so the greybox has readable shadows.
	$Sun.rotation_degrees = Vector3(-50, 30, 0)

	# Paths are GENERATED from path_network.gd data — the same data the
	# audits measure, so walked geometry and audited geometry cannot drift.
	PathNetScript.build($Lanes)
	PierBuilderScript.build(self)
	VillageDressingScript.build(self)
	_build_water()

	_seat_all_structures()

	# Style-guide beauty corner (Part 3A) — plaza only until approved.
	PlazaDressingScript.build(self)

	# Perception machinery modes (A3): feet and eyes.
	var user_args := OS.get_cmdline_user_args()
	if "--walk-routes" in user_args:
		await RouteWalkerScript.run_all(self)
		get_tree().quit()
		return
	if "--screenshot-tour" in user_args:
		await ScreenshotTourScript.run(self)
		get_tree().quit()
		return
	if "--fps-probe" in user_args:
		# Honest frame-rate sample: let the counter warm up for ~4s first.
		for i in 240:
			await get_tree().process_frame
		print("[FpsProbe] %.0f FPS after warmup (vsync may cap at refresh rate)" % Engine.get_frames_per_second())
		get_tree().quit()
		return

	if GameConfig.map_audit:
		_run_map_audit()


## Animated night water (S2). HONESTY (3E): sine-bob vertex waves + a
## scrolling band shader — Phase 9 replaces this with real water (foam,
## fresnel, reflections).
func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 160)
	plane.subdivide_width = 96
	plane.subdivide_depth = 48
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material = material
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.position = Vector3(25, -0.12, 124)
	add_child(water)

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


# --------------------------------------------- universal terrain seating ----

## Root-cause fix (2026-07-02): the old snapper sampled ONE point (the node
## origin), so footprints straddling slopes floated at their corners while
## reporting 0.00. Seating is now footprint-aware and UNIVERSAL (every
## StaticBody in the world, present and future): the base is set to the
## HIGHEST ground under any footprint corner, and where the ground varies
## a stone plinth is generated to fill the downhill gap.
func _seat_all_structures() -> void:
	print("[Seating] --- footprint-aware seating (universal) ---")
	var stack: Array = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is StaticBody3D and node.name != "Terrain":
			# Exemption transparency law (A3): every skip prints its reason.
			if node.has_meta("no_seat"):
				var reason: String = node.get_meta("exempt_reason", "self-seated on ground_at at creation")
				print("[Seating] EXEMPT: %s — %s" % [node.name, reason])
				continue
			if node.name in SEAT_SKIP:
				print("[Seating] EXEMPT: %s — intentionally in water" % node.name)
				continue
			_seat_body(node)


func _seat_body(body: Node3D) -> void:
	var bounds := _collision_bounds(body)
	if bounds.is_empty():
		return
	var min_local: Vector3 = bounds[0]
	var max_local: Vector3 = bounds[1]
	var grounds: Array[float] = []
	for corner_local in [
			Vector3(min_local.x, min_local.y, min_local.z),
			Vector3(max_local.x, min_local.y, min_local.z),
			Vector3(min_local.x, min_local.y, max_local.z),
			Vector3(max_local.x, min_local.y, max_local.z)]:
		var world_corner: Vector3 = body.global_transform * corner_local
		grounds.append(PathNetScript.ground_at(world_corner.x, world_corner.z))
	var highest: float = grounds.max()
	var spread: float = highest - grounds.min()
	# Seat the base on the highest corner ground (never floats uphill).
	var base_world: float = (body.global_transform * min_local).y
	body.position.y += highest - base_world
	# Fill the downhill gap with a plinth so no corner hangs in air.
	if spread > 0.08:
		var plinth := MeshInstance3D.new()
		plinth.name = "Plinth"
		var box := BoxMesh.new()
		box.size = Vector3(max_local.x - min_local.x, spread + 0.35, max_local.z - min_local.z)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.42, 0.41, 0.38)
		box.material = material
		plinth.mesh = box
		plinth.position = Vector3(
			(min_local.x + max_local.x) / 2.0,
			min_local.y + 0.05 - box.size.y / 2.0,
			(min_local.z + max_local.z) / 2.0)
		body.add_child(plinth)
		body.set_meta("plinth", true)
	print("[Seating] %-18s base -> %6.2f (ground spread %.2f%s)"
			% [body.name, highest, spread, ", plinth added" if spread > 0.08 else ""])


func _collision_bounds(body: Node3D) -> Array:
	var min_local := Vector3(1e9, 1e9, 1e9)
	var max_local := Vector3(-1e9, -1e9, -1e9)
	var found := false
	for child in body.get_children():
		if child is CollisionShape3D and child.shape != null:
			var half := Vector3.ZERO
			if child.shape is BoxShape3D:
				half = child.shape.size / 2.0
			elif child.shape is CylinderShape3D:
				half = Vector3(child.shape.radius, child.shape.height / 2.0, child.shape.radius)
			else:
				continue
			found = true
			min_local = min_local.min(child.position - half)
			max_local = max_local.max(child.position + half)
	return [min_local, max_local] if found else []


## The flow audit needs physics ready for its raycasts — wait two frames.
func _run_map_audit() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	MapAuditScript.run(self)
