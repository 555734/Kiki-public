class_name SectionBuilder
extends RefCounted
## Builds a climbing stage (1-7, 1-8) out of hand-made sections.
##
## A section starts from the ledge the runner is standing on (`cursor`) and
## leaves them on a new one. It is written once, in coordinates relative to
## that ledge -- `at(dx, dy)` is dx towards the section's side and dy up -- and
## can be placed mirrored, so the same idea can turn either way up the shaft.
## The old tower and cave were one chamber shape repeated two dozen times;
## here every section is its own piece of design, and no two sit alike.
##
## Every section also writes `route`: how it is meant to be climbed. The
## probes walk it with a real runner, real guardian platforms and the real
## gimmicks (test/climb_route.gd), so a number that says "this is a jump" is
## checked against the physics rather than trusted.
##
## Steps in `route`:
##   jump    -- one ordinary jump from `from` to `to`
##   double  -- needs the mid-air second jump
##   assist  -- out of reach alone: the guardian builds `platforms` (1 or 2)
##   ride    -- a gimmick carries the runner: `how` is spring, pad, warp,
##              updraft or timed (lifts, gears, hands, blinks, belts, crumbles)

const H := 48.0

var ground: Array[Rect2] = []
var gimmicks: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var coins: Array[Vector2] = []
var springs: Array[Vector2] = []
var checkpoints: Array[Vector2] = []
var decor: Array[Dictionary] = []
var route: Array[Dictionary] = []
## {"name", "bottom", "top", "mirror"} per section, bottom to top.
var sections: Array[Dictionary] = []
## What each section puts in the shaft, by room: {"room": index, "rect":
## Rect2, "kind": String}. The kinds:
##   solid   -- ground the runner cannot pass through
##   ledge   -- ground that can be jumped up through
##   moving  -- the whole space a gimmick sweeps over its cycle
##   path    -- the air a jump on the route needs
## Rooms are kept clear of each other by these (see clashes), so a gear's arc
## never runs under the hand of the room above, and no wall of the next room
## stands in the way of this one's last jump.
var boxes: Array[Dictionary] = []
var cursor: Rect2
## Ground this thick or thicker is solid (Stage.ground_is_one_way says the
## same for the stage it builds).
var solid_from := 56.0

var _o := Vector2.ZERO
var _d := 1.0
var _name := ""
var _room := -1

func _init(entry: Rect2, solid_from_: float = 56.0) -> void:
	cursor = entry
	solid_from = solid_from_

# -------------------------------------------------------------- the section
## Starts a section on the current ledge. `mirror` is 1 or -1: which way the
## section's dx runs.
func begin(name: String, mirror: float) -> void:
	_name = name
	_room += 1
	_d = signf(mirror) if mirror != 0.0 else 1.0
	_o = Vector2(cursor.get_center().x, cursor.position.y)
	sections.append({"name": name, "bottom": _o.y, "top": _o.y, "mirror": _d})

## Ends it with the runner standing on `exit`.
func finish(exit: Rect2) -> void:
	cursor = exit
	sections[-1]["top"] = exit.position.y
	sections[-1]["exit"] = exit

## A point dx along the section's side and dy above where it started.
func at(dx: float, dy: float) -> Vector2:
	return Vector2(_o.x + _d * dx, _o.y - dy)

## The section's side as an int, for specs that take a direction.
func side() -> int:
	return int(_d)

func mirrored() -> bool:
	return _d < 0.0

# ------------------------------------------------------------------- pieces
## A ledge centred dx across, its top dy up.
func ledge(dx: float, dy: float, w: float = 220.0, h: float = H) -> Rect2:
	var c := at(dx, dy)
	var r := Rect2(c.x - w * 0.5, c.y, w, h)
	add_ground(r)
	return r

## Ground placed by its own rect.
func add_ground(r: Rect2) -> Rect2:
	ground.append(r)
	boxes.append({"room": _room, "rect": r,
		"kind": "solid" if r.size.y >= solid_from else "ledge"})
	return r

## Ground from dx0 to dx1 along the room's side, its top dy up, h thick.
func span(dx0: float, dx1: float, dy: float, h: float = H) -> Rect2:
	var a := at(dx0, dy)
	var c := at(dx1, dy)
	return add_ground(Rect2(minf(a.x, c.x), a.y, absf(c.x - a.x), h))

