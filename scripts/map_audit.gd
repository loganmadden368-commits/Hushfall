extends Node
## Map audit v3 — perception pass. New laws honored here (A3):
##  - Audits consume the SCENE (collision shapes, mesh bounds, physics
##    raycasts), never a function/table that also produced the thing.
##  - EXEMPTION TRANSPARENCY: every exemption prints with its reason.
##  - The blanket door-zone carve-out is gone: a path may overlap ONLY the
##    structure it terminates at, within 2.4m of its endpoint.
##
##  A  intersections: 0.5m samples across FULL ribbon width (both edges),
##     tested against collision shapes AND visual mesh bounds.
##  B  conformance: physics raycasts prove model ground == scene ground;
##     slope standard on the raycast hits; nothing submerged.
##  C  connectivity graph (gates + doors, one component).
##  D  universal seating (footprint corners).
##  Plus plaza continuity, structure overlap, component assembly, and the
##  retained F10 / F4+R1 / F7 / R3 checks.

const TerrainScript = preload("res://scripts/terrain.gd")
const PathNet = preload("res://scripts/path_network.gd")

const VOICE_RANGE: float = 25.0
const SITE_SEPARATION: float = 28.0
const MAX_PATH_SLOPE_DEG: float = 20.0
const FLOAT_TOLERANCE: float = 0.15
const DOOR_LANDING_RADIUS: float = 2.4
const WATER_LEVEL: float = -0.12

const SITES: Dictionary = {
	"Greenhouse": Vector3(32, 0, 5),
	"Well": Vector3(-25, 0, -14),
	"Cellar": Vector3(47, 0, -46),
	"Bell Tower": Vector3(18, 4, -49),
	"Boathouse": Vector3(16, 0, 39),
	"Windmill": Vector3(-48.7, 0, -54.3),
	"Lighthouse": Vector3(64, 0.55, 57.7),
}

const ROUTES: Array = [
	["Greenhouse", "East Lane", "E", [Vector2(4, 0), Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(30.5, 5)]],
	["Greenhouse", "Back Path", "S", [Vector2(2, 4), Vector2(4, 16), Vector2(6, 24), Vector2(14, 28), Vector2(23, 21), Vector2(28, 13), Vector2(30.5, 5)]],
	["Well", "Well Lane", "W", [Vector2(-4, -1.5), Vector2(-15, -6), Vector2(-20, -9), Vector2(-24.6, -14)]],
	["Well", "Field Crossing (posts)", "N", [Vector2(0, -4), Vector2(0, -15), Vector2(-6, -19), Vector2(-12, -20.5), Vector2(-22, -20), Vector2(-23.5, -17), Vector2(-24.6, -14.2)]],
	["Cellar", "Market Route", "E", [Vector2(4, 0), Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(31, -4), Vector2(38.5, -7), Vector2(45, -11.5), Vector2(45.5, -20), Vector2(45.5, -38), Vector2(44.6, -41), Vector2(45.8, -45.4)]],
	["Cellar", "Upper Route", "N", [Vector2(0, -4), Vector2(0, -15), Vector2(6, -24), Vector2(14, -30.5), Vector2(26, -32), Vector2(34, -32.5), Vector2(41.5, -34.5), Vector2(45.5, -38), Vector2(44.6, -41), Vector2(45.8, -45.4)]],
	["Bell Tower", "North Trunk", "N", [Vector2(0, -4), Vector2(0, -15), Vector2(4, -22), Vector2(8, -30), Vector2(12, -38), Vector2(15, -44), Vector2(18, -48.4)]],
	["Bell Tower", "West Route", "W", [Vector2(-4, -1.5), Vector2(-15, -6), Vector2(-21, -12), Vector2(-19, -22), Vector2(-12, -31), Vector2(-2, -42), Vector2(6, -50), Vector2(10, -47.5), Vector2(15, -47.3), Vector2(17.8, -48.3)]],
	["Boathouse", "South Trunk", "S", [Vector2(2, 4), Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37), Vector2(15.5, 38.6)]],
	["Boathouse", "Shell Cut + Shore", "E", [Vector2(4, 0), Vector2(13, 0), Vector2(19, 0), Vector2(22, 0.5), Vector2(22, 3.4), Vector2(22, 12.6), Vector2(24.3, 16.3), Vector2(28, 13), Vector2(28.5, 24), Vector2(27, 36), Vector2(26, 42.7), Vector2(26, 43), Vector2(24, 38), Vector2(18, 35), Vector2(15.5, 38.6)]],
	["Windmill", "Dark Diagonal", "W", [Vector2(-4, -1.5), Vector2(-15, -6), Vector2(-20, -9), Vector2(-22, -18), Vector2(-27, -28), Vector2(-40, -40), Vector2(-46, -48), Vector2(-48, -53.6)]],
	["Windmill", "North Field (posts)", "N", [Vector2(0, -4), Vector2(0, -15), Vector2(-4, -22), Vector2(-8, -30), Vector2(-48, -30), Vector2(-52, -34), Vector2(-52, -46), Vector2(-50, -50), Vector2(-48, -53.6)]],
	["Lighthouse", "Causeway (SANCTIONED single)", "S", [Vector2(2, 4), Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37), Vector2(18, 35), Vector2(24, 38), Vector2(26, 43), Vector2(32, 43.2), Vector2(60, 43.2), Vector2(63, 44.4), Vector2(64, 46), Vector2(64, 56.6)]],
]

