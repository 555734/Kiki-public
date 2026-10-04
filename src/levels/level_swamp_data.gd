extends RefCounted
## Stage 1-5 climbs out of the poison marsh: the bright green pool stays at the
## bottom, lethal as ever, and the route goes up a hollow, moss-grown cliff
## of rotten ledges, drifting log lifts and columns of marsh gas.
##
## Built like 1-7 and 1-8 (one chamber of four ledges at a time, zig-zagging
## so every turn is a sideways jump rather than a ledge directly overhead),
## but shorter and gentler: it is the first of the climbing stages.
##
##   step rise 125px  -- under the 154px jump, through one-way ledges
##   chambers 14      -- about 7,300px of climb (1-8 is 13,000)

const BASE_Y := 8200.0
const CHAMBER_RISE := 520.0
const STEP_RISE := 125.0
const CHAMBERS := 14
const LEDGE_W := 240.0
const LEDGE_H := 50.0
## The poison sits a little under the starting bank, as it did on the flat.
const WATER_Y := BASE_Y + 60.0
const KILL_Y := BASE_Y + 200.0
const STAGE_NAME := "THE POISON MARSH"
const STAGE_NUMBER := "1-5"
const OBJECTIVE := "Climb out of the poison marsh"

static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

static func _top(chamber: int, step: int) -> float:
	return BASE_Y - float(chamber) * CHAMBER_RISE - float(step + 1) * STEP_RISE

static func _x(chamber: int, step: int) -> float:
	if chamber == 0 and step == 0:
		return -150.0
	var path := [-290.0, -85.0, 115.0, 290.0] if chamber % 2 == 0 \
		else [115.0, 290.0, 85.0, -115.0]
	return path[step]

## What each ledge is. The fourth of every chamber is always plain moss, so
## the climb has a sure footing to read the next chamber from.
static func _kind(chamber: int, step: int) -> String:
	if step == 3 or chamber == 0:
		return "moss"
	match chamber % 5:
		1: return "rot" if step == 1 or step == 2 else "moss"
		2: return "lift" if step == 1 else "moss"
		3: return "gas" if step == 1 else "moss"
		4: return "echo" if step == 2 else ("rot" if step == 0 else "moss")
		_: return "lift" if step == 2 else "moss"

static func _last_top() -> float:
	return _top(CHAMBERS - 1, 3)

## The dry bank at the top, a jump above the last ledge.
static func _shelf() -> Rect2:
	return Rect2(-460, _last_top() - 130.0, 760, 110)

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-520, BASE_Y, 1040, 320)]
	for chamber in CHAMBERS:
		for step in 4:
			if _kind(chamber, step) == "moss":
				out.append(Rect2(_x(chamber, step) - LEDGE_W * 0.5,
					_top(chamber, step), LEDGE_W, LEDGE_H))
	out.append(_shelf())
	return out

static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []

static func hazards() -> Array[Dictionary]:
	# The pool's surface: one sensor, no spikes drawn -- the green is the warning.
	return [{"pos": Vector2(0, WATER_Y + 34), "size": Vector2(3200, 68),
		"draw_spikes": false}]

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# The climbing chaser from 1-3: it rises from the pool, so the climb cannot
	# be taken at leisure; the guardian's shot knocks it back down.
	out.append({"type": "sky_pursuer", "pos": start_position() + Vector2(0, 420),
		"delay": 2.0, "speed": 195.0, "catchup": 460.0, "stun": 1.5,
		"direction": Vector2.UP})
	for chamber in range(1, CHAMBERS):
		# A spiked crawler on the first ledge of every other chamber; it turns
		# at the ledge's edge, so it is a timing question, not a wall.
		if chamber % 2 == 1 and _kind(chamber, 0) == "moss":
			out.append({"type": "walker", "skin": "walker_spiky",
				"pos": Vector2(_x(chamber, 0), _top(chamber, 0) - 21.0), "patrol": 70.0})
		# A marsh fly across the middle of the chamber, in the jump arcs.
		if chamber % 3 == 2:
			out.append({"type": "flyer", "pos": Vector2(0, _top(chamber, 1) - 80.0),
				"patrol": 150.0})
	return out

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		for step in 3:
			var x := _x(chamber, step)
			var top := _top(chamber, step)
			match _kind(chamber, step):
				"rot":
					out.append({"type": "crumble", "pos": Vector2(x, top + 18.0),
						"span": Vector2(LEDGE_W - 40.0, 36)})
				"lift":
					out.append({"type": "moving_platform", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W - 30.0, 26), "travel": Vector2(0, -95),
						"speed": 70.0, "phase": float(chamber) * 0.37})
				"gas":
					out.append({"type": "updraft", "pos": Vector2(x, top + 130.0),
						"span": Vector2(170, 350)})
				"echo":
					# The guardian shoots the lure; the runner gets a ledge.
					var id := "marsh_rise_%d" % chamber
					out.append({"type": "switch", "id": id,
						"pos": Vector2(_x(chamber, 1), _top(chamber, 1) - 80.0),
						"hold": 11.0})
					out.append({"type": "switch_bridge", "id": id,
						"pos": Vector2(x, top + 13.0), "span": Vector2(LEDGE_W, 26)})
	return out

static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in [4, 9]:
		out.append(Vector2(_x(chamber, 3) + 60.0, _top(chamber, 3)))
	return out

static func checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in range(1, CHAMBERS, 2):
		out.append(Vector2(_x(chamber, 3), _top(chamber, 3) - 52.0))
	return out

static func goal() -> Vector2:
	return Vector2(_shelf().position.x + 120.0, _shelf().position.y - 55.0)

static func key_position() -> Vector2:
	return Vector2(_shelf().end.x - 110.0, _shelf().position.y - 4.0)

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in CHAMBERS:
		for step in 4:
			out.append(Vector2(_x(chamber, step), _top(chamber, step) - 76.0))
	return out

static func crystals() -> Array[Vector2]:
	return [Vector2(0, _top(3, 2) - 150.0), Vector2(0, _top(7, 2) - 150.0),
		Vector2(0, _top(11, 2) - 150.0)]

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "swamp_tree", "pos": Vector2(-470, BASE_Y), "height": 300.0},
		{"type": "swamp_reeds", "pos": Vector2(-60, BASE_Y)},
		{"type": "swamp_mushroom", "pos": Vector2(300, BASE_Y)},
		{"type": "swamp_tree", "pos": Vector2(250, _shelf().position.y), "height": 260.0,
			"flip": true},
		{"type": "swamp_reeds", "pos": Vector2(-300, _shelf().position.y)},
	]
	for chamber in range(1, CHAMBERS):
		var x := _x(chamber, 3)
		var top := _top(chamber, 3)
		out.append({"type": "swamp_mushroom" if chamber % 2 == 0 else "swamp_reeds",
			"pos": Vector2(x + (60.0 if chamber % 2 == 0 else -60.0), top)})
	return out
