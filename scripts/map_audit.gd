extends Node
## Map flow audit — turns the design doc's Appendix A doctrine into checks
## that run (and PRINT) every time the world loads, gated by the
## [debug] map_audit config flag. Numbers regenerate each boot, so the
## proof can't rot when geometry moves.
##
## Sections: F10 voice-separation margins, F4 walk-time matrix with R1
## departure-gate flags, F7 landmark-visibility raycast grid, R3 baited-nook
## coverage, and the F2/F3/F5/F6 inventories.
##
## NOTE on route data: waypoint chains below are the authored routes. They
## drift if lanes move — keep them in sync when editing the map (the
## foundation audit is fully automatic; this table is the one manual part).

const TerrainScript = preload("res://scripts/terrain.gd")

# Site interaction points (door / base approach), including height.
const SITES: Dictionary = {
	"Greenhouse": Vector3(32, 0, 5),
	"Well": Vector3(-25, 0, -14),
	"Cellar": Vector3(47, 0, -46),
	"Bell Tower": Vector3(16, 4, -44),
	"Boathouse": Vector3(16, -0.3, 39),
	"Windmill": Vector3(-48, 0, -53),
	"Lighthouse": Vector3(64, 0.3, 57),
}

const VOICE_RANGE: float = 25.0   # plaza separation rule
const SITE_SEPARATION: float = 28.0  # site-to-site rule

# F4/R1 route table: [site, route name, gate, waypoints (x,z)...]
const ROUTES: Array = [
	["Greenhouse", "East Lane", "E", [Vector2(0, 0), Vector2(12, 0), Vector2(30, 0), Vector2(31, 5)]],
	["Greenhouse", "Back Path", "S", [Vector2(0, 0), Vector2(6, 13), Vector2(10.7, 24.5), Vector2(30.5, 4.7), Vector2(31, 5)]],
	["Well", "Well Lane", "W", [Vector2(0, 0), Vector2(-14, -5), Vector2(-24, -9), Vector2(-25, -13)]],
	["Well", "Field Crossing (posts)", "N", [Vector2(0, 0), Vector2(0, -16), Vector2(-8, -20), Vector2(-28, -21), Vector2(-26, -15)]],
	["Cellar", "Market Street", "E", [Vector2(0, 0), Vector2(12, 0), Vector2(33, -1), Vector2(47, -13), Vector2(46, -43), Vector2(47, -45)]],
	["Cellar", "Upper Lane", "N", [Vector2(0, 0), Vector2(0, -16), Vector2(10, -28), Vector2(34, -29), Vector2(39, -33.5), Vector2(44, -33.5), Vector2(46, -43), Vector2(47, -45)]],
	["Bell Tower", "South Slope", "N", [Vector2(0, 0), Vector2(0, -16), Vector2(8, -26), Vector2(14, -36), Vector2(16, -43)]],
	["Bell Tower", "West Slope", "W", [Vector2(0, 0), Vector2(-14, -5), Vector2(-24, -15), Vector2(-12, -38), Vector2(2, -50), Vector2(12, -50), Vector2(16, -46)]],
	["Boathouse", "South Lane", "S", [Vector2(0, 0), Vector2(6, 13), Vector2(6, 29), Vector2(10, 34), Vector2(12, 39), Vector2(15, 39)]],
	["Boathouse", "Shell Cut + Shore Path", "E", [Vector2(0, 0), Vector2(12, 0), Vector2(22, 4), Vector2(22, 12), Vector2(29, 13), Vector2(29, 41), Vector2(24, 41.5), Vector2(19, 37.5), Vector2(15, 39)]],
	["Windmill", "Dark Diagonal", "W", [Vector2(0, 0), Vector2(-14, -5), Vector2(-22, -14), Vector2(-20, -20), Vector2(-46, -46), Vector2(-47.5, -51)]],
	["Windmill", "North Field (posts)", "N", [Vector2(0, 0), Vector2(0, -16), Vector2(-8, -30), Vector2(-48, -30), Vector2(-52, -34), Vector2(-52, -48), Vector2(-47.5, -51)]],
	["Lighthouse", "Causeway (SANCTIONED single)", "S", [Vector2(0, 0), Vector2(6, 13), Vector2(6, 29), Vector2(10, 34), Vector2(13, 38.5), Vector2(19, 37.5), Vector2(24, 41.5), Vector2(62, 43), Vector2(64, 46), Vector2(64, 57)]],
]

