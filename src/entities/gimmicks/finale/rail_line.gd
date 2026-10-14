extends FinaleMachine
## IRON RAIL. Two trains share one 25s timetable: they come out of the west
## portal, stop at the station for five seconds, then pull away east at
## 280px/s and vanish into the far tunnel. Train 0 has the low, mismatched
## roofs the runner boards from the station; train 1 runs a few hundred
## pixels ahead with taller cars, and the gap between them breathes as it
## pulls away -- the train-to-train leap. Two cranes over the line each drop a
## crate onto a passing car; once landed it rides the car as a new obstacle
## (or a step up). A low bridge at the cutting sweeps anyone still on a roof:
## get off onto the footbridge before it.
##
## Everything here is a pure function of the clock -- no state at all.

const CARS := [
	# kind, length, roof height above the rail
	[["red", 300.0, 150.0], ["flat", 300.0, 70.0], ["blue", 300.0, 160.0], ["loco", 320.0, 182.0]],
	[["blue", 300.0, 196.0], ["red", 300.0, 208.0], ["loco", 320.0, 222.0]],
]
const COUPLER := 14.0
const ARRIVE := 4.0
const PARKED := 5.0
const ACCEL := 150.0
const VMAX := 280.0
const GAP := 300.0
const CRATE := Vector2(92, 92)
const HOOK_Y := -560.0   # relative to the rail
const GRAVITY := 2000.0

var _roofs: Array = []   # [train][car] -> AnimatableBody2D
var _crates: Array[AnimatableBody2D] = []
var _cargo: AnimatableBody2D
var _drops: Array = []   # per crane: {"t": release beat, "train", "car", "offset", "land": beat}
var _top: Node2D
var portal_in := 11500.0
var portal_out := 15600.0
var period := 25.0

func _build() -> void:
	add_to_group("finale_rail")
	reach = Vector2(4800, 1400)
	z_index = 5
	portal_in = float(data.get("portal_in", 11500.0))
	portal_out = float(data.get("portal_out", 15600.0))
	period = float(data.get("period", 25.0))
	for train in CARS.size():
		var row: Array = []
		for car in CARS[train]:
			# The whole car body is solid, roof to just above the wheels.
			row.append(make_body(Vector2(float(car[1]), float(car[2]) - 26.0)))
		_roofs.append(row)
	_cargo = make_body(Vector2(84, 80))
	# Each crane: [x, train, car] -- the car it drops its crate onto.
	for c in data.get("cranes", []):
		_crates.append(make_body(CRATE))
		_drops.append(_plan_drop(float(c[0]), int(c[1]), int(c[2])))
	_top = Top.new()
	_top.line = self
	_top.z_index = 8
	add_child(_top)

func is_near() -> bool:
	if not is_instance_valid(runner):
		return true
	var x := runner.global_position.x
	return x > portal_in - 1600 and x < portal_out + 1600 and absf(runner.global_position.y - global_position.y) < 1400

static func depart(u: float) -> float:
	var t1 := VMAX / ACCEL
	if u <= t1:
		return 0.5 * ACCEL * u * u
	return 0.5 * ACCEL * t1 * t1 + VMAX * (u - t1)

func train_length(train: int) -> float:
	var n := 0.0
	for car in CARS[train]:
		n += float(car[1]) + COUPLER
	return n - COUPLER

## Where a train's rear coupler is, world x, at beat `b` of the timetable.
func rear_x(train: int, b: float) -> float:
	var park := global_position.x
	if train == 1:
		park += train_length(0) + GAP
	if b < ARRIVE:
		var distance := park - (portal_in - train_length(train) - 40.0)
		var k := 1.0 - b / ARRIVE
		return park - distance * k * k
	if b < ARRIVE + PARKED:
		return park
	var u := b - ARRIVE - PARKED
	var x := park + depart(u)
	if train == 1:
		# The lead train surges and settles: the gap breathes 300..390px.
		x += 45.0 * (1.0 - cos(u * 0.8))
	return x

