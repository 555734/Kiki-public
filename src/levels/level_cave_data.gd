extends RefCounted
## 1-8 climbs from the deep mine through a broken cave roof into daylight.

const BASE_Y := 13900.0
const CHAMBER_RISE := 510.0
const CHAMBERS := 25
const LEDGE_W := 230.0
const LEDGE_H := 48.0
const SURFACE_Y := 1080.0

static func kill_y_value() -> float: return 14280.0
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE UNDERGROVE"
static func stage_number_value() -> String: return "1-8"
static func objective_value() -> String: return "Climb out of the cavern"

## A vertical climb: every ledge and platform above the cavern floor is taken
## from below, so all of them let the runner jump up through them.
static func platforms_one_way() -> bool: return true
static func ground_one_way(rect: Rect2) -> bool:
	return rect.position.y < start_position().y

static func _top(chamber: int, step: int) -> float:
	return BASE_Y - float(chamber) * CHAMBER_RISE - float(step + 1) * 120.0

static func _x(chamber: int, step: int) -> float:
	if chamber == 0 and step == 0:
		return -150.0
	# The chamber turn is a lateral jump, never a platform directly overhead.
	var path := [-280.0, -80.0, 110.0, 280.0] if chamber % 2 == 0 \
		else [110.0, 280.0, 80.0, -110.0]
	return path[step]

static func _kind(chamber: int, step: int) -> String:
	if step == 3:
		return "stone"
	if chamber % 6 == 5:
		return "echo" if step == 2 else "stone"
	match chamber % 6:
		0: return "lift" if step == 1 else "stone"
		1: return "blink" if step == 1 else ("crumble" if step == 2 else "stone")
		2: return "air" if step == 1 else "stone"
		3: return "belt" if step == 0 else ("lift" if step == 1 else "stone")
		4: return "crumble" if step == 1 else ("blink" if step == 2 else "stone")
		_: return "stone"

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-500, BASE_Y, 1000, 320)]
	for chamber in CHAMBERS:
		for step in 4:
			if _kind(chamber, step) == "stone":
				out.append(Rect2(_x(chamber, step) - LEDGE_W * 0.5,
					_top(chamber, step), LEDGE_W, LEDGE_H))
	# The exit shelf leaves the final updraft unobstructed at x=270.
	out.append(Rect2(-420, 960, 585, 100))
	return out

static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		var y := BASE_Y - float(chamber) * CHAMBER_RISE
		if chamber < 21:
			out.append({"type": "cave_lamp", "pos": Vector2(
				-420.0 if chamber % 2 == 0 else 420.0, y - 345.0)})
		if chamber % 2 == 0:
			out.append({"type": "cave_crystal", "pos": Vector2(
				370.0 if chamber % 4 == 0 else -370.0, y - 175.0)})
		if _kind(chamber, 1) == "lift":
			out.append({"type": "cave_rail", "pos": Vector2(
				_x(chamber, 1), _top(chamber, 1) + 110.0), "width": 170.0})
	return out

static func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in [3, 9, 15, 21]:
		out.append({"pos": Vector2(_x(chamber, 2) + 65.0,
			_top(chamber, 2) - 9.0), "size": Vector2(50, 18)})
	return out

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		if chamber > 0 and chamber % 6 != 4:
			out.append({"type": "cave_enemy",
				"kind": "burrower" if chamber % 3 == 0 else (
					"slime" if chamber % 3 == 1 else "mushroom"),
				"pos": Vector2(_x(chamber, 0), _top(chamber, 0) - 27.0),
				"patrol": 48.0})
		if chamber % 2 == 0 and _kind(chamber, 2) == "stone":
			out.append({"type": "cave_enemy", "kind": "mushroom" if chamber % 4 == 0
				else "slime", "pos": Vector2(_x(chamber, 2), _top(chamber, 2) - 25.0),
				"patrol": 43.0})
		if chamber > 1:
			out.append({"type": "cave_enemy", "kind": "bat" if chamber % 3 == 0
				else "beetle", "pos": Vector2(0, _top(chamber, 1) - 70.0),
				"patrol": 78.0})
	return out

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		for step in 3:
			var x := _x(chamber, step)
			var top := _top(chamber, step)
			match _kind(chamber, step):
				"lift":
					out.append({"type": "moving_platform", "style": "minecart",
						"pos": Vector2(x, top + 13.0), "span": Vector2(LEDGE_W, 26),
						"travel": Vector2(0, -90), "speed": 78.0,
						"phase": float(chamber) * 0.41})
				"blink":
					out.append({"type": "blink", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W, 26), "beat": 1.8,
						"colour": (chamber + step) % 2,
						"phase": float(chamber) * 0.29})
				"crumble":
					out.append({"type": "crumble", "pos": Vector2(x, top + 18.0),
						"span": Vector2(LEDGE_W, 36)})
				"belt":
					out.append({"type": "conveyor", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W, 26), "speed": 105.0,
						"flip": 3.4, "dir": 1 if chamber % 2 == 0 else -1})
				"air":
					out.append({"type": "updraft", "pos": Vector2(x, top + 130.0),
						"span": Vector2(175, 355)})
				"echo":
					var id := "cave_rise_%d" % chamber
					out.append({"type": "switch", "id": id,
						"pos": Vector2(_x(chamber, 1), _top(chamber, 1) - 75.0),
						"hold": 11.0})
					out.append({"type": "switch_bridge", "id": id,
						"pos": Vector2(x, top + 13.0), "span": Vector2(LEDGE_W, 26)})
		if chamber % 6 == 4:
			out.append({"type": "cave_trap", "kind": "boulder",
				"pos": Vector2(_x(chamber, 0), _top(chamber, 0) - 40.0),
				"travel": 45.0, "period": 3.2, "phase": float(chamber) * 0.17})
		if chamber > 2 and chamber % 5 == 2:
			out.append({"type": "cave_trap", "kind": "stalactite",
				"pos": Vector2(_x(chamber, 2), _top(chamber, 2) - 225.0),
				"travel": 175.0, "period": 3.1, "phase": float(chamber) * 0.23})
	out.append({"type": "updraft", "pos": Vector2(280, 1180),
		"span": Vector2(175, 400)})
	return out

static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in [2, 8, 14, 20]:
		out.append(Vector2(_x(chamber, 3), _top(chamber, 3)))
	return out

static func checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in range(1, CHAMBERS, 2):
		out.append(Vector2(_x(chamber, 3), _top(chamber, 3) - 52.0))
	return out

static func goal() -> Vector2: return Vector2(-205, 905)
static func key_position() -> Vector2: return Vector2(280, 1130)

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in CHAMBERS:
		for step in 4:
			out.append(Vector2(_x(chamber, step), _top(chamber, step) - 78.0))
			if step == 3 and chamber % 3 == 0:
				out.append(Vector2(_x(chamber, step) - 38.0,
					_top(chamber, step) - 78.0))
	out.append(Vector2(15, 790))
	return out
