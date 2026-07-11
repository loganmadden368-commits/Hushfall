extends RefCounted
## Plaza recomposition (P3) — composition with INTENT:
##  - The bonfire is the focal point; four benches face it.
##  - Three market stalls form an arc on the north-east quadrant, fronts
##    toward the fire.
##  - The big lantern stands south-west as the deliberate counter-light.
##  - The tree stands north-west, framing (not blocking) the Bell Tower
##    skyline from the square.
##  - TEN one-body houses (P2) sit tangent ON the square's circle
##    (fronts at r=12, the disc edge), doors facing center, leaving the
##    four gate corridors clear.
## All generated; the overlap/assembly/seating audits arbitrate.

const PathNet = preload("res://scripts/path_network.gd")
const HouseBuilder = preload("res://scripts/house_builder.gd")

const RING_RADIUS: float = 14.3  # fronts land exactly on the disc edge r=12
# Bearings (deg, 0=east, 90=south) avoiding gates E=0, S=76, W=202, N=270.
const RING_HOUSES: Array = [
	[30.0, Vector3(4.6, 3.2, 4.6), "wall_cream", "roof_rust"],
	[100.0, Vector3(4.6, 3.4, 4.6), "wall_sage", "roof_rust"],
	[140.0, Vector3(4.6, 3.0, 4.6), "wall_cream", "roof_slate"],
	[180.0, Vector3(4.6, 3.2, 4.6), "wall_rose", "roof_rust"],
	[235.0, Vector3(4.6, 3.0, 4.6), "wall_sage", "roof_slate"],
	[295.0, Vector3(4.6, 3.4, 4.6), "wall_cream", "roof_rust"],
	[331.0, Vector3(4.6, 3.0, 4.6), "wall_rose", "roof_slate"],
]


static func build(world: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PlazaDressing"
	world.add_child(root)

	if GameConfig.night_preview:
		_apply_night(world)

	# Ring houses: tangent to the disc, doors to the fire.
	var ring: Node3D = world.get_node("PlazaRing")
	for entry in RING_HOUSES:
		var theta: float = deg_to_rad(entry[0])
		var x: float = RING_RADIUS * cos(theta)
		var z: float = RING_RADIUS * sin(theta)
		var yaw: float = PI / 2.0 - theta  # local -Z (door) points at center
		HouseBuilder.build(ring, "RingHouse%d" % int(entry[0]), x, z, yaw, entry[1], entry[2], entry[3])

	_dress_bonfire(world)

	# Counter-light SW (bearing 130, r=6).
	_big_lantern(root, Vector3(-3.9, 0, 4.6))

	# Market arc NE (bearings 295/315/335, r=8), fronts toward the fire.
	var stall_index := 1
	for bearing in [295.0, 315.0, 335.0]:
		var theta: float = deg_to_rad(bearing)
		_stall(root, Vector3(8.0 * cos(theta), 0, 8.0 * sin(theta)), PI / 2.0 - theta, stall_index)
		stall_index += 1

	# Benches facing the fire (r=3.6, one per quadrant, offset off gates).
	var bench_index := 1
	for bearing in [40.0, 130.0, 220.0, 310.0]:
		var theta: float = deg_to_rad(bearing)
		_bench(root, Vector3(3.6 * cos(theta), 0, 3.6 * sin(theta)), PI / 2.0 - theta, bench_index)
		bench_index += 1

	# Tree NW (bearing 235, r=9): frames the Bell Tower view north.
	_tree(root, Vector3(9.0 * cos(deg_to_rad(235.0)), 0, 9.0 * sin(deg_to_rad(235.0))))

	print("[PlazaDressing] recomposed: %d ring houses, 3 stalls, 4 benches, counter-light, tree" % RING_HOUSES.size())


static func _color(key: String) -> Color:
	return GameConfig.palette.get(key, Color.MAGENTA)


static func _flat(key: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(key)
	return material


static func _glow(key: String, energy: float) -> StandardMaterial3D:
	var material := _flat(key)
	material.emission_enabled = true
	material.emission = _color(key)
	material.emission_energy_multiplier = energy
	return material


static func _apply_night(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.05, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.3, 0.42)
	environment.ambient_light_energy = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.1, 0.16)
	environment.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.name = "NightPreview"
	world_env.environment = environment
	world.add_child(world_env)
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.light_color = Color(0.6, 0.7, 0.95)
	sun.light_energy = 0.22
	sun.rotation_degrees = Vector3(-62, 40, 0)


static func _dress_bonfire(world: Node3D) -> void:
	var bonfire: Node3D = world.get_node("Bonfire")
	for child in bonfire.get_children():
		if child is MeshInstance3D and not child.has_meta("dressed"):
			child.material_override = _flat("stone_grey")
	for i in 8:
		var angle := i * TAU / 8.0
		var stone := MeshInstance3D.new()
		stone.set_meta("dressed", true)
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.5, 0.5)
		box.material = _flat("stone_grey")
		stone.mesh = box
		stone.position = Vector3(cos(angle) * 1.9, 0.25, sin(angle) * 1.9)
		stone.rotation.y = -angle
		bonfire.add_child(stone)
	var flame := MeshInstance3D.new()
	flame.set_meta("dressed", true)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.8
	cone.height = 1.6
	cone.material = _glow("lantern_glow", 3.0)
	flame.mesh = cone
	flame.position = Vector3(0, 1.6, 0)
	bonfire.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = _color("lantern_glow")
	light.light_energy = 3.0
	light.omni_range = 16.0
	light.position = Vector3(0, 2.2, 0)
	bonfire.add_child(light)