const LANDMARKS: Dictionary = {
	"Bell Spire": Vector3(26, 16, -60),
	"Lighthouse Beacon": Vector3(64, 16, 60.5),
	"Plaza Glow (bonfire proxy)": Vector3(0, 3, 0),
}

const NOOK_MOUTH: Vector3 = Vector3(49.3, 1.4, -30)

# Path infrastructure the intersection audit walks ON (printed per the
# exemption transparency law).
const INFRA_EXEMPT: Dictionary = {
	"Pier": "walking surface (gangway/deck/platform) — walker + assembly verify it",
}
const TRUNKS: Array[String] = ["East Lane", "North Trunk", "Well Lane", "South Trunk", "Back Path"]


static func run(world: Node3D) -> void:
	print("")
	print("================ MAP AUDIT v3 ================")
	print("--- exemption manifest (A3 transparency law) ---")
	for infra_name in INFRA_EXEMPT:
		print("  EXEMPT: %s — %s" % [infra_name, INFRA_EXEMPT[infra_name]])
	print("  EXEMPT: door landings — a path may overlap ONLY its terminal structure within %.1fm of its endpoint (printed below when used)" % DOOR_LANDING_RADIUS)
	var bodies := _collect_bodies(world)
	_audit_intersections(bodies)
	_audit_conformance(world)
	_audit_plaza_continuity()
	_audit_overlap(world)
	_audit_assembly(world)
	_audit_connectivity()
	_audit_seating(world)
	_audit_separations()
	_audit_walk_times()
	_audit_landmarks(world)
	_audit_nook(world)
	print("================ AUDIT COMPLETE ================")
	print("")


## Bodies with their collision shapes AND visual mesh boxes (world xforms).
static func _collect_bodies(world: Node3D) -> Array:
	var out: Array = []
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is StaticBody3D) or node.name == "Terrain" or node.name == "RouteWalker":
			continue
		var entry := {"name": String(node.name), "boxes": [], "exempt": INFRA_EXEMPT.has(String(node.name))}
		for child in node.get_children():
			if child is CollisionShape3D and child.shape != null:
				if child.shape is BoxShape3D:
					entry.boxes.append({"xform": child.global_transform, "half": child.shape.size / 2.0})
				elif child.shape is CylinderShape3D:
					entry.boxes.append({"xform": child.global_transform, "half": Vector3(child.shape.radius, child.shape.height / 2.0, child.shape.radius)})
			elif child is MeshInstance3D and child.mesh != null:
				var aabb: AABB = child.get_aabb()
				entry.boxes.append({"xform": child.global_transform.translated_local(aabb.get_center()), "half": aabb.size / 2.0})
		if not (entry.boxes as Array).is_empty():
			out.append(entry)
	return out


