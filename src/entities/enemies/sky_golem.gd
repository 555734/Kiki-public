class_name SkyGolem
extends Enemy
## A stone guardian that paces its island and stops to stomp. While stomping it
## stands still and its hurt box spreads along the ground, so crossing its
## island is a matter of when, not just where. Three shots put it down.
##
## Its walk is a pure function of the stage clock (a triangle wave with a pause
## at each end), so it needs no snapshot entry until it dies.

@export var patrol: float = 120.0
@export var period: float = 6.0
@export var phase_offset: float = 0.0
## How big this one is. 1-9's guardian of the castle door stands taller than
## any jump, so the only way past it is the guardian's flick.
@export var size_scale: float = 1.0
const BASE_SIZE := Vector2(62, 70)
var SIZE := BASE_SIZE
const STOMP := 0.9

var _origin: Vector2 = Vector2.ZERO
var _rect: RectangleShape2D = null
var direction: int = 1

func _ready() -> void:
	Art.bind_style(self)
	hp = 3
	super._ready()
	collision_mask = 0
	_origin = global_position

func is_flickable() -> bool:
	return true

func hand_radius() -> float:
	return 84.0 * maxf(1.0, size_scale * 0.7)

func _build_body() -> void:
	SIZE = BASE_SIZE * size_scale
	var shape := CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = SIZE
	shape.shape = _rect
	add_child(shape)

func _physics_process(_delta: float) -> void:
	var c := fposmod(Clock.seconds_at(Clock.tick, phase_offset), period)
	var walk := period * 0.5 - STOMP
	var half := period * 0.5
	var leg := fposmod(c, half)
	var outbound := c < half
	var f := clampf(leg / maxf(0.01, walk), 0.0, 1.0)
	var x := lerpf(-patrol, patrol, f) if outbound else lerpf(patrol, -patrol, f)
	queue_redraw()
	direction = 1 if outbound else -1
	global_position = _origin + Vector2(x, 0)
	_rect.size = Vector2(SIZE.x * (2.4 if stomping() else 1.0), SIZE.y)

func stomping() -> bool:
	var leg := fposmod(Clock.seconds_at(Clock.tick, phase_offset), period * 0.5)
	return leg > period * 0.5 - STOMP

## Flicked: it is knocked off its feet, so the picture changes once as it goes.
func flick(dir: Vector2) -> void:
	super.flick(dir)
	queue_redraw()

func _draw() -> void:
	if has_meta("model_3d"):
		return
	if Art.style(self) == "castle":
		_draw_castle()
		return
	if (Art.style(self) == "skyward_ruins") or (Art.style(self) == "sea") or (Art.style(self) == "swamp"):
		var drawn_size := SIZE * Vector2(2.4 if stomping() else 1.0, 1.0)
		if Art.draw_stretched(self, ("s15_lava_golem" if (Art.style(self) == "swamp") else ("s13_golem_attack" if stomping() else "s13_golem_move")), Rect2(-drawn_size * 0.5, drawn_size)):
			return
	draw_rect(Rect2(-SIZE * 0.5, SIZE), Color("8a8f96"))

## 1-9's guardian of the castle door: a knight of grey stone blocks with a
## glowing gem in its chest and a shield as big as the runner, facing the road.
## Knocked flying, it throws its arms out and its eyes go to crosses.
func _draw_castle() -> void:
	var hit := hp <= 0
	var box := Rect2(-SIZE * 0.5, SIZE)
	var key := "castle_golem_hit" if hit else "castle_golem_idle"
	if Art.draw_stretched_flipped(self, key, box.grow_individual(SIZE.x * 0.35, SIZE.y * 0.12, SIZE.x * 0.35, 0.0), false):
		return
	var line := Color("3b2a1e")
	var stone := Color("a6a8a3")
	var dark := Color("7d8079")
	var moss := Color("6aa84f")
	var u := SIZE / Vector2(62, 70)
	var o := box.position
	var stomp := 6.0 * u.y if stomping() and not hit else 0.0
	# Legs.
	for lx in [10.0, 36.0]:
		var leg := Rect2(o + Vector2(lx, 50) * u, Vector2(16, 20) * u)
		draw_rect(leg, dark)
		draw_rect(leg, line, false, 4.0)
	# Body.
	var body := Rect2(o + Vector2(6, 22) * u + Vector2(0, stomp), Vector2(50, 32) * u)
	draw_rect(body, stone)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 6.0 * u.y)), Color(1, 1, 1, 0.18))
	draw_line(body.position + Vector2(body.size.x * 0.5, 0), body.position + Vector2(body.size.x * 0.5, body.size.y), dark, 3.0)
	draw_line(body.position + Vector2(0, body.size.y * 0.5), body.end - Vector2(0, body.size.y * 0.5), dark, 3.0)
	draw_rect(body, line, false, 5.0)
	draw_circle(body.position + Vector2(body.size.x * 0.78, body.size.y * 0.2), 5.0 * u.x, moss)
	# The gem.
	var gem := body.get_center() + Vector2(0, -2.0 * u.y)
	draw_circle(gem, 9.0 * u.x, Color(0.4, 0.8, 1.0, 0.35))
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -6) * u, gem + Vector2(5, 0) * u,
		gem + Vector2(0, 6) * u, gem + Vector2(-5, 0) * u]), Color("5fd0ff"))
	# Head.
	var head := Rect2(o + Vector2(17, 2) * u + Vector2(0, stomp), Vector2(28, 21) * u)
	draw_rect(head, stone)
	draw_rect(head, line, false, 5.0)
	# It guards the door: it always faces the road the runner comes up.
	var face := -1.0
	for ex in [-5.0, 5.0]:
		var eye := head.get_center() + Vector2(ex + face * 3.0, 1.0) * u
		if hit:
			draw_line(eye - Vector2(4, 4) * u.x, eye + Vector2(4, 4) * u.x, line, 4.0)
			draw_line(eye + Vector2(-4, 4) * u.x, eye + Vector2(4, -4) * u.x, line, 4.0)
		else:
			draw_circle(eye, 3.6 * u.x, Color("7fe0ff"))
			draw_circle(eye, 1.6 * u.x, Color.WHITE)
	# Arms and the shield, on the side facing the road.
	if hit:
		for side in [-1.0, 1.0]:
			DrawUtil.limb(self, body.get_center() + Vector2(side * 22.0, -10.0) * u,
				body.get_center() + Vector2(side * 42.0, -30.0) * u, 11.0 * u.x, dark)
		return
	var shield := Rect2(Vector2(face * 22.0 - 12.0, -8.0) * u + Vector2(0, stomp), Vector2(24, 40) * u)
	DrawUtil.rounded_rect(self, shield.grow(3.0), 10.0 * u.x, line)
	DrawUtil.rounded_rect(self, shield, 9.0 * u.x, Color("c2b48d"))
	draw_circle(shield.get_center(), 6.0 * u.x, Color("d8433b"))
	draw_arc(shield.get_center(), 6.0 * u.x, 0.0, TAU, 16, line, 3.0)
