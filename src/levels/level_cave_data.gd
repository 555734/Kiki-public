extends RefCounted
## 1-8 climbs from the deep mine through a broken cave roof into daylight,
## through twenty-two rooms that are each their own idea. The cave used to be
## one four-step chamber repeated twenty-five times; now no room repeats
## another's shape, its machinery or what it asks of the pair. The rooms,
## bottom to top, are listed in ROOMS and described where they are built.
## Every room records its intended route (SectionBuilder), which
## test/climb_probe.gd climbs for real.
##
## Everything above the cavern floor is taken from below, so every ledge lets
## the runner jump up through it.

const BASE_Y := 13900.0
const FLOOR := Rect2(-500, BASE_Y, 1000, 320)
## Daylight starts above this; the goal is above it.
const SURFACE_Y := 1080.0
## The shelf the climb ends on, and the column of air that carries the runner
## (and the key in it) up to it.
const EXIT_TOP := 1000.0
const KEY_Y := 1290.0
## Ledges are kept inside this half-width of the shaft.
const EDGE := 900.0

## Bottom to top. 0 lets the builder turn the room whichever way keeps it in
## the shaft (SectionBuilder.best_turn); 1 or -1 fixes it.
const ROOMS := [
	["mine_mouth", 1], ["cart_line", 0], ["bat_updraft", 0], ["boulder_stairs", 0],
	["stalactite_gallery", 0], ["crystal_blinks", 0], ["crumble_shaft", 0],
	["warp_ladders", 0], ["ore_sorter", 0], ["mushroom_springs", 0], ["wind_vents", 0],
	["echo_chain", 0], ["double_crevasse", 0], ["burrower_run", 0], ["pad_junction", 0],
	["scaffold_wall", 0], ["cart_elevator", 0], ["beetle_swarm", 0], ["twin_bridges", 0],
	["split_paths", 0], ["slime_terraces", 0], ["surface_breakout", 0],
]

static var _built: SectionBuilder = null
static var _key := Vector2.ZERO

static func built() -> SectionBuilder:
	if _built == null:
		_built = _build()
	return _built

static func kill_y_value() -> float: return 14280.0
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE UNDERGROVE"
static func stage_number_value() -> String: return "1-8"
static func objective_value() -> String: return "Climb out of the cavern"

## Stage traits: what Stage answers for this stage instead of its default.
static func painted_2d_value() -> bool: return true
static func progress_direction_value() -> Vector2: return Vector2.UP
static func needs_key_value() -> bool: return true

## A vertical climb: every ledge and platform above the cavern floor is taken
## from below, so all of them let the runner jump up through them.
static func platforms_one_way() -> bool: return true
static func ground_one_way(rect: Rect2) -> bool:
	return rect.position.y < start_position().y

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(built().ground)
	return out
static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().decor)
	return out
static func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().hazards)
	return out
static func enemies() -> Array[Dictionary]:
	# The chaser first, so every other enemy's net id stays put.
	var out: Array[Dictionary] = [{"type": "sky_pursuer", "pos": start_position() + Vector2(0, 550),
			"activation": 120.0, "delay": 4.0, "speed": 85.0, "catchup": 160.0,
			"stun": 2.5, "direction": Vector2.UP}]
	out.append_array(built().enemies)
	return out
static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().gimmicks)
	return out
static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(built().springs)
	return out
static func checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(built().checkpoints)
	return out
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(built().coins)
	return out
static func route() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().route)
	return out
## Name, bottom and top of every room, for the probes and the review tools.
static func rooms() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().sections)
	return out
## What every room puts in the shaft, by room (SectionBuilder.boxes).
static func boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().boxes)
	return out

static func goal() -> Vector2:
	var b := built()
	return Vector2(b.cursor.get_center().x, b.cursor.position.y - 55.0)
## Hanging in the last column of air, below the goal.
static func key_position() -> Vector2:
	built()
	return _key

# ------------------------------------------------------------------- build
static func _build() -> SectionBuilder:
	# Nothing in the cave is solid from below, however thick.
	var b := SectionBuilder.new(Rect2(start_position().x - 120.0, BASE_Y, 240, 48), INF)
	b.ground.append(FLOOR)
	for i in ROOMS.size():
		var turn := SectionBuilder.best_turn(ROOMS, i, b, EDGE, _room)
		b.begin(String(ROOMS[i][0]), float(turn))
		_room(String(ROOMS[i][0]), b)
		# A lamp and a crystal per room, on the side the room is not using.
		if i < ROOMS.size() - 1:
			b.ornament({"type": "cave_lamp", "pos": b.at(-400, 330)})
			b.ornament({"type": "cave_crystal", "pos": b.at(-360, 150)})
			# Every room but the last ends on a checkpoint.
			b.checkpoint_on(b.cursor)
	return b