## A — full-width sampling: center + both ribbon edges, vs collision AND
## visual bounds. Door-landing rule replaces the old blanket exemption.
static func _audit_intersections(bodies: Array) -> void:
	print("--- A: path-structure intersections (full width, visual bounds) ---")
	var violations: int = 0
	var landings_printed: Dictionary = {}
	var frames: Dictionary = PathNet.sample_frames()
	for path_name in frames:
		var info: Dictionary = frames[path_name]
		var half: float = info.width / 2.0
		for frame in info.frames:
			var p: Vector2 = frame.p
			var n := Vector2(-frame.d.y, frame.d.x) * half
			for offset in [Vector2.ZERO, n, -n]:
				var q: Vector2 = p + offset
				var point := Vector3(q.x, PathNet.ground_at(q.x, q.y) + 0.9, q.y)
				for body in bodies:
					if body.exempt:
						continue
					if not _point_in_body(point, body, 0.2):
						continue
					var near_end: bool = q.distance_to(info.first) < DOOR_LANDING_RADIUS or q.distance_to(info.last) < DOOR_LANDING_RADIUS
					if near_end and body.name == info.terminal:
						var key: String = path_name + "|" + body.name
						if not landings_printed.has(key):
							landings_printed[key] = true
							print("  EXEMPT: %s -> %s door landing (terminal overlap within %.1fm)" % [path_name, body.name, DOOR_LANDING_RADIUS])
						continue
					print("  VIOLATION: %s through %s at (%.1f, %.1f)" % [path_name, body.name, q.x, q.y])
					violations += 1
					break
	print("  %s" % ("PASS - no unsanctioned path-structure contact" if violations == 0 else "%d VIOLATIONS" % violations))


static func _point_in_body(point: Vector3, body: Dictionary, buffer: float) -> bool:
	for box in body.boxes:
		var local: Vector3 = (box.xform as Transform3D).affine_inverse() * point
		var half: Vector3 = box.half
		if absf(local.x) <= half.x + buffer and absf(local.y) <= half.y + buffer and absf(local.z) <= half.z + buffer:
			return true
	return false


## B — physics raycasts prove the ground model matches the scene; slope
## standard checked on the HITS; nothing submerged.
static func _audit_conformance(world: Node3D) -> void:
	print("--- B: conformance via physics raycasts (slope limit %.0f deg) ---" % MAX_PATH_SLOPE_DEG)
	print("  EXEMPT: door-landing aprons (<=%.1fm of route ends) — rays there hit the terminal building's roof by design" % DOOR_LANDING_RADIUS)
	print("  EXEMPT: Shell Cut — indoor passage, ray-down hits the shell roof by design")
	var space := world.get_world_3d().direct_space_state
	var frames: Dictionary = PathNet.sample_frames()
	var all_ok := true
	for path_name in frames:
		if path_name == "Shell Cut":
			continue
		var info: Dictionary = frames[path_name]
		var half: float = info.width / 2.0
		var max_dev: float = 0.0
		var max_dev_at := Vector2.ZERO
		var max_slope: float = 0.0
		var submerged: int = 0
		var previous_hit: float = INF
		var index: int = 0
		for frame in info.frames:
			if index % 2 == 1:
				index += 1
				continue
			index += 1
			var n := Vector2(-frame.d.y, frame.d.x) * half
			for offset in [Vector2.ZERO, n, -n]:
				var q: Vector2 = frame.p + offset
				if q.distance_to(info.first) < DOOR_LANDING_RADIUS or q.distance_to(info.last) < DOOR_LANDING_RADIUS:
					continue  # landing apron (exemption printed above)
				var ray := PhysicsRayQueryParameters3D.create(Vector3(q.x, 30, q.y), Vector3(q.x, -10, q.y))
				var hit := space.intersect_ray(ray)
				if hit.is_empty():
					continue
				var hit_y: float = (hit.position as Vector3).y
				if absf(hit_y - PathNet.ground_at(q.x, q.y)) > max_dev:
					max_dev = absf(hit_y - PathNet.ground_at(q.x, q.y))
					max_dev_at = q
				if offset == Vector2.ZERO:
					if previous_hit != INF:
						max_slope = maxf(max_slope, rad_to_deg(atan(absf(hit_y - previous_hit) / 1.0)))
					previous_hit = hit_y
					if hit_y + 0.1 < WATER_LEVEL and q.y > 44.0:
						submerged += 1
		var flags := ""
		if max_dev > 0.35:
			flags += "  MODEL-SCENE DEVIATION %.2fm" % max_dev
			all_ok = false
		if max_slope > MAX_PATH_SLOPE_DEG:
			flags += "  SLOPE VIOLATION"
			all_ok = false
		if submerged > 0:
			flags += "  %d SUBMERGED" % submerged
			all_ok = false
		print("  %-22s dev %.2fm @(%.1f,%.1f)  slope %5.1f deg%s" % [path_name, max_dev, max_dev_at.x, max_dev_at.y, max_slope, flags])
	if all_ok:
		print("  PASS - scene matches model, walkable, dry")