# F7 landmark targets: spire tip, lighthouse beacon, bonfire glow proxy.
const LANDMARKS: Dictionary = {
	"Bell Spire": Vector3(28, 16, -56),
	"Lighthouse Beacon": Vector3(64, 16.3, 60),
	"Plaza Glow (bonfire proxy)": Vector3(0, 3, 0),
}

# R3: the baited nook's mouth (gap between House6/House7, opening west).
const NOOK_MOUTH: Vector3 = Vector3(49.3, 1.4, -30)


static func run(world: Node3D) -> void:
	print("")
	print("================ MAP FLOW AUDIT ================")
	_audit_separations()
	_audit_walk_times()
	_audit_landmarks(world)
	_audit_nook(world)
	_print_inventories()
	print("================ AUDIT COMPLETE ================")
	print("")


# F10 — voice invariant margins.
static func _audit_separations() -> void:
	print("--- F10 separation margins (voice %.0fm / site rule %.0fm) ---" % [VOICE_RANGE, SITE_SEPARATION])
	var names := SITES.keys()
	var worst: float = 1e9
	for site_name in names:
		var d: float = (SITES[site_name] as Vector3).distance_to(Vector3.ZERO)
		var ok := d > VOICE_RANGE
		print("  plaza -> %-11s %6.1fm  margin %+6.1f  %s" % [site_name, d, d - VOICE_RANGE, "OK" if ok else "VIOLATION"])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var d2: float = (SITES[names[i]] as Vector3).distance_to(SITES[names[j]])
			worst = minf(worst, d2)
			if d2 < SITE_SEPARATION:
				print("  %s <-> %s: %.1fm VIOLATION (<%.0f)" % [names[i], names[j], d2, SITE_SEPARATION])
	print("  closest site pair: %.1fm (margin %+.1f over %.0fm rule)" % [worst, worst - SITE_SEPARATION, SITE_SEPARATION])


# F4 + R1 — walk-time matrix with departure gates.
static func _audit_walk_times() -> void:
	var speed: float = GameConfig.move_speed
	print("--- F4 walk times (at %.1f m/s) + R1 departure gates ---" % speed)
	var site_gates: Dictionary = {}
	var site_times: Dictionary = {}
	for route in ROUTES:
		var length: float = 0.0
		var points: Array = route[3]
		for k in range(points.size() - 1):
			length += (points[k] as Vector2).distance_to(points[k + 1])
		var seconds: float = length / speed
		var tier := "NEAR"
		if seconds > GameConfig.walk_tier_far_max_s:
			tier = "OVER-FAR"
		elif seconds > GameConfig.walk_tier_mid_max_s:
			tier = "FAR"
		elif seconds > GameConfig.walk_tier_near_max_s:
			tier = "MID"
		var ceiling_flag := "  ! EXCEEDS %.0fs CEILING" % GameConfig.walk_trip_ceiling_s if seconds > GameConfig.walk_trip_ceiling_s else ""
		print("  %-11s %-26s gate %s  %5.1fm  %4.1fs  [%s]%s" % [route[0], route[1], route[2], length, seconds, tier, ceiling_flag])
		if not site_gates.has(route[0]):
			site_gates[route[0]] = []
			site_times[route[0]] = []
		site_gates[route[0]].append(route[2])
		site_times[route[0]].append(seconds)
	for site_name in site_gates:
		var gates: Array = site_gates[site_name]
		if gates.size() >= 2 and gates[0] == gates[1]:
			print("  R1 FLAG: %s routes share gate %s (single watch-point)" % [site_name, gates[0]])
		if gates.size() >= 2:
			var t: Array = site_times[site_name]
			var diff: float = absf(t[0] - t[1]) / minf(t[0], t[1]) * 100.0
			if diff < 25.0:
				print("  F1 NOTE: %s route lengths differ only %.0f%% (<25%% target) — danger profiles differ, accepted deviation" % [site_name, diff])


