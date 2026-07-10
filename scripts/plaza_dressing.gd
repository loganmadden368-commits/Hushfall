extends RefCounted
## Plaza beauty corner (Part 3A) — the style-guide sample, built
## procedurally from the [style] palette dials so a repaint is a config
## edit. Everything spawns under "PlazaDressing" at runtime: cheap to
## redo, nothing baked into the scene file.
##
## Collision hygiene: props players collide with (stalls, benches, tree
## TRUNKS, lantern post) are simple StaticBody boxes; pure visuals (roofs,
## flames, canopies) have no collision, so gameplay never changes because
## something got cute. All bodies carry no_seat (they seat themselves on
## the flat plaza) but remain covered by audit D's footprint check.
##
## HONESTY (3E): flame = emissive cone (particles are Phase 9); windows
## glow uniformly (no interior lighting logic); roof slabs meet walls with
## visible seams up close; canopies are spheres. All deliberate blockout.

const PathNet = preload("res://scripts/path_network.gd")


static func build(world: Node3D) -> void:
	var root := Node3D.new()
	root.name = "PlazaDressing"
	world.add_child(root)

	if GameConfig.night_preview:
		_apply_night(world)

	_dress_bonfire(world)
	_big_lantern(root, Vector3(5, 0, 1))
	var stall_index := 1
	for stall_data in [[Vector3(-7, 0, 5), 0.4], [Vector3(8, 0, 6), -0.5], [Vector3(-5, 0, -8), 1.2]]:
		_stall(root, stall_data[0], stall_data[1], stall_index)
		stall_index += 1
	var bench_index := 1
	for bench_data in [[Vector3(3.4, 0, -1.2), PI / 2], [Vector3(-3.4, 0, 1.2), -PI / 2], [Vector3(0.8, 0, 3.4), 0.0], [Vector3(-0.8, 0, -3.6), PI]]:
		_bench(root, bench_data[0], bench_data[1], bench_index)
		bench_index += 1
	_tree(root, Vector3(-9, 0, -1))

	# Style sample on three plaza-ring houses (full dress), palette wash
	# on the rest of the ring.
	var ring := world.get_node("PlazaRing")
	_dress_house(ring.get_node("Ring2"), Vector3(6, 3.2, 6), "wall_cream", "roof_rust", Vector3.LEFT)
	_dress_house(ring.get_node("Ring3"), Vector3(6, 3.2, 6), "wall_rose", "roof_slate", Vector3.LEFT)
	_dress_house(ring.get_node("Ring6"), Vector3(8, 4, 8), "wall_sage", "roof_rust", Vector3.RIGHT)
	for house_name in ["Ring1", "Ring4", "Ring5", "Ring7", "Ring8"]:
		_tint(ring.get_node(house_name), "wall_cream")

	print("[PlazaDressing] beauty corner built (night_preview=%s)" % GameConfig.night_preview)


static func _color(key: String) -> Color:
	return GameConfig.palette.get(key, Color.MAGENTA)  # magenta = missing dial


static func _flat(key: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(key)
	return material


static func _glow(key: String, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(key)
	material.emission_enabled = true
	material.emission = _color(key)
	material.emission_energy_multiplier = energy
	return material


# ---------------------------------------------------------------- night ----

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

	# The sun becomes faint blue moonlight.
	var sun: DirectionalLight3D = world.get_node("Sun")
	sun.light_color = Color(0.6, 0.7, 0.95)
	sun.light_energy = 0.22
	sun.rotation_degrees = Vector3(-62, 40, 0)


# ---------------------------------------------------------------- pieces ----

static func _dress_bonfire(world: Node3D) -> void:
	var bonfire: Node3D = world.get_node("Bonfire")
	# Recolor the old greybox drum to stone; add ring stones, flame, light.
	_tint(bonfire, "stone_grey")
	for i in 8:
		var angle := i * TAU / 8.0
		var stone := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.5, 0.5)
		box.material = _flat("stone_grey")
		stone.mesh = box
		stone.position = Vector3(cos(angle) * 1.9, 0.25, sin(angle) * 1.9)
		stone.rotation.y = -angle
		bonfire.add_child(stone)
	var flame := MeshInstance3D.new()
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


static func _stall(root: Node3D, at: Vector3, yaw: float, index: int = 0) -> void:
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
		post.position = Vector3(side * 1.0, 1.1, -0.4)
		body.add_child(post)
	var awning := MeshInstance3D.new()
	var awning_box := BoxMesh.new()
	awning_box.size = Vector3(2.6, 0.08, 1.8)
	awning_box.material = _flat("wall_rose")
	awning.mesh = awning_box
	awning.position = Vector3(0, 2.25, 0.1)
	awning.rotation.x = deg_to_rad(-12)
	body.add_child(awning)
	root.add_child(body)


static func _bench(root: Node3D, at: Vector3, yaw: float, index: int = 0) -> void:
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
	# Canopy: NO collision — players walk under (3D rule).
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


## Full dress: palette walls + pitched roof + oversized door + glowing
## windows + chimney, on the plaza-facing side. Visual only — the house's
## collision box is untouched.
static func _dress_house(house: Node3D, size: Vector3, wall_key: String, roof_key: String, facing: Vector3) -> void:
	_tint(house, wall_key)
	var half := size.x / 2.0
	var top := size.y / 2.0  # house root sits at box center
	var span := half + 0.6   # roof overhang
	var rise := span * tan(deg_to_rad(38))
	var slab_len := span / cos(deg_to_rad(38))
	for side in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		var slab_box := BoxMesh.new()
		slab_box.size = Vector3(slab_len, 0.15, size.z + 1.2)
		slab_box.material = _flat(roof_key)
		slab.mesh = slab_box
		slab.position = Vector3(side * span / 2.0, top + rise / 2.0, 0)
		slab.rotation.z = -side * deg_to_rad(38)
		house.add_child(slab)
	var chimney := MeshInstance3D.new()
	var chimney_box := BoxMesh.new()
	chimney_box.size = Vector3(0.8, 1.8, 0.8)
	chimney_box.material = _flat("stone_grey")
	chimney.mesh = chimney_box
	chimney.position = Vector3(half * 0.5, top + rise * 0.8, size.z * 0.25)
	house.add_child(chimney)
	# Oversized door + two glowing windows on the plaza-facing wall.
	var face_offset := facing * (half + 0.07)
	var door := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.12, 2.3, 1.5) if facing.x != 0 else Vector3(1.5, 2.3, 0.12)
	door_box.material = _flat("wood_warm")
	door.mesh = door_box
	door.position = face_offset + Vector3(0, 1.15 - top, 0)
	house.add_child(door)
	for window_side in [-1.6, 1.6]:
		var window := MeshInstance3D.new()
		var window_box := BoxMesh.new()
		window_box.size = Vector3(0.1, 0.9, 0.9) if facing.x != 0 else Vector3(0.9, 0.9, 0.1)
		window_box.material = _glow("lantern_glow", 0.7)
		window.mesh = window_box
		window.position = face_offset + Vector3(0, 1.7 - top, window_side) if facing.x != 0 \
				else face_offset + Vector3(window_side, 1.7 - top, 0)
		house.add_child(window)


## Recolor an existing greybox body's meshes without touching collision.
static func _tint(node: Node3D, wall_key: String) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = _flat(wall_key)
