class_name SkyCrow
extends Enemy
## A crow patrolling high above a side-scrolling stage.
##
## The ground route never goes this high; they are there for a runner who
## skips the stage on a staircase of guardian platforms. Movement is a pure
## function of the stage clock (both devices agree without a packet), and
## faster on harder settings. One shot drops one.

@export var patrol: float = 220.0
@export var period: float = 5.0
@export var phase_offset: float = 0.0
const SIZE := Vector2(46, 30)

var _origin: Vector2 = Vector2.ZERO
var direction: int = 1
var _flap: float = 0.0

## Crows are placed every 900px along the whole course, so 1-1 alone carries
## about seventeen of them and only one or two are ever on screen. The rest
## used to rebuild their drawing sixty times a second regardless, which cost
## 1.35ms of every frame in 1-1 without adding a single draw call -- invisible
## to a frame-time median on a desktop, and a third of a phone's budget.
##
## The flight itself still runs every tick: the position is a pure function of
## Clock.tick and both devices must agree on it. Only the REDRAW is gated.
var _seen: VisibleOnScreenNotifier2D = null

func _ready() -> void:
	hp = 1
	super._ready()
	collision_mask = 0
	_origin = global_position
	_seen = VisibleOnScreenNotifier2D.new()
	# Wider than the bird, and wider than its patrol, so it is already drawing
	# by the time it slides into view.
	_seen.rect = Rect2(-patrol - 60.0, -70.0, patrol * 2.0 + 120.0, 140.0)
	add_child(_seen)
	_seen.screen_entered.connect(queue_redraw)

func _build_body() -> void:
	_add_box(SIZE)

func _physics_process(_delta: float) -> void:
	var speed := 0.7 + 0.3 * Difficulty.chase_scale() / 1.0
	var a := Clock.seconds_at(Clock.tick, phase_offset) * TAU / period * speed
	global_position = _origin + Vector2(sin(a) * patrol, sin(a * 2.0) * 26.0)
	direction = 1 if cos(a) >= 0.0 else -1
	_flap = Clock.seconds_at(Clock.tick, phase_offset) * 9.0
	if _seen != null and _seen.is_on_screen():
		queue_redraw()

func _draw() -> void:
	var d := float(direction)
	var beat := sin(_flap)
	var body := Color("17191d")
	# Body and head.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2(-4.0 * d, 0), 15.0, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(12.0 * d, -5.0), 8.0, body)
	# Beak and eye.
	draw_colored_polygon(PackedVector2Array([Vector2(18.0 * d, -7.0),
		Vector2(28.0 * d, -3.0), Vector2(18.0 * d, -1.0)]), Color("e0a93a"))
	draw_circle(Vector2(14.0 * d, -7.0), 2.2, Color("ffcf4a"))
	# Tail.
	draw_colored_polygon(PackedVector2Array([Vector2(-16.0 * d, -2.0),
		Vector2(-30.0 * d, -8.0), Vector2(-28.0 * d, 4.0)]), body)
	# Wings, beating.
	for side in [-1.0, 1.0]:
		var tip := Vector2(-6.0 * d + side * 4.0, -4.0 + beat * 20.0 * side * -1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-10.0 * d, -2.0),
			Vector2(6.0 * d, -2.0), tip + Vector2(0, -16.0 * (1.0 if beat > 0 else 0.4))]),
			Color("22262c"))
