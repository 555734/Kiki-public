extends RefCounted
## Builds a climbing stage (1-5, 1-6) out of rooms stacked up a wide shaft.
##
## A room starts from the ledge the runner is standing on (`cursor`) and leaves
## them on a new one. The rooms are what make a climb more than a staircase:
##
##   stairs   -- a few plain jumps, with someone patrolling one of them
##   gap      -- a ledge too high to jump to: the guardian builds the step
##   chasm    -- a ledge too far to jump to: the guardian builds the bridge
##   fork     -- two ways up to one ledge: a long jumping detour past enemies
##               and a thorn strip, or a short cut over a guardian gap
##   lift     -- ride a moving platform up the side of the shaft
##   chimney  -- a column of rising air carries the runner up
##   mirage   -- the guardian shoots the target; a bridge appears over a chasm
##   blinks   -- stepping stones that come and go across the shaft
##   spring   -- a spring on the ledge throws the runner to one far above
##   pad      -- an arrow pad throws the runner up and sideways
##   nook     -- a side alcove off the route with a crystal and a guard
##
## Plain jumps stay inside what the runner measurably clears (120px up, ~190px
## across with 200px+ ledges); a guardian gap is deliberately out of reach
## (250px up, or 360px of air across). Every room also writes `route` -- how it
## is meant to be climbed -- which the probes walk with a real runner and a
## real guardian platform.
##
## The stage supplies its own vocabulary in `theme`: which enemy is a ground
## patroller, which one hangs in the air, and the gimmick spec for each kind.

const W := 240.0         ## an ordinary ledge
const H := 46.0
const JUMP_RISE := 120.0
const JUMP_ACROSS := 190.0
const EDGE := 760.0      ## the shaft's walls; ledges stay inside

var theme: Dictionary = {}
var ground: Array[Rect2] = []
var gimmicks: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var coins: Array[Vector2] = []
var crystals: Array[Vector2] = []
var springs: Array[Vector2] = []
var checkpoints: Array[Vector2] = []
## Ledge tops a stage may stand scenery on.
var decor_spots: Array[Vector2] = []
## How the climb goes: {"via": "jump"|"assist"|"ride", "from": Rect2,
## "to": Rect2, "platform": Rect2 (assist only)}.
var route: Array[Dictionary] = []
var cursor: Rect2
var start_bank: Rect2
var shelf: Rect2
var _rooms := 0
var _heading := 1.0

func _init(bank: Rect2, stage_theme: Dictionary) -> void:
	theme = stage_theme
	start_bank = bank
	ground.append(bank)
	cursor = Rect2(bank.position.x + bank.size.x * 0.5 - W * 0.5, bank.position.y, W, H)

# -------------------------------------------------------------------- helpers
func _ledge(cx: float, top: float, w: float = W) -> Rect2:
	cx = clampf(cx, -EDGE + w * 0.5, EDGE - w * 0.5)
	var r := Rect2(cx - w * 0.5, top, w, H)
	ground.append(r)
	coins.append(Vector2(cx, top - 70.0))
	return r

func _cx(r: Rect2) -> float:
	return r.position.x + r.size.x * 0.5

## Which way the next room heads: on the way it was already going, turning
## only near a wall, so the route sweeps across the shaft and back instead of
## folding over the room it just left.
func _dir(reach: float = 300.0) -> float:
	var x := _cx(cursor)
	if x > 330.0:
		_heading = -1.0
	elif x < -330.0:
		_heading = 1.0
	# The room's far end has to fit inside the shaft unclamped.
	if absf(x + _heading * (cursor.size.x - W) * 0.5 + _heading * reach) > EDGE - W * 0.5:
		_heading = -_heading
	return _heading

## Where a room measures from: an ordinary ledge's centre, or for a wide one
## (a fork's joint) the point a ledge-width in from the edge it leaves by.
func _origin(d: float) -> float:
	return _cx(cursor) + d * (cursor.size.x - W) * 0.5

## A room that runs sideways needs the air along its path empty: one folding
## back over the room below would put a ceiling over its jumps, or a lift
## through its guardian platform. While anything is in the way, climb a step first.
func _headroom(d: float, across: float) -> float:
	for _i in 4:
		if _lane_clear(d, across):
			return d
		# The other way, if it is clear and fits inside the shaft.
		var far := _origin(-d) - d * across
		if absf(far) <= EDGE - W * 0.5 and _lane_clear(-d, across):
			_heading = -d
			return -d
		var up := _ledge(_cx(cursor) - d * 90.0, cursor.position.y - JUMP_RISE)
		_step("jump", cursor, up)
		cursor = up
	return d