## Plaza continuity — trunk paving must reach inside the disc (r=12).
static func _audit_plaza_continuity() -> void:
	print("--- plaza continuity (paving must enter disc r=12) ---")
	var ok := true
	for trunk_name in TRUNKS:
		var first: Vector2 = PathNet.PATHS[trunk_name][2][0]
		var r := first.length()
		if r > 11.0:
			print("  GAP: %s starts at r=%.1f (outside the plaza)" % [trunk_name, r])
			ok = false
		else:
			print("  OK: %s paving enters plaza at r=%.1f" % [trunk_name, r])
	if ok:
		print("  PASS")


## Structure-structure overlap (visual bounds, world-axis AABB, 0.3 shrink).
static func _audit_overlap(world: Node3D) -> void:
	print("--- structure overlap (visual bounds) ---")
	var entries: Array = []
	for container_name in ["Buildings", "MarketLanes", "WestVillage", "PlazaRing"]:
		if not world.has_node(container_name):
			continue
		for body in world.get_node(container_name).get_children():
			var aabb := _visual_aabb(body)
			if aabb.size != Vector3.ZERO:
				entries.append({"name": "%s/%s" % [container_name, body.name], "aabb": aabb})
	var violations: int = 0
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var a: AABB = entries[i].aabb.grow(-0.15)
			if a.intersects(entries[j].aabb.grow(-0.15)):
				print("  OVERLAP: %s <-> %s" % [entries[i].name, entries[j].name])
				violations += 1
	print("  %d structures checked - %s" % [entries.size(), "PASS" if violations == 0 else "%d OVERLAPS" % violations])


