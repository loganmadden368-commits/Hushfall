extends RefCounted
## The path network — SINGLE SOURCE OF TRUTH for every route.
## Compass: north = -Z, east = +X.
##
## v3 (perception pass): ground_at() now returns the RENDERED terrain
## mesh height (terrain.mesh_height_at), not the smooth analytic function
## — the gap between those two was why paths sank into slopes. Trunk
## paths extend INSIDE the plaza disc (r=12) so paving physically reaches
## the square. Field routes get worn strips + post-and-rail fencing so
## they read as routes, not scattered sticks. The causeway is now a
## wooden gangway+pier built by pier_builder.gd.

const TerrainScript = preload("res://scripts/terrain.gd")

const GATES: Dictionary = {
	"Gate E": Vector2(13, 0),
	"Gate N": Vector2(0, -15),
	"Gate W": Vector2(-15, -6),
	"Gate S": Vector2(4, 16),
}

const DOORS: Dictionary = {
	"Greenhouse": Vector2(30.5, 5),
	"Well": Vector2(-24.6, -14),
	"Cellar": Vector2(45.8, -45.4),
	"Bell Tower": Vector2(18, -48.4),
	"Boathouse": Vector2(15.5, 38.6),
	"Windmill": Vector2(-48, -53.6),
	"Lighthouse": Vector2(64, 56.6),
	"Shell1 N": Vector2(22, 3.4),
	"Shell1 S": Vector2(22, 12.6),
}

# name: [width, terminal structure node name (or ""), [points...]]
# Trunks begin at radius 10 — INSIDE the plaza disc — per plaza continuity.
const PATHS: Dictionary = {
	"East Lane": [3.5, "Greenhouse", [Vector2(10, 0), Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(30.5, 5)]],
	"Market Route": [3.5, "", [Vector2(29, 2), Vector2(31, -4), Vector2(38.5, -7), Vector2(45, -11.5), Vector2(45.5, -20), Vector2(45.5, -38)]],
	"Cellar Approach": [2.5, "MushroomCellar", [Vector2(45.5, -38), Vector2(44.6, -41), Vector2(45.8, -45.4)]],
	"Back Path": [2.5, "Greenhouse", [Vector2(2.4, 9.7), Vector2(4, 16), Vector2(6, 24), Vector2(14, 28), Vector2(23, 21), Vector2(28, 13), Vector2(30.5, 5)]],
	"Shell Cut": [2.0, "Shell1", [Vector2(22, 0.5), Vector2(22, 3.4), Vector2(22, 12.6), Vector2(24.3, 16.3)]],
	"Shore Path": [2.5, "", [Vector2(28, 13), Vector2(28.5, 24), Vector2(27, 36), Vector2(26, 42.7)]],
	"Well Lane": [3.5, "Well", [Vector2(-9.3, -3.7), Vector2(-15, -6), Vector2(-20, -9), Vector2(-24.6, -14)]],
	"Windmill Diagonal": [2.5, "Windmill", [Vector2(-20, -9), Vector2(-22, -18), Vector2(-27, -28), Vector2(-40, -40), Vector2(-46, -48), Vector2(-48, -53.6)]],
	"North Trunk": [3.5, "BellTower", [Vector2(0, -10), Vector2(0, -15), Vector2(4, -22), Vector2(8, -30), Vector2(12, -38), Vector2(15, -44), Vector2(18, -48.4)]],
	"Bell West Route": [2.5, "BellTower", [Vector2(-15, -6), Vector2(-21, -12), Vector2(-19, -22), Vector2(-12, -31), Vector2(-2, -42), Vector2(6, -50), Vector2(10, -47.5), Vector2(15, -47.3), Vector2(17.8, -48.3)]],
	"Cellar Upper Route": [2.5, "", [Vector2(0, -15), Vector2(6, -24), Vector2(14, -30.5), Vector2(26, -32), Vector2(34, -32.5), Vector2(41.5, -34.5), Vector2(45.5, -38)]],
	"South Trunk": [3.5, "", [Vector2(2.4, 9.7), Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37)]],
	"Boathouse Approach": [2.0, "Boathouse", [Vector2(12, 37), Vector2(15.5, 38.6)]],
	"Waterfront": [2.5, "Lighthouse", [Vector2(12, 37), Vector2(18, 35), Vector2(24, 38), Vector2(26, 43), Vector2(32, 43.2), Vector2(60, 43.2), Vector2(63, 44.4), Vector2(64, 46), Vector2(64, 56.6)]],
	"Back Alley": [2.0, "", [Vector2(34, -3.5), Vector2(32.8, -10), Vector2(32.8, -27), Vector2(33.5, -31.5)]],
	"Market Connector": [1.6, "", [Vector2(32.8, -21.7), Vector2(42.8, -21.7), Vector2(45.5, -20.5)]],
}

