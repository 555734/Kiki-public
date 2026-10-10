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
## Time the guardian's hand has held it still. Only a HoldableTowerTrap can be
## held; on any other it stays empty and the clock runs straight through.
var hold := HoldTimeline.new(Balance.HOLD_MAX_SECONDS)

## Builds this piece from a stage's gimmick spec ("tower_trap"). The spec is
## parsed here, next to the fields it fills, so a default lives in one place.
static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var trap: TowerTrap = HoldableTowerTrap.new() if bool(spec.get("holdable", false)) else TowerTrap.new()
	trap.kind = String(spec.get("kind", "pendulum"))
	trap.length = float(spec.get("length", 235.0))
	trap.travel = float(spec.get("travel", 150.0))
	trap.period = float(spec.get("period", 3.6))
	trap.phase_offset = float(spec.get("phase", 0.0))
	trap.facing = int(spec.get("facing", 1))
	return trap

func _ready() -> void:
	Art.bind_style(self)
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
		# 1-9's spike block is painted bigger, its spikes underneath.
		if kind == "piston" and Art.style(self) == "castle":
			head.size = Vector2(CASTLE_BLOCK.x - 14.0, CASTLE_BLOCK.y - 10.0)
		_shape.shape = head
	add_child(_shape)

func extension_at(at_tick: int) -> float:
	var phase := fposmod(Clock.seconds_at(hold.local_tick(at_tick), phase_offset) / period, 1.0)
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
		var a := sin(Clock.seconds_at(hold.local_tick(at_tick), phase_offset) * TAU / period) * 0.72
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
	if Art.style(self) == "castle" and _draw_castle(head):
		return
	if (Art.style(self) == "tower"):
		if kind == "pendulum":
			draw_line(Vector2.ZERO, head, Color("a78955"), 6)
			if Art.draw_stretched(self, "s17_pendulum_ball", Rect2(head - Vector2.ONE * 31, Vector2.ONE * 62)): return
		elif kind == "piston":
			draw_rect(Rect2(-8, -105, 16, 105 + head.y), Color("a6b6c2"))
			if Art.draw_stretched(self, "s17_piston_head", Rect2(head - Vector2(47, 22), Vector2(94, 44))): return
		elif extension_at(Clock.tick) > 0.05:
			if Art.draw_stretched(self, "s17_spikes", Rect2(head - Vector2(37.5, 45), Vector2(75, 90))): return
		else:
			draw_rect(Rect2(-18, -45, 20, 90), Color("655d66"))
			return
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

## 1-9's spike block, painted: its stone block with spikes under it.
const CASTLE_BLOCK := Vector2(118, 96)
## 1-9's spiked ball, painted, spikes and all.
const CASTLE_BALL := 92.0

## 1-9's two: the spiked ball on its chain and the spike block hung on one.
func _draw_castle(head: Vector2) -> bool:
	var ball := Art.tex("castle_spike_ball")
	var block := Art.tex("castle_spike_block")
	if (kind == "pendulum" and ball == null) or (kind == "piston" and block == null):
		return false
	var top := Vector2.ZERO if kind == "pendulum" else Vector2(0, -400)
	var end := head if kind == "pendulum" else head - Vector2(0, CASTLE_BLOCK.y * 0.5)
	_chain(top, end)
	if kind == "pendulum":
		draw_texture_rect(ball, Rect2(head - Vector2.ONE * CASTLE_BALL * 0.5, Vector2.ONE * CASTLE_BALL), false)
	else:
		draw_texture_rect(block, Rect2(head - CASTLE_BLOCK * 0.5, CASTLE_BLOCK), false)
	if hold.held_at(Clock.tick):
		draw_arc(head, CASTLE_BALL * 0.62, 0, TAU, 36, Color(Balance.C_HOLO, 0.6), 3.0, true)
	return true

## A run of chain links from `a` to `b`, tiled along it.
func _chain(a: Vector2, b: Vector2) -> void:
	var t := Art.tex("castle_chain")
	var length := a.distance_to(b)
	if t == null or length < 1.0:
		return
	var w := 16.0
	var link := w * float(t.get_height()) / float(t.get_width())
	draw_set_transform(a, (b - a).angle() - PI * 0.5, Vector2.ONE)
	var y := 0.0
	while y < length:
		var h := minf(link, length - y)
		draw_texture_rect_region(t, Rect2(-w * 0.5, y, w, h),
			Rect2(0, 0, t.get_width(), float(t.get_height()) * h / link))
		y += link
	draw_set_transform(Vector2.ZERO)
