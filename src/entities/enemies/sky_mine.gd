class_name SkyMine
extends Enemy
## A spiked orb that drifts in place and, every few seconds, bristles: its
## spikes shoot out and its hurt area nearly doubles for a moment.
##
## Everything it does is a function of the stage clock, so the guest's copy is
## where the host's is without being sent. It cannot be stomped (no enemy can);
## the guardian's shot is the answer.

@export var bob: Vector2 = Vector2(0, 40)
@export var period: float = 3.2
@export var phase_offset: float = 0.0
const SIZE := Vector2(40, 40)
const BRISTLE := 0.7
const ALERT := 0.6

var _origin: Vector2 = Vector2.ZERO
var _rect: RectangleShape2D = null

func _ready() -> void:
	hp = 1
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
	var t := Clock.seconds_at(Clock.tick, phase_offset)
	global_position = _origin + bob * sin(t * TAU / (period * 2.0))
	_rect.size = SIZE * (1.8 if mode() == 2 else 1.0)
	queue_redraw()

## 0 drifting, 1 about to bristle, 2 bristling.
func mode() -> int:
	var c := fposmod(Clock.seconds_at(Clock.tick, phase_offset), period)
	if c > period - BRISTLE:
		return 2
	if c > period - BRISTLE - ALERT:
		return 1
	return 0

func _draw() -> void:
	if has_meta("model_3d"):
		return
	draw_circle(Vector2.ZERO, SIZE.x * (0.9 if mode() == 2 else 0.5), Color("3a3a44"))
