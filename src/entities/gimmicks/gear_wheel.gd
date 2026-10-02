class_name GearWheel
extends AnimatableBody2D
## A slow four-spoke gear. The tangential decks are real moving colliders,
## allowing the runner to ride the wheel around to the next tower landing.

@export var radius: float = 98.0
@export var angular_speed: float = 0.30
@export var phase_offset: float = 0.0
@export var direction: int = 1

const DECK := Vector2(116, 22)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	z_index = 4
	for i in 4:
		var angle := float(i) * PI * 0.5
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = DECK
		shape.shape = rect
		shape.position = Vector2(sin(angle), -cos(angle)) * radius
		shape.rotation = angle
		add_child(shape)

func angle_at(at_tick: int) -> float:
	return Clock.seconds_at(at_tick, phase_offset) * angular_speed * float(direction)

func _physics_process(_delta: float) -> void:
	rotation = angle_at(Clock.tick)

func _draw() -> void:
	if has_meta("model_3d"):
		return
	var rim := PackedVector2Array()
	for i in 96:
		var a := float(i) * TAU / 96.0
		var r := radius * (1.06 if i % 8 in [2, 3, 4, 5] else 0.91)
		rim.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(rim, Color("8b7455"))
	draw_circle(Vector2.ZERO, radius * 0.82, Color("594e45"))
	draw_arc(Vector2.ZERO, radius * 0.80, 0, TAU, 64,
		Color("c4a979"), 11.0, true)
	draw_arc(Vector2.ZERO, radius * 0.67, 0, TAU, 64,
		Color("997e5b"), 4.0, true)
	for i in 4:
		var a := float(i) * PI * 0.5
		var outward := Vector2(sin(a), -cos(a))
		var at := outward * radius
		draw_line(Vector2.ZERO, at, Color("ccb080"), 11.0)
		draw_set_transform(at, a, Vector2.ONE)
		draw_rect(Rect2(-DECK * 0.5, DECK), Color("655849"))
		draw_rect(Rect2(-DECK.x * 0.5, -DECK.y * 0.5, DECK.x, 7),
			Color("e0c89e"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 23, Color("665d52"))
	draw_circle(Vector2.ZERO, 14, Color("7b9fa0"))
	draw_circle(Vector2.ZERO, 5, Color("dae4da"))