static func _big_lantern(root: Node3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "BigLantern"
	body.set_meta("no_seat", true)
	body.position = Vector3(at.x, PathNet.ground_at(at.x, at.z), at.z)
	var post := BoxMesh.new()
	post.size = Vector3(0.3, 3.4, 0.3)
	post.material = _flat("wood_warm")
	var post_mi := MeshInstance3D.new()
	post_mi.mesh = post
	post_mi.position = Vector3(0, 1.7, 0)
	var post_cs := CollisionShape3D.new()
	var post_shape := BoxShape3D.new()
	post_shape.size = post.size
	post_cs.shape = post_shape
	post_cs.position = post_mi.position
	var arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(1.1, 0.2, 0.2)
	arm_box.material = _flat("wood_warm")
	arm.mesh = arm_box
	arm.position = Vector3(0.5, 3.3, 0)
	var cage := MeshInstance3D.new()
	var cage_box := BoxMesh.new()
	cage_box.size = Vector3(0.7, 0.9, 0.7)
	cage_box.material = _glow("lantern_glow", 2.4)
	cage.mesh = cage_box
	cage.position = Vector3(0.9, 2.7, 0)
	var light := OmniLight3D.new()
	light.light_color = _color("lantern_glow")
	light.light_energy = 2.4
	light.omni_range = 18.0
	light.position = Vector3(0.9, 2.7, 0)
	for child in [post_mi, post_cs, arm, cage, light]:
		body.add_child(child)
	root.add_child(body)


static func _stall(root: Node3D, at: Vector3, yaw: float, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Stall%d" % index
	body.set_meta("no_seat", true)
	body.position = Vector3(at.x, PathNet.ground_at(at.x, at.z), at.z)
	body.rotation.y = yaw
	var counter := BoxMesh.new()
	counter.size = Vector3(2.2, 1.0, 1.0)
	counter.material = _flat("wood_warm")
	var counter_mi := MeshInstance3D.new()
	counter_mi.mesh = counter
	counter_mi.position = Vector3(0, 0.5, 0)
	var counter_cs := CollisionShape3D.new()
	var counter_shape := BoxShape3D.new()
	counter_shape.size = counter.size
	counter_cs.shape = counter_shape
	counter_cs.position = counter_mi.position
	body.add_child(counter_mi)
	body.add_child(counter_cs)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_box := BoxMesh.new()
		post_box.size = Vector3(0.15, 2.2, 0.15)
		post_box.material = _flat("wood_warm")
		post.mesh = post_box
		post.position = Vector3(side * 1.0, 1.1, 0.4)
		body.add_child(post)
	var awning := MeshInstance3D.new()
	var awning_box := BoxMesh.new()
	awning_box.size = Vector3(2.6, 0.08, 1.8)
	awning_box.material = _flat("wall_rose")
	awning.mesh = awning_box
	awning.position = Vector3(0, 2.25, -0.1)
	awning.rotation.x = deg_to_rad(12)
	body.add_child(awning)
	root.add_child(body)


static func _bench(root: Node3D, at: Vector3, yaw: float, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Bench%d" % index
	body.set_meta("no_seat", true)
	body.position = Vector3(at.x, PathNet.ground_at(at.x, at.z), at.z)
	body.rotation.y = yaw
	var seat := BoxMesh.new()
	seat.size = Vector3(1.8, 0.14, 0.55)
	seat.material = _flat("wood_warm")
	var seat_mi := MeshInstance3D.new()
	seat_mi.mesh = seat
	seat_mi.position = Vector3(0, 0.5, 0)
	var seat_cs := CollisionShape3D.new()
	var seat_shape := BoxShape3D.new()
	seat_shape.size = Vector3(1.8, 0.5, 0.55)
	seat_cs.shape = seat_shape
	seat_cs.position = Vector3(0, 0.25, 0)
	body.add_child(seat_mi)
	body.add_child(seat_cs)
	for side in [-0.7, 0.7]:
		var leg := MeshInstance3D.new()
		var leg_box := BoxMesh.new()
		leg_box.size = Vector3(0.16, 0.5, 0.5)
		leg_box.material = _flat("wood_warm")
		leg.mesh = leg_box
		leg.position = Vector3(side, 0.25, 0)
		body.add_child(leg)
	root.add_child(body)


static func _tree(root: Node3D, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "PlazaTree"
	body.set_meta("no_seat", true)
	body.position = Vector3(at.x, PathNet.ground_at(at.x, at.z), at.z)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.28
	trunk.bottom_radius = 0.4
	trunk.height = 2.6
	trunk.material = _flat("wood_warm")
	var trunk_mi := MeshInstance3D.new()
	trunk_mi.mesh = trunk
	trunk_mi.position = Vector3(0, 1.3, 0)
	var trunk_cs := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 2.6
	trunk_cs.shape = trunk_shape
	trunk_cs.position = trunk_mi.position
	body.add_child(trunk_mi)
	body.add_child(trunk_cs)
	for blob in [[Vector3(0, 3.4, 0), 1.9, "foliage_deep"], [Vector3(0.7, 4.4, 0.4), 1.3, "foliage_bright"]]:
		var canopy := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = blob[1]
		sphere.height = blob[1] * 1.7
		sphere.material = _flat(blob[2])
		canopy.mesh = sphere
		canopy.position = blob[0]
		body.add_child(canopy)
	root.add_child(body)
