extends FinaleMachine
## THUNDER BRIDGE. The deck is a row of spans; crossing a trigger line calls a
## strike: 0.75s of glow on the target spans, then the bolt -- flash, shake,
## the spans burst into falling stone and the lower route is gone. The third
## strike's double gap can only be crossed on the broken spans above, two of
## which are electrified on a 3s cycle. The guardian can shoot the lightning
## rod on the ruined tower to earth those stones for five seconds.
##
## state: bit i = strike i called. placed_tick = when the latest was called.
## A second id "<id>_rod" carries the rod (aux = tick it stays charged until).

const WARN := 0.75
const DECK_THICK := 70.0
var _spans: Array[AnimatableBody2D] = []
var _rod_until := -1
var _rod: Vector2

func _build() -> void:
	reach = Vector2(2600, 1200)
	z_index = 3
	var n := int(data.get("segments", 13))
	var w := float(data.get("seg_w", 160.0))
	for i in n:
		var b := make_body(Vector2(w, DECK_THICK))
		b.position = Vector2(w * (float(i) + 0.5), DECK_THICK * 0.5)
		_spans.append(b)
	_rod = data.get("rod", Vector2(4480, 610)) - global_position
	make_target(_rod, 28.0)

func _receive(id: String) -> void:
	var fields := id.split("|")
	if fields.size() == 4 and fields[0] == switch_id + "_rod":
		_rod_until = int(float(fields[3]))
		sound("switch", 7.0)
		queue_redraw()
		return
	super._receive(id)

func replay_id() -> String:
	# The rod's charge only matters for a few seconds; the deck is what a
	# reconnecting guest must not get wrong.
	return super.replay_id()

func _on_shot() -> void:
	Events.switch_activated.emit("%s_rod|1|%d|%d" % [switch_id, Clock.tick, Clock.tick + Clock.ticks_for(5.0)])

func strikes() -> Array:
	return data.get("strikes", [])

func latest() -> int:
	var last := -1
	for i in strikes().size():
		if state & (1 << i):
			last = i
	return last

## Which spans are gone at this tick.
func broken_at(tick: int) -> Dictionary:
	var out := {}
	var last := latest()
	for i in strikes().size():
		if not (state & (1 << i)):
			continue
		if i == last and since(tick) < WARN:
			continue
		for s in strikes()[i]["segs"]:
			out[int(s)] = true
	return out

var _flashed := -1

func _pose(tick: int) -> void:
	_ambient(tick)
	var gone := broken_at(tick)
	for i in _spans.size():
		set_solid(_spans[i], not gone.has(i))
	# Every device sees and hears the bolt land; only the host hurts anyone.
	if latest() >= 0 and since(tick) >= WARN and _flashed != placed_tick:
		_flashed = placed_tick
		if since(tick) < WARN + 0.3:
			FinaleFx.flash(1.0)
			FinaleFx.kick(12.0)
			sound("thunder", 0.0, 1.6)
			sound("crumble", -2.0, 1.2)

func _on_state() -> void:
	sound("rumble", 4.0, 0.6)

## Distant sheet lightning over the storm, on a fixed Clock cycle (no gameplay
## effect): a soft flash and, while the runner is near, a low roll of thunder.
func _ambient(tick: int) -> void:
	var beat := fposmod(Clock.seconds_at(tick), 4.6)
	var prev := fposmod(Clock.seconds_at(tick - 1), 4.6)
	if beat < prev and _near:
		FinaleFx.flash(0.45)
		sound("thunder", -5.0, 0.5)

func arcs_live(i: int, t: float) -> bool:
	if Clock.tick < _rod_until:
		return false
	var beat := fposmod(t + float(i) * 1.5, 3.0)
	return beat >= 0.6 and beat < 1.6

func arcs_warning(i: int, t: float) -> bool:
	if Clock.tick < _rod_until:
		return false
	var beat := fposmod(t + float(i) * 1.5, 3.0)
	return beat < 0.6

var _struck_tick := -1

func _host_step(_delta: float) -> void:
	var last := latest()
	var busy := last >= 0 and since() < WARN + 0.2
	if not busy:
		for i in strikes().size():
			if state & (1 << i):
				continue
			if runner.global_position.x >= float(strikes()[i]["at"]):
				set_state(state | (1 << i))
				break
	# The bolt itself: a runner standing on a target span when it lands.
	if last >= 0 and since() >= WARN and _struck_tick != placed_tick:
		_struck_tick = placed_tick
		var w := float(data.get("seg_w", 160.0))
		for s in strikes()[last]["segs"]:
			var x0 := global_position.x + w * float(s)
			if runner.global_position.x > x0 - 10 and runner.global_position.x < x0 + w + 10 \
					and absf(runner.global_position.y - global_position.y) < 90:
				hurt_runner(Vector2(0, -520))
	var t := seconds()
	var arcs: Array = data.get("arcs", [])
	for i in arcs.size():
		var r: Rect2 = arcs[i]
		if arcs_live(i, t) and runner_box().intersects(r.grow_individual(0, 26, 0, 0)):
			hurt_runner(Vector2(-signf(runner.velocity.x + 0.01) * 200.0, -420))