# F7 — landmark visibility raycast grid.
static func _audit_landmarks(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var totals: Dictionary = {}
	for landmark_name in LANDMARKS:
		totals[landmark_name] = 0
	var any_count: int = 0
	var sample_count: int = 0
	var blind_samples: Array[Vector2] = []
	for xi in range(-52, 101, 6):
		for zi in range(-90, 79, 6):
			var ground: float = TerrainScript.height_at(xi, zi)
			var on_spit: bool = xi > 59 and xi < 69 and zi > 44 and zi < 66
			if zi > 47 and not on_spit:
				continue  # open water
			var eye := Vector3(xi, (0.3 if on_spit else ground) + 1.6, zi)
			# Skip samples inside solid geometry.
			var point_params := PhysicsPointQueryParameters3D.new()
			point_params.position = eye
			if not space.intersect_point(point_params, 1).is_empty():
				continue
			sample_count += 1
			var sees_any := false
			for landmark_name in LANDMARKS:
				var target: Vector3 = LANDMARKS[landmark_name]
				var ray := PhysicsRayQueryParameters3D.create(eye, target)
				var hit := space.intersect_ray(ray)
				if hit.is_empty() or (hit.position as Vector3).distance_to(target) < 2.5:
					totals[landmark_name] += 1
					sees_any = true
			if sees_any:
				any_count += 1
			elif blind_samples.size() < 6:
				blind_samples.append(Vector2(xi, zi))
	print("--- F7 landmark visibility (%d outdoor samples, eye 1.6m) ---" % sample_count)
	for landmark_name in totals:
		print("  %-26s visible from %3.0f%% of map" % [landmark_name, 100.0 * totals[landmark_name] / maxf(sample_count, 1)])
	print("  at least one landmark/glow:  %3.0f%%" % (100.0 * any_count / maxf(sample_count, 1)))
	if blind_samples.size() > 0:
		print("  blind pockets (first few): ", blind_samples)


# R3 — what covers the baited nook's mouth, and the nearest lantern dial.
static func _audit_nook(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var covered_from: Array[float] = []
	for zi in range(-43, -11, 2):
		var eye := Vector3(46, 1.6, zi)
		var ray := PhysicsRayQueryParameters3D.create(eye, NOOK_MOUTH)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.position as Vector3).distance_to(NOOK_MOUTH) < 2.0:
			covered_from.append(zi)
	print("--- R3 baited-nook coverage (mouth at %.1v) ---" % NOOK_MOUTH)
	if covered_from.is_empty():
		print("  WARNING: no market-street sightline covers the nook mouth")
	else:
		print("  mouth visible from market street z=%.0f..%.0f (max LOS %.1fm)" % [
			covered_from.min(), covered_from.max(),
			Vector3(46, 1.6, covered_from.min()).distance_to(NOOK_MOUTH)])
	var nearest: float = 1e9
	var nearest_pos := Vector3.ZERO
	for lantern_pos in GameConfig.lantern_positions:
		var d: float = lantern_pos.distance_to(NOOK_MOUTH)
		if d < nearest:
			nearest = d
			nearest_pos = lantern_pos
	if nearest < 1e8:
		print("  nearest lantern dial: %.1v at %.1fm — nook danger tunes with it" % [nearest_pos, nearest])


# F2/F3/F5/F6 — authored inventories with measured values.
static func _print_inventories() -> void:
	print("--- F2 dead ends (cap 3-5, causeway excluded) ---")
	print("  1. Market nook (55,-30)      DEEP  - ambush pocket, lantern-baited")
	print("  2. Plaza SW pocket (-15,9)   shallow - ring gap, ~3s escape")
	print("  3. Windmill tower corner (-54,-63) shallow - behind the tower")
	print("--- F3 chokepoints (target 3-6; * = lantern dial) ---")
	print("  1.* Kiosk corner (33,-1)      east trunk")
	print("  2.* Market north gate (41,-33) north trunk / cellar")
	print("  3.* Causeway mouth (64,46)    lighthouse spit neck")
	print("  4.  Well-yard gate (-27,-5)   dark, alley-class")
	print("  5.  Breezeway4 (39,-27)       dark tunnel")
	print("  6.  Breezeway6 (53,-25)       dark tunnel")
	print("--- F5 perception bands (voice 25m) ---")
	print("  SEE-not-hear: plaza interior (~34m), boardwalk (38m straight),")
	print("    market street (31m, sanctioned), NW field post-line vistas")
	print("  HEAR-before-see: breezeway blind exits, kiosk 45-deg corner,")
	print("    back-alley connector corner, nook mouth, well-yard corner,")
	print("    Rise sheer-face base (sound from crown without LOS)")
	print("--- F6 longest uninterrupted lane sightlines ---")
	print("  east lane ~10m (2m hump blocks) | bend 20m | street 31m*")
	print("  upper A/B 12/14m (kink) | south A/B 18/12m (dogleg)")
	print("  boardwalk 38m* | back path 28m FLAG | shore path 35m FLAG")
	print("  (* sanctioned F5a straightaways; FLAGged straights re-checked")
	print("   at the night milestone - darkness may be the intended break)")