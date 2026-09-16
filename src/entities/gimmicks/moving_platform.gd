class_name MovingPlatform
extends AnimatableBody2D
## A patrolling solid. AnimatableBody2D with sync_to_physics is what carries the
## runner correctly; a StaticBody2D moved by hand would slide out from under
## them. Stage 1-2 pairs one of these with a turret so the guardian has to
## choose between shooting and building while the floor is moving.

@export var span: Vector2 = Vector2(150, 26)
@export var travel: Vector2 = Vector2(220, 0)
@export var speed: float = Balance.MOVING_PLATFORM_SPEED

@export var phase_offset: float = 0.0

var _origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	collision_layer = 1   # terrain, so everything already treats it as ground
	collision_mask = 0
	sync_to_physics = true
	z_index = 4
	_origin = global_position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	shape.shape = rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	global_position = position_at(Clock.tick)

## Where this platform is at a given tick. A pure function of the tick, which is
## the whole point: both devices can evaluate it and get the same answer, so a
## moving platform costs zero bytes per frame on the wire. It used to accumulate
## `delta`, which drifts apart the moment one device drops a frame.
func position_at(at_tick: int) -> Vector2:
	var length := travel.length()
	if length < 1.0:
		return _origin
	var t := Clock.seconds_at(at_tick, phase_offset) * speed / length
	# Ease at the ends so riders are not flung off at the turnaround.
	var s := 0.5 - 0.5 * cos(t * TAU * 0.5)
	return _origin + travel * s

func _draw() -> void:
	var r := Rect2(-span * 0.5, span)
	if Balance.USE_TEXTURES and Art.draw_stretched(self, "moving_platform", r):
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - 4.0, r.size.x, 4.0),
			Color(0.10, 0.09, 0.08, 0.35))
		return
	DrawUtil.rounded_rect(self, r, 7.0, Color("6b7a8c"))
	DrawUtil.rounded_rect(self, Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 8)), 4.0,
		Color("93a3b5"))
	for i in range(int(span.x / 26.0)):
		var x := r.position.x + 14.0 + float(i) * 26.0
		draw_circle(Vector2(x, r.position.y + r.size.y - 7.0), 2.6, Color("4c5866"))
