extends RefCounted
## Procedural styled house (P2 one-body rule): ONE StaticBody3D per
## building — box collision, visual walls + pitched roof + chimney +
## oversized door + glowing windows, all from the [style] palette dials.
## Roof slabs carry seats_on metadata so the assembly audit verifies
## roof-on-wall-top in the scene. Rebuild-cheap by construction (3E).

const PathNet = preload("res://scripts/path_network.gd")

const ROOF_PITCH_DEG: float = 38.0
const ROOF_OVERHANG: float = 0.6


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


## One-body styled house. Door faces local -Z; `yaw` orients it.
static func build(parent: Node3D, house_name: String, x: float, z: float,
		yaw: float, size: Vector3, wall_key: String, roof_key: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = house_name
	body.position = Vector3(x, 0, z)  # seater fixes Y
	body.rotation.y = yaw

	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = size
	wall_mesh.material = _flat(wall_key)
	walls.mesh = wall_mesh
	walls.position = Vector3(0, size.y / 2.0, 0)
	body.add_child(walls)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = walls.position
	body.add_child(shape)

	_add_roof(body, size, roof_key)

	var chimney := MeshInstance3D.new()
	var chimney_mesh := BoxMesh.new()
	chimney_mesh.size = Vector3(0.7, 1.6, 0.7)
	chimney_mesh.material = _flat("stone_grey")
	chimney.mesh = chimney_mesh
	var rise := (size.x / 2.0 + ROOF_OVERHANG) * tan(deg_to_rad(ROOF_PITCH_DEG))
	chimney.position = Vector3(size.x * 0.22, size.y + rise * 0.75, size.z * 0.2)
	body.add_child(chimney)

	# Oversized door on the -Z face, flanked by glowing windows.
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.4, 2.2, 0.12)
	door_mesh.material = _flat("wood_warm")
	door.mesh = door_mesh
	door.position = Vector3(0, 1.1, -size.z / 2.0 - 0.07)
	body.add_child(door)
	for side in [-1.0, 1.0]:
		if size.x < 4.5:
			continue
		var window := MeshInstance3D.new()
		var window_mesh := BoxMesh.new()
		window_mesh.size = Vector3(0.8, 0.8, 0.1)
		window_mesh.material = _glow("lantern_glow", 0.6)
		window.mesh = window_mesh
		window.position = Vector3(side * size.x * 0.28, 1.6, -size.z / 2.0 - 0.06)
		body.add_child(window)

	parent.add_child(body)
	return body


## Palette + pitched roof for an EXISTING box structure (greybox sites,
## market fillers). Visual only; collision untouched.
static func dress_existing(body: Node3D, footprint: Vector2, wall_top: float,
		wall_key: String, roof_key: String) -> void:
	for child in body.get_children():
		if child is MeshInstance3D and not child.has_meta("dressed"):
			child.material_override = _flat(wall_key)
	_add_roof(body, Vector3(footprint.x, wall_top, footprint.y), roof_key)


static func _add_roof(body: Node3D, size: Vector3, roof_key: String) -> void:
	var span := size.x / 2.0 + ROOF_OVERHANG
	var rise := span * tan(deg_to_rad(ROOF_PITCH_DEG))
	var slab_len := span / cos(deg_to_rad(ROOF_PITCH_DEG))
	for side in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		slab.name = "RoofL" if side < 0 else "RoofR"
		slab.set_meta("dressed", true)
		slab.set_meta("seats_on", "Walls")
		var slab_mesh := BoxMesh.new()
		slab_mesh.size = Vector3(slab_len, 0.14, size.z + ROOF_OVERHANG * 2.0)
		slab_mesh.material = _flat(roof_key)
		slab.mesh = slab_mesh
		slab.position = Vector3(side * span / 2.0, size.y + rise / 2.0, 0)
		slab.rotation.z = -side * deg_to_rad(ROOF_PITCH_DEG)
		body.add_child(slab)
