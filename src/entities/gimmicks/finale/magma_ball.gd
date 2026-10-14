extends FinaleMachine
## HOT PURSUIT. Crossing the trigger frees a magma sphere from the lava tube
## behind the runner. It rolls down the cracked slope, accelerating past
## running speed: sprint, or get onto the escape ledge in time. The guardian's
## wall (slot 2) stops it dead while the wall stands. At the bottom it smashes
## the thin crust bridge -- the low path is gone -- and sinks into the lake.
##
## state 0 parked, 1 rolling (distance = aux + S(since)), 2 held at aux.

const V0 := 140.0
const ACCEL := 240.0
const VMAX := 540.0
var _crust: AnimatableBody2D
var _path := PackedVector2Array()
var _length := 0.0
var _crust_s := INF

func _build() -> void:
	z_index = 6
	reach = Vector2(1900, 1100)
	var abs_path: PackedVector2Array = data.get("path", PackedVector2Array())
	for p in abs_path:
		_path.append(p - global_position)
	for i in range(_path.size() - 1):
		_length += _path[i].distance_to(_path[i + 1])
	var crust: Rect2 = data.get("crust", Rect2())
	if crust.size.x > 0:
		_crust = make_body(crust.size)
		_crust.position = crust.get_center() - global_position
		_crust_s = _distance_to_x(crust.position.x + 40.0 - global_position.x)

func _distance_to_x(x: float) -> float:
	var s := 0.0
	for i in range(_path.size() - 1):
		var a := _path[i]
		var b := _path[i + 1]
		if x <= b.x:
			return s + a.distance_to(b) * clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0, 1)
		s += a.distance_to(b)
	return s

static func travel(t: float) -> float:
	var t1 := (VMAX - V0) / ACCEL
	if t <= t1:
		return V0 * t + 0.5 * ACCEL * t * t
	return V0 * t1 + 0.5 * ACCEL * t1 * t1 + VMAX * (t - t1)

func distance_at(tick: int) -> float:
	match state:
		1: return aux + travel(since(tick))
		2: return aux
	return 0.0

func point_at(s: float) -> Vector2:
	var left := s
	for i in range(_path.size() - 1):
		var d := _path[i].distance_to(_path[i + 1])
		if left <= d:
			return _path[i].lerp(_path[i + 1], left / maxf(d, 0.001))
		left -= d
	return _path[-1]

func centre() -> Vector2:
	return global_position + point_at(distance_at(Clock.tick))

func sunk(tick: int = Clock.tick) -> bool:
	return distance_at(tick) >= _length

func _pose(tick: int) -> void:
	if _crust != null:
		set_solid(_crust, distance_at(tick) < _crust_s)

func _on_state() -> void:
	if state == 1 and aux == 0.0:
		sound("rumble", -2.0, 1.6)
		FinaleFx.kick(8.0)
	elif state == 2:
		sound("sizzle", -3.0, 1.2)

func _host_step(_delta: float) -> void:
	if state == 0:
		if runner.global_position.x >= float(data.get("trigger", 9000.0)):
			set_state(1, 0.0)
		return
	if sunk():
		return
	var c := centre()
	var radius := float(data.get("radius", 100.0))
	var wall := _wall_ahead(c, radius)
	if state == 1 and wall:
		set_state(2, distance_at(Clock.tick))
	elif state == 2 and not wall:
		set_state(1, aux)
	if runner_hits_circle(c, radius - 8.0):
		kill_runner("magma")
	if state == 1:
		FinaleFx.kick(2.5)

func _wall_ahead(c: Vector2, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("hologram"):
		if node is Hologram and node.kind == Hologram.Kind.WALL:
			var r := Rect2(node.global_position - Balance.WALL_SIZE * 0.5, Balance.WALL_SIZE)
			var probe := Rect2(c + Vector2(radius - 6.0, -radius * 0.6), Vector2(28, radius * 1.2))
			if r.intersects(probe):
				return true
	return false

func _draw() -> void:
	var radius := float(data.get("radius", 100.0))
	var s := distance_at(Clock.tick)
	var t := seconds()
	# The lava tube it waits in.
	draw_circle(_path[0] + Vector2(-30, -10), radius * 1.25, Color("2a1418"))
	draw_arc(_path[0] + Vector2(-30, -10), radius * 1.25, PI * 0.6, PI * 1.9, 30, Color("ff7a1a", 0.6), 8.0)
	# The crust bridge, cracking as the ball approaches, then gone.
	var crust: Rect2 = data.get("crust", Rect2())
	if crust.size.x > 0:
		var local := Rect2(crust.position - global_position, crust.size)
		if s < _crust_s:
			FinaleArt.slab_on(self, local, "lava")
			if state > 0:
				for k in 5:
					var x := local.position.x + 40.0 + k * 70.0
					draw_line(Vector2(x, local.position.y + 4), Vector2(x + 20, local.end.y), Color("ffb030"), 3.0)
		elif s < _crust_s + 900.0:
			var age := (s - _crust_s) / VMAX
			for k in 6:
				var p := local.position + Vector2(30.0 + k * 62.0, 10 + 0.5 * 1500.0 * age * age)
				FinaleArt.centred(self, "stone", p, 40.0, age * 4.0 + k, Color(0.5, 0.3, 0.3))
	if sunk():
		var age := (s - _length) / VMAX
		if age < 1.4:
			var end := _path[-1]
			for k in 10:
				var a := float(k) / 10.0 * PI + PI
				draw_circle(end + Vector2(cos(a), sin(a)) * (age * 260.0), 16.0 * (1.4 - age), Color(1, 0.6, 0.1, 1.0 - age / 1.4))
		return
	var c := point_at(s)
	if state == 1:
		for k in 5:
			var back := point_at(maxf(0.0, s - 40.0 * (k + 1)))
			draw_circle(back, radius * (0.7 - k * 0.1), Color(1, 0.45, 0.05, 0.18))
	draw_circle(c, radius * 1.18, Color(1, 0.4, 0.05, 0.22 + 0.08 * sin(t * 9.0)))
	FinaleArt.centred(self, "magma_ball", c, radius * 2.2, s / radius)
	if state == 2:
		draw_arc(c, radius + 14, 0, TAU, 36, Color(0.5, 0.95, 1.0, 0.6), 4.0)
