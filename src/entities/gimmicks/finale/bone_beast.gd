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

func _build() -> void:
	z_index = 7
	reach = Vector2(3400, 1600)
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
		# Neck vertebrae trailing down into the canyon.
		for k in 6:
			var p := head + Vector2(-260 - k * 90.0, 160 + k * 120.0)
			draw_circle(p, 58.0 - k * 4.0, Color("6b5642"))
			draw_circle(p, 50.0 - k * 4.0, Color("e8dcc0"))
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

## A fossil skull facing right, centre at `c`. `open` 0..1 drops the jaw.
## Ivory bone shaded from the top, a heavy brow, horns, a burning eye.
func _skull(c: Vector2, s: float, open: float, angle: float) -> void:
	var bone := FinaleGround.BONE
	var shade := FinaleGround.BONE_SHADE
	var rim := FinaleGround.BONE_RIM
	draw_set_transform(c, angle, Vector2(s, s))
	var b := TriBatch.new()
	var hinge := Vector2(-150, 30)
	var jaw_drop := open * 0.6
	var upper := PackedVector2Array([Vector2(-240, -40), Vector2(-215, -150), Vector2(-90, -205), Vector2(60, -195), Vector2(160, -150),
		Vector2(260, -90), Vector2(320, -30), Vector2(310, 22), Vector2(-150, 34)])
	var lower := PackedVector2Array()
	for p in [Vector2(-160, 30), Vector2(300, 36), Vector2(290, 70), Vector2(200, 100), Vector2(40, 128), Vector2(-120, 112), Vector2(-175, 70)]:
		lower.append((p - hinge).rotated(jaw_drop) + hinge)
	# Horns behind the skull.
	for hb in [[Vector2(-150, -170), Vector2(-330, -330)], [Vector2(-60, -195), Vector2(-160, -380)]]:
		var a: Vector2 = hb[0]
		var tip: Vector2 = hb[1]
		var nrm := (tip - a).normalized().orthogonal() * 34.0
		b.poly(PackedVector2Array([a + nrm, a - nrm, tip]), rim)
		b.poly(PackedVector2Array([a + nrm * 0.75, a - nrm * 0.75, tip.lerp(a, 0.06)]), shade)
	# Teeth (behind the bone so their roots hide).
	for i in 8:
		var x := -90.0 + i * 48.0
		var tl := 44.0 if i % 3 == 1 else 32.0
		b.poly(PackedVector2Array([Vector2(x, 20), Vector2(x + 26, 20), Vector2(x + 13, 20 + tl)]), Color("fffaf0"))
		var pts := PackedVector2Array()
		for q in [Vector2(x, 50), Vector2(x + 26, 50), Vector2(x + 13, 50 - tl)]:
			pts.append((q - hinge).rotated(jaw_drop) + hinge)
		b.poly(pts, Color("fffaf0"))
	# Dark mouth behind open jaws.
	if open > 0.05:
		b.poly(PackedVector2Array([hinge, Vector2(300, 30), (Vector2(300, 40) - hinge).rotated(jaw_drop) + hinge]), Color(0.18, 0.06, 0.04))
	for poly in [lower, upper]:
		b.poly(poly, shade)
		var top := PackedVector2Array()
		var lo := INF
		var hi := -INF
		for p in poly:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		# Lit upper part: the same outline squashed toward its top.
		for p in poly:
			top.append(Vector2(p.x, lerpf(lo, p.y, 0.72)) + Vector2(0, 4))
		b.poly(top, bone)
		var line := PackedVector2Array(poly)
		line.append(poly[0])
		b.polyline(line, 7.0, rim)
	# Brow ridge, cheek line, nostril, cracks.
	b.polyline(PackedVector2Array([Vector2(-60, -150), Vector2(30, -168), Vector2(110, -140)]), 9.0, rim)
	b.polyline(PackedVector2Array([Vector2(-120, -10), Vector2(60, -30), Vector2(220, -20)]), 5.0, Color(rim, 0.45))
	b.circle(Vector2(268, -52), 16.0, Color("2a1712"))
	b.polyline(PackedVector2Array([Vector2(-190, -110), Vector2(-140, -70), Vector2(-150, -30)]), 4.0, Color(rim, 0.6))
	# The eye: a deep socket with a burning ember.
	b.circle(Vector2(30, -100), 52.0, Color("2a1712"))
	var glow := 0.65 + 0.35 * sin(seconds() * 7.0)
	b.circle(Vector2(36, -96), 40.0, Color(1.0, 0.25, 0.05, 0.35 * glow))
	b.circle(Vector2(36, -96), 22.0, Color(1.0, 0.45, 0.08, glow))
	b.circle(Vector2(36, -96), 9.0, Color(1.0, 0.95, 0.6))
	b.flush(self)
	draw_set_transform(Vector2.ZERO)
