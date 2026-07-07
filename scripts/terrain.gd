@tool
extends StaticBody3D
## Procedural greybox terrain (Option C): the ground is generated from an
## explicit height(x, z) function, so every slope and elevation is
## COMPUTABLE — the map audit can prove walkability instead of guessing.
##
## Features (all numbers are the terrain spec):
##  - Flat village core (height 0) so lanes and buildings sit predictably.
##  - Waterfront: ground eases down to -0.5m between z=36 and z=50, sliding
##    under the water plane (surface y=0.15) for a natural shoreline.
##  - The Rise: smooth hill at (18,-56), flat 12m-radius crown at +4m.
##    South/west slopes are walkable (~16 deg); north/east faces are sheer
##    (~66 deg) — deliberately unclimbable, they route players to the slopes.
##  - East-lane hump: 2m-high cone at (22,0), radius 8 (~14 deg) — breaks
##    the standing-height sightline down the east lane (F6).
##  - Two far-field swells (SW meadow, NW fields), gentle +/-0.5m rolls in
##    regions chosen to contain no paths or buildings.
##
## The art pass will replace the mesh; height_at() IS the terrain spec.

const GRID_STEP: float = 2.0
const X_MIN: float = -55.0
const X_MAX: float = 105.0
const Z_MIN: float = -95.0
const Z_MAX: float = 85.0


func _ready() -> void:
	_build()


static func height_at(x: float, z: float) -> float:
	var h: float = 0.0

	# Waterfront ease (south edge of the map).
	h -= 0.5 * smoothstep(36.0, 50.0, z)

	# The Rise. Direction-dependent slope run: sheer to the north and east.
	var to_point := Vector2(x - 18.0, z - (-56.0))
	var dist := to_point.length()
	if dist < 30.0:
		var u := to_point / maxf(dist, 0.001)
		# u.y < 0 means north of the hill center; u.x > 0 means east.
		var sheer := maxf(smoothstep(0.4, 0.7, u.x), smoothstep(0.4, 0.7, -u.y))
		var run := lerpf(14.0, 1.8, sheer)  # 14m run = 16 deg; 1.8m = 66 deg
		h += 4.0 * clampf(1.0 - maxf(0.0, dist - 12.0) / run, 0.0, 1.0)

	# East-lane hump.
	var hump_dist := Vector2(x - 22.0, z).length()
	h += 2.0 * maxf(0.0, 1.0 - hump_dist / 8.0)

	# Far-field swells (regions verified to contain no paths/structures).
	h += 0.5 * sin(x * 0.11) * sin(z * 0.09) * _region_mask(x, z, -60.0, -18.0, 20.0, 44.0)
	h += 0.5 * sin(x * 0.13) * sin(z * 0.08) * _region_mask(x, z, -60.0, -34.0, -16.0, 8.0)

	return h


## 1 inside the rectangle, 0 outside, smooth 4m shoulders.
static func _region_mask(x: float, z: float, x0: float, x1: float, z0: float, z1: float) -> float:
	var mx := smoothstep(x0, x0 + 4.0, x) * (1.0 - smoothstep(x1 - 4.0, x1, x))
	var mz := smoothstep(z0, z0 + 4.0, z) * (1.0 - smoothstep(z1 - 4.0, z1, z))
	return mx * mz


func _build() -> void:
	# Clear anything generated on a previous run (editor reloads).
	for child in get_children():
		child.queue_free()

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var cols := int((X_MAX - X_MIN) / GRID_STEP)
	var rows := int((Z_MAX - Z_MIN) / GRID_STEP)

	for row in range(rows):
		for col in range(cols):
			var x0 := X_MIN + col * GRID_STEP
			var z0 := Z_MIN + row * GRID_STEP
			var x1 := x0 + GRID_STEP
			var z1 := z0 + GRID_STEP
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			# Two triangles per cell (material is double-sided, so winding
			# order can't blank the ground out).
			surface.add_vertex(p00)
			surface.add_vertex(p10)
			surface.add_vertex(p11)
			surface.add_vertex(p00)
			surface.add_vertex(p11)
			surface.add_vertex(p01)

	surface.generate_normals()
	var mesh := surface.commit()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.42, 0.32)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	add_child(collision)
