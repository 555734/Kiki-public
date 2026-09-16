class_name Turret
extends Enemy
## The fixed emplacement from stages 1-2 and 1-3. It fires in bursts, which is
## what makes the wall meaningful: chapter 5 describes 1-3 as "the four second
## safe zone", and four seconds is exactly one wall.

@export var aim_direction: Vector2 = Vector2.LEFT
@export var burst: int = 3

var _cooldown: float = 1.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _recoil: float = 0.0
var runner: Runner = null

func _ready() -> void:
	hp = Balance.TURRET_HP
	super._ready()
	collision_mask = 0
	_cooldown = randf_range(0.4, Balance.TURRET_FIRE_INTERVAL)

func _build_body() -> void:
	_add_box(Balance.TURRET_SIZE)
	visual = preload("res://src/entities/enemies/turret_visual.gd").new()
	visual.turret = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 5.0)
	if runner == null or not is_instance_valid(runner):
		return
	if global_position.distance_to(runner.global_position) > Balance.TURRET_RANGE:
		return

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_fire()
			_burst_left -= 1
			_burst_timer = Balance.TURRET_BURST_INTERVAL
			if _burst_left == 0:
				_cooldown = Balance.TURRET_FIRE_INTERVAL
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_burst_left = burst
		_burst_timer = 0.0

func _fire() -> void:
	_recoil = 1.0
	var shot := preload("res://src/entities/enemies/projectile.gd").new()
	shot.direction = aim_direction.normalized()
	shot.global_position = global_position + aim_direction.normalized() * 34.0
	get_parent().add_child(shot)

func recoil() -> float:
	return _recoil

## Seconds until the next shot leaves the barrel. The HUD does not show this,
## but the muzzle glow does -- the guardian is meant to read it off the artwork.
func charge() -> float:
	if _burst_left > 0:
		return clampf(1.0 - _burst_timer / maxf(Balance.TURRET_BURST_INTERVAL, 0.001), 0.0, 1.0)
	return clampf(1.0 - _cooldown / maxf(Balance.TURRET_FIRE_INTERVAL, 0.001), 0.0, 1.0)