func beat(tick: int = Clock.tick) -> float:
	return fposmod(Clock.seconds_at(tick), period)

## Left x of a car, world.
func car_x(train: int, car: int, b: float) -> float:
	var x := rear_x(train, b)
	for i in car:
		x += float(CARS[train][i][1]) + COUPLER
	return x

func roof_y(train: int, car: int) -> float:
	return global_position.y - float(CARS[train][car][2])

func car_visible(train: int, car: int, b: float) -> bool:
	var x := car_x(train, car, b)
	var w := float(CARS[train][car][1])
	return x + w > portal_in + 8.0 and x < portal_out - 8.0

## Solid only once wholly out of the tunnels: a half-emerged car's hidden
## end must not reach under the station deck and scoop up a waiting runner.
func car_solid(train: int, car: int, b: float) -> bool:
	var x := car_x(train, car, b)
	return x >= portal_in and x + float(CARS[train][car][1]) <= portal_out

## For enemies riding a roof: world point on the roof centre, or INF.
func roof_point(train: int, car: int) -> Vector2:
	var b := beat()
	if train >= CARS.size() or car >= CARS[train].size() or not car_solid(train, car, b):
		return Vector2(INF, INF)
	return Vector2(car_x(train, car, b) + float(CARS[train][car][1]) * 0.5, roof_y(train, car))

## Crane drops are planned once: release so the crate lands on the middle of
## the target car as it passes under the hook after departure.
func _plan_drop(crane_x: float, train: int, car: int) -> Dictionary:
	var fall := sqrt(2.0 * (-HOOK_Y - float(CARS[train][car][2]) - CRATE.y * 0.5 + 20.0) / GRAVITY)
	var b := ARRIVE + PARKED
	while b < period:
		var centre := car_x(train, car, b + fall) + float(CARS[train][car][1]) * 0.5
		if centre >= crane_x:
			var offset := crane_x - car_x(train, car, b + fall)
			return {"crane": crane_x, "t": b, "land": b + fall, "train": train, "car": car, "offset": offset}
		b += 1.0 / 60.0
	return {"crane": crane_x, "t": INF, "land": INF, "train": train, "car": car, "offset": 0.0}

## Crate centre (world) and phase: 0 hanging, 1 falling, 2 riding, 3 gone.
func crate_at(i: int, b: float) -> Array:
	var d: Dictionary = _drops[i]
	var hook := Vector2(float(d["crane"]), global_position.y + HOOK_Y)
	if b < float(d["t"]):
		return [hook + Vector2(0, CRATE.y * 0.5 + 20.0), 0]
	if b < float(d["land"]):
		var t := b - float(d["t"])
		return [hook + Vector2(0, CRATE.y * 0.5 + 20.0 + 0.5 * GRAVITY * t * t), 1]
	var train := int(d["train"])
	var car := int(d["car"])
	if not car_solid(train, car, b):
		return [Vector2(INF, INF), 3]
	var x := car_x(train, car, b) + float(d["offset"])
	return [Vector2(x, roof_y(train, car) - CRATE.y * 0.5), 2]

func _pose(tick: int) -> void:
	var b := beat(tick)
	for train in CARS.size():
		for car in CARS[train].size():
			var body: AnimatableBody2D = _roofs[train][car]
			var w := float(CARS[train][car][1])
			var h := float(CARS[train][car][2]) - 26.0
			body.global_position = Vector2(car_x(train, car, b) + w * 0.5, roof_y(train, car) + h * 0.5)
			set_solid(body, car_solid(train, car, b))
	_cargo.global_position = Vector2(car_x(0, 1, b) + 150.0, roof_y(0, 1) - 40.0)
	set_solid(_cargo, car_solid(0, 1, b))
	for i in _crates.size():
		var at: Array = crate_at(i, b)
		if at[1] == 3:
			set_solid(_crates[i], false)
			continue
		_crates[i].global_position = at[0]
		set_solid(_crates[i], at[1] != 0)

