class_name Level02Data
extends RefCounted
## Stage 1-C "THE CROSSING": short cooperative route with skilled alternatives.
## Ordinary walls and timed triple jumps are legitimate traversal tools.
## Sections 1 and 3 teach how a guardian can help; they do not restrict solo
## movement. The 600px crossings and the final rising gap retain room for
## platforms and launches. stage_probe plays the assisted route;
## movement_probe checks full-speed triple-jump reach separately.
## Re-run both probes after movement changes: old measured arcs are not bounds
## on new movement, and neither probe exhaustively searches every solo route.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(-1300, 340)
const STAGE_NAME := "THE CROSSING"
const STAGE_NUMBER := "1-C"
const OBJECTIVE := "Cross together"

## Where the ground is in each section, so the rest of the file can refer to it
## by name instead of by a number that has to be kept in step by hand.
const FLOOR := 420.0
const SHELF := 200.0     # section 1's step: 220 above FLOOR, a single sprint jump is lower
const MID := 240.0
const HIGH := 40.0      # 200 above MID; paired with the final wide gap

## The shelf teaches a guardian wall kick. Ordinary wall kicks and timed
## triple jumps are valid skilled alternatives; cooperation is enforced by
## the wide crossings, not by taking movement controls away.
const SHELF_TOP := -30.0

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in decor():
		match String(d.get("type", "")):
			"conduit":
				var size: Vector2 = d.get("size", Vector2(90, 76))
				var base: Vector2 = d["pos"]
				out.append(Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y))
			"blocks":
				var cell: float = float(d.get("cell", 46.0))
				var n: int = int(d.get("count", 3))
				var at: Vector2 = d["pos"]
				out.append(Rect2(at.x, at.y, cell * float(n), cell))
	return out

## Solid ground: Rect2(x, top_y, width, height), each drawn down to GROUND_BASE
## so a high ledge reads as a column of earth rather than a slab in the sky.
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		# ---- 1: a safe first opportunity to help --------------------------
		# A 200px gap with a 220px rise on the far side. The gap alone is a
		# hop; an ordinary first jump falls short. Skilled wall/chain routes
		# are allowed. First lesson, and the safest place in the stage to learn
		# a control: nothing here can kill anybody.
		[-1900.0, -300.0, FLOOR],
		[-100.0, 700.0, SHELF],

		# ---- 2: the same move, with a drop under it ------------------------
		[700.0, 1100.0, SHELF],
		[1700.0, 2500.0, SHELF],          # 600px: a wide cooperative crossing

		# ---- 3: the shelf, and the wall that reaches it --------------------
		[2500.0, 3700.0, MID],            # a long flat run to work on
		[3700.0, 4500.0, SHELF_TOP],      # 270 up: one kick off a guardian wall
		[4500.0, 5000.0, MID],            # back down to the route

		# ---- 4: the crossing the stage is named for ------------------------
		[5000.0, 5700.0, MID],
		[6300.0, 7300.0, MID],            # 600px: past a jump, inside a launch.

		# ---- 5: the corridor with something in it --------------------------
		[7300.0, 8800.0, MID],

		# ---- 6: everything, then the gate ----------------------------------
		[8800.0, 9300.0, MID],
		[9780.0, 10700.0, HIGH],          # 480px AND 200 up: teach a climbing launch
		[10700.0, 11600.0, HIGH],
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## Spikes. Used sparingly here: the gaps are the danger, and a stage that is
## lethal everywhere gives a pair no room to talk.
static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(1200, 560), "size": Vector2(460, 46)},   # under the 600px gap
		{"pos": Vector2(6000, 560), "size": Vector2(560, 46)},   # under the crossing
		{"pos": Vector2(9540, 560), "size": Vector2(440, 46)},   # under the last one
	]

