class_name BlinkBlock
extends StaticBody2D
## Stage 1-3's dotted hologram slab: solid for one beat, gone for the next.
##
## Whether it is there is a pure function of the stage clock, so both devices
## agree without a byte on the wire -- the same property MovingPlatform has.
## Blue and purple slabs run in opposite halves of the cycle, so a pair of them
## is a staircase that only exists one step at a time.

@export var span: Vector2 = Vector2(150, 26)
## Seconds solid, then the same seconds gone.
@export var beat: float = 1.6
## 0 = blue (solid first), 1 = purple (solid second).
@export var colour: int = 0
@export var phase_offset: float = 0.0
## Warning before it vanishes: a slab that disappears without one reads as a bug.
const WARN := 0.5

var _shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	_shape.shape = rect
	add_child(_shape)

func _physics_process(_delta: float) -> void:
	var on := solid_at(Clock.tick)
	if _shape.disabled == on:
		_shape.set_deferred("disabled", not on)
	queue_redraw()

func _cycle_time(at_tick: int) -> float:
	return fposmod(Clock.seconds_at(at_tick, phase_offset) + float(colour) * beat, beat * 2.0)

func solid_at(at_tick: int) -> bool:
	return _cycle_time(at_tick) < beat

## True in the last WARN seconds before a solid slab goes.
func warning() -> bool:
	var t := _cycle_time(Clock.tick)
	return t < beat and t > beat - WARN

func _draw() -> void:
	var on := solid_at(Clock.tick)
	if has_meta("model_3d"):
		# The painted slab is 3D; while it is away, a faint dashed outline
		# says where it will come back.
		if not on:
			var ghost := Color("6fd6ff") if colour == 0 else Color("b98cff")
			ghost.a = 0.45
			var r := Rect2(-span * 0.5, span)
			for i in int(span.x / 18.0):
				var x := r.position.x + float(i) * 18.0
				draw_line(Vector2(x, r.position.y), Vector2(x + 9.0, r.position.y), ghost, 2.0)
				draw_line(Vector2(x, r.end.y), Vector2(x + 9.0, r.end.y), ghost, 2.0)
		return
	var c := Color("6fd6ff") if colour == 0 else Color("b98cff")
	c.a = 0.85 if on else 0.18
	if on and warning() and int(Clock.tick / 4) % 2 == 0:
		c.a = 0.35
	draw_rect(Rect2(-span * 0.5, span), c)
	draw_rect(Rect2(-span * 0.5, span), Color(1, 1, 1, c.a), false, 2.0)
