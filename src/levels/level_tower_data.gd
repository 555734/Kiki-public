extends RefCounted
## 1-7: twenty-three linked tower chambers. The route rises almost 14,000px,
## over twice the height of 1-3. Four landings form each chamber; every fourth
## is permanent so the long climb has a reliable place to read the next room.

const BASE_Y := 14400.0
const CHAMBER_RISE := 600.0
const CHAMBERS := 23
const LEDGE_W := 210.0
const LEDGE_H := 55.0

static func kill_y_value() -> float: return 14940.0
static func start_position() -> Vector2: return Vector2(-360, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE CLOCKWORK TOWER"
static func stage_number_value() -> String: return "1-7"
static func objective_value() -> String: return "Climb the clockwork tower"

static func _top(chamber: int, step: int) -> float:
	return BASE_Y - float(chamber) * CHAMBER_RISE - float(step + 1) * 145.0

static func _x(chamber: int, step: int) -> float:
	var path := [-300.0, -100.0, 100.0, 300.0] if chamber % 2 == 0 \
		else [300.0, 100.0, -100.0, -300.0]
	return path[step]

static func _kind(chamber: int, step: int) -> String:
	if step == 3:
		return "stone"
	match chamber % 6:
		0:
			return "lift" if step == 1 else "stone"
		1:
			return "hand" if step == 1 else ("blink" if step == 2 else "stone")
		2:
			return "air" if step == 1 else ("crumble" if step == 2 else "stone")
		3:
			return "belt" if step == 0 else ("crumble" if step == 2 else "stone")
		4:
			return "blink" if step == 0 else ("lift" if step == 1 else "stone")
		_:
			# The missing third landing creates a 290px rise after the
			# crumbling stone. A guardian platform is required here.
			return "crumble" if step == 1 else ("air" if step == 2 else "stone")

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-560, BASE_Y, 1120, 240)]
	for chamber in CHAMBERS:
		for step in 4:
			if _kind(chamber, step) == "stone":
				out.append(Rect2(_x(chamber, step) - LEDGE_W * 0.5,
					_top(chamber, step), LEDGE_W, LEDGE_H))
	return out