# Unpaved-but-WORN field routes (R2): narrow worn strip + fence line.
const FIELD_ROUTES: Dictionary = {
	"Well Crossing": [Vector2(0, -15), Vector2(-6, -19), Vector2(-12, -20.5), Vector2(-22, -20), Vector2(-23.5, -17), Vector2(-24.6, -14.2)],
	"Windmill Field": [Vector2(0, -15), Vector2(-4, -22), Vector2(-8, -30), Vector2(-48, -30), Vector2(-52, -34), Vector2(-52, -46), Vector2(-50, -50), Vector2(-48, -53.6)],
}

# Pier walking surfaces (built by pier_builder.gd from these SAME numbers;
# the capsule walker + assembly audit verify the physical result).
const GANGWAY_RECT := Rect2(62.5, 46.0, 3.0, 6.0)   # shore ramp up
const DECK_RECT := Rect2(62.5, 52.0, 3.0, 12.5)     # deck run south
const PLATFORM_RECT := Rect2(60.5, 57.0, 7.0, 7.0)  # lighthouse platform
const DECK_TOP: float = 0.55


static func ground_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if PLATFORM_RECT.has_point(p) or DECK_RECT.has_point(p):
		return DECK_TOP
	if GANGWAY_RECT.has_point(p):
		var t: float = clampf((z - GANGWAY_RECT.position.y) / GANGWAY_RECT.size.y, 0.0, 1.0)
		return lerpf(TerrainScript.mesh_height_at(x, GANGWAY_RECT.position.y - 0.3), DECK_TOP, t)
	return TerrainScript.mesh_height_at(x, z)


## Generate ribbons, worn field strips, fences, and marker posts.
static func build(lanes: Node3D) -> void:
	for child in lanes.get_children():
		child.queue_free()

	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color("8A7355")
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var worn_material := StandardMaterial3D.new()
	worn_material.albedo_color = Color("6E5F49")
	worn_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for path_name in PATHS:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = path_name.replace(" ", "")
		mesh_instance.mesh = _ribbon_mesh(PATHS[path_name][2], PATHS[path_name][0])
		mesh_instance.material_override = path_material
		lanes.add_child(mesh_instance)

	# Worn strips make field routes legible as ROUTES (W1).
	for route_name in FIELD_ROUTES:
		var strip := MeshInstance3D.new()
		strip.name = route_name.replace(" ", "") + "Worn"
		strip.mesh = _ribbon_mesh(FIELD_ROUTES[route_name], 1.6)
		strip.material_override = worn_material
		lanes.add_child(strip)
		_build_fence(lanes, route_name, FIELD_ROUTES[route_name])


## Post-and-rail fence along ONE side of a field route (offset 1.5m).
static func _build_fence(lanes: Node3D, route_name: String, points: Array) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7A5C3E")
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 1.1, 0.22)
	post_mesh.material = wood
	var post_shape := BoxShape3D.new()
	post_shape.size = post_mesh.size
	var fence_points: Array = []  # Vector3 or null (gap at route crossings)
	var samples := _resample(points, 5.0, 4.0)
	for i in samples.size():
		var here: Vector2 = samples[i]
		var ahead: Vector2 = samples[mini(i + 1, samples.size() - 1)]
		var back: Vector2 = samples[maxi(i - 1, 0)]
		var dir := (ahead - back).normalized()
		var offset := Vector2(-dir.y, dir.x) * 1.5
		var p := here + offset
		# Gap the fence wherever any path/route crosses (gateway effect).
		fence_points.append(null if _near_any_route(p, route_name) else Vector3(p.x, ground_at(p.x, p.y), p.y))
	for i in fence_points.size():
		if fence_points[i] == null:
			continue
		var post := StaticBody3D.new()
		post.name = "%sFence%d" % [route_name.replace(" ", ""), i]
		post.set_meta("no_seat", true)
		var mi := MeshInstance3D.new()
		mi.mesh = post_mesh
		mi.position = Vector3(0, 0.55, 0)
		var cs := CollisionShape3D.new()
		cs.shape = post_shape
		cs.position = mi.position
		post.add_child(mi)
		post.add_child(cs)
		post.position = fence_points[i]
		lanes.add_child(post)
		if i > 0 and fence_points[i - 1] != null:
			var a: Vector3 = fence_points[i - 1] + Vector3(0, 0.85, 0)
			var b: Vector3 = fence_points[i] + Vector3(0, 0.85, 0)
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.1, 0.12, a.distance_to(b))
			rail_mesh.material = wood
			rail.mesh = rail_mesh
			rail.position = (a + b) / 2.0
			rail.look_at_from_position(rail.position, b, Vector3.UP)
			lanes.add_child(rail)


## True when a point sits within 4m of any path or other field route —
## fence posts skip these spots so fences never block a walkable line.
static func _near_any_route(p: Vector2, own_route: String) -> bool:
	for path_name in PATHS:
		var pts: Array = PATHS[path_name][2]
		for k in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p) < 4.0:
				return true
	for route_name in FIELD_ROUTES:
		if route_name == own_route:
			continue
		var pts: Array = FIELD_ROUTES[route_name]
		for k in range(pts.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1]).distance_to(p) < 4.0:
				return true
	return false