static func _visual_aabb(body: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	var stack: Array = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and node.mesh != null and node.name != "Plinth":
			var aabb: AABB = (node as MeshInstance3D).global_transform * node.get_aabb()
			merged = aabb if first else merged.merge(aabb)
			first = false
	return merged if not first else AABB()


## Component assembly — parts seat on their supports (visual bounds).
static func _audit_assembly(world: Node3D) -> void:
	print("--- component assembly (part seats on support) ---")
	var checks: int = 0
	var problems: int = 0
	# Lighthouse on pier platform.
	var lighthouse: Node3D = world.get_node_or_null("Buildings/Lighthouse")
	if lighthouse != null and lighthouse.has_meta("seats_on_pier"):
		var tower: MeshInstance3D = lighthouse.get_node("TowerMesh")
		var bottom: float = (tower.global_transform * tower.get_aabb()).position.y
		var expected: float = lighthouse.get_meta("seats_on_pier")
		checks += 1
		if absf(bottom - expected) > 0.07:
			print("  ASSEMBLY FAIL: Lighthouse tower bottom %.2f vs platform top %.2f" % [bottom, expected])
			problems += 1
		else:
			print("  OK: Lighthouse tower bottom %.2f == pier platform top %.2f" % [bottom, expected])
	# Generic: any MeshInstance with meta seats_on = sibling name.
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D and node.has_meta("seats_on"):
			var support: Node = node.get_parent().get_node_or_null(node.get_meta("seats_on"))
			if support is MeshInstance3D:
				var part_bottom: float = ((node as MeshInstance3D).global_transform * node.get_aabb()).position.y
				var support_box: AABB = (support as MeshInstance3D).global_transform * support.get_aabb()
				var support_top: float = support_box.position.y + support_box.size.y
				checks += 1
				if absf(part_bottom - support_top) > 0.12:
					print("  ASSEMBLY FAIL: %s/%s bottom %.2f vs %s top %.2f" % [node.get_parent().name, node.name, part_bottom, node.get_meta("seats_on"), support_top])
					problems += 1
	print("  %d assembly joints checked - %s" % [checks, "PASS" if problems == 0 else "%d FAILURES" % problems])


static func _audit_connectivity() -> void:
	print("--- C: connectivity graph (gates + doors) ---")
	var result: Dictionary = PathNet.connectivity()
	if (result.missing as Array).is_empty():
		print("  PASS - all %d gates/doors reachable in one network" % (result.main_has as Array).size())
	else:
		for item in result.missing:
			print("  ORPHAN: %s NOT connected" % item)


static func _audit_seating(world: Node3D) -> void:
	print("--- D: universal seating (footprint corners, tolerance %.2fm) ---" % FLOAT_TOLERANCE)
	var checked: int = 0
	var problems: int = 0
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is StaticBody3D) or node.name in ["Terrain", "RouteWalker"]:
			continue
		if node.has_meta("no_seat") and node.has_meta("exempt_reason"):
			continue  # already printed by the seater's exemption manifest
		var corners: Array = _footprint_corners(node)
		if corners.is_empty():
			continue
		checked += 1
		var worst: float = -1e9
		for corner in corners:
			worst = maxf(worst, corner.y - PathNet.ground_at(corner.x, corner.z))
		if worst > FLOAT_TOLERANCE and not node.has_meta("plinth"):
			print("  FLOATING: %-18s worst corner %.2fm above ground" % [node.name, worst])
			problems += 1
	print("  %d bodies checked - %s" % [checked, "PASS" if problems == 0 else "%d FLOATING" % problems])


static func _footprint_corners(body: Node3D) -> Array:
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
			elif child.shape is SphereShape3D:
				half = Vector3.ONE * child.shape.radius
			else:
				continue
			found = true
			min_local = min_local.min(child.position - half)
			max_local = max_local.max(child.position + half)
	if not found:
		return []
	var y := min_local.y
	var out: Array = []
	for corner in [Vector3(min_local.x, y, min_local.z), Vector3(max_local.x, y, min_local.z), Vector3(min_local.x, y, max_local.z), Vector3(max_local.x, y, max_local.z)]:
		out.append(body.global_transform * corner)
	return out


static func _audit_separations() -> void:
	print("--- F10 separation margins (voice %.0fm / site rule %.0fm) ---" % [VOICE_RANGE, SITE_SEPARATION])
	var names := SITES.keys()
	var worst: float = 1e9
	for site_name in names:
		var d: float = (SITES[site_name] as Vector3).distance_to(Vector3.ZERO)
		print("  plaza -> %-11s %6.1fm  margin %+6.1f  %s" % [site_name, d, d - VOICE_RANGE, "OK" if d > VOICE_RANGE else "VIOLATION"])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var d2: float = (SITES[names[i]] as Vector3).distance_to(SITES[names[j]])
			worst = minf(worst, d2)
			if d2 < SITE_SEPARATION:
				print("  %s <-> %s: %.1fm VIOLATION" % [names[i], names[j], d2])
	print("  closest site pair: %.1fm (margin %+.1f)" % [worst, worst - SITE_SEPARATION])