static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Fixed needles are reserved for safe stone landings with room to jump over.
	for chamber in range(8, CHAMBERS, 6):
		out.append({"pos": Vector2(_x(chamber, 3) + 62.0, _top(chamber, 3) - 12.0),
			"size": Vector2(60, 24)})
	return out

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		if chamber % 3 == 1:
			out.append({"type": "turret",
				"pos": Vector2(_x(chamber, 3), _top(chamber, 3) - 60.0),
				"aim": Vector2.LEFT if chamber % 2 == 0 else Vector2.RIGHT,
				"burst": 2})
		if chamber > 3 and chamber % 4 == 2:
			out.append({"type": "mine", "pos": Vector2(0, _top(chamber, 1) - 38.0),
				"bob": Vector2(75, 25), "period": 3.6,
				"phase": float(chamber) * 0.37})
	return out

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		if chamber % 6 == 0:
			out.append({"type": "gear_wheel",
				"pos": Vector2(-80 if chamber % 2 == 0 else 80,
					BASE_Y - float(chamber) * CHAMBER_RISE - 550),
				"radius": 98.0, "speed": 0.27 + float(chamber / 6) * 0.025,
				"dir": 1 if chamber % 2 == 0 else -1,
				"phase": float(chamber) * 0.37})
		for step in 3:
			var x := _x(chamber, step)
			var top := _top(chamber, step)
			match _kind(chamber, step):
				"lift":
					out.append({"type": "moving_platform", "pos": Vector2(x, top + 13),
						"span": Vector2(LEDGE_W, 26), "travel": Vector2(0, -105),
						"speed": 75.0 + float(chamber / 6) * 9.0,
						"phase": float(chamber) * 0.49})
				"hand":
					out.append({"type": "clock_hand", "pos": Vector2(x - 90, top + 13),
						"length": 225.0, "period": 4.2,
						"phase": float(chamber) * 0.27})
				"blink":
					out.append({"type": "blink", "pos": Vector2(x, top + 13),
						"span": Vector2(LEDGE_W, 26), "beat": 1.8,
						"colour": (chamber + step) % 2,
						"phase": float(chamber % 4) * 0.32})
				"crumble":
					out.append({"type": "crumble", "pos": Vector2(x, top + 18),
						"span": Vector2(LEDGE_W, 36)})
				"belt":
					out.append({"type": "conveyor", "pos": Vector2(x, top + 13),
						"span": Vector2(LEDGE_W, 26), "speed": 135.0,
						"flip": 3.4, "dir": -1 if chamber % 2 == 0 else 1,
						"phase": float(chamber) * 0.23})
		if chamber % 6 == 2:
			out.append({"type": "updraft",
				"pos": Vector2(_x(chamber, 0), _top(chamber, 0) + 45),
				"span": Vector2(155, 355)})
		if chamber % 6 == 1:
			out.append({"type": "tower_trap", "kind": "pendulum",
				"pos": Vector2(0, _top(chamber, 2) - 130),
				"length": 235.0, "period": 3.6,
				"phase": float(chamber) * 0.31})
		if chamber % 6 == 3:
			out.append({"type": "tower_trap", "kind": "piston",
				"pos": Vector2(0, _top(chamber, 1) - 105),
				"travel": 150.0, "period": 3.3,
				"phase": float(chamber) * 0.43})
		if chamber % 6 == 4:
			out.append({"type": "tower_trap", "kind": "spikes",
				"pos": Vector2(_x(chamber, 2) - 150.0,
					_top(chamber, 2) - 80), "period": 3.0,
				"phase": float(chamber) * 0.41,
				"facing": 1})
			# A portal across the trap room gives a deliberate alternate line.
			var entry := Vector2(_x(chamber, 0), _top(chamber, 0) - 45)
			var exit := Vector2(_x(chamber, 2), _top(chamber, 2) - 72)
			out.append({"type": "warp", "pos": entry, "size": Vector2(78, 106),
				"exit": exit})
			out.append({"type": "warp_exit", "pos": exit,
				"size": Vector2(78, 106)})
		if chamber % 6 == 5:
			# The guardian sees the demanded mark on the gate; the runner sees
			# marks on these two targets. A wrong shot locks both for four seconds.
			var id := "tower_gate_%d" % chamber
			var demanded := 1 + (chamber / 6) % 3
			var y := _top(chamber, 2)
			out.append({"type": "switch", "id": id,
				"pos": Vector2(-190, y - 100), "sigil": demanded,
				"hold": 10.0})
			out.append({"type": "switch", "id": id,
				"pos": Vector2(190, y - 100), "sigil": 1 + demanded % 3,
				"hold": 10.0})
			out.append({"type": "gate", "id": id, "wants": demanded,
				"pos": Vector2(-200 if chamber % 2 == 1 else 200,
					_top(chamber, 3) - 18), "span": Vector2(65, 270)})
		# A few springs break up the climb, but never replace the co-op gates.
		if chamber % 6 == 0 and chamber > 0:
			out.append({"type": "updraft",
				"pos": Vector2(0, _top(chamber, 1) + 100),
				"span": Vector2(120, 250)})
	return out

static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in [0, 6, 12, 18]:
		out.append(Vector2(_x(chamber, 3), _top(chamber, 3)))
	return out

static func checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in range(1, CHAMBERS - 1, 2):
		out.append(Vector2(_x(chamber, 3), _top(chamber, 3) - 52))
	return out

static func goal() -> Vector2:
	return Vector2(_x(CHAMBERS - 1, 3), _top(CHAMBERS - 1, 3) - 55)

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in CHAMBERS:
		for step in 4:
			var centre := Vector2(_x(chamber, step), _top(chamber, step) - 72)
			out.append(centre + Vector2(-42, 10))
			out.append(centre)
			out.append(centre + Vector2(42, 10))
	return out

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		var base := BASE_Y - float(chamber) * CHAMBER_RISE
		out.append({"type": "tower_banner",
			"pos": Vector2(-440 if chamber % 2 == 0 else 440, base - 120)})
		out.append({"type": "tower_lamp",
			"pos": Vector2(430 if chamber % 2 == 0 else -430, base - 445)})
		if _kind(chamber, 1) == "lift":
			out.append({"type": "tower_rail",
				"pos": Vector2(_x(chamber, 1), _top(chamber, 1) + 115),
				"height": 260.0})
	return out
