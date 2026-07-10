extends RefCounted
## Village dressing (D1 + architecture upgrade): 13 styled density houses
## (approved plan) and palette + pitched roofs for every existing
## structure, so the re-walk judges ONE coherent town. All new bodies are
## one-body composed houses (P2); everything passes the full audit suite
## (intersections, overlap, seating, assembly) every boot.
##
## D1 RIDER (lonely walk): the last shore hut's east face is at x=45; the
## causeway mouth is at x=62.5 — a deliberate 17.5m empty stretch.

const HouseBuilder = preload("res://scripts/house_builder.gd")

# name, x, z, yaw, size, wall, roof
const DENSITY: Array = [
	["MarketOuter1", 54.0, -6.0, PI / 2, Vector3(7, 3.4, 6), "wall_cream", "roof_rust"],
	["MarketOuter2", 58.0, -20.0, PI / 2, Vector3(8, 3.8, 7), "wall_sage", "roof_slate"],
	["MarketOuter3", 61.5, -25.0, PI / 2, Vector3(6, 3.2, 6), "wall_rose", "roof_rust"],
	["AlleyInfill", 20.5, -21.5, -PI / 2, Vector3(6, 3.0, 6), "wall_cream", "roof_slate"],
	["Ring9", 17.5, -14.0, 2.24, Vector3(5, 3.0, 5), "wall_rose", "roof_rust"],
	["Outskirt1", -20.0, 22.0, -0.74, Vector3(7, 3.4, 7), "wall_sage", "roof_rust"],
	["WellHamlet1", -37.0, 3.0, -PI / 2, Vector3(6, 3.2, 6), "wall_rose", "roof_slate"],
	["WellHamlet2", -40.0, -6.0, -PI / 2, Vector3(7, 3.6, 6), "wall_cream", "roof_rust"],
	["ShoreHut1", -2.0, 41.0, -PI / 2, Vector3(5, 2.8, 5), "wall_sage", "roof_rust"],
	["ShoreHut2", 34.0, 38.5, PI, Vector3(5, 2.8, 5), "wall_cream", "roof_slate"],
	["ShoreHut3", 42.0, 38.5, PI, Vector3(6, 3.0, 5), "wall_rose", "roof_rust"],
	["RiseHut", 7.0, -55.0, -PI / 2, Vector3(5, 3.0, 5), "wall_sage", "roof_slate"],
	["WindmillBarn", -40.0, -62.0, PI / 2, Vector3(6, 3.2, 6), "wall_cream", "roof_rust"],
]

# Existing structures: node path -> [footprint, wall_top, wall, roof]
const DRESS: Dictionary = {
	"Buildings/Well": [Vector2(10, 10), 3.7, "wall_cream", "roof_rust"],
	"Buildings/Greenhouse": [Vector2(10, 10), 3.7, "wall_sage", "roof_slate"],
	"Buildings/MushroomCellar": [Vector2(10, 10), 3.7, "wall_rose", "roof_slate"],
	"Buildings/Boathouse": [Vector2(10, 10), 3.7, "wood_warm", "roof_slate"],
	"Buildings/BellTower": [Vector2(10, 10), 3.7, "wall_cream", "roof_rust"],
	"Buildings/Windmill": [Vector2(10, 10), 3.7, "wall_cream", "roof_slate"],
	"MarketLanes/House2": [Vector2(6, 6), 3.2, "wall_cream", "roof_rust"],
	"MarketLanes/House7": [Vector2(6, 6), 3.2, "wall_sage", "roof_slate"],
	"MarketLanes/House8": [Vector2(6, 6), 3.2, "wall_rose", "roof_rust"],
	"MarketLanes/House9": [Vector2(8, 8), 4.0, "wall_cream", "roof_slate"],
	"MarketLanes/House3": [Vector2(8, 8), 4.0, "wall_sage", "roof_rust"],
	"WestVillage/WellRow1": [Vector2(6, 6), 3.2, "wall_cream", "roof_slate"],
	"WestVillage/Barn1": [Vector2(6, 6), 3.2, "wall_rose", "roof_rust"],
	"WestVillage/Barn2": [Vector2(6, 6), 3.2, "wall_cream", "roof_slate"],
	"PlazaRing/Ring4": [Vector2(8, 8), 4.0, "wall_cream", "roof_rust"],
	"PlazaRing/Ring5": [Vector2(6, 6), 3.2, "wall_rose", "roof_slate"],
	"PlazaRing/Ring7": [Vector2(6, 6), 3.2, "wall_sage", "roof_rust"],
	"PlazaRing/Ring8": [Vector2(8, 8), 4.0, "wall_cream", "roof_slate"],
}

# Palette wash only (no pitched roof: tunnels, shells, towers, fences).
const TINT_ONLY: Dictionary = {
	"MarketLanes/Breezeway4": "wall_sage",
	"MarketLanes/Breezeway6": "wall_cream",
	"MarketLanes/Shell1": "wall_rose",
	"MarketLanes/Shell5": "wall_sage",
	"MarketLanes/NookFence": "wood_warm",
	"MarketLanes/CornerKiosk": "wall_rose",
	"Buildings/BellSpire": "stone_grey",
	"Buildings/WindmillTower": "wood_warm",
}


static func build(world: Node3D) -> void:
	var container := Node3D.new()
	container.name = "DensityHouses"
	world.add_child(container)
	for entry in DENSITY:
		HouseBuilder.build(container, entry[0], entry[1], entry[2], entry[3], entry[4], entry[5], entry[6])
	for node_path in DRESS:
		var body: Node3D = world.get_node_or_null(node_path)
		if body != null:
			var spec: Array = DRESS[node_path]
			HouseBuilder.dress_existing(body, spec[0], spec[1], spec[2], spec[3])
	for node_path in TINT_ONLY:
		var body: Node3D = world.get_node_or_null(node_path)
		if body == null:
			continue
		for child in body.get_children():
			if child is MeshInstance3D and not child.has_meta("dressed"):
				child.material_override = HouseBuilder._flat(TINT_ONLY[node_path])
	print("[VillageDressing] %d density houses + %d dressed + %d tinted" % [DENSITY.size(), DRESS.size(), TINT_ONLY.size()])