static func _room(name: String, b: SectionBuilder) -> void:
	match name:
		"mine_mouth": _mine_mouth(b)
		"cart_line": _cart_line(b)
		"bat_updraft": _bat_updraft(b)
		"boulder_stairs": _boulder_stairs(b)
		"stalactite_gallery": _stalactite_gallery(b)
		"crystal_blinks": _crystal_blinks(b)
		"crumble_shaft": _crumble_shaft(b)
		"warp_ladders": _warp_ladders(b)
		"ore_sorter": _ore_sorter(b)
		"mushroom_springs": _mushroom_springs(b)
		"wind_vents": _wind_vents(b)
		"echo_chain": _echo_chain(b)
		"double_crevasse": _double_crevasse(b)
		"burrower_run": _burrower_run(b)
		"pad_junction": _pad_junction(b)
		"scaffold_wall": _scaffold_wall(b)
		"cart_elevator": _cart_elevator(b)
		"beetle_swarm": _beetle_swarm(b)
		"twin_bridges": _twin_bridges(b)
		"split_paths": _split_paths(b)
		"slime_terraces": _slime_terraces(b)
		"surface_breakout": _surface_breakout(b)
		_: push_error("1-8: no room called " + name)

# ----------------------------------------------------------------- helpers
## A ground enemy walking a ledge, kept off its ends.
static func _walker(b: SectionBuilder, kind: String, on: Rect2, dx: float = 0.0,
		patrol: float = 90.0) -> void:
	b.enemy({"type": "cave_enemy", "kind": kind, "pos": b.top_of(on, dx) + Vector2(0, -27),
		"patrol": minf(patrol, on.size.x * 0.5 - 30.0)})

## A bat or beetle darting about a box round (dx, dy), never on a fixed path.
static func _flier(b: SectionBuilder, kind: String, dx: float, dy: float, box: Vector2,
		dart: float = 1.3) -> void:
	b.enemy({"type": "cave_enemy", "kind": kind, "pos": b.at(dx, dy), "patrol": 60.0,
		"wander": box, "dart": dart})

## A minecart lift. `period` is shared by lifts that hand the runner over, so
## they stay in step: each one's speed is set from its travel to match it.
static func _cart(b: SectionBuilder, dx: float, dy: float, travel: Vector2, period: float,
		phase: float) -> Vector2:
	var at := b.surface(dx, dy)
	b.gimmick({"type": "moving_platform", "style": "minecart", "pos": at,
		"span": Vector2(180, 26), "travel": travel, "speed": 2.0 * travel.length() / period,
		"phase": phase})
	return at

## A hidden landing and the target that raises it.
static func _echo(b: SectionBuilder, id: String, dx: float, dy: float, w: float,
		target: Vector2) -> Rect2:
	b.gimmick({"type": "switch", "id": id, "pos": b.at(target.x, target.y), "hold": 11.0})
	var at := b.surface(dx, dy)
	b.gimmick({"type": "switch_bridge", "id": id, "pos": at, "span": Vector2(w, 26)})
	return Rect2(at.x - w * 0.5, at.y - 13.0, w, 26)

# ------------------------------------------------------------------- rooms
## 1. The mine's mouth: a ladder of stone straight up off the cavern floor, a
## slime and a mushroom on the way. Nothing moves yet.
static func _mine_mouth(b: SectionBuilder) -> void:
	var s: Array[Rect2] = [b.ledge(0, 110, 200), b.ledge(190, 225, 180),
		b.ledge(20, 340, 180), b.ledge(200, 455, 180)]
	var x: Rect2 = b.ledge(40, 570, 220)
	b.jump(b.cursor, s[0])
	for k in s.size() - 1:
		b.jump(s[k], s[k + 1])
	b.jump(s[-1], x)
	_walker(b, "slime", s[1], 0.0, 50.0)
	_walker(b, "mushroom", s[3], 0.0, 50.0)
	for r in s:
		b.coins_over(r)
	b.coins_over(x, 2)
	b.finish(x)