## The stretch dx0..dx1 of a piece of ground, as the route sees it: not built.
func part(dx0: float, dx1: float, of: Rect2) -> Rect2:
	var a := at(dx0, 0).x
	var c := at(dx1, 0).x
	return Rect2(minf(a, c), of.position.y, absf(c - a), of.size.y)

## A solid column from dy_low up to dy_high, centred dx across.
func wall(dx: float, dy_low: float, dy_high: float, w: float = 48.0) -> Rect2:
	var c := at(dx, dy_high)
	var r := Rect2(c.x - w * 0.5, c.y, w, dy_high - dy_low)
	add_ground(r)
	return r

## The middle of a ledge's top, nudged dx along the section's side.
func top_of(r: Rect2, dx: float = 0.0) -> Vector2:
	return Vector2(r.get_center().x + _d * dx, r.position.y)

## The point a gimmick is placed at so its surface is level with a top: specs
## centre their span on `pos`.
func surface(dx: float, dy: float, thickness: float = 26.0) -> Vector2:
	return at(dx, dy) + Vector2(0, thickness * 0.5)

func coin(dx: float, dy: float) -> void:
	coins.append(at(dx, dy))

## n coins on the straight line between two relative points.
func coin_line(dx0: float, dy0: float, dx1: float, dy1: float, n: int) -> void:
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		coin(lerpf(dx0, dx1, t), lerpf(dy0, dy1, t))

## Coins over a ledge, a little above head height.
func coins_over(r: Rect2, n: int = 1, spacing: float = 40.0) -> void:
	var c := r.get_center().x
	for i in n:
		coins.append(Vector2(c + (float(i) - float(n - 1) * 0.5) * spacing, r.position.y - 72.0))

func gimmick(spec: Dictionary) -> Dictionary:
	gimmicks.append(spec)
	var swept := sweep(spec)
	if swept.has_area():
		boxes.append({"room": _room, "rect": swept, "kind": kind_of(spec)})
	return spec

## How a gimmick stands in the way of others: a gate is a wall, a belt or a
## blinking stone is a ledge like any other, and the rest move.
static func kind_of(spec: Dictionary) -> String:
	match String(spec.get("type", "")):
		"gate":
			return "solid"
		"blink", "crumble", "conveyor", "switch_bridge":
			return "ledge"
	return "moving"

## The space a gimmick can occupy, over the whole of its cycle.
static func sweep(spec: Dictionary) -> Rect2:
	var at: Vector2 = spec.get("pos", Vector2.ZERO)
	match String(spec.get("type", "")):
		"volcanic_hazard":
			var travel_: Vector2 = spec.get("travel", Vector2(0, -230))
			var size_ := Vector2.ONE * float(spec.get("width", 64.0))
			return Rect2(at - size_ * 0.5, size_).merge(Rect2(at + travel_ - size_ * 0.5, size_))
		"gear_wheel":
			# The far corner of a deck, wherever the wheel has turned it.
			var r := Vector2(float(spec.get("radius", 98.0)) + GearWheel.DECK.y * 0.5,
				GearWheel.DECK.x * 0.5).length()
			return Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)
		"clock_hand":
			var l := float(spec.get("length", 225.0))
			var drop := l * sin(0.24) + 14.0
			return Rect2(at.x - 24.0, at.y - drop, l + 24.0, drop * 2.0)
		"moving_platform":
			var span: Vector2 = spec.get("span", Vector2(150, 26))
			var a := Rect2(at - span * 0.5, span)
			return a.merge(Rect2(a.position + Vector2(spec.get("travel", Vector2.ZERO)), span))
		"tower_trap":
			var kind := String(spec.get("kind", "pendulum"))
			if kind == "pendulum":
				# Only the ball hurts: the arc it swings along, not the rod.
				var l2 := float(spec.get("length", 235.0))
				var half := l2 * sin(0.72) + 31.0
				return Rect2(at.x - half, at.y + l2 * cos(0.72) - 31.0, half * 2.0,
					l2 * (1.0 - cos(0.72)) + 62.0)
			if kind == "piston":
				# The housing sits inside whatever the piston hangs from.
				return Rect2(at.x - 47.0, at.y - 22.0, 94.0, float(spec.get("travel", 150.0)) + 44.0)
			var reach := float(spec.get("travel", 150.0)) * float(spec.get("facing", 1))
			return Rect2(at.x + minf(0.0, reach) - 37.5, at.y - 45.0, absf(reach) + 75.0, 90.0)
		"cave_trap":
			var travel := float(spec.get("travel", 145.0))
			if String(spec.get("kind", "boulder")) == "boulder":
				# Rolls either way from where it is placed.
				return Rect2(at.x - travel - 40.0, at.y - 40.0, travel * 2.0 + 80.0, 80.0)
			return Rect2(at.x - 30.0, at.y - 44.0, 60.0, travel + 88.0)
		"blink", "crumble", "conveyor", "switch_bridge":
			var span2: Vector2 = spec.get("span", Vector2(150, 26))
			return Rect2(at - span2 * 0.5, span2)
		"gate":
			var span3: Vector2 = spec.get("span", Vector2(40, 190))
			return Rect2(at - span3 * 0.5, span3)
	return Rect2()

