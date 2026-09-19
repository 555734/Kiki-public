class_name Walker
extends Enemy
## The mushroom-shaped ground enemy from the mockups. Like every enemy, it must
## be avoided by the runner or defeated by the guardian.

@export var patrol_half_width: float = 110.0

## Which of the two paintings this one wears. Purely cosmetic: both skins walk,
## turn and die identically, and the 1-1 hand-over simply arrived with two
## ground enemies where the game had one.
##
## It is LEVEL DATA, set once at build time from the same spec on both devices,
## so it never goes on the wire -- the same reason a moving platform's path
## does not (docs/netcode.md section 4). An enemy is identified across the link
## by its index in that level data, and skin does not change that index.
@export var skin: String = "walker"

var direction: int = -1
var _origin_x: float = 0.0
var _walk_phase: float = 0.0

func _ready() -> void:
	hp = Balance.WALKER_HP
	super._ready()
	# Kept as a classification group for tests/capture helpers. Runner contact
	# no longer routes through a stomp attack; Runner._resolve_hazard handles it
	# as ordinary enemy damage instead.
	add_to_group("stompable")
	_origin_x = global_position.x

func _build_body() -> void:
	_add_box(Balance.WALKER_SIZE)
	visual = preload("res://src/entities/enemies/walker_visual.gd").new()
	visual.walker = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	_walk_phase += delta * 6.0
	velocity.x = float(direction) * Balance.WALKER_SPEED
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta, Balance.RUNNER_TERMINAL_VELOCITY)
	move_and_slide()

	# Turn at a wall, at the patrol limit, or at the lip of a drop, so a walker
	# never walks itself into a pit the guardian was saving for the runner.
	if is_on_wall():
		direction = -direction
	elif absf(global_position.x - _origin_x) > patrol_half_width:
		direction = -1 if global_position.x > _origin_x else 1
	elif is_on_floor() and not _ground_ahead():
		direction = -direction

func _ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var probe := Balance.WALKER_SIZE * 0.5
	var from := global_position + Vector2(float(direction) * probe.x, probe.y - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 14.0), 1 | 8, [get_rid()])
	return not space.intersect_ray(query).is_empty()

func walk_phase() -> float:
	return _walk_phase