## 2. A cart line over a drop: one cart runs across, a second lifts, a third
## runs back. They meet on the beat, so the runner changes carts on the move.
static func _cart_line(b: SectionBuilder) -> void:
	var period := 5.6
	var side := float(b.side())
	var c1 := _cart(b, 240, 40, Vector2(side * 320.0, 0), period, 0.0)
	var c2 := _cart(b, 740, 40, Vector2(0, -300), period, period * 0.5)
	var c3 := _cart(b, 500, 400, Vector2(-side * 300.0, 0), period, 0.0)
	var x: Rect2 = b.ledge(60, 470, 200)
	b.ride("timed", b.cursor, x, {"pieces": [c1, c2, c3], "tries": 12, "spacing": 29,
		"frames": 1500})
	b.ornament({"type": "cave_rail", "pos": b.at(400, 30), "width": 340.0})
	_flier(b, "beetle", 480, 220, Vector2(150, 60), 1.5)
	_flier(b, "bat", 700, 460, Vector2(80, 50))
	_flier(b, "bat", 150, 300, Vector2(70, 50), 1.6)
	b.coin_line(300, 120, 600, 120, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 3. A shaft of rising air with bats darting about inside it. Steer round
## them on the way up, or have the guardian clear the way.
static func _bat_updraft(b: SectionBuilder) -> void:
	var base: Vector2 = b.at(250, -10)
	b.gimmick({"type": "updraft", "pos": base, "span": Vector2(170, 700)})
	for k in 3:
		_flier(b, "bat", 250, 200.0 + 150.0 * float(k), Vector2(55, 40), 1.1 + 0.2 * float(k))
	var x: Rect2 = b.ledge(420, 640, 200)
	b.ride("updraft", b.cursor, x, {"at": base})
	b.coin_line(250, 120, 250, 560, 5)
	b.coins_over(x, 2)
	b.finish(x)

## 4. Broad stairs with a boulder rolling back and forth on every step: hop up
## between rolls.
static func _boulder_stairs(b: SectionBuilder) -> void:
	var steps: Array[Rect2] = [b.ledge(220, 110, 260), b.ledge(470, 230, 260),
		b.ledge(220, 350, 260), b.ledge(470, 470, 260)]
	var x: Rect2 = b.ledge(220, 590, 240)
	for k in steps.size():
		b.gimmick({"type": "cave_trap", "kind": "boulder",
			"pos": b.top_of(steps[k]) + Vector2(0, -40), "travel": 80.0,
			"period": 3.0 + 0.3 * float(k), "phase": 0.7 * float(k)})
	b.jump(b.cursor, steps[0])
	for k in steps.size() - 1:
		b.jump(steps[k], steps[k + 1])
	b.jump(steps[-1], x)
	_flier(b, "bat", 340, 420, Vector2(120, 50), 1.6)
	_flier(b, "beetle", 600, 160, Vector2(60, 60), 1.3)
	b.coin_line(220, 200, 470, 320, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 5. A gallery under hanging stone: stalactites drop in a wave along a long
## walkway, and again along the one above. Keep moving, or wait out a drop.
static func _stalactite_gallery(b: SectionBuilder) -> void:
	var w1: Rect2 = b.ledge(380, 60, 600)
	var e1: Rect2 = b.ledge(770, 170, 140)
	var w2: Rect2 = b.ledge(400, 290, 520)
	var e2: Rect2 = b.ledge(60, 410, 160)
	var x: Rect2 = b.ledge(300, 530, 300)
	# Under w2, dropping onto w1 ...
	for k in 4:
		b.gimmick({"type": "cave_trap", "kind": "stalactite",
			"pos": b.at(200.0 + 150.0 * float(k), 242), "travel": 150.0,
			"period": 2.6, "phase": 0.5 * float(k)})
	# ... and under x, dropping onto w2.
	for k in 2:
		b.gimmick({"type": "cave_trap", "kind": "stalactite",
			"pos": b.at(220.0 + 160.0 * float(k), 482), "travel": 150.0,
			"period": 2.4, "phase": 0.6 * float(k)})
	b.jump(b.cursor, w1)
	b.jump(w1, e1)
	b.jump(e1, w2)
	b.jump(w2, e2)
	b.jump(e2, x)
	_walker(b, "slime", w1, -150.0, 60.0)
	_walker(b, "mushroom", w2, 120.0, 60.0)
	b.coin_line(150, 110, 650, 110, 5)
	b.coin_line(200, 340, 600, 340, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 6. A staircase of crystal that lights in a wave: each step wakes a beat
## after the one below, so the climb has to keep pace with it.
static func _crystal_blinks(b: SectionBuilder) -> void:
	var beat := 1.6
	var pieces: Array = []
	for k in 6:
		var at: Vector2 = b.surface(200.0 if k % 2 == 0 else 380.0, 100.0 + 100.0 * float(k))
		# Alternate colours, the same wave: the second colour runs half a cycle
		# late, so its phase gives the half back.
		b.gimmick({"type": "blink", "pos": at, "span": Vector2(150, 26), "beat": beat,
			"colour": k % 2, "phase": -0.45 * float(k) - beat * float(k % 2)})
		pieces.append(at)
		b.coin(200.0 if k % 2 == 0 else 380.0, 170.0 + 100.0 * float(k))
	var x: Rect2 = b.ledge(290, 700, 240)
	b.ride("timed", b.cursor, x, {"pieces": pieces, "tries": 20, "spacing": 13,
		"frames": 1500})
	_flier(b, "beetle", 520, 380, Vector2(60, 120), 1.4)
	_flier(b, "bat", 60, 520, Vector2(60, 90), 1.7)
	b.coins_over(x, 2)
	b.finish(x)

## 7. A shaft of crumbling stone, left and right and left: each gives way soon
## after it is stood on, and none sits in the arc of a jump before its turn.
static func _crumble_shaft(b: SectionBuilder) -> void:
	var pieces: Array = []
	for k in 5:
		var at: Vector2 = b.at(200.0 if k % 2 == 0 else 380.0, 115.0 + 115.0 * float(k)) \
			+ Vector2(0, 18)
		b.gimmick({"type": "crumble", "pos": at, "span": Vector2(130, 36)})
		pieces.append(at)
	var x: Rect2 = b.ledge(380, 690, 220)
	b.ride("timed", b.cursor, x, {"pieces": pieces, "tries": 4, "spacing": 60, "frames": 1200})
	_flier(b, "bat", 580, 300, Vector2(70, 90), 1.2)
	_flier(b, "bat", 0, 520, Vector2(70, 90), 1.5)
	b.coin_line(290, 160, 290, 620, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 8. Snakes and ladders: five crystal portals on a scramble of ledges. Two
## climb (one skips a floor, one goes straight to the top), one drops the
## runner back to the first ledge, one opens on a coin alcove, and the
## alcove's own portal throws back to the room's start. Each is marked, so the
## pair can learn them.
static func _warp_ladders(b: SectionBuilder) -> void:
	var entry: Rect2 = b.cursor
	var l1: Rect2 = b.ledge(240, 110, 240)
	var l2: Rect2 = b.ledge(40, 230, 200)
	var l3: Rect2 = b.ledge(100, 420, 220)
	var l3b: Rect2 = b.ledge(-160, 420, 120)
	var alcove: Rect2 = b.ledge(-300, 470, 160)
	var l4: Rect2 = b.ledge(320, 540, 200)
	var x: Rect2 = b.ledge(120, 820, 240)
	# [mouth dx, standing on, leads to]
	var portals := [[330.0, l1, l3], [-30.0, l2, alcove], [-160.0, l3b, l1],
		[410.0, l4, x], [-340.0, alcove, entry]]
	var mouths: Array[Vector2] = []
	for k in portals.size():
		var on: Rect2 = portals[k][1]
		var to: Rect2 = portals[k][2]
		var mouth := Vector2(b.at(float(portals[k][0]), 0).x, on.position.y - 55.0)
		var exit := Vector2(to.get_center().x, to.position.y - 40.0)
		mouths.append(mouth)
		b.gimmick({"type": "warp", "pos": mouth, "size": Vector2(78, 106), "exit": exit,
			"mark": k + 1})
		b.gimmick({"type": "warp_exit", "pos": exit + Vector2(0, -20), "size": Vector2(78, 106),
			"mark": k + 1})
	b.jump(entry, l1)
	b.ride("warp", l1, l3, {"at": mouths[0]})
	b.jump(l3, l4)
	b.ride("warp", l4, x, {"at": mouths[3]})
	_walker(b, "mushroom", l2, 40.0, 40.0)
	_flier(b, "beetle", 300, 680, Vector2(90, 50), 1.4)
	b.coins_over(alcove, 4, 34)
	b.coins_over(l3, 2)
	b.coins_over(x, 3)
	b.finish(x)

## 9. The ore sorter: belts stacked over each other, running opposite ways and
## turning round now and then, with a boulder rolling along the middle one and
## beetles flitting between.
static func _ore_sorter(b: SectionBuilder) -> void:
	var b1: Vector2 = b.surface(280, 100)
	b.gimmick({"type": "conveyor", "pos": b1, "span": Vector2(360, 26), "speed": 120.0,
		"flip": 3.0, "dir": b.side(), "phase": 0.0})
	var b2: Vector2 = b.surface(500, 220)
	b.gimmick({"type": "conveyor", "pos": b2, "span": Vector2(300, 26), "speed": 120.0,
		"flip": 2.6, "dir": -b.side(), "phase": 1.0})
	var b3: Vector2 = b.surface(260, 340)
	b.gimmick({"type": "conveyor", "pos": b3, "span": Vector2(300, 26), "speed": 120.0,
		"flip": 3.4, "dir": b.side(), "phase": 0.5})
	var r1 := Rect2(b1.x - 180.0, b1.y - 13.0, 360, 26)
	var r2 := Rect2(b2.x - 150.0, b2.y - 13.0, 300, 26)
	var r3 := Rect2(b3.x - 150.0, b3.y - 13.0, 300, 26)
	b.gimmick({"type": "cave_trap", "kind": "boulder", "pos": b2 + Vector2(0, -53),
		"travel": 90.0, "period": 3.6, "phase": 0.0})
	var x: Rect2 = b.ledge(480, 460, 220)
	b.step("jump", b.cursor, r1, {"tries": 6, "spacing": 23})
	b.step("jump", r1, r2, {"tries": 6, "spacing": 23})
	b.step("jump", r2, r3, {"tries": 6, "spacing": 23})
	b.step("jump", r3, x, {"tries": 6, "spacing": 23})
	_flier(b, "beetle", 620, 120, Vector2(80, 60), 1.2)
	_flier(b, "beetle", 120, 260, Vector2(80, 60), 1.6)
	b.coin_line(150, 160, 400, 160, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 10. A garden of spring-capped mushrooms jutting from alternate sides: land
## on a cap's outer half, step onto its spring, and steer across to the next.
static func _mushroom_springs(b: SectionBuilder) -> void:
	var l1: Rect2 = b.ledge(289, 40, 190)
	var r1: Rect2 = b.ledge(351, 240, 190)
	var l2: Rect2 = b.ledge(289, 440, 190)
	var x: Rect2 = b.ledge(320, 640, 348)
	var shelf: Rect2 = b.ledge(620, 360, 140)
	var s1: Vector2 = b.spring_on(l1, 75)
	var s2: Vector2 = b.spring_on(r1, -75)
	var s3: Vector2 = b.spring_on(l2, 75)
	b.jump(b.cursor, l1)
	b.ride("spring", l1, r1, {"at": s1})
	b.ride("spring", r1, l2, {"at": s2})
	b.ride("spring", l2, x, {"at": s3})
	_walker(b, "mushroom", shelf, 0.0, 30.0)
	_flier(b, "bat", 80, 300, Vector2(60, 80), 1.3)
	_flier(b, "beetle", 560, 560, Vector2(60, 50), 1.6)
	b.coins_over(shelf, 3, 34)
	b.coin_line(320, 160, 320, 600, 4)
	b.coins_over(x, 3)
	b.finish(x)

## 11. Wind vents: three short columns of air, out and back and out again.
## Step off each ledge into a vent, ride it up and drift onto the next.
static func _wind_vents(b: SectionBuilder) -> void:
	var v1: Vector2 = b.at(150, 0)
	var m1: Rect2 = b.ledge(315, 250, 180)
	var v2: Vector2 = b.at(510, 250)
	var m2: Rect2 = b.ledge(345, 500, 180)
	var v3: Vector2 = b.at(150, 500)
	var x: Rect2 = b.ledge(315, 760, 180)
	for v in [v1, v2, v3]:
		b.gimmick({"type": "updraft", "pos": v, "span": Vector2(150, 330)})
	b.ride("updraft", b.cursor, m1, {"at": v1})
	b.ride("updraft", m1, m2, {"at": v2})
	b.ride("updraft", m2, x, {"at": v3})
	_flier(b, "bat", 330, 380, Vector2(100, 40), 1.4)
	_flier(b, "bat", 330, 640, Vector2(100, 40), 1.7)
	_flier(b, "beetle", 600, 150, Vector2(60, 70), 1.4)
	b.coin_line(150, 120, 150, 300, 3)
	b.coin_line(510, 380, 510, 560, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 12. A chain of missing landings: two ledges that only exist for a few
## seconds after the guardian shoots their targets, one above the other.
static func _echo_chain(b: SectionBuilder) -> void:
	var s1: Rect2 = b.ledge(180, 110, 200)
	var h1 := _echo(b, "cave_rise_a", 400, 230, 200, Vector2(560, 320))
	var h2 := _echo(b, "cave_rise_b", 180, 350, 200, Vector2(20, 440))
	var x: Rect2 = b.ledge(400, 470, 220)
	b.jump(b.cursor, s1)
	b.ride("echo", s1, h1, {"id": "cave_rise_a"})
	b.ride("echo", h1, h2, {"id": "cave_rise_b"})
	b.jump(h2, x)
	_flier(b, "bat", 300, 260, Vector2(110, 50), 1.5)
	_flier(b, "beetle", 560, 120, Vector2(60, 50), 1.3)
	b.coins_over(s1)
	b.coin_line(180, 420, 400, 300, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 13. A crevasse climbed on second jumps, with stalactites dropping across it.
static func _double_crevasse(b: SectionBuilder) -> void:
	var d1: Rect2 = b.ledge(240, 225, 160)
	var d2: Rect2 = b.ledge(30, 450, 160)
	var d3: Rect2 = b.ledge(250, 675, 200)
	b.double(b.cursor, d1)
	b.double(d1, d2)
	b.double(d2, d3)
	for k in 2:
		b.gimmick({"type": "cave_trap", "kind": "stalactite",
			"pos": b.at(140.0, 330.0 + 225.0 * float(k)), "travel": 130.0,
			"period": 2.8, "phase": 1.2 * float(k)})
	_flier(b, "beetle", 380, 400, Vector2(60, 100), 1.3)
	_flier(b, "bat", -110, 560, Vector2(60, 80), 1.6)
	for r in [d1, d2]:
		b.coins.append(Vector2(r.get_center().x, r.position.y - 150.0))
	b.coins_over(d3, 2)
	b.finish(d3)

## 14. Long benches where burrowers dig back and forth: get past them, or let
## the guardian put them down (they take two shots).
static func _burrower_run(b: SectionBuilder) -> void:
	var r1: Rect2 = b.ledge(260, 110, 460)
	var r2: Rect2 = b.ledge(540, 230, 300)
	var r3: Rect2 = b.ledge(260, 350, 460)
	var x: Rect2 = b.ledge(540, 470, 240)
	b.jump(b.cursor, r1)
	b.jump(r1, r2)
	b.jump(r2, r3)
	b.jump(r3, x)
	_walker(b, "burrower", r1, -40.0, 150.0)
	_walker(b, "slime", r2, 0.0, 90.0)
	_flier(b, "bat", 260, 260, Vector2(150, 40), 1.4)
	_walker(b, "burrower", r3, 40.0, 150.0)
	b.coins_over(r1, 3, 40)
	b.coins_over(r3, 3, 40)
	b.coins_over(x, 2)
	b.finish(x)

## 15. A junction of arrow pads that turn round on the clock: launched the
## right way the runner lands a floor up, the wrong way in a coin pocket. Each
## pad throws back across the one below, so the room folds over itself.
static func _pad_junction(b: SectionBuilder) -> void:
	var floor_: Rect2 = b.ledge(300, 60, 520)
	var pad1: Vector2 = b.top_of(floor_, 170)
	b.gimmick({"type": "trick_pad", "pos": pad1, "dir": -b.side(), "flip": 2.4,
		"phase": 0.0, "forward": 380.0, "rise": 1200.0})
	var r1: Rect2 = b.ledge(230, 290, 200)
	var pocket1: Rect2 = b.ledge(670, 240, 120)
	var pad2: Vector2 = b.top_of(r1, -60)
	b.gimmick({"type": "trick_pad", "pos": pad2, "dir": b.side(), "flip": 3.0,
		"phase": 0.8, "forward": 380.0, "rise": 1200.0})
	var x: Rect2 = b.ledge(410, 520, 200)
	var pocket2: Rect2 = b.ledge(-30, 470, 120)
	b.jump(b.cursor, floor_)
	b.ride("pad", floor_, r1, {"at": pad1, "dir": -b.side()})
	b.ride("pad", r1, x, {"at": pad2, "dir": b.side()})
	_walker(b, "mushroom", floor_, -60.0, 50.0)
	b.coins_over(pocket1, 3, 34)
	b.coins_over(pocket2, 3, 34)
	b.coins_over(x, 2)
	b.finish(x)

## 16. A blank stretch of rock far beyond any jump: the guardian scaffolds the
## way up, two platforms at a time, while a bat worries at the runner.
static func _scaffold_wall(b: SectionBuilder) -> void:
	var x: Rect2 = b.ledge(330, 430, 220)
	var p1: Rect2 = b.platform(150, 143)
	var p2: Rect2 = b.platform(260, 286)
	b.assist(b.cursor, x, [p1, p2])
	_flier(b, "bat", 120, 300, Vector2(70, 60), 1.2)
	_flier(b, "beetle", 420, 200, Vector2(60, 60), 1.5)
	b.gimmick({"type": "cave_trap", "kind": "stalactite", "pos": b.at(-80, 330),
		"travel": 140.0, "period": 3.2, "phase": 0.4})
	b.coin_line(150, 210, 260, 350, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 17. A mine elevator: two cars rising side by side half a beat apart, and a
## shuttle across the top. Step from car to car as they pass.
static func _cart_elevator(b: SectionBuilder) -> void:
	var period := 5.6
	var c1 := _cart(b, 200, 40, Vector2(0, -300), period, 0.0)
	var c2 := _cart(b, 400, 320, Vector2(0, -300), period, period * 0.5)
	var c3 := _cart(b, 220, 680, Vector2(-float(b.side()) * 300.0, 0), period, 0.0)
	var x: Rect2 = b.ledge(-200, 760, 200)
	b.ride("timed", b.cursor, x, {"pieces": [c1, c2, c3], "tries": 12, "spacing": 29,
		"frames": 1500})
	b.ornament({"type": "cave_rail", "pos": b.at(300, 330), "width": 300.0})
	_flier(b, "beetle", 560, 400, Vector2(60, 120), 1.5)
	b.coin_line(300, 200, 300, 600, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 18. Stepping stones out and back under a swarm of beetles that dart where
## they please.
static func _beetle_swarm(b: SectionBuilder) -> void:
	var stones: Array[Rect2] = [b.ledge(240, 80, 170), b.ledge(460, 190, 170),
		b.ledge(680, 300, 170), b.ledge(460, 410, 170), b.ledge(240, 520, 170)]
	var x: Rect2 = b.ledge(20, 630, 200)
	b.jump(b.cursor, stones[0])
	for k in stones.size() - 1:
		b.jump(stones[k], stones[k + 1])
	b.jump(stones[-1], x)
	for k in 5:
		_flier(b, "beetle", 200.0 + 120.0 * float(k), 160.0 + 70.0 * float(k % 3),
			Vector2(90, 55), 1.0 + 0.2 * float(k))
	for r in stones:
		b.coins_over(r)
	b.coins_over(x, 2)
	b.finish(x)

## 19. A chasm too wide for any jump, and later a second one back: the
## guardian shoots the target over each and a bridge rises for a while.
## Between them the far side climbs on second jumps, high enough that the way
## back cannot be jumped from where the room began.
static func _twin_bridges(b: SectionBuilder) -> void:
	var entry: Rect2 = b.cursor
	var reach := entry.size.x * 0.5
	var far: Rect2 = b.ledge(reach + 680.0, 0, 160)
	var s1: Rect2 = b.ledge(reach + 640.0, 175, 160)
	var s2: Rect2 = b.ledge(reach + 660.0, 400, 160)
	var w: Rect2 = b.ledge(-40, 400, 200)
	var x: Rect2 = b.ledge(170, 520, 220)
	_echo(b, "cave_rise_c", reach + 300.0, 0, 600.0, Vector2(reach + 300.0, 230))
	_echo(b, "cave_rise_d", (60.0 + reach + 580.0) * 0.5, 400, reach + 520.0,
		Vector2((60.0 + reach + 580.0) * 0.5, 630))
	_flier(b, "bat", reach + 300.0, 150, Vector2(200, 34), 1.9)
	_flier(b, "beetle", reach + 300.0, 520, Vector2(180, 30), 1.7)
	b.ride("echo", entry, far, {"id": "cave_rise_c"})
	b.double(far, s1)
	b.double(s1, s2)
	b.ride("echo", s2, w, {"id": "cave_rise_d"})
	b.jump(w, x)
	b.coin_line(reach + 100.0, 60, reach + 500.0, 60, 5)
	b.coin_line(reach + 100.0, 460, reach + 500.0, 460, 5)
	b.coins_over(x, 2)
	b.finish(x)

## 20. A fork: blinking crystal up one side, crumbling stone up the other,
## meeting again at the top. Either will do; the pair picks.
static func _split_paths(b: SectionBuilder) -> void:
	var x: Rect2 = b.ledge(0, 480, 220)
	var lit: Array = []
	var crumbling: Array = []
	var spots := [Vector2(200, 120), Vector2(380, 240), Vector2(200, 360)]
	for k in spots.size():
		var p: Vector2 = spots[k]
		var a: Vector2 = b.surface(-p.x, p.y)
		b.gimmick({"type": "blink", "pos": a, "span": Vector2(150, 26), "beat": 1.6,
			"colour": 0, "phase": -0.45 * float(k)})
		lit.append(a)
		var c: Vector2 = b.at(p.x, p.y) + Vector2(0, 18)
		b.gimmick({"type": "crumble", "pos": c, "span": Vector2(130, 36)})
		crumbling.append(c)
	b.ride("timed", b.cursor, x, {"pieces": lit, "tries": 20, "spacing": 13, "frames": 1200})
	b.ride("timed", b.cursor, x, {"pieces": crumbling, "tries": 4, "spacing": 60,
		"frames": 1200})
	_flier(b, "bat", 0, 280, Vector2(60, 100), 1.4)
	_flier(b, "beetle", 0, 210, Vector2(60, 40), 1.2)
	b.coin_line(-380, 300, -200, 420, 3)
	b.coin_line(380, 300, 200, 420, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 21. Terraces where slimes and a mushroom keep house, and a cart that runs
## across the one gap too wide to jump.
static func _slime_terraces(b: SectionBuilder) -> void:
	var t1: Rect2 = b.ledge(300, 110, 400)
	var t2: Rect2 = b.ledge(600, 230, 260)
	var cart := _cart(b, 380, 260, Vector2(-float(b.side()) * 260.0, 0), 5.8, 0.0)
	var t3: Rect2 = b.ledge(-60, 350, 240)
	var x: Rect2 = b.ledge(120, 470, 220)
	b.jump(b.cursor, t1)
	b.jump(t1, t2)
	b.ride("timed", t2, t3, {"pieces": [cart], "tries": 12, "spacing": 29})
	b.jump(t3, x)
	_walker(b, "slime", t1, -60.0, 120.0)
	_walker(b, "mushroom", t2, 30.0, 70.0)
	_walker(b, "slime", t3, 0.0, 70.0)
	b.coins_over(t1, 3, 40)
	b.coins_over(x, 2)
	b.finish(x)

## 22. The breakout: a last scramble of ledges (as many as it takes to reach
## the roof), then a column of air through the broken roof into daylight,
## with the exit key hanging in it, and the goal on the grass above.
static func _surface_breakout(b: SectionBuilder) -> void:
	var origin_y := b.at(0, 0).y
	var at: Rect2 = b.cursor
	var k := 0
	# Up to a ledge whose top is between EXIT_TOP + 420 and + 540: the column
	# from there reaches the shelf, with the key in its lower half.
	while at.position.y - 120.0 >= EXIT_TOP + 420.0:
		var dy := origin_y - at.position.y + 120.0
		var next: Rect2 = b.ledge(160.0 if k % 2 == 0 else -20.0, dy, 180)
		b.jump(at, next)
		b.coins_over(next)
		if k == 1:
			_flier(b, "beetle", 330, dy + 80.0, Vector2(60, 40), 1.6)
		at = next
		k += 1
	var base := Vector2(at.get_center().x + float(b.side()) * 190.0, at.position.y + 10.0)
	b.gimmick({"type": "updraft", "pos": base, "span": Vector2(170, base.y - (EXIT_TOP - 60.0))})
	_key = Vector2(base.x, KEY_Y)
	for i in 4:
		b.coins.append(Vector2(base.x, base.y - 100.0 - 110.0 * float(i)))
	var shelf := Rect2(base.x + float(b.side()) * 170.0 - 110.0, EXIT_TOP, 220, 48)
	b.ride("updraft", at, shelf, {"at": base})
	# The shelf is the stage's last piece of ground: the goal stands on it.
	b.add_ground(shelf)
	b.coins_over(shelf, 3)
	b.finish(shelf)