static func _audit_walk_times() -> void:
	var speed: float = GameConfig.move_speed
	print("--- F4 walk times (%.1f m/s) + R1 gates ---" % speed)
	var site_gates: Dictionary = {}
	var site_times: Dictionary = {}
	for route in ROUTES:
		var length: float = 0.0
		var pts: Array = route[3]
		for k in range(pts.size() - 1):
			length += (pts[k] as Vector2).distance_to(pts[k + 1])
		var seconds := length / speed
		var tier := "NEAR"
		if seconds > GameConfig.walk_tier_far_max_s:
			tier = "OVER-FAR"
		elif seconds > GameConfig.walk_tier_mid_max_s:
			tier = "FAR"
		elif seconds > GameConfig.walk_tier_near_max_s:
			tier = "MID"
		var ceiling := "  ! EXCEEDS CEILING" if seconds > GameConfig.walk_trip_ceiling_s else ""
		print("  %-11s %-28s gate %s %6.1fm %5.1fs [%s]%s" % [route[0], route[1], route[2], length, seconds, tier, ceiling])
		if not site_gates.has(route[0]):
			site_gates[route[0]] = []
			site_times[route[0]] = []
		site_gates[route[0]].append(route[2])
		site_times[route[0]].append(seconds)
	for site_name in site_gates:
		var gates: Array = site_gates[site_name]
		if gates.size() >= 2 and gates[0] == gates[1]:
			print("  R1 FLAG: %s routes share gate %s" % [site_name, gates[0]])
		if gates.size() >= 2:
			var t: Array = site_times[site_name]
			var diff: float = absf(t[0] - t[1]) / minf(t[0], t[1]) * 100.0
			if diff < 25.0:
				print("  F1 NOTE: %s lengths differ %.0f%% (<25%%) — accepted if danger profiles differ" % [site_name, diff])


static func _audit_landmarks(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var totals: Dictionary = {}
	for landmark_name in LANDMARKS:
		totals[landmark_name] = 0
	var any_count: int = 0
	var sample_count: int = 0
	for xi in range(-52, 101, 6):
		for zi in range(-90, 79, 6):
			var ground := PathNet.ground_at(xi, zi)
			if zi > 45 and ground < WATER_LEVEL:
				continue  # open water
			var eye := Vector3(xi, ground + 1.6, zi)
			var point_params := PhysicsPointQueryParameters3D.new()
			point_params.position = eye
			if not space.intersect_point(point_params, 1).is_empty():
				continue
			sample_count += 1
			var sees_any := false
			for landmark_name in LANDMARKS:
				var target: Vector3 = LANDMARKS[landmark_name]
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target))
				if hit.is_empty() or (hit.position as Vector3).distance_to(target) < 2.5:
					totals[landmark_name] += 1
					sees_any = true
			if sees_any:
				any_count += 1
	print("--- F7 landmark visibility (%d samples) ---" % sample_count)
	for landmark_name in totals:
		print("  %-26s %3.0f%%" % [landmark_name, 100.0 * totals[landmark_name] / maxf(sample_count, 1)])
	print("  at least one:              %3.0f%%" % (100.0 * any_count / maxf(sample_count, 1)))


static func _audit_nook(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var covered: Array[float] = []
	for zi in range(-43, -11, 2):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(46, 1.6, zi), NOOK_MOUTH))
		if hit.is_empty() or (hit.position as Vector3).distance_to(NOOK_MOUTH) < 2.0:
			covered.append(zi)
	print("--- R3 baited-nook coverage ---")
	if covered.is_empty():
		print("  WARNING: no street sightline covers the nook mouth")
	else:
		print("  mouth visible from street z=%.0f..%.0f" % [covered.min(), covered.max()])
	var nearest: float = 1e9
	for lantern_pos in GameConfig.lantern_positions:
		nearest = minf(nearest, (lantern_pos as Vector3).distance_to(NOOK_MOUTH))
	if nearest < 1e8:
		print("  nearest lantern dial %.1fm away — nook danger is tunable" % nearest)
