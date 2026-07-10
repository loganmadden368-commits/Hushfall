extends RefCounted
## Screenshot tour (perception machinery 1A) — flies a camera through a
## scripted shot list and saves PNGs to res://screenshots/ (i.e.
## E:\hushfall\screenshots\). Per A3: a visual claim counts only with a
## reviewed screenshot; this is the shared contact sheet.
##
## Trigger: launch with `-- --screenshot-tour` in a VISIBLE window
## (rendering requires one). Most shots use bright "inspection lighting";
## shots whose label starts with "night_" keep the night mood.

const PathNet = preload("res://scripts/path_network.gd")
const MapAuditScript = preload("res://scripts/map_audit.gd")

const DIR := "res://screenshots"


static func run(world: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var camera := Camera3D.new()
	camera.fov = 65
	world.add_child(camera)
	camera.make_current()

	var inspection := DirectionalLight3D.new()
	inspection.rotation_degrees = Vector3(-55, 25, 0)
	inspection.light_energy = 1.0
	world.add_child(inspection)

	var shots: Array = _shot_list()
	print("[Tour] capturing %d shots to %s" % [shots.size(), ProjectSettings.globalize_path(DIR)])
	for shot in shots:
		var label: String = shot[0]
		inspection.visible = not label.begins_with("night_")
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for i in 6:
			await world.get_tree().process_frame
		var image := world.get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [DIR, label])
	print("[Tour] done.")
	inspection.queue_free()
	camera.queue_free()


static func _eye(x: float, z: float, height: float = 2.2) -> Vector3:
	return Vector3(x, PathNet.ground_at(x, z) + height, z)


static func _shot_list() -> Array:
	var shots: Array = []

	# Plaza panorama + gate connections (paving must reach the disc).
	shots.append(["plaza_panorama", Vector3(0, 14, 22), Vector3(0, 0, 0)])
	shots.append(["night_plaza_mood", _eye(6, 8, 1.7), Vector3(0, 1.5, 0)])
	var gates := {"gate_E": Vector2(13, 0), "gate_S": Vector2(4, 16), "gate_W": Vector2(-15, -6), "gate_N": Vector2(0, -15)}
	for gate_name in gates:
		var g: Vector2 = gates[gate_name]
		var out: Vector2 = g + g.normalized() * 6.0
		shots.append([gate_name + "_junction", _eye(out.x, out.y, 3.0), Vector3(g.x * 0.5, 0.2, g.y * 0.5)])

	# Every site approach + door.
	for site_name in MapAuditScript.SITES:
		var door: Vector3 = MapAuditScript.SITES[site_name]
		var back := Vector3(door.x, 0, door.z).normalized() * -1.0
		var from := Vector3(door.x, 0, door.z) - Vector3(door.x - 0.0, 0, door.z - 0.0).normalized() * 0.0
		var approach := Vector3(door.x, door.y + 2.5, door.z) + (Vector3.ZERO - Vector3(door.x, 0, door.z)).normalized() * -9.0
		approach.y = PathNet.ground_at(approach.x, approach.z) + 2.5
		shots.append(["site_" + site_name.replace(" ", "_"), approach, door + Vector3(0, 1, 0)])

	# Route interval shots: every ~15m along every paved path + field route.
	var frames: Dictionary = PathNet.sample_frames()
	for path_name in frames:
		var pts: Array = frames[path_name].frames
		var stride: int = 30  # samples are 0.5m apart -> ~15m
		var index := 0
		var shot_number := 0
		while index < pts.size() - 4:
			var here: Vector2 = pts[index].p
			var ahead: Vector2 = pts[mini(index + 8, pts.size() - 1)].p
			shots.append(["route_%s_%02d" % [path_name.replace(" ", "_"), shot_number],
					_eye(here.x, here.y, 2.6), Vector3(ahead.x, PathNet.ground_at(ahead.x, ahead.y) + 0.5, ahead.y)])
			index += stride
			shot_number += 1

	# The full shore -> pier -> lighthouse approach, stepwise (third strike).
	var causeway: Array = [Vector2(52, 43), Vector2(60, 43.5), Vector2(63.5, 45.5), Vector2(64, 49), Vector2(64, 53), Vector2(64, 56)]
	for i in causeway.size():
		var p: Vector2 = causeway[i]
		var next: Vector2 = causeway[mini(i + 1, causeway.size() - 1)] if i < causeway.size() - 1 else Vector2(64, 60)
		shots.append(["lighthouse_step_%d" % i, _eye(p.x, p.y, 2.0), Vector3(next.x, PathNet.ground_at(next.x, next.y) + 1.5, next.y)])
	shots.append(["lighthouse_wide", Vector3(48, 6, 34), Vector3(64, 4, 58)])
	shots.append(["shoreline_wide", Vector3(10, 5, 36), Vector3(40, -0.5, 52)])
	shots.append(["night_shoreline", _eye(20, 42, 1.7), Vector3(50, 0, 50)])

	# Field-route legibility (W1) and the Rise climbs (B1).
	shots.append(["field_well_crossing", _eye(-4, -17, 2.4), Vector3(-20, 0, -20)])
	shots.append(["field_windmill", _eye(-12, -30, 2.4), Vector3(-40, 0, -30)])
	shots.append(["rise_climb_north", _eye(6, -27, 2.2), Vector3(15, 3, -44)])
	shots.append(["rise_climb_west", _eye(-4, -43, 2.2), Vector3(10, 4, -51)])
	shots.append(["market_street", _eye(46, -14, 2.6), Vector3(46, 0, -38)])
	shots.append(["night_dressed_houses", _eye(8, 5, 1.7), Vector3(17, 2, -6)])
	return shots