func enemy(spec: Dictionary) -> Dictionary:
	enemies.append(spec)
	return spec

func hazard(pos: Vector2, size: Vector2) -> void:
	hazards.append({"pos": pos, "size": size})

## Needles lying on a ledge, dx along it from its centre.
func needles_on(r: Rect2, dx: float, w: float = 56.0) -> void:
	hazard(Vector2(r.get_center().x + _d * dx, r.position.y - 9.0), Vector2(w, 18.0))

func spring_on(r: Rect2, dx: float = 0.0) -> Vector2:
	var at_top := top_of(r, dx)
	springs.append(at_top)
	return at_top

func checkpoint_on(r: Rect2, dx: float = 0.0) -> void:
	checkpoints.append(top_of(r, dx) + Vector2(0, -52.0))

func ornament(spec: Dictionary) -> void:
	decor.append(spec)

# -------------------------------------------------------------------- route
func step(via: String, from: Rect2, to: Rect2, extra: Dictionary = {}) -> void:
	var s := {"via": via, "from": from, "to": to, "section": _name}
	s.merge(extra)
	route.append(s)
	# The guardian's stair is climbed a hop at a time.
	var hops: Array[Rect2] = [from]
	if via == "assist":
		for p in extra.get("platforms", []):
			hops.append(p)
	hops.append(to)
	for k in hops.size() - 1:
		var air := path_of("jump" if via == "assist" else via, hops[k], hops[k + 1])
		if air.has_area():
			boxes.append({"room": _room, "rect": air, "kind": "path"})

## The air a step on foot needs: between where it leaves one ledge and where
## it reaches the other (the near edges, or straight up through a ledge
## overhead), up to the top of the jump, head and all. Rides fly where their
## gimmick says, and have no path of their own.
static func path_of(via: String, from: Rect2, to: Rect2) -> Rect2:
	var rise := 0.0
	match via:
		"jump": rise = Balance.RUNNER_JUMP_HEIGHT
		"double": rise = Balance.RUNNER_JUMP_HEIGHT + Balance.RUNNER_AIR_JUMP_HEIGHT
		"assist": rise = 0.0
		_: return Rect2()
	var leave := clampf(to.get_center().x, from.position.x, from.end.x)
	var reach := clampf(from.get_center().x, to.position.x, to.end.x)
	var half := Balance.RUNNER_SIZE.x * 0.5 + 10.0
	var x0 := minf(leave, reach) - half
	var x1 := maxf(leave, reach) + half
	var top := minf(from.position.y - rise, to.position.y) - Balance.RUNNER_SIZE.y
	var bottom := maxf(from.position.y, to.position.y)
	return Rect2(x0, top, x1 - x0, bottom - top)

func jump(from: Rect2, to: Rect2) -> void:
	step("jump", from, to)

func double(from: Rect2, to: Rect2) -> void:
	step("double", from, to)

## The guardian builds `platforms` (top-left-sized rects) and the runner
## climbs from one to the next.
func assist(from: Rect2, to: Rect2, platforms: Array[Rect2]) -> void:
	step("assist", from, to, {"platforms": platforms})

func ride(how: String, from: Rect2, to: Rect2, extra: Dictionary = {}) -> void:
	var s := extra.duplicate()
	s["how"] = how
	step("ride", from, to, s)

