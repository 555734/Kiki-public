extends Enemy
## Stage 1-2's unkillable pursuer. It overtakes the runner unless the guardian
## buys time by shooting it. This script is preloaded by LevelBuilder so a fresh
## git pull does not depend on Godot having already rebuilt its class-name cache.

var runner: Runner = null

@export var wake_delay: float = 2.25
@export var cruise_speed: float = 220.0
@export var catchup_speed: float = 520.0
@export var stun_duration: float = 1.35
@export var kill_distance_x: float = 40.0
@export var kill_distance_y: float = 58.0

var _wake_left: float = 0.0
var _stun_left: float = 0.0
var _phase: float = 0.0
var _hit_flash: float = 0.0

func _ready() -> void:
	hp = 9999
	super._ready()
	# Ignore terrain so the chase cannot stall on route geometry. Enemy._ready()
	# still puts it on the enemy layer; instant_death is the fail-state contract.
	collision_mask = 0
	add_to_group("instant_death")
	_wake_left = wake_delay

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
	if _wake_left > 0.0:
		_wake_left = maxf(0.0, _wake_left - delta)
		return
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		return

	var gap := runner.global_position.x - global_position.x
	if gap > 1180.0:
		global_position = runner.global_position + Vector2(-900.0, -24.0)
		gap = 900.0

	# Chase through the runner, not to a point behind them. Its floor speed also
	# follows the runner's forward speed, so sprinting alone cannot trivialise it.
	var target := runner.global_position + Vector2(18.0, -8.0)
	var runner_forward := maxf(0.0, runner.velocity.x)
	var close_speed := maxf(cruise_speed, runner_forward + 65.0)
	var catchup := clampf((gap - 100.0) / 700.0, 0.0, 1.0)
	var speed := lerpf(close_speed, catchup_speed, catchup)
	var to_target := target - global_position
	if to_target.length_squared() > 0.01:
		var step := minf(speed * delta, to_target.length())
		global_position += to_target.normalized() * step

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
	global_position.x -= 92.0
	global_position.y -= 12.0

func phase() -> float:
	return _phase

func stunned() -> bool:
	return _stun_left > 0.0

func hit_flash() -> float:
	return _hit_flash
