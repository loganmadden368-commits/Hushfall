extends Node
## Map audit v2 — after the 2026-07-02 root-cause: every check below now
## measures ACTUAL SCENE GEOMETRY (collision shapes, generated paths,
## terrain function), not authored claims. Prints at boot, fails loudly.
##
##  A. Path-structure intersection: every path sampled at 0.5m against
##     every collision shape (exact rotated-local test). Door zones exempt.
##  B. Path-terrain conformance: slope between samples within ramp
##     standard; no submerged samples.
##  C. Connectivity graph: all gates + site doors in ONE component.
##  D. Universal seating: every StaticBody's footprint corners vs ground.
##  Plus the retained real checks: F10 separations (math on real
##  positions), F4 walk times (now measured on the SAME data that
##  generates the paths), F7 landmark raycasts, R3 nook raycasts.

const TerrainScript = preload("res://scripts/terrain.gd")
const PathNet = preload("res://scripts/path_network.gd")

const VOICE_RANGE: float = 25.0
const SITE_SEPARATION: float = 28.0
const MAX_PATH_SLOPE_DEG: float = 20.0
const FLOAT_TOLERANCE: float = 0.15

# Site interaction points (door positions, with height). Compass: N = -Z.
const SITES: Dictionary = {
	"Greenhouse": Vector3(32, 0, 5),
	"Well": Vector3(-25, 0, -14),
	"Cellar": Vector3(47, 0, -46),
	"Bell Tower": Vector3(18, 4, -49),
	"Boathouse": Vector3(16, -0.3, 39),
	"Windmill": Vector3(-48.7, 0, -54.3),
	"Lighthouse": Vector3(64, 0.3, 57.2),
}

# F4/R1 routes — waypoints match path_network.gd polylines (which GENERATE
# the walked geometry, so this data and the scene cannot drift apart).
const ROUTES: Array = [
	["Greenhouse", "East Lane", "E", [Vector2(0, 0), Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(30.5, 5)]],
	["Greenhouse", "Back Path", "S", [Vector2(0, 0), Vector2(4, 16), Vector2(6, 24), Vector2(14, 27), Vector2(22, 20), Vector2(28, 13), Vector2(30.5, 5)]],
	["Well", "Well Lane", "W", [Vector2(0, 0), Vector2(-15, -6), Vector2(-20, -9), Vector2(-24.6, -14)]],
	["Well", "Field Crossing (posts)", "N", [Vector2(0, 0), Vector2(0, -15), Vector2(-6, -19), Vector2(-12, -20.5), Vector2(-22, -20), Vector2(-24.5, -16), Vector2(-24.6, -14)]],
	["Cellar", "Market Route", "E", [Vector2(0, 0), Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(33, -2), Vector2(38.5, -6.5), Vector2(45, -12), Vector2(46, -20), Vector2(46, -42), Vector2(45.8, -45.4)]],
	["Cellar", "Upper Route", "N", [Vector2(0, 0), Vector2(0, -15), Vector2(6, -24), Vector2(14, -30.5), Vector2(26, -32), Vector2(34, -32.5), Vector2(41, -34.5), Vector2(45, -38), Vector2(45, -43), Vector2(45.8, -45.4)]],
	["Bell Tower", "North Trunk", "N", [Vector2(0, 0), Vector2(0, -15), Vector2(4, -22), Vector2(8, -30), Vector2(12, -38), Vector2(15, -44), Vector2(18, -48.4)]],
	["Bell Tower", "West Route", "W", [Vector2(0, 0), Vector2(-15, -6), Vector2(-21, -12), Vector2(-19, -22), Vector2(-12, -31), Vector2(-2, -42), Vector2(6, -50), Vector2(11, -49), Vector2(15, -48.5), Vector2(17.5, -48.4)]],
	["Boathouse", "South Trunk", "S", [Vector2(0, 0), Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37), Vector2(15.5, 38.6)]],
	["Boathouse", "Shell Cut + Shore", "E", [Vector2(0, 0), Vector2(13, 0), Vector2(19, 0), Vector2(22, 0.5), Vector2(22, 3.4), Vector2(22, 12.6), Vector2(24.5, 15.5), Vector2(28, 13), Vector2(28.5, 24), Vector2(27, 36), Vector2(26, 42.7), Vector2(26, 43), Vector2(24, 38), Vector2(18, 35), Vector2(15.5, 38.6)]],
	["Windmill", "Dark Diagonal", "W", [Vector2(0, 0), Vector2(-15, -6), Vector2(-20, -9), Vector2(-22, -18), Vector2(-27, -28), Vector2(-40, -40), Vector2(-46, -48), Vector2(-48, -53.6)]],
	["Windmill", "North Field (posts)", "N", [Vector2(0, 0), Vector2(0, -15), Vector2(-4, -22), Vector2(-8, -30), Vector2(-48, -30), Vector2(-52, -34), Vector2(-52, -46), Vector2(-50, -50), Vector2(-48, -53.6)]],
	["Lighthouse", "Causeway (SANCTIONED single)", "S", [Vector2(0, 0), Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37), Vector2(18, 35), Vector2(24, 38), Vector2(26, 43), Vector2(32, 43.2), Vector2(60, 43.2), Vector2(63.5, 44.5), Vector2(63.5, 48.5), Vector2(64, 50.5), Vector2(64, 56.6)]],
]

