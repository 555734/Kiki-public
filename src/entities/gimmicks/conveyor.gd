class_name Conveyor
extends StaticBody2D
## An arrow belt that carries whoever stands on it, and turns round now and then.
##
## The carry is the physics engine's own: a StaticBody2D's
## constant_linear_velocity is what a CharacterBody2D standing on it inherits,
## so nothing in the runner needs to know conveyors exist. Direction is a pure
## function of the stage clock, with the arrows flashing before each reversal.

@export var span: Vector2 = Vector2(220, 26)
@export var speed: float = 150.0
## Seconds between reversals; 0 never reverses.
@export var flip_every: float = 0.0
@export var start_direction: int = 1
@export var phase_offset: float = 0.0
const WARN := 0.6

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	shape.shape = rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	constant_linear_velocity = Vector2(float(direction_at(Clock.tick)) * speed, 0.0)
	queue_redraw()

func direction_at(at_tick: int) -> int:
	if flip_every <= 0.0:
		return start_direction
	var n := int(floor(Clock.seconds_at(at_tick, phase_offset) / flip_every))
	return start_direction if n % 2 == 0 else -start_direction

func warning() -> bool:
	if flip_every <= 0.0:
		return false
	var t := fposmod(Clock.seconds_at(Clock.tick, phase_offset), flip_every)
	return t > flip_every - WARN

func _draw() -> void:
	if has_meta("model_3d"):
		return
	draw_rect(Rect2(-span * 0.5, span), Color("2c3448"))
	var d := float(direction_at(Clock.tick))
	var lit := Color("ffc93c") if not (warning() and int(Clock.tick / 4) % 2 == 0) else Color("ff5a3c")
	for i in int(span.x / 40.0):
		var x := -span.x * 0.5 + 20.0 + float(i) * 40.0
		draw_polyline(PackedVector2Array([Vector2(x - 6 * d, -7), Vector2(x + 6 * d, 0),
			Vector2(x - 6 * d, 7)]), lit, 3.0)
