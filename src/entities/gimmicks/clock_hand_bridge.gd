class_name ClockHandBridge
extends AnimatableBody2D
## A broad clock hand the runner can ride. Its angle is derived from Clock.tick
## on both peers; the moving collision body carries the runner with it.

@export var length: float = 225.0
@export var period: float = 4.2
@export var phase_offset: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, 26)
	shape.shape = rect
	shape.position = Vector2(length * 0.5, 0)
	add_child(shape)

func angle_at(at_tick: int) -> float:
	return sin(Clock.seconds_at(at_tick, phase_offset) * TAU / period) * 0.24

func _physics_process(_delta: float) -> void:
	rotation = angle_at(Clock.tick)

func _draw() -> void:
	if has_meta("model_3d"):
		return
	var body := Rect2(0, -13, length, 26)
	draw_rect(body, Color("77664f"))
	draw_rect(Rect2(0, -13, length, 7), Color("c5ab79"))
	draw_rect(Rect2(0, 8, length, 5), Color("544d46"))
	for x in range(35, int(length) - 15, 46):
		draw_circle(Vector2(float(x), 0), 3.0, Color("e1cfaa"))
	draw_circle(Vector2.ZERO, 29, Color("5c5752"))
	draw_circle(Vector2.ZERO, 24, Color("b09868"))
	draw_circle(Vector2.ZERO, 12, Color("678d95"))
	draw_circle(Vector2.ZERO, 5, Color("d5e7e5"))