## Train speed, world px/s, at beat `b`.
func train_speed(train: int, b: float) -> float:
	return (rear_x(train, b + 0.02) - rear_x(train, b)) / 0.02

## The train under the runner's feet, or -1.
func _riding() -> int:
	for train in _roofs.size():
		for body in _roofs[train]:
			if runner_on(body):
				return train
	return -1

## A jump off a moving train keeps the train's speed: the runner's own air
## control is relative to the air, so without this the train would drive out
## from under every leap and the train-to-train gap could never be crossed.
var _carry := 0.0

func _host_step(delta: float) -> void:
	var b := beat()
	var riding := _riding()
	if riding >= 0:
		_carry = train_speed(riding, b)
	elif runner.is_on_floor():
		_carry = 0.0
	elif absf(_carry) > 1.0:
		runner.move_and_collide(Vector2(_carry * delta, 0.0))
	for i in _crates.size():
		var at: Array = crate_at(i, b)
		if at[1] == 1 and runner_box().intersects(Rect2(at[0] - CRATE * 0.5, CRATE).grow(-6)):
			hurt_runner(Vector2(-220, 120))
	var bridge := float(data.get("low_bridge", 15060.0))
	var box := runner_box()
	if box.end.x > bridge and box.position.x < bridge + 40.0 and box.position.y < global_position.y - 120.0 \
			and box.end.y > global_position.y - 240.0:
		kill_runner("low_bridge")

func _draw() -> void:
	var b := beat()
	var rail := Vector2(portal_in - global_position.x, 0)
	var rail_end := portal_out - global_position.x
	# Sleepers and rails.
	var x := rail.x
	while x < rail_end:
		draw_rect(Rect2(x, 4, 26, 12), Color("5a3a26"))
		x += 44.0
	draw_line(Vector2(rail.x, 2), Vector2(rail_end, 2), Color("8f96a6"), 5.0)
	draw_line(Vector2(rail.x, 6), Vector2(rail_end, 6), Color("3d3f4a"), 2.0)
	for train in CARS.size():
		for car in CARS[train].size():
			_draw_car(train, car, b)
	for i in _crates.size():
		var at: Array = crate_at(i, b)
		if at[1] == 3:
			continue
		var c: Vector2 = at[0] - global_position
		if at[1] == 0:
			var warn := float(_drops[i]["t"]) - b
			if warn < 0.8:
				c.x += sin(b * 40.0) * 3.0
				var shadow_y := roof_y(int(_drops[i]["train"]), int(_drops[i]["car"])) - global_position.y
				draw_rect(Rect2(c.x - 40, shadow_y - 6, 80, 8), Color(0, 0, 0, 0.35))
		FinaleArt.centred(self, "crate", c, CRATE.x + 8.0)

