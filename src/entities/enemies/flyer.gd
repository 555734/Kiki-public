class_name Flyer
extends Enemy
## The airborne enemy from stage 1-2 ("look out above"). Deliberately *not*
## stompable: it is the first threat the runner cannot solve alone, which is
## what forces the first real "shoot that for me" exchange.

@export var patrol_half_width: float = 190.0
var direction: int = -1
var _origin: Vector2 = Vector2.ZERO
var _phase: float = 0.0

func _ready() -> void:
	hp = Balance.FLYER_HP
	super._ready()
	collision_mask = 0   # flies over terrain
	_origin = global_position
	_phase = randf() * TAU

func _build_body() -> void:
	_add_box(Balance.FLYER_SIZE)
	visual = preload("res://src/entities/enemies/flyer_visual.gd").new()
	visual.flyer = self
	add_child(visual)

func _physics_process(delta: float) -> void:
	_phase += delta * 3.0
	var x := global_position.x + float(direction) * Balance.FLYER_SPEED * delta
	if absf(x - _origin.x) > patrol_half_width:
		direction = -direction
		x = global_position.x
	global_position = Vector2(x, _origin.y + sin(_phase) * Balance.FLYER_AMPLITUDE)

func phase() -> float:
	return _phase