func _lane_clear(d: float, across: float) -> bool:
	var x := _origin(d)
	var top := cursor.position.y
	var lane := Rect2(minf(x, x + d * across) - 40.0, top - 260.0, across + 80.0, 250.0)
	for r in ground:
		if r != cursor and r != start_bank and r.intersects(lane):
			return false
	for g in gimmicks:
		var span: Vector2 = g.get("span", Vector2(160, 26))
		var box := Rect2(g["pos"] - span * 0.5, span)
		# A lift sweeps its whole track.
		box = box.merge(Rect2(box.position + g.get("travel", Vector2.ZERO), box.size))
		if box.intersects(lane):
			return false
	# Nor may its stones hang over the guardian platform the pair arrived by.
	var below := Rect2(lane.position, lane.size + Vector2(0, 150.0))
	for st in route:
		if st["via"] == "assist" and (st["platform"] as Rect2).intersects(below):
			return false
	return true

func _step(via: String, from: Rect2, to: Rect2, platform: Rect2 = Rect2()) -> void:
	route.append({"via": via, "from": from, "to": to, "platform": platform})

func _ground_enemy(r: Rect2, patrol: float = 50.0) -> void:
	enemies.append(theme["ground"].call(Vector2(_cx(r), r.position.y), patrol))

func _air_enemy(at: Vector2, patrol: float = 130.0) -> void:
	enemies.append(theme["air"].call(at, patrol))

func _done(spot_decor: bool = true) -> void:
	_rooms += 1
	if spot_decor:
		decor_spots.append(Vector2(_cx(cursor), cursor.position.y))
	if _rooms % 3 == 0:
		checkpoints.append(Vector2(_cx(cursor), cursor.position.y - 52.0))

# ---------------------------------------------------------------------- rooms
func stairs(count: int = 3, guard: bool = true) -> void:
	var d := _dir()
	for i in count:
		var next := _ledge(_cx(cursor) + d * JUMP_ACROSS, cursor.position.y - JUMP_RISE)
		_step("jump", cursor, next)
		cursor = next
		if guard and i == 1:
			_ground_enemy(next)
		if absf(_cx(cursor)) > 450.0:
			d = -d
	_done()

## Too high: one guardian platform halfway. Coins hang where it goes.
func gap(with_flyer: bool = false) -> void:
	var d := _dir(430.0)
	d = _headroom(d, 430.0)
	var x := _origin(d)
	var top := cursor.position.y
	# Clear of the ledge's edge: the platform is solid from below.
	var plat := Rect2(Vector2(x + d * 265.0 - 75.0, top - 125.0), Vector2(150, 26))
	var exit := _ledge(x + d * 430.0, top - 250.0)
	_step("assist", cursor, exit, plat)
	for k in 3:
		coins.append(plat.get_center() + Vector2(-40.0 + 40.0 * k, -40.0))
	if with_flyer:
		_air_enemy(Vector2(plat.get_center().x, top - 210.0), 110.0)
	cursor = exit
	_done()

## Too far: one guardian platform in the middle, a flyer patrolling the air.
func chasm() -> void:
	var d := _dir(560.0)
	d = _headroom(d, 560.0)
	var x := _origin(d)
	var top := cursor.position.y
	var exit := _ledge(x + d * 560.0, top - 30.0)
	var mid := (x + _cx(exit)) * 0.5
	var plat := Rect2(Vector2(mid - 75.0, top + 20.0), Vector2(150, 26))
	_step("assist", cursor, exit, plat)
	for k in 3:
		coins.append(Vector2(mid - 40.0 + 40.0 * k, top - 60.0))
	_air_enemy(Vector2(mid, top - 150.0), 160.0)
	cursor = exit
	_done()

## Two ways to one wide ledge 390px up. Needs the middle of the shaft, so a
## fork near a wall starts with a step back towards the centre.
func fork() -> void:
	while absf(_cx(cursor)) > 200.0:
		var back := _ledge(_cx(cursor) - signf(_cx(cursor)) * JUMP_ACROSS, cursor.position.y - JUMP_RISE)
		_step("jump", cursor, back)
		cursor = back
	var x := _cx(cursor)
	var d := 1.0 if x <= 0.0 else -1.0
	var top := cursor.position.y
	var joint := _ledge(x + d * 40.0, top - 390.0, 420.0)
	# The long way: out towards the wall and back, past a guard and thorns.
	var a1 := _ledge(x - d * 190.0, top - 100.0)
	var a2 := _ledge(x - d * 380.0, top - 200.0)
	var a3 := _ledge(x - d * 190.0, top - 300.0)
	_step("jump", cursor, a1)
	_step("jump", a1, a2)
	_step("jump", a2, a3)
	_step("jump", a3, joint)
	_ground_enemy(a2, 40.0)
	# Thorns on the outer end, past where anyone lands or takes off.
	hazards.append({"pos": Vector2(_cx(a2) - d * 98.0, a2.position.y - 9.0),
		"size": Vector2(44, 18)})
	coins.append(Vector2(_cx(a2), a2.position.y - 120.0))
	# The short cut: a guardian step, then one jump.
	var plat := Rect2(Vector2(x + d * 265.0 - 75.0, top - 130.0), Vector2(150, 26))
	var b1 := _ledge(x + d * 430.0, top - 260.0)
	_step("assist", cursor, b1, plat)
	_step("jump", b1, joint)
	_air_enemy(Vector2(x + d * 330.0, top - 340.0), 90.0)
	cursor = joint
	_done()

