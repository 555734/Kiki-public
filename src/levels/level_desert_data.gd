extends RefCounted
## Stage 1-6 climbs the sandglass ruins: a broken sandstone tower standing out
## of the dunes, climbed ledge by ledge to the open sky at its top. Sand belts,
## blinking cyan stones, falling causeway stones, lifts, the desert wind, and
## the two co-op pieces the flat stage had -- mirage ledges the guardian's shot
## makes solid, and arrow pads that throw the runner up and across.
##
## Built like 1-7 and 1-8 (four ledges a chamber, zig-zagging so every turn is
## a sideways jump), a little longer than 1-5 and shorter than 1-7.
##
##   step rise 124px  -- under the 154px jump, through one-way ledges
##   chambers 16      -- about 8,700px of climb

const BASE_Y := 9400.0
const CHAMBER_RISE := 540.0
const STEP_RISE := 124.0
const CHAMBERS := 16
const LEDGE_W := 240.0
const LEDGE_H := 50.0
const KILL_Y := BASE_Y + 380.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE SANDGLASS RUINS"
static func stage_number_value() -> String: return "1-6"
static func objective_value() -> String: return "Climb the sandglass ruins"

static func _top(chamber: int, step: int) -> float:
	return BASE_Y - float(chamber) * CHAMBER_RISE - float(step + 1) * STEP_RISE

static func _x(chamber: int, step: int) -> float:
	if chamber == 0 and step == 0:
		return -150.0
	var path := [-280.0, -80.0, 115.0, 285.0] if chamber % 2 == 0 \
		else [115.0, 285.0, 80.0, -115.0]
	return path[step]

## What each ledge is. The fourth of every chamber is always sandstone.
static func _kind(chamber: int, step: int) -> String:
	if step == 3 or chamber == 0:
		return "stone"
	match chamber % 6:
		1: return "belt" if step == 0 else ("blink" if step == 1 else "stone")
		2: return "fall" if step == 1 or step == 2 else "stone"
		3: return "lift" if step == 1 else "stone"
		4: return "wind" if step == 1 else ("blink" if step == 2 else "stone")
		5: return "mirage" if step == 2 else "stone"
		_: return "belt" if step == 1 else "stone"

static func _last_top() -> float:
	return _top(CHAMBERS - 1, 3)

## The top of the ruin, a jump above the last ledge, open to the sky.
static func _shelf() -> Rect2:
	return Rect2(-460, _last_top() - 128.0, 760, 110)

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(-520, BASE_Y, 1040, 360)]
	for chamber in CHAMBERS:
		for step in 4:
			if _kind(chamber, step) == "stone":
				out.append(Rect2(_x(chamber, step) - LEDGE_W * 0.5,
					_top(chamber, step), LEDGE_W, LEDGE_H))
	out.append(_shelf())
	return out

static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []

static func hazards() -> Array[Dictionary]:
	# None: on a climb every ledge is both a landing and a take-off, and a
	# thorn strip on either end is where a runner has to put their feet.
	return []

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# The climbing chaser from 1-3: it rises out of the dunes behind the pair.
	out.append({"type": "sky_pursuer", "pos": start_position() + Vector2(0, 420),
		"delay": 2.0, "speed": 200.0, "catchup": 470.0, "stun": 1.45,
		"direction": Vector2.UP})
	for chamber in range(1, CHAMBERS):
		# Ground walkers on plain ledges: the scarab runs, the cactus creeps.
		if _kind(chamber, 0) == "stone" and chamber % 2 == 0:
			out.append({"type": "desert_enemy", "kind": "scarab",
				"pos": Vector2(_x(chamber, 0), _top(chamber, 0) - 27.0), "patrol": 60.0})
		elif _kind(chamber, 2) == "stone" and chamber % 3 == 1:
			out.append({"type": "desert_enemy", "kind": "cactus",
				"pos": Vector2(_x(chamber, 2), _top(chamber, 2) - 33.0), "patrol": 40.0})
		# The floaters hang across the middle of a chamber, in the jump arcs.
		if chamber % 4 == 2:
			out.append({"type": "desert_enemy", "kind": "jelly",
				"pos": Vector2(0, _top(chamber, 1) - 85.0), "patrol": 120.0})
		elif chamber % 4 == 0:
			out.append({"type": "desert_enemy", "kind": "fin",
				"pos": Vector2(0, _top(chamber, 2) - 70.0), "patrol": 110.0})
	return out

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chamber in CHAMBERS:
		for step in 3:
			var x := _x(chamber, step)
			var top := _top(chamber, step)
			match _kind(chamber, step):
				"belt":
					out.append({"type": "conveyor", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W, 26), "speed": 110.0, "flip": 3.2,
						"dir": 1 if chamber % 2 == 0 else -1})
				"blink":
					out.append({"type": "blink", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W, 26), "beat": 1.6,
						"colour": (chamber + step) % 2, "phase": float(chamber) * 0.31})
				"fall":
					out.append({"type": "crumble", "pos": Vector2(x, top + 18.0),
						"span": Vector2(LEDGE_W - 30.0, 36)})
				"lift":
					out.append({"type": "moving_platform", "pos": Vector2(x, top + 13.0),
						"span": Vector2(LEDGE_W - 20.0, 26), "travel": Vector2(0, -100),
						"speed": 75.0, "phase": float(chamber) * 0.43})
				"wind":
					out.append({"type": "updraft", "pos": Vector2(x, top + 130.0),
						"span": Vector2(170, 355)})
				"mirage":
					# The guardian shoots the sigil; the ghost ledge turns solid.
					var id := "desert_mirage_%d" % chamber
					out.append({"type": "switch", "id": id,
						"pos": Vector2(_x(chamber, 1), _top(chamber, 1) - 80.0),
						"hold": 10.0})
					out.append({"type": "switch_bridge", "id": id,
						"pos": Vector2(x, top + 13.0), "span": Vector2(LEDGE_W, 26)})
	# Two arrow pads on the safe ledges halfway up: a big throw up and across
	# for a runner who trusts it.
	for chamber in [6, 12]:
		out.append({"type": "trick_pad",
			"pos": Vector2(_x(chamber, 3), _top(chamber, 3)),
			"dir": -1 if chamber % 2 == 0 else 1, "forward": 200.0, "rise": 1050.0})
	return out

static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for chamber in [3, 9, 13]:
		out.append(Vector2(_x(chamber, 3) + 55.0, _top(chamber, 3)))
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

static func crystals() -> Array[Vector2]: return []

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "desert_arch", "pos": Vector2(-380, BASE_Y), "height": 235.0},
		{"type": "desert_flower", "pos": Vector2(60, BASE_Y)},
		{"type": "desert_cactus", "pos": Vector2(360, BASE_Y)},
		{"type": "desert_arch", "pos": Vector2(150, _shelf().position.y), "height": 210.0},
		{"type": "desert_crystal", "pos": Vector2(-300, _shelf().position.y)},
	]
	for chamber in range(1, CHAMBERS):
		var x := _x(chamber, 3)
		var top := _top(chamber, 3)
		var kinds := ["desert_crystal", "desert_flower", "desert_cactus"]
		out.append({"type": kinds[chamber % 3],
			"pos": Vector2(x + (55.0 if chamber % 2 == 0 else -55.0), top)})
	return out
