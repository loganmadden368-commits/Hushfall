extends RefCounted
## Route walker (perception machinery 1B) — a physics-simulated capsule
## that traverses every route with the player's ACTUAL movement code
## (shared player_movement.gd module + identical capsule), asserting it
## reaches each destination without getting stuck, falling through, or
## leaving the path. Per A3: traversal claims count only with this log.
##
## Trigger: launch with `-- --walk-routes` (works headless — no rendering
## needed for physics).

const PlayerMovement = preload("res://scripts/player_movement.gd")
const MapAuditScript = preload("res://scripts/map_audit.gd")
const PathNet = preload("res://scripts/path_network.gd")

const REACH_DISTANCE: float = 0.9
const STUCK_SECONDS: float = 3.0
const OFF_PATH_LIMIT: float = 4.0
const FALL_Y: float = -6.0

# Walker-only sequences for path geometry not covered by the site routes.
const EXTRA_WALKS: Array = [
	["Back Alley loop", [Vector2(33, -2), Vector2(34, -3.5), Vector2(32.8, -10), Vector2(32.8, -27), Vector2(34, -31.8)]],
	["Market Connector", [Vector2(32.8, -21.3), Vector2(40, -21.3), Vector2(45.5, -20.5)]],
]


static func run_all(world: Node3D) -> void:
	print("")
	print("=============== ROUTE WALKER (player-identical physics) ===============")
	Engine.time_scale = 8.0
	var passed: int = 0
	var failed: int = 0
	var walks: Array = []
	for route in MapAuditScript.ROUTES:
		walks.append(["%s / %s" % [route[0], route[1]], route[3]])
	walks.append_array(EXTRA_WALKS)
	for walk in walks:
		var result: Dictionary = await _walk(world, walk[1])
		if result.ok:
			passed += 1
			print("  PASS  %-42s %5.1fm in %4.1fs (sim)" % [walk[0], result.dist, result.time])
		else:
			failed += 1
			print("  FAIL  %-42s %s at (%.1f, %.1f, %.1f)" % [walk[0], result.reason, result.at.x, result.at.y, result.at.z])
	Engine.time_scale = 1.0
	print("=============== WALKER: %d PASS / %d FAIL ===============" % [passed, failed])
	print("")


static func _walk(world: Node3D, points: Array) -> Dictionary:
	var body := CharacterBody3D.new()
	body.name = "RouteWalker"
	body.add_child(PlayerMovement.make_capsule())
	world.add_child(body)
	var start: Vector2 = points[0]
	body.global_position = Vector3(start.x, PathNet.ground_at(start.x, start.y) + 1.2, start.y)

	var target_index: int = 1
	var travelled: float = 0.0
	var sim_time: float = 0.0
	var stuck_timer: float = 0.0
	var last_position: Vector3 = body.global_position
	var result := {"ok": false, "reason": "", "at": Vector3.ZERO, "dist": 0.0, "time": 0.0}

	while target_index < points.size():
		await world.get_tree().physics_frame
		var delta: float = world.get_physics_process_delta_time()
		sim_time += delta
		var target: Vector2 = points[target_index]
		var flat_pos := Vector2(body.global_position.x, body.global_position.z)
		var wish := Vector3(target.x - flat_pos.x, 0, target.y - flat_pos.y)
		PlayerMovement.step(body, wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, delta)

		var moved: float = body.global_position.distance_to(last_position)
		travelled += moved
		stuck_timer = stuck_timer + delta if moved < 0.02 else 0.0
		last_position = body.global_position

		if body.global_position.y < FALL_Y:
			result.reason = "FELL THROUGH"
			break
		if stuck_timer > STUCK_SECONDS:
			result.reason = "STUCK"
			break
		if sim_time > 180.0:
			result.reason = "TIMEOUT"
			break
		var segment_a: Vector2 = points[target_index - 1]
		var off: float = Geometry2D.get_closest_point_to_segment(flat_pos, segment_a, target).distance_to(flat_pos)
		if off > OFF_PATH_LIMIT:
			result.reason = "LEFT PATH (%.1fm off)" % off
			break
		if flat_pos.distance_to(target) < REACH_DISTANCE:
			target_index += 1

	result.at = body.global_position
	result.dist = travelled
	result.time = sim_time
	result.ok = target_index >= points.size()
	body.queue_free()
	return result