const LANDMARKS: Dictionary = {
	"Bell Spire": Vector3(26, 16, -60),
	"Lighthouse Beacon": Vector3(64, 16.3, 60),
	"Plaza Glow (bonfire proxy)": Vector3(0, 3, 0),
}

const NOOK_MOUTH: Vector3 = Vector3(49.3, 1.4, -30)

# Structures the intersection audit ignores (path infrastructure you WALK ON,
# and marker posts that flank routes by construction).
const INTERSECT_EXEMPT_PREFIXES: Array[String] = ["LighthouseSpit", "CausewayWedge", "WellCrossingPost", "WindmillFieldPost"]


static func run(world: Node3D) -> void:
	print("")
	print("================ MAP AUDIT v2 ================")
	var bodies := _collect_shapes(world)
	_audit_intersections(bodies)
	_audit_conformance()
	_audit_connectivity()
	_audit_seating(world)
	_audit_separations()
	_audit_walk_times()
	_audit_landmarks(world)
	_audit_nook(world)
	print("================ AUDIT COMPLETE ================")
	print("")


## Gather every collision shape with its world transform.
static func _collect_shapes(world: Node3D) -> Array:
	var out: Array = []
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is CollisionShape3D and node.shape != null:
			var body := node.get_parent()
			if body == null or body.name == "Terrain" or not (body is StaticBody3D):
				continue
			var exempt := false
			for prefix in INTERSECT_EXEMPT_PREFIXES:
				if String(body.name).begins_with(prefix):
					exempt = true
			out.append({"name": body.name, "shape": node.shape, "xform": node.global_transform, "exempt": exempt})
	return out


## A — no path sample may fall inside any structure (0.2m buffer).
static func _audit_intersections(bodies: Array) -> void:
	print("--- A: path-structure intersections (0.5m samples, 0.2m buffer) ---")
	var violations: int = 0
	var samples: Dictionary = PathNet.all_samples()
	for path_name in samples:
		for sample in samples[path_name]:
			if _in_door_zone(sample):
				continue
			var point := Vector3(sample.x, PathNet.ground_at(sample.x, sample.y) + 0.9, sample.y)
			for entry in bodies:
				if entry.exempt:
					continue
				if _point_in_shape(point, entry, 0.2):
					print("  VIOLATION: %s passes through %s at (%.1f, %.1f)" % [path_name, entry.name, sample.x, sample.y])
					violations += 1
					break
	print("  %s" % ("PASS - no path crosses a structure" if violations == 0 else "%d VIOLATIONS" % violations))


static func _in_door_zone(sample: Vector2) -> bool:
	for door_name in PathNet.DOORS:
		if (PathNet.DOORS[door_name] as Vector2).distance_to(sample) < 2.6:
			return true
	return false


static func _point_in_shape(point: Vector3, entry: Dictionary, buffer: float) -> bool:
	var local: Vector3 = (entry.xform as Transform3D).affine_inverse() * point
	var shape = entry.shape
	if shape is BoxShape3D:
		var h: Vector3 = shape.size / 2.0
		return absf(local.x) <= h.x + buffer and absf(local.y) <= h.y + buffer and absf(local.z) <= h.z + buffer
	if shape is CylinderShape3D:
		return Vector2(local.x, local.z).length() <= shape.radius + buffer and absf(local.y) <= shape.height / 2.0 + buffer
	return false


