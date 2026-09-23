class_name SkyGolem
extends Enemy
## A stone guardian that paces its island and stops to stomp. While stomping it
## stands still and its hurt box spreads along the ground, so crossing its
## island is a matter of when, not just where. Three shots put it down.
##
## Its walk is a pure function of the stage clock (a triangle wave with a pause
## at each end), so it needs no snapshot entry until it dies.

@export var patrol: float = 120.0
@export var period: float = 6.0
@export var phase_offset: float = 0.0
const SIZE := Vector2(62, 70)
const STOMP := 0.9

var _origin: Vector2 = Vector2.ZERO
var _rect: RectangleShape2D = null
var direction: int = 1

func _ready() -> void:
	hp = 3
	super._ready()
	collision_mask = 0
	_origin = global_position

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = SIZE
	shape.shape = _rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	var c := fposmod(Clock.seconds_at(Clock.tick, phase_offset), period)
	var walk := period * 0.5 - STOMP
	var half := period * 0.5
	var leg := fposmod(c, half)
	var outbound := c < half
	var f := clampf(leg / maxf(0.01, walk), 0.0, 1.0)
	var x := lerpf(-patrol, patrol, f) if outbound else lerpf(patrol, -patrol, f)
	direction = 1 if outbound else -1
	global_position = _origin + Vector2(x, 0)
	_rect.size = Vector2(SIZE.x * (2.4 if stomping() else 1.0), SIZE.y)

func stomping() -> bool:
	var leg := fposmod(Clock.seconds_at(Clock.tick, phase_offset), period * 0.5)
	return leg > period * 0.5 - STOMP

func _draw() -> void:
	if has_meta("model_3d"):
		return
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color("8a8f96"))
