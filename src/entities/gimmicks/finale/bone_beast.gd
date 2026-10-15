extends FinaleMachine
## IT COMES ALIVE -> CLOSING JAWS. A long vertebra bridge over the canyon.
## Halfway across, an ancient skeletal beast erupts from below, bursting
## three vertebrae out of the deck and roaring before it sinks again: jump
## the new gap (double jump) or ride the sand geyser that blows up through
## it to the rib above. Leaving the deck wakes it for good: the jaws come up
## behind the runner at 350px/s -- faster than a run -- snapping, through the
## collapsing pillars, until the stone gate stops them and they slam shut.
##
## state 1 = erupted at placed_tick, 2 = chasing since placed_tick.

const SEG := 100.0
const DECK := 50.0
const ERUPT_UP := 0.6
const ERUPT_HOLD := 0.5
const ERUPT_DOWN := 0.9
const BREAK := 0.45
var _segments: Array[AnimatableBody2D] = []
var _gap := Vector2.ZERO
var _snapped := false

var _ribs: Node2D

func _build() -> void:
	z_index = 7
	reach = Vector2(3400, 1600)
	_ribs = Ribs.new()
	_ribs.beast = self
	_ribs.z_as_relative = false
	_ribs.z_index = 1
	add_child(_ribs)
	_gap = data.get("gap", Vector2(21900, 22200))
	var n := int((float(data.get("deck_to", 22600.0)) - global_position.x) / SEG)
	for i in n:
		var b := make_body(Vector2(SEG, DECK))
		b.position = Vector2(SEG * (float(i) + 0.5), DECK * 0.5)
		_segments.append(b)

func in_gap(i: int) -> bool:
	var x := global_position.x + SEG * (float(i) + 0.5)
	return x > _gap.x and x < _gap.y

func broken(tick: int = Clock.tick) -> bool:
	return state == 2 or (state == 1 and since(tick) >= BREAK)

func _pose(tick: int) -> void:
	var gone := broken(tick)
	for i in _segments.size():
		set_solid(_segments[i], not (gone and in_gap(i)))

func _on_state() -> void:
	_snapped = false
	if state == 1:
		sound("boom", -2.0, 1.7)
		FinaleFx.kick(14.0)
	else:
		sound("crumble", -4.0, 1.4)
		FinaleFx.kick(8.0)

## Eruption head centre (world) and how open the jaws are.
func erupt_head() -> Vector2:
	var t := since()
	var x := float(data.get("erupt_x", 22050.0))
	var low := global_position.y + 900.0
	var high := global_position.y - 260.0
	var y := low
	if t < ERUPT_UP:
		var k := t / ERUPT_UP
		y = lerpf(low, high, 1.0 - (1.0 - k) * (1.0 - k))
	elif t < ERUPT_UP + ERUPT_HOLD:
		y = high
	elif t < ERUPT_UP + ERUPT_HOLD + ERUPT_DOWN:
		var k := (t - ERUPT_UP - ERUPT_HOLD) / ERUPT_DOWN
		y = lerpf(high, low, k * k)
	return Vector2(x, y)

func jaw_front(tick: int = Clock.tick) -> float:
	var from := float(data.get("chase_from", 22300.0))
	var gate := float(data.get("gate_x", 23880.0))
	return minf(gate, from + float(data.get("speed", 300.0)) * since(tick))

func chase_head() -> Vector2:
	var rise := clampf(since() / 0.5, 0.0, 1.0)
	var sink := 0.0
	var gate := float(data.get("gate_x", 23880.0))
	var arrived := (gate - float(data.get("chase_from", 22300.0))) / float(data.get("speed", 300.0))
	if since() > arrived + 1.2:
		sink = clampf((since() - arrived - 1.2) / 1.0, 0.0, 1.0)
	return Vector2(jaw_front() - 230.0, global_position.y - 60.0 + (1.0 - rise) * 700.0 + sink * 900.0)

func jaws_open() -> float:
	if state == 2:
		var gate := float(data.get("gate_x", 23880.0))
		if jaw_front() >= gate:
			return 0.0
		return 0.5 + 0.5 * sin(since() * 9.0)
	return clampf(since() / ERUPT_UP, 0.0, 1.0)

