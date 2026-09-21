class_name Thornmite
extends Enemy
## Stage 1-2 ground hunter.
##
## Unlike the round walker family, the Thornmite is a low quadruped made from
## broken stone. It patrols slowly, telegraphs, then commits to a short charge.
## The runner reads the horn and dust; the guardian can remove it with two hits.

const BODY_SIZE := Vector2(76.0, 46.0)
const WALK_SPEED := 82.0
const CHARGE_SPEED := 255.0
const ALERT_X := 285.0
const ALERT_Y := 92.0
const WINDUP_TIME := 0.38
const CHARGE_TIME := 0.72
const RECOVER_TIME := 0.46

@export var patrol_half_width: float = 140.0
var runner: Runner = null

var direction: int = -1
var _origin_x: float = 0.0
var _phase: float = 0.0
var _mode: int = 0 # 0 patrol, 1 windup, 2 charge, 3 recover
var _timer: float = 0.0

func _ready() -> void:
	hp = 2
	super._ready()
	_origin_x = global_position.x

func _build_body() -> void:
	_add_box(BODY_SIZE)
	visual = preload("res://src/entities/enemies/thornmite_visual.gd").new()
	visual.thornmite = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	_phase += delta * (7.0 if _mode == 2 else 3.8)
	velocity.y = minf(velocity.y + Balance.RUNNER_GRAVITY * delta,
		Balance.RUNNER_TERMINAL_VELOCITY)

	match _mode:
		0:
			velocity.x = float(direction) * WALK_SPEED
			if _runner_ahead():
				_mode = 1
				_timer = WINDUP_TIME
				velocity.x = 0.0
		1:
			velocity.x = move_toward(velocity.x, 0.0, CHARGE_SPEED * delta * 5.0)
			_timer -= delta
			if _timer <= 0.0:
				_mode = 2
				_timer = CHARGE_TIME
		2:
			velocity.x = float(direction) * CHARGE_SPEED
			_timer -= delta
			if _timer <= 0.0:
				_start_recover()
		3:
			velocity.x = move_toward(velocity.x, 0.0, CHARGE_SPEED * delta * 3.5)
			_timer -= delta
			if _timer <= 0.0:
				_mode = 0

	move_and_slide()

	if is_on_wall():
		direction = -direction
		_start_recover()
	elif is_on_floor() and not _ground_ahead():
		direction = -direction
		_start_recover()
	elif _mode == 0 and absf(global_position.x - _origin_x) > patrol_half_width:
		direction = -1 if global_position.x > _origin_x else 1

func _runner_ahead() -> bool:
	if runner == null or not is_instance_valid(runner) or runner.state == Runner.State.DEAD:
		return false
	var delta := runner.global_position - global_position
	if absf(delta.y) > ALERT_Y or absf(delta.x) > ALERT_X:
		return false
	return signf(delta.x) == float(direction)

func _ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var half := BODY_SIZE * 0.5
	var from := global_position + Vector2(float(direction) * (half.x + 5.0), half.y - 3.0)
	var query := PhysicsRayQueryParameters2D.create(
		from, from + Vector2(0.0, 18.0), 1 | 8, [get_rid()])
	return not space.intersect_ray(query).is_empty()

func _start_recover() -> void:
	if _mode != 3:
		_mode = 3
		_timer = RECOVER_TIME

func phase() -> float:
	return _phase

func mode() -> int:
	return _mode