## Terrain-conformant ribbon draped on the RENDERED mesh + 0.10m.
static func _ribbon_mesh(points: Array, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width / 2.0
	var samples: Array[Vector2] = _resample(points, 0.75, 0.0)
	for i in range(samples.size() - 1):
		var a: Vector2 = samples[i]
		var b: Vector2 = samples[i + 1]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * half
		var al := Vector3(a.x + n.x, ground_at(a.x + n.x, a.y + n.y) + 0.1, a.y + n.y)
		var ar := Vector3(a.x - n.x, ground_at(a.x - n.x, a.y - n.y) + 0.1, a.y - n.y)
		var bl := Vector3(b.x + n.x, ground_at(b.x + n.x, b.y + n.y) + 0.1, b.y + n.y)
		var br := Vector3(b.x - n.x, ground_at(b.x - n.x, b.y - n.y) + 0.1, b.y - n.y)
		surface.add_vertex(al)
		surface.add_vertex(bl)
		surface.add_vertex(br)
		surface.add_vertex(al)
		surface.add_vertex(br)
		surface.add_vertex(ar)
	surface.generate_normals()
	return surface.commit()


static func _resample(points: Array, step: float, margin: float) -> Array[Vector2]:
	var total: float = 0.0
	for i in range(points.size() - 1):
		total += (points[i] as Vector2).distance_to(points[i + 1])
	var out: Array[Vector2] = []
	var travelled: float = margin
	while travelled <= total - margin:
		out.append(_point_at(points, travelled))
		travelled += step
	if margin == 0.0:
		out.append(points[points.size() - 1])
	return out


static func _point_at(points: Array, distance: float) -> Vector2:
	var remaining := distance
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg := a.distance_to(b)
		if remaining <= seg:
			return a.lerp(b, remaining / maxf(seg, 0.001))
		remaining -= seg
	return points[points.size() - 1]


## Audit frames: { name: {width, terminal, end, frames: [{p, d}] } } at
## <=0.5m spacing — paved and field routes alike.
static func sample_frames() -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = {}
	for path_name in PATHS:
		all[path_name] = {"width": PATHS[path_name][0], "terminal": PATHS[path_name][1], "pts": PATHS[path_name][2]}
	for route_name in FIELD_ROUTES:
		all[route_name] = {"width": 1.6, "terminal": "Well" if route_name == "Well Crossing" else "Windmill", "pts": FIELD_ROUTES[route_name]}
	for name in all:
		var pts: Array = all[name].pts
		var samples := _resample(pts, 0.5, 0.0)
		var frames: Array = []
		for i in samples.size():
			var ahead: Vector2 = samples[mini(i + 1, samples.size() - 1)]
			var back: Vector2 = samples[maxi(i - 1, 0)]
			frames.append({"p": samples[i], "d": (ahead - back).normalized()})
		out[name] = {"width": all[name].width, "terminal": all[name].terminal,
				"first": pts[0], "last": pts[pts.size() - 1], "frames": frames}
	return out


## Connectivity graph (unchanged from v2, still real: built on the same
## polylines that generate the walked ribbons).
static func connectivity() -> Dictionary:
	var polylines: Dictionary = {}
	for path_name in PATHS:
		polylines[path_name] = PATHS[path_name][2]
	for route_name in FIELD_ROUTES:
		polylines[route_name] = FIELD_ROUTES[route_name]

	var ids: Array = []
	var owner_path: Array = []
	var offsets: Dictionary = {}
	for path_name in polylines:
		offsets[path_name] = ids.size()
		for p in polylines[path_name]:
			ids.append(p)
			owner_path.append(path_name)

	var parent: Array[int] = []
	for i in ids.size():
		parent.append(i)
	for path_name in polylines:
		var base: int = offsets[path_name]
		for i in range(polylines[path_name].size() - 1):
			_union(parent, base + i, base + i + 1)
	const TOLERANCE := 1.6
	for i in ids.size():
		for path_name in polylines:
			if owner_path[i] == path_name:
				continue
			var pts: Array = polylines[path_name]
			var base: int = offsets[path_name]
			for k in range(pts.size() - 1):
				if Geometry2D.get_closest_point_to_segment(ids[i], pts[k], pts[k + 1]).distance_to(ids[i]) <= TOLERANCE:
					_union(parent, i, base + k)
					break

	var gate_e_root := -1
	for i in ids.size():
		if ids[i].distance_to(GATES["Gate E"]) < 0.6:
			gate_e_root = _find(parent, i)
			break
	var roots: Dictionary = {}
	for i in ids.size():
		roots[_find(parent, i)] = true
	var main_has: Array = []
	var missing: Array = []
	var targets: Dictionary = {}
	targets.merge(GATES)
	targets.merge(DOORS)
	for target_name in targets:
		var found := false
		for i in ids.size():
			if ids[i].distance_to(targets[target_name]) <= 1.6 and _find(parent, i) == gate_e_root:
				found = true
				break
		if found:
			main_has.append(target_name)
		else:
			missing.append(target_name)
	return {"components": roots.size(), "main_has": main_has, "missing": missing}


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: Array[int], a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)