func _host_step(_delta: float) -> void:
	var x := runner.global_position.x
	if state == 0 and x >= float(data.get("erupt_at", 21650.0)):
		set_state(1)
	elif state < 2 and x >= float(data.get("chase_at", 22700.0)):
		set_state(2)
	if state == 1 and since() < ERUPT_UP + ERUPT_HOLD + ERUPT_DOWN:
		if runner_hits_circle(erupt_head() + Vector2(0, 40), 150.0):
			kill_runner("beast")
	elif state == 2:
		var gate := float(data.get("gate_x", 23880.0))
		var front := jaw_front()
		var head := chase_head()
		if x < front + 12.0 and runner.global_position.y > head.y - 330.0 and since() > 0.4:
			kill_runner("jaws")
		if front >= gate and not _snapped:
			_snapped = true
			sound("boom", 2.0, 1.7)
			FinaleFx.kick(16.0)

func _draw() -> void:
	var gone := broken()
	var live: Array = []
	for i in _segments.size():
		if not (gone and in_gap(i)):
			live.append(Rect2(SEG * float(i), 0, SEG, DECK))
	_vertebrae(live)
	if state == 1:
		var t := since()
		if t >= BREAK and t < BREAK + 2.0:
			var age := t - BREAK
			for k in 9:
				var vx := (DrawUtil.hash01(k * 5) - 0.5) * 520.0
				var vy := -380.0 - DrawUtil.hash01(k * 9) * 320.0
				var p := Vector2(lerpf(_gap.x, _gap.y, DrawUtil.hash01(k)) - global_position.x, 20) \
					+ Vector2(vx * age, vy * age + 0.5 * 1800.0 * age * age)
				FinaleArt.centred(self, "bone_tile", p, 46.0, age * 5.0 + k)
		if t < ERUPT_UP + ERUPT_HOLD + ERUPT_DOWN:
			_skull(erupt_head() - global_position, 1.0, jaws_open(), -PI * 0.42)
	elif state == 2:
		var head := chase_head() - global_position
		# Neck vertebrae trailing down and back into the canyon.
		for k in range(7, -1, -1):
			var p := head + Vector2(-330.0 - float(k) * 105.0, 150.0 + float(k) * 125.0 + sin(seconds() * 4.0 + float(k)) * 8.0)
			_sprite(TEX_VERT, Vector2(100, 110), p, -0.5 + 0.05 * float(k), 1.7 - 0.06 * float(k))
		_skull(head, 1.0, jaws_open(), 0.0)

## The deck: a spine of giant vertebrae, pass by pass so each pass batches
## (discs, spines, bodies, shading, rims). The walk line is the flat top.
func _vertebrae(rects: Array) -> void:
	var b := TriBatch.new()
	var bone := FinaleGround.BONE
	var shade := FinaleGround.BONE_SHADE
	var rim := FinaleGround.BONE_RIM
	for r in rects:
		b.rect(Rect2(r.position.x - 6, r.position.y + 10, 12, 30), Color("8f7a5c"))
	for r in rects:
		var c: Vector2 = r.position + Vector2(SEG * 0.5, DECK)
		var spine := PackedVector2Array([c + Vector2(-20, -4), c + Vector2(18, -4), c + Vector2(-2, 92), c + Vector2(-14, 92)])
		b.poly(spine, shade)
		b.circle(c + Vector2(-8, 92), 9.0, shade)
	var bodies: Array = []
	for r in rects:
		var x: float = r.position.x
		bodies.append(PackedVector2Array([Vector2(x + 6, 0), Vector2(x + SEG - 6, 0), Vector2(x + SEG, 12), Vector2(x + SEG - 3, 36),
			Vector2(x + SEG - 14, DECK), Vector2(x + 14, DECK), Vector2(x + 3, 36), Vector2(x, 12)]))
	for body in bodies:
		b.poly(body, shade)
	for r in rects:
		var x: float = r.position.x
		b.poly(PackedVector2Array([Vector2(x + 8, 2), Vector2(x + SEG - 8, 2), Vector2(x + SEG - 4, 14),
			Vector2(x + SEG - 10, 30), Vector2(x + 10, 30), Vector2(x + 4, 14)]), bone)
	for r in rects:
		b.circle(r.position + Vector2(SEG * 0.5, 30), 7.0, Color("6b5642"))
	var outlines := PackedVector2Array()
	var shine := PackedVector2Array()
	for body in bodies:
		for k in body.size():
			outlines.append(body[k])
			outlines.append(body[(k + 1) % body.size()])
	for r in rects:
		shine.append(r.position + Vector2(10, 4))
		shine.append(Vector2(r.end.x - 10, r.position.y + 4))
	b.multiline(outlines, 3.0, rim)
	b.multiline(shine, 3.0, Color("fffaf0"))
	b.flush(self)

