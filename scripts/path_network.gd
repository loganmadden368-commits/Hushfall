extends RefCounted
## The path network — SINGLE SOURCE OF TRUTH for every route in the village.
##
## Root-cause lesson (2026-07-02): the old flow audit validated hand-typed
## route data while the scene held separately hand-placed strips; the two
## drifted and a site shipped with no path at all. Now the strips are
## GENERATED from this data, so the audited network and the walked network
## are the same object by construction.
##
## Compass: north = -Z, east = +X.
##
## - PAVED paths become terrain-conformant ribbon meshes (visual only, no
##   collision — the terrain itself is the walking surface).
## - FIELD routes stay unpaved by design (R2) but get generated marker
##   posts and are fully audited like paved paths.
## - ground_at() includes built surfaces (lighthouse spit deck, causeway
##   wedge), so paths, seating, and audits all agree on "the ground".

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

# name: [width, [points...]]  (paved ribbons)
const PATHS: Dictionary = {
	"East Lane": [3.5, [Vector2(13, 0), Vector2(19, 0), Vector2(25, 0), Vector2(29, 2), Vector2(30.5, 5)]],
	"Market Route": [3.5, [Vector2(29, 2), Vector2(33, -2), Vector2(38.5, -6.5), Vector2(45, -12), Vector2(46, -20), Vector2(46, -42), Vector2(45.8, -45.4)]],
	"Back Path": [2.5, [Vector2(4, 16), Vector2(6, 24), Vector2(14, 27), Vector2(22, 20), Vector2(28, 13), Vector2(30.5, 5)]],
	"Shell Cut": [2.0, [Vector2(22, 0.5), Vector2(22, 3.4), Vector2(22, 12.6), Vector2(24.5, 15.5)]],
	"Shore Path": [2.5, [Vector2(28, 13), Vector2(28.5, 24), Vector2(27, 36), Vector2(26, 42.7)]],
	"Well Lane": [3.5, [Vector2(-15, -6), Vector2(-20, -9), Vector2(-24.6, -14)]],
	"Windmill Diagonal": [2.5, [Vector2(-20, -9), Vector2(-22, -18), Vector2(-27, -28), Vector2(-40, -40), Vector2(-46, -48), Vector2(-48, -53.6)]],
	"North Trunk": [3.5, [Vector2(0, -15), Vector2(4, -22), Vector2(8, -30), Vector2(12, -38), Vector2(15, -44), Vector2(18, -48.4)]],
	"Bell West Route": [2.5, [Vector2(-15, -6), Vector2(-21, -12), Vector2(-19, -22), Vector2(-12, -31), Vector2(-2, -42), Vector2(6, -50), Vector2(11, -49), Vector2(15, -48.5), Vector2(17.5, -48.4)]],
	"Cellar Upper Route": [2.5, [Vector2(0, -15), Vector2(6, -24), Vector2(14, -30.5), Vector2(26, -32), Vector2(34, -32.5), Vector2(41, -34.5), Vector2(45, -38), Vector2(45, -43), Vector2(45.8, -45.4)]],
	"South Trunk": [3.5, [Vector2(4, 16), Vector2(6, 24), Vector2(8, 32), Vector2(12, 37), Vector2(15.5, 38.6)]],
	"Waterfront": [2.5, [Vector2(12, 37), Vector2(18, 35), Vector2(24, 38), Vector2(26, 43), Vector2(32, 43.2), Vector2(60, 43.2), Vector2(63.5, 44.5), Vector2(63.5, 48.5), Vector2(64, 50.5), Vector2(64, 56.6)]],
	"Back Alley": [2.0, [Vector2(34, -3.5), Vector2(32.8, -10), Vector2(32.8, -27), Vector2(34, -31.8)]],
	"Market Connector": [2.0, [Vector2(32.8, -21.3), Vector2(40, -21.3), Vector2(45.5, -20.5)]],
}

# Unpaved, post-marked field routes (R2): audited, not ribboned.
const FIELD_ROUTES: Dictionary = {
	"Well Crossing": [Vector2(0, -15), Vector2(-6, -19), Vector2(-12, -20.5), Vector2(-22, -20), Vector2(-24.5, -16), Vector2(-24.6, -14)],
	"Windmill Field": [Vector2(0, -15), Vector2(-4, -22), Vector2(-8, -30), Vector2(-48, -30), Vector2(-52, -34), Vector2(-52, -46), Vector2(-50, -50), Vector2(-48, -53.6)],
}

# Built walking surfaces that override raw terrain height.
const SPIT_RECT := Rect2(59.5, 45.0, 9.0, 21.0)   # x, z, w, d -> deck 0.3
const WEDGE_RECT := Rect2(62.0, 43.0, 3.0, 5.0)    # causeway ramp up the spit


static func ground_at(x: float, z: float) -> float:
	if WEDGE_RECT.has_point(Vector2(x, z)):
		var t: float = clampf((z - WEDGE_RECT.position.y) / WEDGE_RECT.size.y, 0.0, 1.0)
		return lerpf(-0.29, 0.31, t)
	if SPIT_RECT.has_point(Vector2(x, z)):
		return 0.3
	return TerrainScript.height_at(x, z)