func lift() -> void:
	var d := _dir(430.0)
	d = _headroom(d, 430.0)
	var x := _origin(d)
	var top := cursor.position.y
	# Level with the ledge and a step off it, so it is no ceiling to anyone.
	var exit := _ledge(x + d * 430.0, top - 330.0)
	var at := Vector2(x + d * 230.0, top + 13.0)
	gimmicks.append(theme["lift"].call(at, Vector2(160, 26), Vector2(0, -300)))
	_step("ride", cursor, exit)
	_air_enemy(Vector2(x + d * 200.0, top - 420.0), 100.0)
	cursor = exit
	_done()

func chimney() -> void:
	var d := _dir(390.0)
	d = _headroom(d, 390.0)
	var x := _origin(d)
	var top := cursor.position.y
	var col := x + d * 190.0
	gimmicks.append(theme["air_column"].call(Vector2(col, top - 140.0), Vector2(170, 380)))
	var exit := _ledge(col + d * 200.0, top - 420.0)
	for k in 4:
		coins.append(Vector2(col, top - 80.0 - 80.0 * k))
	_step("ride", cursor, exit)
	cursor = exit
	_done()

## The bridge exists only while the guardian keeps its target lit.
func mirage(id: String) -> void:
	var d := _dir(560.0)
	d = _headroom(d, 560.0)
	var x := _origin(d)
	var top := cursor.position.y
	var exit := _ledge(x + d * 560.0, top - 40.0)
	var mid := (x + _cx(exit)) * 0.5
	gimmicks.append({"type": "switch", "id": id, "pos": Vector2(mid, top - 220.0),
		"hold": 10.0})
	gimmicks.append({"type": "switch_bridge", "id": id,
		"pos": Vector2(mid, top - 7.0), "span": Vector2(300, 26)})
	_step("ride", cursor, exit)
	cursor = exit
	_done()

## Stones across the shaft that blink in a wave.
func blinks() -> void:
	var d := _dir(740.0)
	d = _headroom(d, 740.0)
	var x := _origin(d)
	var top := cursor.position.y
	# Off the ledge's end, not over it: a stone above a ledge is a ceiling.
	for k in 3:
		gimmicks.append(theme["blink"].call(
			Vector2(x + d * (235.0 + 165.0 * k), top - 30.0 - 25.0 * k), k))
	var exit := _ledge(x + d * 740.0, top - 110.0)
	_air_enemy(Vector2(x + d * 350.0, top - 190.0), 140.0)
	_step("ride", cursor, exit)
	cursor = exit
	_done()

func spring() -> void:
	var d := _dir(140.0)
	var x := _origin(d)
	var top := cursor.position.y
	springs.append(Vector2(x + d * 95.0, top))
	var exit := _ledge(x + d * 140.0, top - 290.0)
	_step("ride", cursor, exit)
	cursor = exit
	_done()

func pad() -> void:
	var d := _dir(300.0)
	var x := _origin(d)
	var top := cursor.position.y
	gimmicks.append({"type": "trick_pad", "pos": Vector2(x, top),
		"dir": int(d), "forward": 230.0, "rise": 1050.0})
	var exit := _ledge(x + d * 300.0, top - 250.0)
	_step("ride", cursor, exit)
	cursor = exit
	_done()

## A dead end off to the side: a crystal, coins, and someone guarding them.
func nook() -> void:
	var d := -_dir()
	var x := _cx(cursor)
	var top := cursor.position.y
	# Against a wall there is no room for an alcove: the crystal hangs over
	# the ledge instead, with a flyer for company.
	if absf(x + d * 180.0) > EDGE - 110.0:
		crystals.append(Vector2(x, top - 200.0))
		_air_enemy(Vector2(x, top - 150.0), 90.0)
		return
	var side := _ledge(x + d * 180.0, top - 105.0, 220.0)
	crystals.append(Vector2(_cx(side), top - 190.0))
	_ground_enemy(side, 40.0)
	_step("jump", cursor, side)

## The top: a wide bank a jump above the last ledge, for the goal and key.
func finish() -> void:
	var cx := clampf(_cx(cursor), -EDGE + 380.0, EDGE - 380.0)
	shelf = Rect2(cx - 380.0, cursor.position.y - JUMP_RISE, 760, 110)
	ground.append(shelf)
	_step("jump", cursor, shelf)
