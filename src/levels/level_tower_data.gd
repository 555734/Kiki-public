extends RefCounted
## 1-7: the clockwork tower, climbed through twenty rooms that are each their
## own idea. The tower used to be one four-landing chamber repeated
## twenty-three times; now no room repeats another's shape, its machinery or
## what it asks of the pair. The rooms, bottom to top, are listed in ROOMS and
## described where they are built. Every room records its intended route
## (SectionBuilder), which test/climb_probe.gd climbs for real.
##
## Ledges are thin and can be jumped through from below, as a climb's should
## be; walls, the piston corridor's roof and the entrance floor are thick and
## solid (see ground_one_way).

const BASE_Y := 14400.0
const FLOOR := Rect2(-560, BASE_Y, 1120, 240)
## Ledges are kept inside this half-width of the shaft.
const EDGE := 900.0
## Anything this thick or thicker is solid from below.
const SOLID_FROM := 56.0

## Bottom to top. 0 lets the builder turn the room whichever way keeps it in
## the shaft (see _best_turn); 1 or -1 fixes it.
const ROOMS := [
	["first_flight", 1], ["gear_bridge", 0], ["clock_hands", 0],
	["blink_wave", 0], ["piston_corridor", 0], ["pendulum_gaps", 0],
	["conveyor_boost", 0], ["crumble_rush", 0], ["warp_hall", 0],
	["updraft_mines", 0], ["spring_chimney", 0], ["pad_pinball", 0],
	["sigil_door", 0], ["echo_bridge", 0], ["double_ladder", 0],
	["guardian_wall", 0], ["lift_transfer", 0], ["mine_field", 0],
	["spike_gauntlet", 0], ["clock_crown", 0],
]

static var _built: SectionBuilder = null

static func built() -> SectionBuilder:
	if _built == null:
		_built = _build()
	return _built

static func kill_y_value() -> float: return 14940.0
static func start_position() -> Vector2: return Vector2(-360, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE CLOCKWORK TOWER"
static func stage_number_value() -> String: return "1-7"
static func objective_value() -> String: return "Climb the clockwork tower"

## Stage traits: what Stage answers for this stage instead of its default.
static func painted_2d_value() -> bool: return true
static func progress_direction_value() -> Vector2: return Vector2.UP
## Lifts, blinks and belts can be jumped up through, like the ledges.
static func platforms_one_way() -> bool: return true
static func ground_one_way(rect: Rect2) -> bool:
	return rect.size.y < SOLID_FROM

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(built().ground)
	return out
static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().hazards)
	return out
