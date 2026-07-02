extends CharacterBody3D
## One player avatar — a first-person capsule. Every connected player gets one.
##
## The multiplayer trick that makes this work: each Player node is NAMED after
## the peer id of the player who owns it (e.g. the host's is "1"). We use that
## name to set the node's "multiplayer authority" — whose input controls it.
## Every machine has a copy of every player's capsule, but each capsule only
## listens to input on the machine that owns it. The camera works the same
## way: only YOUR capsule's camera turns on, on YOUR machine.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D


func _enter_tree() -> void:
	# Node name == owning peer id (set by world.gd when spawning).
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	if not is_multiplayer_authority():
		return  # someone else's avatar — just a capsule we look at
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # lock mouse for mouselook


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Esc toggles the mouse free/captured (handy in windowed dev builds).
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Mouselook: body turns left/right (yaw), only the head tilts up/down
	# (pitch) — so movement direction follows where your body faces.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * GameConfig.mouse_sensitivity)
		head.rotate_x(-event.relative.y * GameConfig.mouse_sensitivity)
		# Stop the head flipping over backwards.
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	# WASD -> a direction relative to where the body is facing.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * GameConfig.move_speed
		velocity.z = direction.z * GameConfig.move_speed
	else:
		# No input -> stop instantly. (Acceleration/friction feel is a
		# playtest dial for much later; instant is fine for greybox.)
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