func _draw_car(train: int, car: int, b: float) -> void:
	var spec: Array = CARS[train][car]
	var left := car_x(train, car, b)
	var w := float(spec[1])
	var lo := maxf(left, portal_in)
	var hi := minf(left + w, portal_out)
	if hi <= lo:
		return
	var key := "train_" + String(spec[0])
	var t := FinaleArt.tex(key)
	if t == null:
		return
	var roof := float(spec[2])
	var top_frac := 0.56 if spec[0] == "flat" else 0.08
	var h := roof / (0.97 - top_frac)
	var top := -roof - h * top_frac
	var u0 := (lo - left) / w
	var u1 := (hi - left) / w
	var dst := Rect2(lo - global_position.x, top, hi - lo, h)
	var src := Rect2(u0 * t.get_width(), 0, (u1 - u0) * t.get_width(), t.get_height())
	draw_texture_rect_region(t, dst, src)
	# Speed: wind streaks trailing off the car and wheel blur, both scaled by
	# how fast the train is actually going (nothing moves while parked).
	var v := train_speed(train, b)
	if v > 60.0:
		var k := clampf(v / VMAX, 0.0, 1.0)
		var tail := lo - global_position.x
		var streaks := PackedVector2Array()
		for i in 5:
			var y := top + h * (0.18 + 0.15 * float(i))
			var len := (60.0 + 50.0 * DrawUtil.hash01(i * 7 + car * 3 + train * 11)) * k
			var x0 := tail - 6.0 - fposmod(b * 900.0 + float(i) * 37.0, 30.0)
			streaks.append(Vector2(x0, y))
			streaks.append(Vector2(x0 - len, y))
		draw_multiline(streaks, Color(1, 1, 1, 0.55 * k), 3.0)
		draw_rect(Rect2(lo - global_position.x, -24, hi - lo, 18), Color(0.25, 0.22, 0.24, 0.35 * k))
	if spec[0] == "loco" and v > 30.0:
		# Exhaust puffs left behind in the air as the loco pulls away.
		var stack := Vector2(left - global_position.x + w * 0.72, top + h * 0.02)
		for i in 6:
			var age := fposmod(b * 2.2 + float(i) / 6.0, 1.0)
			var p := stack + Vector2(-age * v * 0.45, -age * 70.0 - 10.0)
			draw_circle(p, 12.0 + age * 26.0, Color(0.92, 0.92, 0.95, 0.55 * (1.0 - age)))
	if spec[0] == "flat" and train == 0:
		# Cargo lashed on the flatcar.
		FinaleArt.centred(self, "crate", Vector2(left - global_position.x + w * 0.5, -roof - 40), 90.0)

## Portals, cranes and the low bridge, drawn over the trains.
class Top extends Node2D:
	var line
	func _draw() -> void:
		var origin: Vector2 = line.global_position
		var b: float = line.beat()
		# Tunnel mouths: dark openings framed in stone, under the deck/cutting.
		var west: float = line.portal_in - origin.x
		var east: float = line.portal_out - origin.x
		draw_rect(Rect2(west - 140, -160, 140, 180), Color("1c1a22"))
		draw_rect(Rect2(west - 18, -160, 26, 180), Color("7c7468"))
		draw_rect(Rect2(east, -260, 100, 280), Color("1c1a22"))
		draw_rect(Rect2(east - 8, -260, 26, 280), Color("7c7468"))
		for d in line._drops:
			var cx: float = float(d["crane"]) - origin.x
			FinaleArt.sprite(self, "crane", Vector2(cx - 40, 30), 760.0)
			var hook_y: float = line.HOOK_Y
			draw_line(Vector2(cx, hook_y - 200), Vector2(cx, hook_y + 20), Color("3a3a40"), 3.0)
			var warn: float = float(d["t"]) - b
			draw_circle(Vector2(cx, hook_y + 10), 9.0, Color("ff4a3a") if warn < 0.8 and warn > 0 else Color("ffd34a"))
		# Line-side catenary posts in front of the trains: they whip past
		# a runner on a moving roof and sell the train's speed.
		var px: float = line.portal_in - origin.x + 260.0
		while px < east - 120.0:
			draw_rect(Rect2(px - 7, -330, 14, 350), Color("2b2a33"))
			draw_rect(Rect2(px - 40, -332, 80, 10), Color("2b2a33"))
			draw_circle(Vector2(px - 36, -318), 6.0, Color("ffd34a"))
			px += 520.0
		var bx: float = float(line.data.get("low_bridge", 15060.0)) - origin.x
		draw_rect(Rect2(bx, -250, 40, 110), Color("2c2b33"))
		for k in 4:
			draw_rect(Rect2(bx, -250 + k * 28, 40, 14), Color("f0c330"))
		if fposmod(b, 0.6) < 0.3:
			draw_circle(Vector2(bx + 20, -258), 10.0, Color("ff3b30"))