## Generate ribbons, causeway wedge, and field-route posts under `lanes`.
static func build(lanes: Node3D) -> void:
	for child in lanes.get_children():
		child.queue_free()

	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.54, 0.45, 0.33)
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	for path_name in PATHS:
		var width: float = PATHS[path_name][0]
		var points: Array = PATHS[path_name][1]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = path_name.replace(" ", "")
		mesh_instance.mesh = _ribbon_mesh(points, width)
		mesh_instance.material_override = path_material
		lanes.add_child(mesh_instance)

	# Physical causeway wedge: terrain-to-deck ramp with collision.
	var wedge := StaticBody3D.new()
	wedge.name = "CausewayWedge"
	wedge.set_meta("no_seat", true)
	var wedge_mesh := BoxMesh.new()
	wedge_mesh.size = Vector3(3, 0.12, 5.06)
	var wedge_material := StandardMaterial3D.new()
	wedge_material.albedo_color = Color(0.4, 0.38, 0.34)
	wedge_mesh.material = wedge_material
	var wedge_shape := BoxShape3D.new()
	wedge_shape.size = wedge_mesh.size
	var wedge_mi := MeshInstance3D.new()
	wedge_mi.mesh = wedge_mesh
	var wedge_cs := CollisionShape3D.new()
	wedge_cs.shape = wedge_shape
	wedge.add_child(wedge_mi)
	wedge.add_child(wedge_cs)
	# Tilt: south (+z) end rises 0.6 over ~5m (~6.8 deg).
	wedge.transform = Transform3D(
		Vector3(1, 0, 0), Vector3(0, 0.993, 0.117), Vector3(0, -0.117, 0.993),
		Vector3(63.5, 0.01, 45.5))
	lanes.add_child(wedge)

	# Field-route marker posts, evenly spaced (R2 legibility).
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.3, 1.2, 0.3)
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color(0.45, 0.36, 0.26)
	post_mesh.material = post_material
	var post_shape := BoxShape3D.new()
	post_shape.size = post_mesh.size
	for route_name in FIELD_ROUTES:
		var pts: Array = FIELD_ROUTES[route_name]
		var index := 0
		for sample in _resample(pts, 6.0, 4.0):
			var post := StaticBody3D.new()
			post.name = "%sPost%d" % [route_name.replace(" ", ""), index]
			post.set_meta("no_seat", true)  # seated right here
			var mi := MeshInstance3D.new()
			mi.mesh = post_mesh
			var cs := CollisionShape3D.new()
			cs.shape = post_shape
			post.add_child(mi)
			post.add_child(cs)
			post.position = Vector3(sample.x, ground_at(sample.x, sample.y) + 0.6, sample.y)
			lanes.add_child(post)
			index += 1


## Terrain-conformant ribbon: subdivided every ~1m, draped at ground+0.04.
static func _ribbon_mesh(points: Array, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width / 2.0
	var samples: Array[Vector2] = _resample(points, 1.0, 0.0)
	for i in range(samples.size() - 1):
		var a: Vector2 = samples[i]
		var b: Vector2 = samples[i + 1]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x) * half
		var al := Vector3(a.x + n.x, ground_at(a.x + n.x, a.y + n.y) + 0.04, a.y + n.y)
		var ar := Vector3(a.x - n.x, ground_at(a.x - n.x, a.y - n.y) + 0.04, a.y - n.y)
		var bl := Vector3(b.x + n.x, ground_at(b.x + n.x, b.y + n.y) + 0.04, b.y + n.y)
		var br := Vector3(b.x - n.x, ground_at(b.x - n.x, b.y - n.y) + 0.04, b.y - n.y)
		surface.add_vertex(al)
		surface.add_vertex(bl)
		surface.add_vertex(br)
		surface.add_vertex(al)
		surface.add_vertex(br)
		surface.add_vertex(ar)
	surface.generate_normals()
	return surface.commit()


## Resample a polyline every `step` meters (skipping `margin` at both ends).
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


## All audit samples: { path_name: Array[Vector2] } at <=0.5m spacing,
## paved and field routes alike.
static func all_samples() -> Dictionary:
	var out: Dictionary = {}
	for path_name in PATHS:
		out[path_name] = _resample(PATHS[path_name][1], 0.5, 0.0)
	for route_name in FIELD_ROUTES:
		out[route_name] = _resample(FIELD_ROUTES[route_name], 0.5, 0.0)
	return out


## Connectivity graph over waypoints of every path/route + gates + doors.
## Nodes merge when a waypoint sits within `tolerance` of another path's
## segment. Returns { "components": int, "main_has": Array, "missing": Array }.
static func connectivity() -> Dictionary:
	var polylines: Dictionary = {}
	for path_name in PATHS:
		polylines[path_name] = PATHS[path_name][1]
	for route_name in FIELD_ROUTES:
		polylines[route_name] = FIELD_ROUTES[route_name]

	# Collect nodes: (path, index) -> flat id.
	var ids: Array = []          # flat list of Vector2
	var owner_path: Array = []   # parallel list of path names
	var offsets: Dictionary = {}
	for path_name in polylines:
		offsets[path_name] = ids.size()
		for p in polylines[path_name]:
			ids.append(p)
			owner_path.append(path_name)

	var parent: Array[int] = []
	for i in ids.size():
		parent.append(i)

	# Union consecutive waypoints within each path.
	for path_name in polylines:
		var base: int = offsets[path_name]
		for i in range(polylines[path_name].size() - 1):
			_union(parent, base + i, base + i + 1)

	# Union waypoints onto other paths' segments within tolerance.
	const TOLERANCE := 1.6
	for i in ids.size():
		for path_name in polylines:
			if owner_path[i] == path_name:
				continue
			var pts: Array = polylines[path_name]
			var base: int = offsets[path_name]
			for k in range(pts.size() - 1):
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ids[i], pts[k], pts[k + 1])
				if closest.distance_to(ids[i]) <= TOLERANCE:
					_union(parent, i, base + k)
					break

	# Which component holds Gate E?
	var gate_e_root := -1
	for i in ids.size():
		if ids[i].distance_to(GATES["Gate E"]) < 0.1:
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
		var target: Vector2 = targets[target_name]
		var found := false
		for i in ids.size():
			if ids[i].distance_to(target) <= 1.6 and _find(parent, i) == gate_e_root:
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