static func enemies() -> Array[Dictionary]:
	# The chaser first, so every other enemy's net id stays put.
	var out: Array[Dictionary] = [{"type": "sky_pursuer",
		"pos": start_position() + Vector2(0, 550),
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
static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(built().decor)
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

# ------------------------------------------------------------------- build
static func _build() -> SectionBuilder:
	var b := SectionBuilder.new(Rect2(start_position().x - 120.0, BASE_Y, 240, 48), SOLID_FROM)
	b.ground.append(FLOOR)
	for i in ROOMS.size():
		var room: Array = ROOMS[i]
		var turn := SectionBuilder.best_turn(ROOMS, i, b, EDGE, _room)
		b.begin(String(room[0]), float(turn))
		_room(String(room[0]), b)
		# A banner and a lamp per room, on the side the room is not using.
		b.ornament({"type": "tower_banner", "pos": b.at(-430, 170)})
		b.ornament({"type": "tower_lamp", "pos": b.at(-390, 470)})
		# Every other room ends on a checkpoint, and so does the one before the
		# last; the last ends on the goal.
		if (i % 2 == 1 and i < ROOMS.size() - 1) or i == ROOMS.size() - 2:
			b.checkpoint_on(b.cursor)
	return b

static func _room(name: String, b: SectionBuilder) -> void:
	match name:
		"first_flight": _first_flight(b)
		"gear_bridge": _gear_bridge(b)
		"clock_hands": _clock_hands(b)
		"blink_wave": _blink_wave(b)
		"piston_corridor": _piston_corridor(b)
		"pendulum_gaps": _pendulum_gaps(b)
		"conveyor_boost": _conveyor_boost(b)
		"crumble_rush": _crumble_rush(b)
		"warp_hall": _warp_hall(b)
		"updraft_mines": _updraft_mines(b)
		"spring_chimney": _spring_chimney(b)
		"pad_pinball": _pad_pinball(b)
		"sigil_door": _sigil_door(b)
		"echo_bridge": _echo_bridge(b)
		"double_ladder": _double_ladder(b)
		"guardian_wall": _guardian_wall(b)
		"lift_transfer": _lift_transfer(b)
		"mine_field": _mine_field(b)
		"spike_gauntlet": _spike_gauntlet(b)
		"clock_crown": _clock_crown(b)
		_: push_error("1-7: no room called " + name)

# ------------------------------------------------------------------- rooms
## 1. A first flight of stairs off the entrance floor: nothing moves yet.
static func _first_flight(b: SectionBuilder) -> void:
	var steps: Array[Rect2] = [b.ledge(240, 110, 220), b.ledge(470, 225, 200),
		b.ledge(250, 340, 220), b.ledge(30, 455, 220)]
	var x: Rect2 = b.ledge(250, 570, 240)
	b.jump(b.cursor, steps[0])
	for k in steps.size() - 1:
		b.jump(steps[k], steps[k + 1])
	b.jump(steps[-1], x)
	for r in steps:
		b.coins_over(r, 2)
	b.coins_over(x, 3)
	b.finish(x)

## 2. A gap too wide to jump, with a gear wheel turning in it: hop onto a deck
## as it comes up, ride it over the top, and step off on the far side. Then
## up two steps past a mine that cannot keep still.
static func _gear_bridge(b: SectionBuilder) -> void:
	# The wheel turns just past the end of the ledge the room starts on, so a
	# deck comes level within a hop of it.
	var reach := b.cursor.size.x * 0.5
	var hub: Vector2 = b.at(reach + 170.0, -80)
	b.gimmick({"type": "gear_wheel", "pos": hub, "radius": 115.0, "speed": 0.42,
		"dir": b.side(), "phase": 0.0})
	var f: Rect2 = b.ledge(reach + 430.0, 120, 220)
	var g: Rect2 = b.ledge(reach + 210.0, 240, 200)
	var h: Rect2 = b.ledge(reach + 430.0, 360, 200)
	var x: Rect2 = b.ledge(reach + 210.0, 480, 220)
	b.enemy({"type": "mine", "pos": b.at(reach + 280.0, 300), "bob": Vector2.ZERO,
		"period": 3.4, "phase": 0.3, "wander": Vector2(120, 34), "dart": 1.6})
	b.ride("timed", b.cursor, f, {"pieces": [hub], "tries": 18, "spacing": 29})
	b.jump(f, g)
	b.jump(g, h)
	b.jump(h, x)
	for k in 5:
		var a := -0.8 + 0.4 * float(k)
		b.coins.append(hub + Vector2(sin(a) * float(b.side()), -cos(a)) * 175.0)
	b.coins_over(g)
	b.coins_over(x, 2)
	b.finish(x)

## 3. Two clock hands rocking like seesaws, one above the other: board each
## where it dips to you, walk up it as it rises, and step off at the top.
static func _clock_hands(b: SectionBuilder) -> void:
	# A hand always reaches right from its pivot. Turning right, the hands are
	# boarded at the pivot and left at the tip; turning left, the other way.
	var entry: Rect2 = b.cursor
	var right := not b.mirrored()
	var hand1 := Vector2(entry.end.x + 30.0 if right else entry.position.x - 290.0, entry.position.y - 70.0)
	b.gimmick({"type": "clock_hand", "pos": hand1, "length": 260.0, "period": 4.0, "phase": 0.0})
	var m: Rect2
	if right:
		m = b.add_ground(Rect2(hand1.x + 260.0 + 10.0, hand1.y - 160.0, 180, 48))
	else:
		m = b.add_ground(Rect2(hand1.x - 200.0, hand1.y - 105.0, 180, 48))
	var hand2 := Vector2(m.position.x - 300.0 if right else m.end.x + 30.0, m.position.y - 70.0)
	b.gimmick({"type": "clock_hand", "pos": hand2, "length": 260.0, "period": 4.4, "phase": 1.1})
	var x: Rect2
	if right:
		x = b.add_ground(Rect2(hand2.x - 220.0, hand2.y - 105.0, 200, 48))
	else:
		x = b.add_ground(Rect2(hand2.x + 260.0 + 10.0, hand2.y - 160.0, 200, 48))
	b.ride("timed", entry, m, {"pieces": [hand1], "tries": 16, "spacing": 17})
	b.ride("timed", m, x, {"pieces": [hand2], "tries": 16, "spacing": 17})
	b.coins.append(hand1 + Vector2(130, -80))
	b.coins.append(hand2 + Vector2(130, -80))
	b.coins_over(m)
	b.coins_over(x, 3)
	b.finish(x)

## 4. A wave of blinking stones across the shaft and back: each wakes a beat
## after the one before, so the pair keeps moving or loses the floor.
static func _blink_wave(b: SectionBuilder) -> void:
	var out: Array = []
	for k in 4:
		var pos: Vector2 = b.surface(240.0 + 165.0 * float(k), 50.0 + 55.0 * float(k))
		b.gimmick({"type": "blink", "pos": pos, "span": Vector2(150, 26), "beat": 1.6,
			"colour": 0, "phase": -0.5 * float(k)})
		out.append(pos)
		b.coin(240.0 + 165.0 * float(k), 120.0 + 55.0 * float(k))
	var m: Rect2 = b.ledge(900, 280, 180)
	var back: Array = []
	for k in 3:
		var pos2: Vector2 = b.surface(700.0 - 165.0 * float(k), 340.0 + 55.0 * float(k))
		b.gimmick({"type": "blink", "pos": pos2, "span": Vector2(150, 26), "beat": 1.4,
			"colour": 1, "phase": -0.45 * float(k)})
		back.append(pos2)
	var x: Rect2 = b.ledge(200, 520, 220)
	b.enemy({"type": "mine", "pos": b.at(470, 430), "bob": Vector2.ZERO,
		"period": 3.0, "phase": 1.2, "wander": Vector2(130, 30), "dart": 1.3})
	b.ride("timed", b.cursor, m, {"pieces": out, "tries": 20, "spacing": 13})
	b.ride("timed", m, x, {"pieces": back, "tries": 20, "spacing": 13})
	b.coins_over(m)
	b.coins_over(x, 2)
	b.finish(x)

## 5. A low corridor under a roof of pistons that slam in a travelling wave;
## at the far end a spring throws the runner up past the roof's edge, and a
## last step leads on.
static func _piston_corridor(b: SectionBuilder) -> void:
	var floor_: Rect2 = b.ledge(380, 60, 640)
	var roof: Rect2 = b.ledge(380, 340, 520, 64)
	for k in 3:
		b.gimmick({"type": "tower_trap", "kind": "piston",
			"pos": Vector2(b.at(210.0 + 170.0 * float(k), 0).x, roof.end.y),
			"travel": 181.0, "period": 2.7, "phase": 0.6 * float(k)})
	var spring: Vector2 = b.spring_on(floor_, 290.0)
	var x1: Rect2 = b.ledge(770, 300, 180)
	var x: Rect2 = b.ledge(540, 420, 220)
	b.jump(b.cursor, floor_)
	b.ride("spring", floor_, x1, {"at": spring})
	b.jump(x1, x)
	b.coin_line(190, 110, 590, 110, 5)
	b.coins_over(x, 2)
	b.finish(x)

## 6. Small stones over gaps, two tiers of them, with a pendulum sweeping
## each gap in turn.
static func _pendulum_gaps(b: SectionBuilder) -> void:
	var p1: Rect2 = b.ledge(290, 30, 140)
	var p2: Rect2 = b.ledge(520, 70, 140)
	var m: Rect2 = b.ledge(750, 190, 180)
	# The second tier comes back over the first, high enough above it that a
	# jump on the first cannot catch its edges.
	var q1: Rect2 = b.ledge(520, 300, 140)
	var q2: Rect2 = b.ledge(290, 370, 140)
	var x: Rect2 = b.ledge(70, 450, 200)
	# Each ball's lowest swing crosses its gap at jumping height, and none of
	# them swings up past the room's last ledge.
	var pivots := [Vector2(165, 300), Vector2(405, 330), Vector2(405, 550), Vector2(180, 575)]
	for k in pivots.size():
		b.gimmick({"type": "tower_trap", "kind": "pendulum", "pos": b.at(pivots[k].x, pivots[k].y),
			"length": 210.0, "period": 3.2, "phase": 1.6 * float(k % 2)})
	b.jump(b.cursor, p1)
	b.jump(p1, p2)
	b.jump(p2, m)
	b.jump(m, q1)
	b.jump(q1, q2)
	b.jump(q2, x)
	for r in [p1, p2, q1, q2]:
		b.coins_over(r)
	b.coins_over(x, 3)
	b.finish(x)

## 7. Belts that turn round now and then. Against the belt the gap at its end
## is too far to jump; with it, the belt's own speed carries the runner over.
## (A second jump in the air also does it.) Twice, the second time back.
static func _conveyor_boost(b: SectionBuilder) -> void:
	var belt1: Vector2 = b.surface(330, 90)
	b.gimmick({"type": "conveyor", "pos": belt1, "span": Vector2(380, 26), "speed": 150.0,
		"flip": 3.2, "dir": b.side(), "phase": 0.0})
	var r1 := Rect2(belt1.x - 190.0, belt1.y - 13.0, 380, 26)
	var l: Rect2 = b.ledge(820, 120, 180)
	var belt2: Vector2 = b.surface(520, 260)
	b.gimmick({"type": "conveyor", "pos": belt2, "span": Vector2(340, 26), "speed": 150.0,
		"flip": 2.8, "dir": -b.side(), "phase": 1.0})
	var r2 := Rect2(belt2.x - 170.0, belt2.y - 13.0, 340, 26)
	var w: Rect2 = b.ledge(80, 290, 200)
	var x: Rect2 = b.ledge(300, 410, 220)
	b.jump(b.cursor, r1)
	b.step("jump", r1, l, {"tries": 8, "spacing": 24})
	b.jump(l, r2)
	b.step("jump", r2, w, {"tries": 8, "spacing": 21})
	b.jump(w, x)
	b.coin_line(570, 170, 700, 170, 3)
	b.coin_line(230, 340, 330, 340, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 8. Crumbling stones climbing across the shaft and one back: each gives
## way soon after it is stood on. A crumble wakes when anything passes through
## its top, so none of them sits in the arc of a jump before its turn. A second
## jump off the fourth reaches a coin cache, if the stone holds that long.
static func _crumble_rush(b: SectionBuilder) -> void:
	var pieces: Array = []
	var spots := [Vector2(220, 60), Vector2(400, 140), Vector2(580, 220), Vector2(760, 300),
		Vector2(560, 380)]
	for p in spots:
		var pos: Vector2 = b.at(p.x, p.y) + Vector2(0, 18)
		b.gimmick({"type": "crumble", "pos": pos, "span": Vector2(130, 36)})
		pieces.append(pos)
	var x: Rect2 = b.ledge(380, 460, 220)
	b.ride("timed", b.cursor, x, {"pieces": pieces, "tries": 4, "spacing": 60, "frames": 1200})
	b.coin_line(700, 470, 820, 470, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 9. A hall of five numbered warps. Mark 3 goes on up. The others: back to
## the hall's door, out to a coin room behind it, to a far lookout, and to a
## balcony a second jump below the way on -- every wrong door pays a little
## for the trip, and the pair learns the hall.
static func _warp_hall(b: SectionBuilder) -> void:
	var entry: Rect2 = b.cursor
	var hall: Rect2 = b.ledge(470, 80, 960)
	var y := hall.position.y - 55.0
	var behind: Rect2 = b.ledge(-260, 300, 200)
	var lookout: Rect2 = b.ledge(940, 330, 180)
	var balcony: Rect2 = b.ledge(560, 300, 180)
	var up: Rect2 = b.ledge(380, 540, 240)
	var exits := [
		Vector2(entry.get_center().x, entry.position.y - 40.0),
		Vector2(behind.get_center().x, behind.position.y - 40.0),
		Vector2(up.get_center().x, up.position.y - 40.0),
		Vector2(lookout.get_center().x, lookout.position.y - 40.0),
		Vector2(balcony.get_center().x, balcony.position.y - 40.0),
	]
	var mouths: Array[Vector2] = []
	for k in 5:
		mouths.append(Vector2(b.at(330.0 + 140.0 * float(k), 0).x, y))
		b.gimmick({"type": "warp", "pos": mouths[k], "size": Vector2(78, 106),
			"exit": exits[k], "mark": k + 1})
		if k != 0:
			b.gimmick({"type": "warp_exit", "pos": exits[k] + Vector2(0, -20),
				"size": Vector2(78, 106), "mark": k + 1})
	b.coins_over(behind, 5, 34)
	b.coins_over(lookout, 4, 34)
	b.coins_over(balcony, 3)
	b.coins_over(up, 3)
	# Land on the apron by the door, short of the first mouth.
	var apron := Rect2(minf(b.at(-10, 80).x, b.at(200, 80).x), hall.position.y, 210, 48)
	b.jump(entry, apron)
	b.ride("warp", hall, up, {"at": mouths[2]})
	b.ride("warp", hall, balcony, {"at": mouths[4]})
	b.double(balcony, up)
	b.finish(up)

## 10. A column of rising air with mines darting about inside it. Steer round
## them on the way up -- or have the guardian clear the way.
static func _updraft_mines(b: SectionBuilder) -> void:
	var base: Vector2 = b.at(250, -10)
	b.gimmick({"type": "updraft", "pos": base, "span": Vector2(170, 660)})
	for k in 3:
		b.enemy({"type": "mine", "pos": b.at(250, 190.0 + 140.0 * float(k)),
			"bob": Vector2.ZERO, "period": 2.8 + 0.4 * float(k), "phase": 0.7 * float(k),
			"wander": Vector2(52, 34), "dart": 1.1 + 0.25 * float(k)})
	# The landing overlaps the column's edge, so the air leaves the runner
	# above it rather than beside it.
	var x: Rect2 = b.ledge(420, 600, 200)
	b.ride("updraft", b.cursor, x, {"at": base})
	b.coin_line(250, 120, 250, 520, 5)
	b.coins_over(x, 2)
	b.finish(x)

## 11. A chimney between two walls, climbed on springs. Shelves jut from
## alternate walls and overlap in the middle; each spring sits at a shelf's
## inner tip, so a throw lands on the next shelf well clear of its spring, and
## a few steps take the runner onto it. The last throw goes up through the lid.
## Needles stud the walls.
static func _spring_chimney(b: SectionBuilder) -> void:
	b.wall(170, 230, 592)
	b.wall(470, 0, 592)
	var l1: Rect2 = b.ledge(289, 40, 190)
	var r1: Rect2 = b.ledge(351, 240, 190)
	var l2: Rect2 = b.ledge(289, 440, 190)
	var x: Rect2 = b.ledge(320, 640, 348)
	var s1: Vector2 = b.spring_on(l1, 75)
	var s2: Vector2 = b.spring_on(r1, -75)
	var s3: Vector2 = b.spring_on(l2, 75)
	b.hazard(b.at(203, 330), Vector2(18, 70))
	b.hazard(b.at(437, 530), Vector2(18, 70))
	b.jump(b.cursor, l1)
	b.ride("spring", l1, r1, {"at": s1})
	b.ride("spring", r1, l2, {"at": s2})
	b.ride("spring", l2, x, {"at": s3})
	b.coin_line(320, 160, 320, 600, 4)
	b.coins_over(x, 3)
	b.finish(x)

## 12. Arrow pads that turn round on the clock. Launched the right way, the
## runner lands a floor up; the wrong way, in a coin pocket to drop back from.
## Each pad throws back across the one below it, so the room folds over itself.
static func _pad_pinball(b: SectionBuilder) -> void:
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
	b.coins_over(pocket1, 3, 34)
	b.coins_over(pocket2, 3, 34)
	b.jump(b.cursor, floor_)
	b.ride("pad", floor_, r1, {"at": pad1, "dir": -b.side()})
	b.ride("pad", r1, x, {"at": pad2, "dir": b.side()})
	b.coins_over(x, 2)
	b.finish(x)

## 13. A door that only the right shot opens, under a housing it slides up
## into. The guardian can see which mark the door wants; only the runner can
## read the marks on the three targets round it. The housing is too tall for
## any jump, so the way on is through the door, up the far side, and onto its
## roof. A mine keeps the runner moving while the pair talks it over.
static func _sigil_door(b: SectionBuilder) -> void:
	var id := "tower_sigil"
	var s1: Rect2 = b.ledge(60, 110, 160)
	var near: Rect2 = b.ledge(310, 220, 220)
	# Past the door the floor is solid: there is no coming up through it from
	# the steps below.
	var far: Rect2 = b.span(420, 740, 220, 64.0)
	b.gimmick({"type": "gate", "id": id, "pos": b.at(450, 280), "span": Vector2(60, 120),
		"wants": Sigil.SQUARE})
	var housing: Rect2 = b.span(330, 570, 620, 280.0)
	var landing: Rect2 = b.ledge(660, 445, 160)
	var marks := [[Sigil.TRIANGLE, Vector2(-80, 290)], [Sigil.SQUARE, Vector2(240, 560)],
		[Sigil.CIRCLE, Vector2(130, 430)]]
	for m in marks:
		b.gimmick({"type": "switch", "id": id, "pos": b.at(m[1].x, m[1].y), "sigil": m[0],
			"hold": 10.0})
	b.enemy({"type": "mine", "pos": b.at(160, 330), "bob": Vector2.ZERO,
		"period": 3.2, "phase": 0.5, "wander": Vector2(70, 40), "dart": 1.4})
	# The route's view of the floor: the near side up to the door's far face,
	# and the open floor past the housing.
	var door_side := b.part(200, 480, near)
	var open_side := b.part(570, 740, far)
	b.jump(b.cursor, s1)
	b.jump(s1, near)
	b.ride("gate", door_side, open_side, {"id": id, "sigil": Sigil.SQUARE})
	b.double(open_side, landing)
	b.double(landing, housing)
	b.coins_over(s1)
	b.coins_over(near, 2)
	b.coin_line(660, 300, 660, 380, 2)
	b.coins_over(housing, 3)
	b.finish(housing)

## 14. A chasm too wide for any jump, and later a second one back: the
## guardian shoots the target over each and a bridge rises for a few seconds.
## Between them the far side climbs on second jumps, high enough that the way
## back cannot be jumped from where the room began.
static func _echo_bridge(b: SectionBuilder) -> void:
	var entry: Rect2 = b.cursor
	var reach := entry.size.x * 0.5
	var far: Rect2 = b.ledge(reach + 680.0, 0, 160)
	var s1: Rect2 = b.ledge(reach + 640.0, 175, 160)
	var s2: Rect2 = b.ledge(reach + 660.0, 400, 160)
	var w: Rect2 = b.ledge(-40, 400, 200)
	var x: Rect2 = b.ledge(170, 520, 220)
	# Each bridge spans its chasm edge to edge: nothing to fall through at
	# either end once it is up.
	_bridge(b, "tower_echo_a", reach, reach + 600.0, 0, 230)
	_bridge(b, "tower_echo_b", 60.0, reach + 580.0, 400, 630)
	b.enemy({"type": "mine", "pos": b.at(reach + 300.0, 150), "bob": Vector2.ZERO,
		"period": 3.6, "phase": 0.4, "wander": Vector2(200, 34), "dart": 1.9})
	b.ride("echo", entry, far, {"id": "tower_echo_a"})
	b.double(far, s1)
	b.double(s1, s2)
	b.ride("echo", s2, w, {"id": "tower_echo_b"})
	b.jump(w, x)
	b.coin_line(reach + 100.0, 60, reach + 500.0, 60, 5)
	b.coin_line(reach + 100.0, 460, reach + 500.0, 460, 5)
	b.coins_over(x, 2)
	b.finish(x)

## A hidden bridge from dx0 to dx1 with its top dy up, and the target that
## raises it, `target_dy` up over its middle.
static func _bridge(b: SectionBuilder, id: String, dx0: float, dx1: float, dy: float,
		target_dy: float) -> void:
	var mid := (dx0 + dx1) * 0.5
	b.gimmick({"type": "switch", "id": id, "pos": b.at(mid, target_dy), "hold": 9.0})
	b.gimmick({"type": "switch_bridge", "id": id, "pos": b.surface(mid, dy),
		"span": Vector2(dx1 - dx0, 26)})

## 15. A ladder of ledges a second jump apart, with a turret firing across it.
static func _double_ladder(b: SectionBuilder) -> void:
	var r1: Rect2 = b.ledge(200, 225, 180)
	var r2: Rect2 = b.ledge(20, 450, 180)
	var r3: Rect2 = b.ledge(200, 675, 200)
	b.double(b.cursor, r1)
	b.double(r1, r2)
	b.double(r2, r3)
	var perch: Rect2 = b.ledge(-260, 330, 120)
	b.enemy({"type": "turret", "pos": b.top_of(perch) + Vector2(0, -26),
		"aim": Vector2(float(b.side()), 0), "burst": 3})
	for r in [r1, r2]:
		b.coins.append(Vector2(r.get_center().x, r.position.y - 150.0))
	b.coins_over(r3, 2)
	b.finish(r3)

## 16. A blank stretch of wall far beyond any jump: the guardian builds the
## stair, two platforms at a time, while a blade stabs out of the wall.
static func _guardian_wall(b: SectionBuilder) -> void:
	var x: Rect2 = b.ledge(330, 430, 220)
	var p1: Rect2 = b.platform(150, 143)
	var p2: Rect2 = b.platform(260, 286)
	b.wall(-150, 0, 400, 60)
	b.gimmick({"type": "tower_trap", "kind": "spikes", "pos": b.at(-110, 210),
		"travel": 250.0, "period": 3.0, "phase": 0.5, "facing": b.side()})
	b.assist(b.cursor, x, [p1, p2])
	b.coin_line(150, 210, 260, 350, 3)
	b.coins_over(x, 2)
	b.finish(x)

## 17. Three lifts on three axes -- across, up, and up-and-back -- with no floor
## between them: change lifts in the air.
static func _lift_transfer(b: SectionBuilder) -> void:
	# One period for all three, half a period apart: each lift reaches the
	# hand-over point just as the next one gets there.
	var period := 5.6
	var l1: Vector2 = b.surface(260, 40)
	var l2: Vector2 = b.surface(740, 60)
	var l3: Vector2 = b.surface(600, 380)
	var t1 := Vector2(float(b.side()) * 300.0, 0)
	var t2 := Vector2(0, -260)
	var t3 := Vector2(-float(b.side()) * 300.0, -180)
	b.gimmick({"type": "moving_platform", "pos": l1, "span": Vector2(180, 26),
		"travel": t1, "speed": 2.0 * t1.length() / period, "phase": 0.0})
	b.gimmick({"type": "moving_platform", "pos": l2, "span": Vector2(180, 26),
		"travel": t2, "speed": 2.0 * t2.length() / period, "phase": period * 0.5})
	b.gimmick({"type": "moving_platform", "pos": l3, "span": Vector2(180, 26),
		"travel": t3, "speed": 2.0 * t3.length() / period, "phase": 0.0})
	var x: Rect2 = b.ledge(180, 630, 220)
	b.ride("timed", b.cursor, x, {"pieces": [l1, l2, l3], "tries": 12, "spacing": 29,
		"frames": 1500})
	b.ornament({"type": "tower_rail", "pos": b.at(740, 180), "height": 300.0})
	b.coins_over(x, 2)
	b.finish(x)

## 18. Stepping stones out and back under mines that dart where they please.
static func _mine_field(b: SectionBuilder) -> void:
	var h1: Rect2 = b.ledge(250, 30, 170)
	var h2: Rect2 = b.ledge(480, 60, 170)
	var h3: Rect2 = b.ledge(710, 100, 170)
	var k1: Rect2 = b.ledge(500, 210, 170)
	var k2: Rect2 = b.ledge(270, 260, 170)
	var x: Rect2 = b.ledge(40, 360, 200)
	for k in 5:
		b.enemy({"type": "mine", "pos": b.at(200.0 + 130.0 * float(k), 160.0 + 40.0 * float(k % 2)),
			"bob": Vector2.ZERO, "period": 3.0 + 0.3 * float(k), "phase": 0.9 * float(k),
			"wander": Vector2(90, 55), "dart": 1.0 + 0.2 * float(k)})
	b.jump(b.cursor, h1)
	b.jump(h1, h2)
	b.jump(h2, h3)
	b.jump(h3, k1)
	b.jump(k1, k2)
	b.jump(k2, x)
	for r in [h1, h2, h3, k1, k2]:
		b.coins_over(r)
	b.coins_over(x, 2)
	b.finish(x)

## 19. A narrow shaft whose walls stab blades out across each landing in turn.
## The walls start a little above the floor, so the jump that arrives here
## from the room below has the air it needs.
static func _spike_gauntlet(b: SectionBuilder) -> void:
	b.wall(-150, 150, 590)
	b.wall(420, 150, 590)
	var steps: Array[Rect2] = [b.ledge(120, 130, 150), b.ledge(270, 250, 150),
		b.ledge(120, 370, 150), b.ledge(270, 490, 150)]
	var x: Rect2 = b.ledge(170, 630, 240)
	for k in steps.size():
		# From the near wall across a left-hand landing, from the far wall
		# across a right-hand one; the blade reaches the landing's middle.
		var near := k % 2 == 0
		var base_dx := -110.0 if near else 380.0
		var reach := 230.0 if near else 110.0
		b.gimmick({"type": "tower_trap", "kind": "spikes",
			"pos": b.at(base_dx, 130.0 + 120.0 * float(k) + 45.0),
			"travel": reach, "period": 2.6, "phase": 0.65 * float(k),
			"facing": b.side() * (1 if near else -1)})
	b.jump(b.cursor, steps[0])
	for k in steps.size() - 1:
		b.jump(steps[k], steps[k + 1])
	b.jump(steps[-1], x)
	b.coin_line(195, 190, 195, 550, 4)
	b.coins_over(x, 2)
	b.finish(x)

## 20. The clock's crown: the great wheel and the pendulum under a turret's
## fire, up to the top of the tower. Ride the wheel over the top and step off
## before its deck sinks into the pendulum's swing, then a second jump takes
## the pair onto the crown itself.
static func _clock_crown(b: SectionBuilder) -> void:
	var a: Rect2 = b.ledge(160, 110, 180)
	var a2: Rect2 = b.ledge(330, 220, 160)
	var hub: Vector2 = b.at(540, 200)
	b.gimmick({"type": "gear_wheel", "pos": hub, "radius": 140.0, "speed": 0.32,
		"dir": b.side(), "phase": 0.0})
	var m: Rect2 = b.ledge(790, 400, 180)
	b.gimmick({"type": "tower_trap", "kind": "pendulum", "pos": b.at(700, 330),
		"length": 180.0, "period": 3.8, "phase": 0.9})
	var top: Rect2 = b.ledge(660, 660, 480)
	var perch: Rect2 = b.ledge(-120, 300, 120)
	b.enemy({"type": "turret", "pos": b.top_of(perch) + Vector2(0, -26),
		"aim": Vector2(float(b.side()), 0), "burst": 2})
	b.jump(b.cursor, a)
	b.jump(a, a2)
	b.ride("timed", a2, m, {"pieces": [hub], "tries": 18, "spacing": 37})
	b.double(m, top)
	b.coins_over(m, 2)
	b.coins_over(top, 5, 40)
	b.finish(top)
