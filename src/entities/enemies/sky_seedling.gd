class_name SkySeedling
extends Enemy
## A floating sprout that traces a lazy figure-eight across a gap, so the safe
## moment to jump moves every time. Clock-driven like SkyMine.

@export var reach: Vector2 = Vector2(150, 60)
@export var period: float = 5.0
@export var phase_offset: float = 0.0
const SIZE := Vector2(40, 40)

var _origin: Vector2 = Vector2.ZERO
var direction: int = 1

func _ready() -> void:
	hp = 1
	super._ready()
	collision_mask = 0
	_origin = global_position

func _build_body() -> void:
	_add_box(SIZE)

func _physics_process(_delta: float) -> void:
	var a := Clock.seconds_at(Clock.tick, phase_offset) * TAU / period
	global_position = _origin + Vector2(sin(a) * reach.x, sin(a * 2.0) * reach.y)
	direction = 1 if cos(a) >= 0.0 else -1

func _draw() -> void:
	if has_meta("model_3d"):
		return
	draw_circle(Vector2.ZERO, SIZE.x * 0.5, Color("8fcf4a"))
