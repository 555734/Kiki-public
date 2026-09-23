class_name BlackHoleChaser
extends Enemy
## Prototype pressure enemy: a floating black hole that starts behind the runner,
## wakes when the runner actually leaves the start, then relentlessly follows.
## Contact is instant death through Runner's existing `instant_death` handling.
##
## It deliberately ignores terrain. This is a chase-pressure test, not a pathfinding
## test, and flying through gaps/steps keeps the behaviour predictable while we tune
## whether being pursued is fun at all.

@export var runner: Runner = null
@export var chase_speed: float = 360.0
@export var activation_distance: float = 100.0
@export var spawn_distance: float = 420.0

const HIT_RADIUS: float = 38.0
const CORE_RADIUS: float = 27.0

var _active: bool = false
var _runner_origin_x: float = 0.0
var _spin: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("instant_death")
	# Keep the enemy layer so Runner's hurtbox sees us, but do not collide with
	# terrain, holograms or the runner's physics body. The black hole floats.
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 12
	if runner != null and is_instance_valid(runner):
		_runner_origin_x = runner.global_position.x
	Events.runner_respawned.connect(_on_runner_respawned)
	queue_redraw()

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	add_child(shape)

func _physics_process(_delta: float) -> void:
	if runner == null or not is_instance_valid(runner) or runner.state == Runner.State.DEAD:
		velocity = Vector2.ZERO
		return

	# Do not let the chase consume the player while they are still on the opening
	# screen. The first deliberate horizontal movement arms it.
	if not _active:
		if absf(runner.global_position.x - _runner_origin_x) < activation_distance:
			velocity = Vector2.ZERO
			return
		_active = true

	var to_runner := runner.global_position - global_position
	if to_runner.length_squared() < 1.0:
		velocity = Vector2.ZERO
		return
	velocity = to_runner.normalized() * chase_speed * Difficulty.chase_scale()
	move_and_slide()

func _process(delta: float) -> void:
	_spin = fmod(_spin + delta * 1.8, TAU)
	queue_redraw()

func _draw() -> void:
	# Procedural placeholder art: no asset dependency, obvious even at a glance.
	# The outer rings make its motion readable while the core remains black.
	draw_circle(Vector2.ZERO, 52.0, Color(0.32, 0.08, 0.55, 0.16))
	draw_circle(Vector2.ZERO, 43.0, Color(0.22, 0.04, 0.38, 0.32))
	for i in 3:
		var phase := _spin + float(i) * TAU / 3.0
		var radius := 42.0 + float(i) * 4.0
		draw_arc(Vector2.ZERO, radius, phase, phase + 1.65, 24,
			Color(0.58, 0.24, 0.92, 0.82 - float(i) * 0.15), 4.0, true)
	draw_circle(Vector2.ZERO, CORE_RADIUS + 5.0, Color(0.05, 0.01, 0.08, 0.95))
	draw_circle(Vector2.ZERO, CORE_RADIUS, Color(0.0, 0.0, 0.0, 1.0))

## The prototype pursuer is environmental pressure, not a target for the guardian.
## Shots still pass through the normal hit query, but cannot delete the chase.
func take_damage(_amount: int, _by: String = "snipe") -> void:
	pass

func _on_runner_respawned(_checkpoint_index: int) -> void:
	if runner == null or not is_instance_valid(runner):
		return
	# A retry should restart the pressure near the retry point, not make the black
	# hole spend half the stage travelling from the original start.
	global_position = runner.global_position + Vector2(-spawn_distance, 0.0)
	_runner_origin_x = runner.global_position.x
	_active = false
	velocity = Vector2.ZERO
