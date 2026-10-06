class_name WarpGate
extends Node2D
## A painted stone portal that sends the runner to its partner.
##
## Only the host moves the runner, exactly like the guardian's hologram warp
## (Guardian._service_warp): the guest sees the jump in the next snapshot, and
## client_session already snaps rather than interpolates any runner move longer
## than TELEPORT_PX, so the exit must be further away than that.

@export var size: Vector2 = Vector2(90, 120)
## Where this mouth delivers the runner, in world space.
@export var exit: Vector2 = Vector2.ZERO
## A one-way gate still draws its exit mouth; only the entry is live.
@export var is_exit: bool = false
## 1-5 for a gate in a row of several: a colour and a count of pips, shown on
## the entry and on the exit it leads to, so a pair can learn which mouth goes
## where. 0 is an unmarked gate.
@export var mark: int = 0

## One colour per mark, far enough apart to tell at a glance.
const MARK_COLOURS := [Color("ffffff"), Color("e8574f"), Color("f2b33d"),
	Color("62c46b"), Color("4f9de8"), Color("b57be8")]

var runner: Node2D = null
var _cooldown: float = 0.0

## Builds this piece from a stage's gimmick spec ("warp" / "warp_exit"). The spec is
## parsed here, next to the fields it fills, so a default lives in one place.
static func from_spec(spec: Dictionary, runner: Runner) -> Node2D:
	var portal := WarpGate.new()
	portal.runner = runner
	portal.is_exit = String(spec.get("type")) == "warp_exit"
	portal.exit = spec.get("exit", Vector2.ZERO)
	portal.size = spec.get("size", Vector2(90, 120))
	portal.mark = int(spec.get("mark", 0))
	return portal

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_exit or not Clock.is_host or _cooldown > 0.0:
		return
	if runner == null or not is_instance_valid(runner):
		return
	if not Rect2(global_position - size * 0.5, size).has_point(runner.global_position):
		return
	var from := runner.global_position
	runner.global_position = exit
	_cooldown = Balance.WARP_COOLDOWN
	Events.runner_warped.emit(from, exit)

func _draw() -> void:
	if has_meta("model_3d"):
		return
	if (Art.style(self) == "cave"):
		_draw_cave()
		_draw_mark()
		return
	if (Art.style(self) == "tower") and Art.draw_stretched(self, "s17_warp_exit" if is_exit else "s17_warp", Rect2(-size * 0.5, size)):
		_draw_mark()
		return
	if (Art.style(self) == "tower"):
		var frame := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y)
		DrawUtil.rounded_rect(self, frame.grow(7), 23, Color("6b6057"))
		DrawUtil.rounded_rect(self, frame, 20, Color("b8a17c"))
		DrawUtil.rounded_rect(self, frame.grow(-9), 14,
			Color("756787") if not is_exit else Color("718e92"))
		draw_arc(Vector2.ZERO, size.x * 0.28, 0, TAU, 32,
			Color("cbbbd5", 0.55) if not is_exit else Color("b6d5d0", 0.55), 3.0, true)
		_draw_mark()
		return
	var c := (Color("8c82a5") if not is_exit else Color("a69b79")) \
		if (Art.style(self) == "tower") else (Color("7fb8ff") if not is_exit else Color("ffd46b"))
	draw_rect(Rect2(-size * 0.5, size), Color(c.r, c.g, c.b, 0.35))
	draw_rect(Rect2(-size * 0.5, size), c, false, 3.0)
	_draw_mark()

func _ready() -> void:
	Art.bind_style(self)

## The cave has no painted portal: a ring of crystal round a dark mouth.
func _draw_cave() -> void:
	var r := minf(size.x, size.y) * 0.5
	var glow: Color = MARK_COLOURS[mark] if mark > 0 else Color("8fd3d6")
	draw_circle(Vector2.ZERO, r * 1.05, Color("2c2733"))
	draw_circle(Vector2.ZERO, r * 0.82, Color(glow.r * 0.35, glow.g * 0.35, glow.b * 0.40))
	draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 32, Color(glow, 0.55 if is_exit else 0.85), 3.0, true)
	for i in 8:
		var a := float(i) * TAU / 8.0 + 0.2
		var at := Vector2(cos(a), sin(a)) * r * 0.95
		var tip := at + Vector2(cos(a), sin(a)) * r * 0.32
		var side := Vector2(-sin(a), cos(a)) * r * 0.13
		draw_colored_polygon(PackedVector2Array([at - side, tip, at + side]),
			Color("9fe0e3") if i % 2 == 0 else Color("6fb7c4"))

## The mark: a coloured rim and dice pips over the mouth.
func _draw_mark() -> void:
	if mark <= 0:
		return
	var c: Color = MARK_COLOURS[clampi(mark, 1, 5)]
	var frame := Rect2(-size * 0.5, size)
	draw_rect(frame.grow(3.0), Color(c, 0.85), false, 4.0)
	var centre := Vector2(0, -size.y * 0.5 - 22.0)
	DrawUtil.rounded_rect(self, Rect2(centre - Vector2(22, 18), Vector2(44, 36)), 8.0, Color("2b2530", 0.92))
	draw_rect(Rect2(centre - Vector2(22, 18), Vector2(44, 36)), c, false, 2.0)
	for pip in _pips(mark):
		draw_circle(centre + pip * 10.0, 4.2, c)

static func _pips(n: int) -> Array[Vector2]:
	match n:
		1: return [Vector2.ZERO]
		2: return [Vector2(-1, -1), Vector2(1, 1)]
		3: return [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)]
		4: return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	return [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)]

