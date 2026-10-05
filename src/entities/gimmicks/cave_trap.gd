class_name CaveTrap
extends Area2D
## A rolling boulder or dropping stalactite, driven only by the shared clock.

@export_enum("boulder", "stalactite") var kind := "boulder"
@export var travel := 145.0
@export var period := 3.5
@export var phase_offset := 0.0

var _shape: CollisionShape2D

func _ready() -> void:
	add_to_group("instant_death")
	collision_layer = Hazard.LAYER_HAZARD
	collision_mask = 0
	z_index = 5
	_shape = CollisionShape2D.new()
	if kind == "boulder":
		var circle := CircleShape2D.new()
		circle.radius = 39.0
		_shape.shape = circle
	else:
		var box := RectangleShape2D.new()
		box.size = Vector2(52, 80)
		_shape.shape = box
	add_child(_shape)

func head_at(at_tick: int) -> Vector2:
	var t := Clock.seconds_at(at_tick, phase_offset)
	if kind == "boulder":
		return Vector2(sin(t * TAU / period) * travel, 0)
	var beat := fposmod(t / period, 1.0)
	var reach := 0.0
	if beat >= 0.30 and beat < 0.46:
		reach = (beat - 0.30) / 0.16
	elif beat >= 0.46 and beat < 0.68:
		reach = 1.0
	elif beat >= 0.68 and beat < 0.90:
		reach = 1.0 - (beat - 0.68) / 0.22
	return Vector2(0, reach * travel)

func _physics_process(_delta: float) -> void:
	_shape.position = head_at(Clock.tick)
	var active_camera := get_viewport().get_camera_2d()
	if active_camera == null or absf(global_position.x - active_camera.global_position.x) < 1200.0:
		queue_redraw()

func _draw() -> void:
	var at := head_at(Clock.tick)
	if Stage.is_cave():
		var key := "s18_boulder" if kind == "boulder" else "s18_terrain_stalactite"
		var box := Rect2(at - Vector2(39, 39), Vector2(78, 78)) if kind == "boulder" else Rect2(at - Vector2(26, 40), Vector2(52, 80))
		if Art.draw_stretched(self, key, box): return
	if kind == "boulder":
		draw_circle(at, 41, Color("554840"))
		draw_circle(at + Vector2(-4, -5), 35, Color("917258"))
		draw_arc(at + Vector2(-4, -5), 29, 0, TAU, 20,
			Color("b79670"), 3.0)
		var spin := at.x / 39.0
		for offset in [Vector2(-14, -9), Vector2(11, -16), Vector2(16, 11)]:
			draw_circle(at + offset.rotated(spin), 5.0, Color("735b49"))
	else:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-30, -32), at + Vector2(30, -32),
			at + Vector2(0, 38)]), Color("8f806b"))
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-23, -26), at + Vector2(4, -26),
			at + Vector2(-2, 26)]), Color("c1a27a"))
		draw_rect(Rect2(-32, -50, 64, 14), Color("5f5b57"))