## Enemy y values put the BOTTOM of the box on the ledge, not somewhere near it.
static func enemies() -> Array[Dictionary]:
	return [
		# Prototype pressure enemy. It starts behind the runner, ignores terrain,
		# and only wakes once the runner has actually begun moving.
		{"type": "chaser", "pos": START + Vector2(-420, 0), "speed": 360.0,
			"activation": 100.0, "spawn_distance": 420.0},
		# 2: one walker on the far side, so the landing is not free.
		{"type": "walker", "pos": Vector2(2100, SHELF - 21.0), "patrol": 180.0},
		# 3: a flyer over the shelf. It cannot be stomped from below, so the
		# runner either times it or asks for it to be shot.
		{"type": "flyer", "pos": Vector2(4100, -140), "patrol": 200.0},
		# 4: a walker waiting where a launch lands, which is the argument for
		# aiming the launch rather than just taking it.
		{"type": "walker", "pos": Vector2(6700, MID - 21.0), "patrol": 200.0},
		# 5: the corridor. Two of them, facing whoever is nearest.
		{"type": "shieldbearer", "pos": Vector2(7800, MID - 23.0)},
		{"type": "shieldbearer", "pos": Vector2(8350, MID - 23.0)},
		# 6: the last stretch.
		{"type": "flyer", "pos": Vector2(9100, 60), "patrol": 160.0},
		{"type": "walker", "pos": Vector2(10400, HIGH - 21.0), "patrol": 200.0},
	]

## No moving floors or lasers in this one. 1-1 has them; here the moving parts
## are the two players, and adding a third thing to time would be noise.
static func gimmicks() -> Array[Dictionary]:
	return []

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(800, SHELF - 40.0),       # after the first lesson
		Vector2(2700, MID - 40.0),        # before the shelf
		Vector2(5300, MID - 40.0),        # before the crossing
		Vector2(7400, MID - 40.0),        # before the corridor
		Vector2(8900, MID - 40.0),        # before the last gap
	]

static func goal() -> Vector2:
	return Vector2(11400, HIGH - 55.0)

## Crystals, which is how the runner pays for the next thing the guardian does.
##
## Half of them are on the route -- a pair who are simply getting through still
## gets something back -- and half are one decision off it. None of them is
## required, and none of them is free.
static func crystals() -> Array[Vector2]:
	return [
		Vector2(300, SHELF - 60.0),       # on the route: the first is a gift
		Vector2(1400, SHELF - 190.0),     # over the 600px gap, mid-air: a detour
		Vector2(3000, MID - 60.0),        # on the route
		Vector2(4100, -110.0),            # the wall-jump shelf: the whole point of it
		Vector2(5450, MID - 60.0),        # on the route, before the crossing
		Vector2(6000, MID - 230.0),       # high over the crossing: aim the launch
		Vector2(7600, MID - 60.0),        # on the route
		Vector2(8600, MID - 200.0),       # over the corridor, past the shields
		Vector2(9200, MID - 60.0),        # on the route
		Vector2(10150, HIGH - 130.0),     # the last detour
	]

static func springs() -> Array[Vector2]:
	return []

static func coins() -> Array[Vector2]:
	return []

static func decor() -> Array[Dictionary]:
	return [
		# Signposts stand where a pair needs to stop and look at something. The
		# teaching here is the shape of the ground, not a wall of text.
		{"type": "signpost", "pos": Vector2(-1100, FLOOR)},
		{"type": "tree", "pos": Vector2(-1500, FLOOR)},
		{"type": "flowers", "pos": Vector2(-700, FLOOR)},
		{"type": "fence", "pos": Vector2(-500, FLOOR), "width": 160.0},

		{"type": "signpost", "pos": Vector2(600, SHELF)},
		{"type": "flowers", "pos": Vector2(200, SHELF)},
		{"type": "tree", "pos": Vector2(1900, SHELF)},

		{"type": "signpost", "pos": Vector2(3500, MID)},
		{"type": "conduit", "pos": Vector2(2900, MID), "size": Vector2(60, 84)},
		{"type": "flowers", "pos": Vector2(3200, MID)},
		{"type": "tree", "pos": Vector2(4700, MID)},

		{"type": "signpost", "pos": Vector2(5600, MID)},
		{"type": "fence", "pos": Vector2(5200, MID), "width": 180.0},
		{"type": "tree", "pos": Vector2(6500, MID)},

		{"type": "signpost", "pos": Vector2(7450, MID)},
		{"type": "flowers", "pos": Vector2(8700, MID)},

		{"type": "signpost", "pos": Vector2(9100, MID)},
		{"type": "tree", "pos": Vector2(10100, HIGH)},
		{"type": "flowers", "pos": Vector2(11200, HIGH)},
	]

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
