class_name CaveTrap
extends Area2D
## A rolling boulder or dropping stalactite, driven only by the shared clock.

@export_enum("boulder", "stalactite") var kind := "boulder"
@export var travel := 145.0
@export var period := 3.5
@export var phase_offset := 0.0

var _shape: CollisionShape2D
## The guardian's hand can press it still (GuardianHand). Numbered by the
## builder in spec order, the same on both devices, so a hold can name it.
var hand_id: int = -1
var hold := HoldTimeline.new(Balance.HOLD_MAX_SECONDS)

## Builds this piece from a stage's gimmick spec ("cave_trap"). The spec is
## parsed here, next to the fields it fills, so a default lives in one place.
static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var trap := CaveTrap.new()
	trap.kind = String(spec.get("kind", "boulder"))
	trap.travel = float(spec.get("travel", 145.0))
	trap.period = float(spec.get("period", 3.5))
	trap.phase_offset = float(spec.get("phase", 0.0))
	return trap

func _ready() -> void:
	Art.bind_style(self)
	add_to_group("instant_death")
	add_to_group("hand_holdable")
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

## Where a finger has to land to press it still.
func hand_grab_at(world: Vector2) -> bool:
	var head := global_position + head_at(Clock.tick)
	return world.distance_to(head) <= (62.0 if kind == "boulder" else 52.0)

func hand_point() -> Vector2:
	return global_position + head_at(Clock.tick)

## Held still by the hand from `tick` / let go at `tick`. Host-decided; the
## other device hears it from the packet (Protocol.hold).
func hold_begin(tick: int) -> void:
	hold.begin(tick)
	queue_redraw()

func hold_end(tick: int) -> void:
	hold.end(tick)
	queue_redraw()

## Still a pure function of the tick: the shared clock minus whatever time the
## hand held it, which the host decided and both devices know.
func head_at(at_tick: int) -> Vector2:
	var t := Clock.seconds_at(hold.local_tick(at_tick), phase_offset)
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
	if hold.held_at(Clock.tick):
		# Pressed still: it strains against the finger.
		at += Vector2(sin(float(Clock.tick) * 1.7) * 1.5, 0)
		draw_arc(at, 50.0, 0, TAU, 32, Color(Balance.C_HOLO, 0.55), 3.0, true)
	if kind != "boulder":
		var beat := fposmod(Clock.seconds_at(hold.local_tick(Clock.tick), phase_offset) / period, 1.0)
		# The shared clock warns before the falling stone reaches the lane.
		if beat >= 0.10 and beat < 0.30:
			var target := Vector2(0, travel + 40)
			draw_line(target - Vector2(28, 0), target + Vector2(28, 0), Color("ffb64d"), 4.0, true)
			draw_colored_polygon(PackedVector2Array([target + Vector2(-8, -18), target + Vector2(8, -18), target + Vector2(0, -5)]), Color("ffb64d"))
	if Art.style(self) == "castle" and kind == "boulder":
		if Art.draw_stretched(self, "castle_boulder", Rect2(at - Vector2(41, 41), Vector2(82, 82))) \
				or Art.draw_stretched(self, "s18_boulder", Rect2(at - Vector2(39, 39), Vector2(78, 78))):
			return
	if (Art.style(self) == "cave"):
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