## The painted skull (assets/stage_1_10/beast_skull.png, beast_jaw.png,
## tools/promotion/make_creature_art.py), facing right, centre at `c`;
## `open` 0..1 drops the lower jaw about its hinge. The skull is drawn at
## SKULL_SCALE of its painting: about 840 x 450 world px.
const TEX_SKULL := "res://assets/stage_1_10/beast_skull.png"
const TEX_JAW := "res://assets/stage_1_10/beast_jaw.png"
const TEX_VERT := "res://assets/stage_1_10/beast_vertebra.png"
const TEX_RIB := "res://assets/stage_1_10/beast_rib.png"
const SKULL_SCALE := 1.35
const SKULL_HINGE := Vector2(150, 230)
const JAW_HINGE := Vector2(40, 90)

func _skull(c: Vector2, s: float, open: float, angle: float) -> void:
	var base := Transform2D(angle, c) * Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
	var hinge := Vector2(-150, 40)
	var k := SKULL_SCALE
	var jaw := FinaleArt._load(TEX_JAW)
	var skull := FinaleArt._load(TEX_SKULL)
	if jaw != null:
		draw_set_transform_matrix(base * Transform2D(open * 0.62, hinge) * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))
		draw_texture(jaw, -JAW_HINGE)
	if skull != null:
		draw_set_transform_matrix(base * Transform2D(0.0, hinge) * Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO))
		draw_texture(skull, -SKULL_HINGE)
	# The burning eye in its socket.
	draw_set_transform_matrix(base)
	var eye := hinge + (Vector2(268, 140) - SKULL_HINGE) * k
	var glow := 0.65 + 0.35 * sin(seconds() * 7.0)
	draw_circle(eye, 46.0, Color(1.0, 0.25, 0.05, 0.30 * glow))
	draw_circle(eye, 24.0, Color(1.0, 0.45, 0.08, glow))
	draw_circle(eye, 10.0, Color(1.0, 0.95, 0.6))
	draw_set_transform(Vector2.ZERO)

## A painted bone sprite with pivot `pivot` (sprite px) at `at` (local).
func _sprite(path: String, pivot: Vector2, at: Vector2, angle: float, scale: float) -> void:
	var tex := FinaleArt._load(path)
	if tex == null:
		return
	draw_set_transform(at, angle, Vector2(scale, scale))
	draw_texture(tex, -pivot)
	draw_set_transform(Vector2.ZERO)


## The beast's ribcage heaving along behind its neck, deep in the canyon and
## behind the pillars: the size of the thing that is chasing.
class Ribs extends Node2D:
	var beast
	func _process(_delta: float) -> void:
		if beast._near:
			queue_redraw()
	func _draw() -> void:
		if beast.state != 2:
			return
		var tex := FinaleArt._load(beast.TEX_RIB)
		if tex == null:
			return
		var head: Vector2 = beast.chase_head() - beast.global_position
		var t: float = beast.seconds()
		for k in 6:
			var root := head + Vector2(-620.0 - float(k) * 200.0, 1350.0 - float(k) * 30.0)
			var breath := sin(t * 3.0 + float(k) * 0.7) * 0.03
			draw_set_transform(root, -0.18 + 0.06 * float(k) + breath, Vector2(2.1, 2.1) * (1.0 - 0.05 * float(k)))
			draw_texture(tex, -Vector2(40, 540), Color(0.92, 0.86, 0.78))
			draw_set_transform(Vector2.ZERO)
