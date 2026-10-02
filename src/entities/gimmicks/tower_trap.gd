class_name TowerTrap
extends Area2D
## Three clockwork hazards share a deterministic phase: hanging pendulum,
## vertical piston, and retractable wall spikes. All kill on touch.

@export_enum("pendulum", "piston", "spikes") var kind: String = "pendulum"
@export var length: float = 235.0
@export var travel: float = 150.0
@export var period: float = 3.6
@export var phase_offset: float = 0.0
@export var facing: int = 1

var _shape: CollisionShape2D = null

func _ready() -> void:
	add_to_group("instant_death")
	collision_layer = Hazard.LAYER_HAZARD
	collision_mask = 0
	z_index = 5
	_shape = CollisionShape2D.new()
	if kind == "pendulum":
		var ball := CircleShape2D.new()
		ball.radius = 31
		_shape.shape = ball
	else:
		var head := RectangleShape2D.new()
		head.size = Vector2(94, 44) if kind == "piston" else Vector2(75, 90)
		_shape.shape = head
	add_child(_shape)

func extension_at(at_tick: int) -> float:
	var phase := fposmod(Clock.seconds_at(at_tick, phase_offset) / period, 1.0)
	# Pause at both ends, giving the player a visible safe and dangerous beat.
	if phase < 0.30:
		return 0.0
	if phase < 0.48:
		return (phase - 0.30) / 0.18
	if phase < 0.68:
		return 1.0
	if phase < 0.86:
		return 1.0 - (phase - 0.68) / 0.18
	return 0.0

func head_at(at_tick: int) -> Vector2:
	if kind == "pendulum":
		var a := sin(Clock.seconds_at(at_tick, phase_offset) * TAU / period) * 0.72
		return Vector2(sin(a), cos(a)) * length
	if kind == "piston":
		return Vector2(0, extension_at(at_tick) * travel)
	return Vector2(float(facing) * extension_at(at_tick) * travel, 0)

func _physics_process(_delta: float) -> void:
	_shape.position = head_at(Clock.tick)
	var safe := kind == "spikes" and extension_at(Clock.tick) < 0.28
	if _shape.disabled != safe:
		_shape.set_deferred("disabled", safe)
	queue_redraw()

func _draw() -> void:
	if has_meta("model_3d"):
		return
	var head := head_at(Clock.tick)
	match kind:
		"pendulum":
			draw_line(Vector2.ZERO, head, Color("5e5b57"), 10.0)
			draw_line(Vector2.ZERO, head, Color("a79470"), 4.0)
			draw_circle(Vector2.ZERO, 14, Color("ae9466"))
			draw_circle(head, 34, Color("554f4b"))
			draw_circle(head, 27, Color("a58b62"))
			draw_circle(head, 7, Color("d1ba8b"))
		"piston":
			draw_rect(Rect2(-12, -105, 24, 105 + head.y), Color("6b6760"))
			draw_rect(Rect2(-7, -100, 14, 100 + head.y), Color("b4a17d"))
			var r := Rect2(head - Vector2(47, 22), Vector2(94, 44))
			draw_rect(r, Color("a87963"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 9)), Color("d9ab88"))
			draw_rect(r, Color("69534d"), false, 3.0)
		"spikes":
			draw_rect(Rect2(-20 * facing - 8, -53, 28, 106), Color("756b5d"))
			var r := Rect2(head - Vector2(37, 45), Vector2(75, 90))
			if extension_at(Clock.tick) > 0.05:
				for i in 3:
					var y := r.position.y + 15 + float(i) * 28.0
					var root_x := r.end.x - 8 if facing > 0 else r.position.x + 8
					draw_colored_polygon(PackedVector2Array([
						Vector2(root_x, y - 11), Vector2(root_x, y + 11),
						Vector2(root_x + float(facing) * 33.0, y)]), Color("aeb4b4"))
				draw_rect(r, Color("665e58"), false, 3.0)
