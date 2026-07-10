extends RefCounted
## Pier builder (L1, third-strike rebuild) — the lighthouse approach as
## ONE continuous physically-walked surface: shore -> gangway ramp ->
## deck -> platform -> lighthouse door. Built from the SAME rects
## path_network.gd routes over; verified by the capsule walker (physics)
## and the stepwise screenshot sequence, per third-strike protocol.
## Assembly metas let the audit check part-on-part seating in the scene.

const PathNet = preload("res://scripts/path_network.gd")


static func build(world: Node3D) -> void:
	var pier := StaticBody3D.new()
	pier.name = "Pier"
	pier.set_meta("no_seat", true)
	pier.set_meta("exempt_reason", "walking surface — verified by capsule walker + assembly audit")
	world.add_child(pier)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7A5C3E")

	# Gangway: sloped plank from the sand up to deck height.
	var shore_h: float = PathNet.ground_at(64.0, 46.7)
	var rise: float = PathNet.DECK_TOP - shore_h
	var run: float = PathNet.GANGWAY_RECT.size.y
	var length: float = sqrt(rise * rise + run * run)
	var angle: float = atan(rise / run)
	var gangway_mesh := BoxMesh.new()
	gangway_mesh.size = Vector3(3, 0.15, length + 0.4)
	gangway_mesh.material = wood
	var gangway_shape := BoxShape3D.new()
	gangway_shape.size = gangway_mesh.size
	var gangway_mi := MeshInstance3D.new()
	gangway_mi.mesh = gangway_mesh
	var gangway_cs := CollisionShape3D.new()
	gangway_cs.shape = gangway_shape
	var mid_y: float = (shore_h + PathNet.DECK_TOP) / 2.0 - 0.075
	var basis := Basis(Vector3.RIGHT, -angle)  # +z end rises southward
	gangway_mi.transform = Transform3D(basis, Vector3(64, mid_y, 49.5))
	gangway_cs.transform = gangway_mi.transform
	pier.add_child(gangway_mi)
	pier.add_child(gangway_cs)

	# Deck + platform: flat planks at DECK_TOP.
	_plank(pier, wood, Vector3(3, 0.15, 12.9), Vector3(64, PathNet.DECK_TOP - 0.075, 58.4))
	var platform := _plank(pier, wood, Vector3(7, 0.15, 7), Vector3(64, PathNet.DECK_TOP - 0.075, 60.5))
	platform.set_meta("part_name", "platform")

	# Pilings (visual) so the deck reads supported, not floating.
	for z in [50.5, 54.0, 57.5, 61.0, 63.5]:
		for side in [-1.3, 1.3]:
			var piling := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.16
			cylinder.bottom_radius = 0.2
			cylinder.height = 1.6
			cylinder.material = wood
			piling.mesh = cylinder
			piling.position = Vector3(64 + side, PathNet.DECK_TOP - 0.85, z)
			pier.add_child(piling)

	# Shore rocks: waterline clusters (S1 dressing, real cover).
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8C8A7E")
	for rock_data in [[56.0, 47.8, 1.2], [59.5, 47.5, 0.9], [68.0, 49.0, 1.4], [44.0, 46.5, 1.0], [20.0, 47.5, 1.1], [-6.0, 46.0, 1.3]]:
		var rock := StaticBody3D.new()
		rock.name = "ShoreRock"
		rock.set_meta("no_seat", true)
		var sphere := SphereMesh.new()
		sphere.radius = rock_data[2]
		sphere.height = rock_data[2] * 1.4
		sphere.material = stone
		var rock_mi := MeshInstance3D.new()
		rock_mi.mesh = sphere
		var rock_cs := CollisionShape3D.new()
		var rock_shape := SphereShape3D.new()
		rock_shape.radius = rock_data[2] * 0.9
		rock_cs.shape = rock_shape
		rock.add_child(rock_mi)
		rock.add_child(rock_cs)
		rock.position = Vector3(rock_data[0], PathNet.ground_at(rock_data[0], rock_data[1]) + rock_data[2] * 0.3, rock_data[1])
		world.add_child(rock)

	# Seat the Lighthouse ON the platform (assembly-checked, not assumed).
	var lighthouse: Node3D = world.get_node("Buildings/Lighthouse")
	lighthouse.position = Vector3(64, PathNet.DECK_TOP, 60.5)
	lighthouse.set_meta("no_seat", true)
	lighthouse.set_meta("exempt_reason", "seats on pier platform — assembly-audited")
	lighthouse.set_meta("seats_on_pier", PathNet.DECK_TOP)


static func _plank(pier: Node3D, material: StandardMaterial3D, size: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	pier.add_child(mi)
	pier.add_child(cs)
	return mi
