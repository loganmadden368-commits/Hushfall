@tool
extends StaticBody3D
## One greybox outbuilding: a 10x10m box room with a doorway and a floating
## name sign. Instanced several times in world.tscn to form the village
## spokes. Real architecture replaces these in the Phase 9 art pass.
##
## (@tool means this script also runs inside the editor, so the name sign
## updates live when you change building_name in the Inspector.)

@export var building_name: String = "Building":
	set(value):
		building_name = value
		if name_sign != null:
			name_sign.text = value

@onready var name_sign: Label3D = $NameSign


func _ready() -> void:
	name_sign.text = building_name