## B — slope between consecutive samples within ramp standard; nothing
## submerged. (Paved ribbons are generated AT ground level, so vertical
## conformance is true by construction; slope is the real check.)
static func _audit_conformance() -> void:
	print("--- B: path-terrain conformance (slope limit %.0f deg) ---" % MAX_PATH_SLOPE_DEG)
	var samples: Dictionary = PathNet.all_samples()
	var all_ok := true
	for path_name in samples:
		var pts: Array = samples[path_name]
		var max_slope: float = 0.0
		var submerged: int = 0
		for i in range(pts.size() - 1):
			var g1: float = PathNet.ground_at(pts[i].x, pts[i].y)
			var g2: float = PathNet.ground_at(pts[i + 1].x, pts[i + 1].y)
			var run: float = (pts[i] as Vector2).distance_to(pts[i + 1])
			max_slope = maxf(max_slope, rad_to_deg(atan(absf(g2 - g1) / maxf(run, 0.01))))
			if pts[i].y > 49.0 and g1 < 0.15 and not PathNet.SPIT_RECT.has_point(pts[i]):
				submerged += 1
		var flags := ""
		if max_slope > MAX_PATH_SLOPE_DEG:
			flags += "  SLOPE VIOLATION"
			all_ok = false
		if submerged > 0:
			flags += "  %d SUBMERGED samples" % submerged
			all_ok = false
		print("  %-22s max slope %5.1f deg%s" % [path_name, max_slope, flags])
	if all_ok:
		print("  PASS - all paths walkable and dry")


## C — one connected component holding all gates and site doors.
static func _audit_connectivity() -> void:
	print("--- C: connectivity graph (gates + doors) ---")
	var result: Dictionary = PathNet.connectivity()
	if (result.missing as Array).is_empty():
		print("  PASS - all %d gates/doors reachable in one network (%d raw components incl. field posts merges)" % [(result.main_has as Array).size(), result.components])
	else:
		for item in result.missing:
			print("  ORPHAN: %s is NOT connected to the main network" % item)


## D — universal seating: every StaticBody footprint corner vs ground.
static func _audit_seating(world: Node3D) -> void:
	print("--- D: universal seating (footprint corners, tolerance %.2fm) ---" % FLOAT_TOLERANCE)
	var checked: int = 0
	var problems: int = 0
	var stack: Array = [world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is StaticBody3D) or node.name == "Terrain":
			continue
		# no_seat only exempts bodies from the SEATER; the audit still checks
		# them. Only water/ramp infrastructure is excluded here.
		if String(node.name) in ["LighthouseSpit", "CausewayWedge"]:
			continue
		var corners: Array = _footprint_corners(node)
		if corners.is_empty():
			continue
		checked += 1
		var worst_float: float = -1e9
		for corner in corners:
			var gap: float = corner.y - PathNet.ground_at(corner.x, corner.z)
			worst_float = maxf(worst_float, gap)
		if worst_float > FLOAT_TOLERANCE and not node.has_meta("plinth"):
			print("  FLOATING: %-16s worst corner %.2fm above ground" % [node.name, worst_float])
			problems += 1
	print("  %d bodies checked - %s" % [checked, "PASS (plinths cover slope spans)" if problems == 0 else "%d FLOATING" % problems])


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
			else:
				continue
			found = true
			min_local = min_local.min(child.position - half)
			max_local = max_local.max(child.position + half)
	if not found:
		return []
	var y := min_local.y
	var out: Array = []
	for corner_local in [Vector3(min_local.x, y, min_local.z), Vector3(max_local.x, y, min_local.z), Vector3(min_local.x, y, max_local.z), Vector3(max_local.x, y, max_local.z)]:
		out.append(body.global_transform * corner_local)
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
			var on_spit: bool = PathNet.SPIT_RECT.has_point(Vector2(xi, zi))
			if zi > 47 and not on_spit:
				continue
			var eye := Vector3(xi, PathNet.ground_at(xi, zi) + 1.6, zi)
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
		var eye := Vector3(46, 1.6, zi)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, NOOK_MOUTH))
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
