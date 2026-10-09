extends Enemy
## Stage 1-2's unkillable pursuer. It overtakes the runner unless the guardian
## buys time by shooting it. This script is preloaded by LevelBuilder so a fresh
## git pull does not depend on Godot having already rebuilt its class-name cache.

var runner: Runner = null
## Preloaded, like this script itself, rather than named by class.
const _LIFT_GATE := preload("res://src/entities/gimmicks/lift_gate.gd")

@export var activation_distance: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _activated := false

@export var wake_delay: float = 2.25
@export var cruise_speed: float = 220.0
@export var catchup_speed: float = 520.0
@export var stun_duration: float = 1.35
@export var kill_distance_x: float = 40.0
@export var kill_distance_y: float = 58.0
@export var chase_direction: Vector2 = Vector2.RIGHT

var _wake_left: float = 0.0
var _stun_left: float = 0.0
var _phase: float = 0.0
var _hit_flash: float = 0.0
## Held at a shut gate on its last step. It does not leap ahead to catch up
## then: a gate dropped on it is meant to shut it out.
var _gated := false

func _ready() -> void:
	hp = 9999
	super._ready()
	# Ignore terrain so the chase cannot stall on route geometry. Enemy._ready()
	# still puts it on the enemy layer; instant_death is the fail-state contract.
	collision_mask = 0
	add_to_group("instant_death")
	_wake_left = wake_delay
	if runner != null: _origin = runner.global_position
	_activated = activation_distance <= 0.0
	Events.runner_warped.connect(_on_runner_warped)

func _on_runner_warped(from: Vector2, to: Vector2) -> void:
	if not Clock.is_host: return
	var forward := chase_direction.normalized()
	if forward.length_squared() < 0.5: forward = Vector2.RIGHT
	if (to - from).dot(forward) >= -300.0: return
	# Folded courses resume the chase from behind, instead of leaving the
	# pursuer ahead of the new route. Keep any Guardian stun already earned.
	var gap := clampf((from - global_position).dot(forward), 300.0, 900.0)
	global_position = to - forward * gap + Vector2(0, -24)
	_wake_left = maxf(_wake_left, 1.0)

## It cannot die, but it can be thrown: a flick sends it a long way back the
## way it came and leaves it dazed.
func is_flickable() -> bool:
	return true

func hand_radius() -> float:
	return 74.0

func flick(direction: Vector2) -> void:
	if not Clock.is_host:
		return
	var back := -chase_direction.normalized()
	if back.length_squared() < 0.5:
		back = Vector2.LEFT
	Events.enemy_flicked.emit(global_position, direction)
	global_position += back * Balance.FLICK_PURSUER_PUSH + Vector2(0, clampf(direction.y, -1.0, 1.0) * 120.0)
	_stun_left = maxf(_stun_left, Balance.FLICK_PURSUER_STUN)
	_hit_flash = 0.3

func _build_body() -> void:
	_add_box(Vector2(106, 92))
	visual = preload("res://src/entities/enemies/sky_pursuer_visual.gd").new()
	visual.pursuer = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	_phase += delta * 2.2
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if runner == null or not is_instance_valid(runner):
		return
	if runner.state == Runner.State.DEAD:
		return
	if not _activated:
		if runner.global_position.distance_to(_origin) < activation_distance:
			return
		_activated = true
	if _wake_left > 0.0:
		_wake_left = maxf(0.0, _wake_left - delta)
		return
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		return

	var forward := chase_direction.normalized()
	if forward.length_squared() < 0.5:
		forward = Vector2.RIGHT
	var gap := (runner.global_position - global_position).dot(forward)
	if gap > 1180.0 and not _gated:
		global_position = runner.global_position - forward * 900.0 + Vector2(0.0, -24.0)
		gap = 900.0

	# Chase through the runner, not to a point behind them. Its floor speed also
	# follows the runner's forward speed, so sprinting alone cannot trivialise it.
	var target := runner.global_position + forward * 18.0
	var runner_forward := maxf(0.0, runner.velocity.dot(forward))
	var close_speed := maxf(cruise_speed, runner_forward + 65.0)
	var catchup := clampf((gap - 100.0) / 700.0, 0.0, 1.0)
	# The chosen difficulty scales the whole speed, including the part that
	# tracks the runner, or EASY would be no easier while the runner is moving.
	var speed := lerpf(close_speed, catchup_speed, catchup) * Difficulty.chase_scale()
	var to_target := target - global_position
	if to_target.length_squared() > 0.01:
		var step := minf(speed * delta, to_target.length())
		var next := global_position + to_target.normalized() * step
		# It flies through everything except a shut gate: that is the one
		# thing the guardian can drop in its way.
		var stop: float = _LIFT_GATE.stop_x(get_tree(), global_position.x, next.x,
			global_position.y, Clock.tick, 70.0)
		_gated = stop != INF
		if _gated:
			next.x = stop
		global_position = next

	# Explicit overlap test keeps the visible catch and death frame in agreement.
	var dx := absf(runner.global_position.x - global_position.x)
	var dy := absf(runner.global_position.y - global_position.y)
	if dx <= kill_distance_x and dy <= kill_distance_y:
		runner.die("pursuer")

func take_damage(_amount: int, _by: String = "snipe") -> void:
	if is_queued_for_deletion():
		return
	_stun_left = maxf(_stun_left, stun_duration)
	_hit_flash = 0.20
	# Away from progress is left in 1-2 and down in the vertical stage.
	global_position -= chase_direction.normalized() * 92.0
	if absf(chase_direction.x) > 0.5:
		global_position.y -= 12.0

func phase() -> float:
	return _phase

func stunned() -> bool:
	return _stun_left > 0.0

func hit_flash() -> float:
	return _hit_flash
