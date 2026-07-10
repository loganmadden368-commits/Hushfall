extends RefCounted
## Shared movement module — THE single implementation of player locomotion.
##
## Consumed by BOTH player.gd (live players) and route_walker.gd (the
## traversal audit). A3 bans models verifying models: the walker doesn't
## imitate player physics, it CALLS this same code with the same collider,
## so any future movement change (sprint, crouch, jump tuning) flows into
## the audit automatically.

# The player capsule (player.tscn's CollisionShape3D matches these).
const CAPSULE_RADIUS: float = 0.4
const CAPSULE_HEIGHT: float = 1.8


## One physics tick of ground movement. `wish_dir` is the desired travel
## direction in world space (y ignored), already normalized or zero.
static func step(body: CharacterBody3D, wish_dir: Vector3, delta: float) -> void:
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta

	if wish_dir != Vector3.ZERO:
		body.velocity.x = wish_dir.x * GameConfig.move_speed
		body.velocity.z = wish_dir.z * GameConfig.move_speed
	else:
		body.velocity.x = 0.0
		body.velocity.z = 0.0

	body.move_and_slide()


## Build a collider identical to the player's, for the walker.
static func make_capsule() -> CollisionShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, CAPSULE_HEIGHT / 2.0, 0)
	return collision
