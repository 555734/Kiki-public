extends FinaleMachine
## IT COMES ALIVE -> CLOSING JAWS. A long vertebra bridge over the canyon.
## Halfway across, an ancient skeletal beast erupts from below, bursting
## three vertebrae out of the deck and roaring before it sinks again: jump
## the new gap (double jump) or ride the sand geyser that blows up through
## it to the rib above. Leaving the deck wakes it for good: the jaws come up
## behind the runner at 300px/s -- faster than a walk -- snapping, through the
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
		sound("gate", -15.0, 1.6)
		FinaleFx.kick(14.0)
	else:
		sound("enemy_die", -14.0, 1.4)
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
			sound("gate", -10.0, 1.6)
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

## The deck's vertebrae, pass by pass so each pass batches.
func _vertebrae(rects: Array) -> void:
	var t := FinaleArt.tex("bone_tile")
	var polys: Array = []
	for r in rects:
		polys.append(PackedVector2Array([r.position + Vector2(4, 0), Vector2(r.end.x - 4, r.position.y),
			Vector2(r.end.x, r.position.y + 14), Vector2(r.end.x - 10, r.end.y), Vector2(r.position.x + 10, r.end.y),
			r.position + Vector2(0, 14)]))
	for r in rects:
		draw_rect(Rect2(r.get_center().x - 14, r.end.y - 4, 28, 26), Color("cdbf9f"))
	for poly in polys:
		var uvs := PackedVector2Array()
		for p in poly:
			uvs.append(p / 160.0)
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(Color.WHITE)
		draw_polygon(poly, cols, uvs, t)
	var outlines := PackedVector2Array()
	var shine := PackedVector2Array()
	for i in polys.size():
		var poly: PackedVector2Array = polys[i]
		for k in poly.size():
			outlines.append(poly[k])
			outlines.append(poly[(k + 1) % poly.size()])
		var r: Rect2 = rects[i]
		shine.append(r.position + Vector2(8, 3))
		shine.append(Vector2(r.end.x - 8, r.position.y + 3))
	draw_multiline(outlines, Color("6b5642"), 3.0)
	draw_multiline(shine, Color("fff7e4"), 3.0)

## A fossil skull facing right, centre at `c`. `open` 0..1 drops the jaw.
func _skull(c: Vector2, s: float, open: float, angle: float) -> void:
	var tex := FinaleArt.tex("bone_tile")
	draw_set_transform(c, angle, Vector2(s, s))
	var upper := PackedVector2Array([Vector2(-230, -40), Vector2(-200, -150), Vector2(-60, -190), Vector2(120, -150),
		Vector2(250, -80), Vector2(300, -20), Vector2(290, 20), Vector2(-150, 30)])
	var jaw_drop := open * 0.55
	var lower := PackedVector2Array()
	for p in [Vector2(-150, 30), Vector2(280, 40), Vector2(260, 90), Vector2(60, 120), Vector2(-120, 100)]:
		lower.append((p - Vector2(-150, 30)).rotated(jaw_drop) + Vector2(-150, 30))
	for poly in [lower, upper]:
		var uvs := PackedVector2Array()
		for p in poly:
			uvs.append(p / 180.0)
		var cols := PackedColorArray()
		cols.resize(poly.size())
		cols.fill(Color(0.95, 0.9, 0.82))
		draw_polygon(poly, cols, uvs, tex)
		var line := PackedVector2Array(poly)
		line.append(poly[0])
		draw_polyline(line, Color("5b4532"), 6.0, true)
	# Teeth along both jaws.
	for i in 8:
		var x := -100.0 + i * 46.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 26), Vector2(x + 22, 26), Vector2(x + 11, 66)]), Color("fffaf0"))
		var a := (Vector2(x, 44) - Vector2(-150, 30)).rotated(jaw_drop) + Vector2(-150, 30)
		var b := (Vector2(x + 22, 44) - Vector2(-150, 30)).rotated(jaw_drop) + Vector2(-150, 30)
		var tip := (Vector2(x + 11, 4) - Vector2(-150, 30)).rotated(jaw_drop) + Vector2(-150, 30)
		draw_colored_polygon(PackedVector2Array([a, b, tip]), Color("fffaf0"))
	# Eye socket with an ember, nostril, cracks.
	draw_circle(Vector2(20, -100), 44.0, Color("3a2420"))
	var glow := 0.6 + 0.4 * sin(seconds() * 6.0)
	draw_circle(Vector2(26, -96), 18.0, Color(1.0, 0.55, 0.1, glow))
	draw_circle(Vector2(26, -96), 8.0, Color(1.0, 0.95, 0.6))
	draw_circle(Vector2(230, -60), 14.0, Color("3a2420"))
	draw_line(Vector2(-160, -120), Vector2(-90, -60), Color("8a7258"), 4.0)
	draw_set_transform(Vector2.ZERO)