## A guardian platform's rect centred dx across, its top dy up.
func platform(dx: float, dy: float) -> Rect2:
	var c := at(dx, dy)
	return Rect2(c.x - Balance.PLATFORM_SIZE.x * 0.5, c.y,
		Balance.PLATFORM_SIZE.x, Balance.PLATFORM_SIZE.y)

# ------------------------------------------------------------------- layout
## Whether two boxes from different rooms are in each other's way. Anything
## that moves wants 40px of air round it; a jump's path may pass through a
## ledge it can jump through, and paths never block each other.
static func clashes(a: Dictionary, c: Dictionary) -> bool:
	var ka := String(a["kind"])
	var kc := String(c["kind"])
	if ka == "path" and (kc == "path" or kc == "ledge"):
		return false
	if kc == "path" and ka == "ledge":
		return false
	var margin := 0.0
	if (ka == "moving" and kc != "path") or (kc == "moving" and ka != "path"):
		margin = 40.0
	return (a["rect"] as Rect2).grow(margin).intersects(c["rect"] as Rect2)

## Every pair of boxes from different rooms that clash, as "room/room" names.
## The ledge two rooms share is exempt: one ends on it and the other starts.
static func clashes_between(all: Array[Dictionary], rooms: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Dictionary = all[i]
			var c: Dictionary = all[j]
			var ra := int(a["room"])
			var rc := int(c["room"])
			if ra == rc or ra < 0 or rc < 0:
				continue
			if absi(ra - rc) == 1:
				var shared: Rect2 = rooms[mini(ra, rc)].get("exit", Rect2())
				if (a["rect"] as Rect2) == shared or (c["rect"] as Rect2) == shared:
					continue
			if clashes(a, c):
				out.append("%s/%s" % [rooms[ra]["name"], rooms[rc]["name"]])
	return out

## Which way room `index` of `rooms` ([name, turn] pairs) should turn: its
## fixed turn if it has one, otherwise whichever keeps it inside the shaft and
## clear of the rooms below, then nearer the middle. It looks one room ahead,
## so no room leaves the next one (a last room that only turns one way, say)
## without anywhere to go. `build` builds a room by name into a builder.
static func best_turn(rooms: Array, index: int, b: SectionBuilder, edge: float,
		build: Callable) -> int:
	if int(rooms[index][1]) != 0:
		return int(rooms[index][1])
	var best := 1
	var best_score := INF
	for turn in [1, -1]:
		var trial := _trial(rooms, index, turn, b.cursor, b.solid_from, build)
		var score := _fit(trial, b.boxes, b.cursor, edge)
		if index + 1 < rooms.size():
			var below: Array[Dictionary] = []
			below.append_array(b.boxes)
			below.append_array(trial.boxes)
			var fixed := int(rooms[index + 1][1])
			var ahead := INF
			for turn2 in ([fixed] if fixed != 0 else [1, -1]):
				var next := _trial(rooms, index + 1, turn2, trial.cursor, b.solid_from, build)
				ahead = minf(ahead, _fit(next, below, trial.cursor, edge))
			score += ahead
		if score < best_score:
			best_score = score
			best = turn
	return best

static func _trial(rooms: Array, index: int, turn: int, from: Rect2, solid: float,
		build: Callable) -> SectionBuilder:
	var trial := SectionBuilder.new(from, solid)
	trial.begin(String(rooms[index][0]), float(turn))
	build.call(String(rooms[index][0]), trial)
	return trial

## How badly a trial room fits: past the shaft's edge, into the rooms below
## (it may touch `shared`, the ledge it starts from), and how far from the
## middle it leaves the runner.
static func _fit(trial: SectionBuilder, below: Array[Dictionary], shared: Rect2,
		edge: float) -> float:
	var lo := INF
	var hi := -INF
	for box in trial.boxes:
		if String(box["kind"]) == "path":
			continue
		lo = minf(lo, (box["rect"] as Rect2).position.x)
		hi = maxf(hi, (box["rect"] as Rect2).end.x)
	var over := maxf(0.0, hi - edge) + maxf(0.0, -edge - lo)
	var count := 0
	for mine in trial.boxes:
		for theirs in below:
			if (theirs["rect"] as Rect2) == shared or (mine["rect"] as Rect2) == shared:
				continue
			if clashes(mine, theirs):
				count += 1
	return over * 100.0 + float(count) * 5000.0 + absf(trial.cursor.get_center().x)
