class_name LiftGate
extends StaticBody2D
## A portcullis nobody can open from the ground. The guardian's finger holds it
## up; the moment the finger lets go it drops -- on whatever is chasing the
## runner, if the timing is right.
##
## Where it is, like the boulders, is a pure function of the shared clock and
## of when it was held (HoldTimeline), so both devices agree at every tick
## without a position ever being sent. Spec ("lift_gate"): "pos" is the middle
## of its foot, on the ground; "height" how tall it stands.

## How tall the bars are, and how much of that has to be clear above the
## ground before a runner fits under.
@export var height: float = 420.0
const WIDTH: float = 56.0
const RUNNER_CLEARANCE: float = 70.0

var hand_id: int = -1
var hold := HoldTimeline.new(Balance.LIFT_GATE_MAX_HOLD)
var _shape: CollisionShape2D
var _box: RectangleShape2D

static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var gate := LiftGate.new()
	gate.height = float(spec.get("height", 420.0))
	return gate

func _ready() -> void:
	Art.bind_style(self)
	add_to_group("lift_gate")
	add_to_group("hand_holdable")
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	_box = RectangleShape2D.new()
	_box.size = Vector2(WIDTH - 8.0, height)
	_shape = CollisionShape2D.new()
	_shape.shape = _box
	add_child(_shape)
	_sync(Clock.tick)

## 0 shut, 1 fully up.
func lift_at(tick: int) -> float:
	return hold.lift_at(tick, Clock.ticks_for(Balance.LIFT_GATE_RISE),
		Clock.ticks_for(Balance.LIFT_GATE_DROP))

## How far the bars' foot is above the ground at `tick`.
func raised_at(tick: int) -> float:
	return lift_at(tick) * (height - 40.0)

## Whether something on the ground could get past at `tick`.
func passable_at(tick: int) -> bool:
	return raised_at(tick) >= RUNNER_CLEARANCE

func hand_grab_at(world: Vector2) -> bool:
	var raised := raised_at(Clock.tick)
	var rect := Rect2(global_position + Vector2(-WIDTH * 0.5, -height - raised),
		Vector2(WIDTH, height)).grow(26.0)
	return rect.has_point(world)

func hand_point() -> Vector2:
	return global_position + Vector2(0, -RUNNER_CLEARANCE - raised_at(Clock.tick))

func hold_begin(tick: int) -> void:
	hold.begin(tick)

func hold_end(tick: int) -> void:
	hold.end(tick)

## Where something moving from `from_x` to `to_x` at height `y` has to stop,
## because a shut gate is in the way -- or INF if nothing stops it. Used by the
## pursuer, which flies through everything else.
static func stop_x(tree: SceneTree, from_x: float, to_x: float, y: float, tick: int,
		margin: float) -> float:
	for node in tree.get_nodes_in_group("lift_gate"):
		var gate := node as LiftGate
		var gx := gate.global_position.x
		if y < gate.global_position.y - gate.height or y > gate.global_position.y + 20.0:
			continue
		if gate.passable_at(tick):
			continue
		var side := signf(to_x - from_x)
		if side == 0.0:
			continue
		var stop := gx - side * margin
		if (from_x - stop) * side <= 0.0 and (to_x - stop) * side > 0.0:
			return stop
	return INF

func _physics_process(_delta: float) -> void:
	_sync(Clock.tick)

func _sync(tick: int) -> void:
	var raised := raised_at(tick)
	_shape.position = Vector2(0, -height * 0.5 - raised)
	queue_redraw()

func _draw() -> void:
	var raised := raised_at(Clock.tick)
	if Art.style(self) == "castle" and _draw_castle(raised):
		return
	# The stone frame does not move: two posts and a lintel the bars hang from.
	var post := Color("4a4f57")
	var post_hi := Color("6b717a")
	draw_rect(Rect2(-WIDTH * 0.5 - 26, -height - 46, 22, height + 46), post)
	draw_rect(Rect2(WIDTH * 0.5 + 4, -height - 46, 22, height + 46), post)
	draw_rect(Rect2(-WIDTH * 0.5 - 34, -height - 70, WIDTH + 68, 30), post_hi)
	draw_rect(Rect2(-WIDTH * 0.5 - 34, -height - 70, WIDTH + 68, 30), Color(0, 0, 0, 0.35), false, 3.0)
	var bars := Rect2(-WIDTH * 0.5, -height - raised, WIDTH, height)
	if not Art.draw_stretched(self, "keeper_portcullis", bars):
		var iron := Color("2c2f36")
		for i in 5:
			var x := bars.position.x + 6.0 + float(i) * (WIDTH - 12.0) / 4.0
			draw_line(Vector2(x, bars.position.y), Vector2(x, bars.end.y), iron, 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, bars.end.y),
				Vector2(x + 5, bars.end.y), Vector2(x, bars.end.y + 14)]), iron)
		for j in 4:
			var y := bars.position.y + 30.0 + float(j) * (height - 60.0) / 3.0
			draw_rect(Rect2(bars.position.x, y, WIDTH, 10), iron)
	if hold.held_at(Clock.tick):
		draw_rect(bars.grow(6.0), Color(Balance.C_HOLO, 0.45), false, 3.0)

## 1-9's portcullis, painted, in the gatehouse CastleSet draws round it: as
## wide as the archway (wider than the bars' own box, which is all that stops
## the hound).
const CASTLE_BARS_W := 128.0

func _draw_castle(raised: float) -> bool:
	var t := Art.tex("castle_gate_bars")
	if t == null:
		return false
	var bars := Rect2(-CASTLE_BARS_W * 0.5, -height - raised, CASTLE_BARS_W, height)
	draw_texture_rect(t, bars, false)
	if hold.held_at(Clock.tick):
		draw_rect(bars.grow(6.0), Color(Balance.C_HOLO, 0.45), false, 3.0)
	return true