func _draw() -> void:
	var w := float(data.get("seg_w", 160.0))
	var tick := Clock.tick
	var gone := broken_at(tick)
	var last := latest()
	var t := seconds()
	var live: Array = []
	for i in _spans.size():
		if not gone.has(i):
			live.append(Rect2(w * float(i), 0, w, DECK_THICK))
	FinaleArt.slabs_on(self, live, "storm")
	for r in live:
		# Balustrade posts.
		draw_rect(Rect2(r.position.x + 12, -34, 10, 34), Color("54627f"))
		draw_rect(Rect2(r.position.x + 8, -40, 18, 8), Color("8291b2"))
	draw_line(Vector2(0, -30), Vector2(w * _spans.size(), -30), Color("8291b2", 0.6), 4.0)
	# The strike in progress.
	if last >= 0:
		var age := since(tick)
		for s in strikes()[last]["segs"]:
			var cx := w * (float(s) + 0.5)
			if age < WARN:
				var glow := 0.35 + 0.35 * sin(age * 40.0)
				draw_rect(Rect2(w * float(s), -6, w, DECK_THICK + 6), Color(0.6, 0.85, 1.0, glow))
				for k in 4:
					var a := float(k) * 1.7 + age * 22.0
					draw_line(Vector2(cx + cos(a) * 50, -10), Vector2(cx + cos(a + 1.0) * 70, -40 + sin(a) * 18), Color(0.8, 0.95, 1.0, 0.8), 2.0)
			elif age < WARN + 0.32:
				var k := (age - WARN) / 0.32
				_bolt(Vector2(cx + 60, -1100), Vector2(cx, 20), int(placed_tick + s), 70.0, 12.0)
				_bolt(Vector2(cx - 30, -1100), Vector2(cx + 10, 10), int(placed_tick + s) + 5, 50.0, 6.0)
				draw_circle(Vector2(cx, 10), 120.0 * (1.0 - k) + 30.0, Color(0.75, 0.92, 1.0, 0.55 * (1.0 - k)))
				draw_circle(Vector2(cx, 10), 50.0 * (1.0 - k) + 12.0, Color(1, 1, 1, 0.9 * (1.0 - k)))
			if age >= WARN and age < WARN + 2.2:
				_debris(Vector2(w * float(s), 0), w, age - WARN, int(s))
	# Electrified broken spans.
	var arcs: Array = data.get("arcs", [])
	for i in arcs.size():
		var r: Rect2 = arcs[i]
		var local := Rect2(r.position - global_position, r.size)
		if arcs_live(i, t):
			for k in 3:
				var seed := int(t * 20.0) + k * 7 + i * 31
				_bolt(local.position + Vector2(8, -2), local.position + Vector2(local.size.x - 8, -2), seed, 26.0, 2.5)
			draw_rect(local.grow(4), Color(0.5, 0.85, 1.0, 0.25))
		elif arcs_warning(i, t):
			var spark := Vector2(fposmod(t * 300.0 + i * 40.0, local.size.x), -6)
			draw_circle(local.position + spark, 4.0, Color(0.85, 0.97, 1.0, 0.9))
	# The lightning rod on the tower: brass mast, charged ring.
	var charged := Clock.tick < _rod_until
	draw_line(_rod + Vector2(0, 30), _rod + Vector2(0, 210), Color("5c4a3a"), 9.0)
	draw_line(_rod + Vector2(0, -40), _rod + Vector2(0, 30), Color("e3b55a"), 7.0)
	draw_circle(_rod, 24.0, Color("2f3550"))
	draw_arc(_rod, 20.0, 0, TAU, 28, Color("8ff0ff") if charged else Color("e3b55a"), 4.0, true)
	draw_line(_rod + Vector2(-9, 0), _rod + Vector2(9, 0), Color.WHITE, 2.0)
	draw_line(_rod + Vector2(0, -9), _rod + Vector2(0, 9), Color.WHITE, 2.0)
	if charged:
		for i in arcs.size():
			var r: Rect2 = arcs[i]
			_bolt(_rod, r.get_center() - global_position, int(t * 15.0) + i * 3, 30.0, 2.0, Color(0.6, 0.95, 1.0, 0.6))

func _bolt(a: Vector2, b: Vector2, seed: int, jag: float = 60.0, width: float = 6.0,
		colour: Color = Color(0.92, 0.97, 1.0)) -> void:
	var pts := PackedVector2Array([a])
	var n := 9
	for i in range(1, n):
		var k := float(i) / float(n)
		var off := (DrawUtil.hash01(seed * 13 + i) - 0.5) * 2.0 * jag
		var dir := (b - a).normalized()
		pts.append(a.lerp(b, k) + Vector2(-dir.y, dir.x) * off)
	pts.append(b)
	draw_polyline(pts, Color(0.45, 0.7, 1.0, colour.a * 0.45), width * 3.2, true)
	draw_polyline(pts, colour, width, true)

func _debris(origin: Vector2, w: float, age: float, seed: int) -> void:
	for k in 8:
		var vx := (DrawUtil.hash01(seed * 7 + k) - 0.5) * 520.0
		var vy := -320.0 - DrawUtil.hash01(seed * 11 + k) * 420.0
		var p := origin + Vector2(w * (0.15 + 0.7 * DrawUtil.hash01(seed + k * 5)), 10) \
			+ Vector2(vx * age, vy * age + 0.5 * 1800.0 * age * age)
		var size := 22.0 + DrawUtil.hash01(seed * 3 + k) * 30.0
		FinaleArt.centred(self, "stone", p, size, age * (3.0 + k), Color(0.7, 0.78, 0.95))
