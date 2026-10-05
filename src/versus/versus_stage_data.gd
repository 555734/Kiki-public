class_name VersusStageData
## The star arena: a small, left-right symmetric loop built from the stages'
## own pieces -- their slabs, block rows, conduits and scenery -- with a
## ground of its own for each stage (LAYOUTS): hills in 1-1, cliffs in 1-2,
## islands in 1-3, a dune in 1-4, rocks over poison in 1-5.
##
## Small on purpose: about three screens round, so the other runners are
## usually on screen and never more than one short run away; the HUD's map
## and the edge arrows cover the rest (docs/versus-2v2-stars.md).
##
## Co-op Level01Data is unchanged. Everything the match measures reads these
## functions, so the scene, the host's star physics and a client's collision
## world are all the same list.
##
## Y is positive downwards and every figure below is the TOP of a surface.
## Mirror rule: a piece at [x0, x1] on the left has a twin at
## [WIDTH - x1, WIDTH - x0] on the right. `test/versus_arena_probe.gd` checks it.

## One lap of the loop runs from x=0 to x=WIDTH.
const WIDTH: float = 3200.0
const LEFT: float = 0.0
const RIGHT: float = WIDTH
## The field is a loop: x=WIDTH is x=0. Both ends are floor at the same
## height, so the join is one continuous stretch of ground and running off
## either edge brings you in at the other without a step, a wall or a cut.
## Everything that measures a distance does it to the nearest lap
## (nearest_image), and everything solid exists one lap either side too, so
## a runner standing on the join has floor under both feet.
const LAPS: Array[int] = [-1, 0, 1]
## How far past either end the neighbouring laps are actually built. A
## runner is always carried back into the middle lap, so nothing further out
## than half a screen plus the camera's lead is ever seen or touched; building
## the whole of both neighbours drew and collided three laps for one.
const LAP_MARGIN: float = 1400.0

## `r` cut to what is built (the middle lap and LAP_MARGIN either side), or
## an empty rectangle if none of it is.
static func clip_to_built(r: Rect2) -> Rect2:
	var x0 := maxf(r.position.x, LEFT - LAP_MARGIN)
	var x1 := minf(r.end.x, RIGHT + LAP_MARGIN)
	if x1 <= x0:
		return Rect2()
	return Rect2(x0, r.position.y, x1 - x0, r.size.y)
## The base 1-1 draws every slab down to.
const GROUND_BASE: float = Level01Data.GROUND_BASE
## The region the HUD's map shows. Covers every surface and a jump above the
## highest block, and nothing of the empty sky or the ground's skirt.
const MAP_RECT := Rect2(LEFT, -120.0, WIDTH, 580.0)
## The lowest ground any stage has: the low ground of the original flat
## arena, kept for the few things measured against "the floor".
const FLOOR_TOP: float = 400.0
const BLOCK_CELL: float = 46.0

## Each stage has its own ground (docs/versus-2v2-stars.md). Every layout is
## the LEFT half, x in [0, 1600]; the right half is its mirror, so the two
## ends meet at x=0/3200 at one height and nobody's side is better.
##   floors:    [x0, x1, top]        -- solid ground drawn down to GROUND_BASE
##   blocks:    [x, top, count]      -- rows of blocks (mirrored); the high
##                                      ones are the upper tier
##   centre:    [x, top, count]      -- rows on the mirror line, listed once
##   obstacles: [x, w, h]            -- a solid piece standing on the floor at
##                                      x (a conduit, ruin stack, rock, stone)
##   springs:   [x]                  -- co-op Spring pads on the floor at x
##   movers:    [x, y, w, dx, dy]    -- co-op MovingPlatform: centre, width,
##                                      travel (shown the same on every
##                                      device: Clock.tick). A lift stands
##                                      on a floor, never in a pit, where
##                                      it would be in the way of the jump.
##   blinks:    [x, y, w, colour]    -- co-op BlinkBlock (1-3)
##   updrafts:  [x, top, bottom, w]  -- co-op Updraft column (1-3)
##   belts:     [x, top, w]          -- co-op Conveyor on the floor at x (none
##                                      used: raised, it is a step to trip
##                                      on; sunk, it fights the floor)
##   enemies:   [kind, x0, x1, y]    -- VersusEnemies: "walker" patrols the
##                                      floor whose top is y, "flyer" flies
##                                      between x0 and x1 around height y
##   starts:    [x, facing]          -- 2v2 uses the first two (half a lap apart)
## Rules every layout keeps (test/versus_probe.gd checks them, and
## versus_reach_probe drives a runner over every step, pit and spring): a step
## is <= 80px, a pit is <= 140px with its far side no more than 40px higher,
## every block row can be walked under and, if it is within 200px above a
## floor, keeps 80px clear of that floor's edges -- a row over a take-off is a
## ceiling the jump hits. The upper tier is reached by springs and lifts.
const LAYOUTS := {
	Stage.Which.ROYAL_ARENA: {
		"floors": [[0.0, 360.0, 400.0], [360.0, 620.0, 340.0],
			[620.0, 740.0, 280.0], [740.0, 940.0, 240.0],
			[1080.0, 1240.0, 260.0], [1240.0, 1420.0, 340.0], [1420.0, 1600.0, 280.0]],
		"blocks": [[120.0, 290.0, 3], [520.0, 25.0, 2], [800.0, -20.0, 2]],
		"centre": [[1462.0, 20.0, 6]], "obstacles": [],
		"springs": [680.0],
		"movers": [[1300.0, 160.0, 120.0, 65.0, -55.0]],
		"enemies": [["walker", 35.0, 265.0, 400.0], ["flyer", 1050.0, 1240.0, 130.0]],
		"starts": [[800.0, 1], [280.0, 1], [1520.0, 1], [1160.0, 1]],
	},
	# 1-1: two rolling hills, and a sky bridge over the middle. A spring on
	# each shoulder of the middle hill throws you up to it; a cloud platform
	# drifts between the hilltop and the bridge.
	Stage.Which.GREENFIELD: {
		"floors": [
			[0.0, 380.0, 400.0], [380.0, 620.0, 330.0], [620.0, 900.0, 250.0],
			[900.0, 1080.0, 330.0], [1080.0, 1220.0, 400.0], [1360.0, 1600.0, 370.0],
		],
		"blocks": [[160.0, 290.0, 3], [714.0, 140.0, 2], [1180.0, 120.0, 4]],
		"centre": [[1485.0, 100.0, 5]],
		"obstacles": [[1000.0, 46.0, 92.0]],
		"springs": [1420.0],
		"movers": [[990.0, 170.0, 100.0, 120.0, 0.0]],
		"enemies": [["walker", 30.0, 260.0, 400.0], ["flyer", 1050.0, 1340.0, 220.0]],
		"starts": [[800.0, 1], [300.0, 1], [1490.0, 1], [520.0, 1]],
	},
	# 1-2: a village of cliffs. Up two ledges to a high plateau with a
	# spring to the rooftops above it, across two pits to the square, where
	# another spring reaches its roof of ruin blocks.
	Stage.Which.HORROR: {
		"floors": [
			[0.0, 300.0, 400.0], [300.0, 500.0, 320.0], [500.0, 820.0, 240.0],
			[960.0, 1120.0, 270.0], [1260.0, 1600.0, 300.0],
		],
		"blocks": [[100.0, 290.0, 2], [600.0, 40.0, 3], [1380.0, 190.0, 3]],
		"centre": [[1531.0, 190.0, 3]],
		"obstacles": [[420.0, 46.0, 92.0]],
		"springs": [560.0, 1320.0],
		"enemies": [["walker", 985.0, 1095.0, 270.0], ["flyer", 620.0, 900.0, 160.0]],
		"starts": [[800.0, 1], [150.0, 1], [1450.0, 1], [400.0, 1]],
	},
	# 1-3: islands in the sky, higher towards the middle. A rising column of
	# air in the first gap catches whoever falls in; blinking slabs bridge
	# the second; a spring on the middle island reaches the high ruins.
	Stage.Which.SKYWARD_RUINS: {
		"floors": [
			[0.0, 360.0, 380.0], [500.0, 700.0, 345.0], [700.0, 860.0, 280.0],
			[1000.0, 1180.0, 250.0], [1320.0, 1600.0, 230.0],
		],
		"blocks": [[140.0, 270.0, 2]],
		"centre": [[1508.0, 40.0, 4]],
		"obstacles": [],
		"springs": [1360.0],
		"blinks": [[930.0, 300.0, 100.0, 0]],
		"updrafts": [[430.0, 250.0, 700.0, 110.0]],
		"enemies": [["walker", 525.0, 675.0, 345.0], ["flyer", 520.0, 840.0, 200.0]],
		"starts": [[800.0, 1], [150.0, 1], [1450.0, 1], [1080.0, 1]],
	},
	# 1-4: a beach and a big dune. Low sand by the sea at the join, a pit
	# onto the water, then the dune climbs to its peak; a spring on the peak
	# reaches a sea stack above it. Crabs walk the dune, gulls the beach.
	Stage.Which.SEA: {
		"floors": [
			[0.0, 300.0, 410.0], [440.0, 700.0, 400.0], [700.0, 900.0, 330.0],
			[900.0, 1100.0, 260.0], [1100.0, 1300.0, 210.0], [1300.0, 1600.0, 190.0],
		],
		"blocks": [[80.0, 300.0, 2], [520.0, 290.0, 2], [1380.0, 20.0, 3]],
		"centre": [[1554.0, 80.0, 2]],
		"obstacles": [[1000.0, 100.0, 46.0]],
		"springs": [1340.0],
		"enemies": [["walker", 1125.0, 1275.0, 210.0], ["flyer", 100.0, 600.0, 230.0]],
		"starts": [[800.0, 1], [150.0, 1], [1450.0, 1], [560.0, 1]],
	},
	# 1-5: mud and rock over poison. Rocks rising out of the mud, three pits,
	# and a spring beside the middle up to the high stones over it.
	Stage.Which.SWAMP: {
		"floors": [
			[0.0, 260.0, 400.0], [400.0, 560.0, 370.0], [560.0, 680.0, 300.0],
			[680.0, 880.0, 370.0], [1020.0, 1220.0, 340.0], [1220.0, 1300.0, 270.0],
			[1440.0, 1600.0, 250.0],
		],
		"blocks": [],
		"centre": [[1531.0, 70.0, 3]],
		"obstacles": [[730.0, 100.0, 46.0]],
		"springs": [1480.0],
		"enemies": [["walker", 425.0, 535.0, 370.0], ["flyer", 300.0, 700.0, 200.0]],
		"starts": [[800.0, 1], [120.0, 1], [1560.0, 1], [1260.0, 1]],
	},
}

static func layout() -> Dictionary:
	return LAYOUTS.get(theme, LAYOUTS[Stage.Which.GREENFIELD])

static func _mirror_span(x0: float, x1: float) -> Vector2:
	return Vector2(WIDTH - x1, WIDTH - x0)

## Everything below is derived from LAYOUTS and the theme alone, and the HUD,
## the spawner and the scene ask for it often; it is worked out once per
## stage and handed out as copies (callers append to what they get).
static var _cache: Dictionary = {}

static func _cached(name: String, make: Callable) -> Array:
	var key := "%s:%d" % [name, theme]
	if not _cache.has(key):
		_cache[key] = make.call()
	return _cache[key].duplicate()

## Solid ground, one lap of it.
static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(_cached("ground", _make_ground))
	return out

static func _make_ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var left: Array = layout()["floors"]
	for f in left:
		out.append(_slab(f[0], f[1], f[2]))
	for i in range(left.size() - 1, -1, -1):
		var f: Array = left[i]
		var m := _mirror_span(f[0], f[1])
		out.append(_slab(m.x, m.y, f[2]))
	return out

static func _slab(x0: float, x1: float, top: float) -> Rect2:
	return Rect2(x0, top, x1 - x0, 140.0 if theme == Stage.Which.ROYAL_ARENA else GROUND_BASE - top)

## The floors a runner stands on, without the walls.
static func floors() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in ground():
		if r.position.x >= LEFT and r.end.x <= RIGHT:
			out.append(r)
	return out

## Top of the floor under x (anywhere round the loop), or INF over a pit.
static func top_at(x: float) -> float:
	var at := wrap_x(x)
	for r in floors():
		if at >= r.position.x and at <= r.end.x:
			return r.position.y
	return INF

## Every height a runner can stand at, lowest last. For the probes and the map.
static func surface_tops() -> Array[float]:
	var out: Array[float] = []
	for r in floors():
		if not out.has(r.position.y):
			out.append(r.position.y)
	out.sort()
	return out

# ------------------------------------------------------------------- themes
## Which stage the arena is. Each has its own ground (LAYOUTS) and its own
## art. The wire never carries geometry: the host's WELCOME names the stage
## and every machine builds the same layout from it.
const DEFAULT_THEME: int = Stage.Which.ROYAL_ARENA
const THEMES: Array[int] = [DEFAULT_THEME, Stage.Which.GREENFIELD, Stage.Which.HORROR,
	Stage.Which.SKYWARD_RUINS, Stage.Which.SEA, Stage.Which.SWAMP]
static var theme: int = DEFAULT_THEME

## Paint the arena as `which` from now on. Also points Stage at it, which is
## what the sky, the terrain painter and the 3D view all read.
static func use_theme(which: int) -> void:
	theme = which if THEMES.has(which) else DEFAULT_THEME
	Stage.use(theme)

static func theme_label(which: int) -> String:
	match which:
		Stage.Which.ROYAL_ARENA: return "ロイヤル・アリーナ"
		Stage.Which.HORROR: return "1-2 うつろな村外れ"
		Stage.Which.SKYWARD_RUINS: return "1-3 天空の遺跡"
		Stage.Which.SEA: return "1-4 陽光の海岸"
		Stage.Which.SWAMP: return "1-5 毒の沼地"
		_: return "1-1 みどりの草原"

## The conduits, one either side, as the rectangle they occupy.
const PIPE_SIZE := Vector2(46.0, 92.0)
## How thick a floor is painted in 1-3, where the ground is floating islands.
const ISLAND_THICKNESS: float = 150.0

## Everything solid besides the floors and walls: the block rows and the two
## conduits. The same in every theme.
static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.assign(_cached("solid_decor", _make_solid_decor))
	return out

static func _make_solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _block_rows():
		out.append(Rect2(row["pos"], Vector2(BLOCK_CELL * float(row["count"]), BLOCK_CELL)))
	out.append_array(_obstacles())
	return out

## The obstacles standing on the floor, as rectangles, mirrored.
static func _obstacles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for o in layout().get("obstacles", []):
		for x in [float(o[0]), WIDTH - float(o[0])]:
			var top := top_at(x)
			out.append(Rect2(x - float(o[1]) * 0.5, top - float(o[2]), float(o[1]), float(o[2])))
	return out

## The block rows as {pos (top left), count}, mirrored.
static func _block_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in layout()["blocks"]:
		var width := BLOCK_CELL * float(b[2])
		out.append({"pos": Vector2(b[0], b[1]), "count": int(b[2])})
		out.append({"pos": Vector2(WIDTH - b[0] - width, b[1]), "count": int(b[2])})
	for b in layout()["centre"]:
		out.append({"pos": Vector2(b[0], b[1]), "count": int(b[2])})
	return out

## The slabs the terrain painter draws. 1-1 and 1-2 draw the collision floors
## and walls themselves, down to the ground's base. 1-3 is islands in the sky:
## each floor is drawn as an island of its own thickness, the block rows and
## conduits become small islands, and the walls are drawn as stacked columns
## (see decor) because an island painting has no body to stretch.
## The floors as painted: the two end floors are one stretch of ground across
## the join, so they are drawn as one piece reaching into the next lap rather
## than two pieces meeting at x=0 -- an island painting (1-3) has rounded
## ends, and two of them touching left a visible notch at the join.
static func painted_floors() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var first: Rect2 = Rect2()
	for f in floors():
		if is_equal_approx(f.position.x, LEFT):
			first = f
	for f in floors():
		if is_equal_approx(f.position.x, LEFT) and first.size.x > 0.0:
			continue
		if is_equal_approx(f.end.x, RIGHT) and first.size.x > 0.0 \
				and is_equal_approx(f.position.y, first.position.y):
			out.append(Rect2(f.position, Vector2(f.size.x + first.size.x, f.size.y)))
		else:
			out.append(f)
	return out

static func painted_slabs() -> Array[Rect2]:
	if theme in [Stage.Which.SEA, Stage.Which.SWAMP, Stage.Which.ROYAL_ARENA]:
		# The coast's and the marsh's floating rows are painted as that
		# stage's own ground: thin slabs of sand or mud, exactly their
		# collision rectangle.
		var slabs := painted_floors()
		for row in _block_rows():
			slabs.append(Rect2(row["pos"], Vector2(BLOCK_CELL * float(row["count"]), BLOCK_CELL)))
		return slabs
	if theme != Stage.Which.SKYWARD_RUINS:
		return painted_floors()
	# 1-3: each floor is an island of its own thickness. The rows are NOT
	# islands -- an island painting hangs far below its top, so a 46px row
	# drawn as one looked like a tall pillar you could walk through -- they
	# are ruin blocks, drawn exactly (decor).
	var out: Array[Rect2] = []
	for f in painted_floors():
		out.append(Rect2(f.position, Vector2(f.size.x, ISLAND_THICKNESS)))
	return out

## Scenery and solid pieces in the current theme's own vocabulary. Solid kinds
## are drawn exactly over solid_decor()'s rectangles; everything else is
## scenery, collides with nothing, and stands wholly on one floor (the probe
## checks every piece's footprint: no overhang off an edge, nothing that
## looks like a ledge where there is none).
static func decor() -> Array[Dictionary]:
	match theme:
		Stage.Which.ROYAL_ARENA:
			return _decor_royal()
		Stage.Which.HORROR:
			return _decor_horror()
		Stage.Which.SKYWARD_RUINS:
			return _decor_sky()
		Stage.Which.SEA:
			return _decor_sea()
		Stage.Which.SWAMP:
			return _decor_swamp()
		_:
			return _decor_greenfield()

## The width a piece of scenery covers on the ground, for the placement rule.
const FOOTPRINT := {
	"tree": 150.0, "signpost": 60.0, "flowers": 60.0, "fence": 200.0,
	"lantern": 30.0, "grave": 50.0, "banner": 50.0, "roots": 90.0, "puddle": 90.0,
	"cart": 120.0, "sea_palm": 120.0, "sea_grass": 110.0, "sea_seaweed": 100.0,
	"sea_boulder": 120.0, "sea_palm_small": 90.0, "swamp_tree": 196.0,
	"swamp_reeds": 90.0, "swamp_boulder": 120.0, "swamp_mushroom": 90.0,
	"sign": 70.0, "arch": 200.0, "grass": 80.0,
}

## A piece of scenery at x and its mirror twin, each standing on whatever
## floor is under it.
static func _pairs(out: Array[Dictionary], kind: String, x: float,
		extra: Dictionary = {}) -> void:
	var left := {"type": kind, "pos": Vector2(x, top_at(x))}
	left.merge(extra)
	var right := left.duplicate()
	right["pos"] = Vector2(WIDTH - x, top_at(WIDTH - x))
	right["flip"] = not bool(extra.get("flip", false))
	out.append(left)
	out.append(right)

## Something on the mirror line, standing on the middle floor.
static func _centre(out: Array[Dictionary], kind: String, half_width: float,
		extra: Dictionary = {}) -> void:
	var item := {"type": kind, "pos": Vector2(WIDTH * 0.5 - half_width, top_at(WIDTH * 0.5))}
	item.merge(extra)
	out.append(item)

static func _rows_as(out: Array[Dictionary], kind: String) -> void:
	for row in _block_rows():
		out.append({"type": kind, "pos": row["pos"], "count": row["count"],
			"cell": BLOCK_CELL})

static func _decor_greenfield() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_rows_as(out, "blocks")
	for r in _obstacles():
		out.append({"type": "conduit", "pos": Vector2(r.get_center().x, r.end.y), "size": r.size})
	_pairs(out, "tree", 90.0)
	_pairs(out, "signpost", 340.0)
	_pairs(out, "flowers", 700.0)
	_pairs(out, "flowers", 1130.0)
	_pairs(out, "flowers", 1520.0)
	return out

## 1-2: the rows as crumbling ruin blocks, the conduits as two-block stacks,
## and the village's graves, lanterns, banners and cart.
static func _decor_horror() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_rows_as(out, "ruin_blocks")
	for r in _obstacles():
		for k in range(int(round(r.size.y / BLOCK_CELL))):
			out.append({"type": "ruin_blocks", "count": 1, "cell": BLOCK_CELL,
				"pos": r.position + Vector2(0.0, BLOCK_CELL * k)})
	_pairs(out, "lantern", 40.0, {"scale": 0.8})
	_pairs(out, "grave", 230.0, {"scale": 0.72})
	_pairs(out, "banner", 760.0)
	_pairs(out, "roots", 1040.0)
	_pairs(out, "cart", 1330.0)
	return out

## The obstacles as footing art (1-4's rocks, 1-5's stones), fitted to their
## collision rectangle; anything the painter draws below the top is behind
## the ground.
static func _footings(out: Array[Dictionary], kind: String) -> void:
	for r in _obstacles():
		out.append({"type": kind, "rect": r, "pos": r.position + Vector2(r.size.x * 0.5, r.size.y)})

## 1-4: a beach and a dune above the sea. Sand floors, the obstacle as a sea
## rock, palms, dune grass and seaweed.
static func _decor_sea() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "sea_rock")
	_pairs(out, "sea_palm", 230.0, {"height": 260.0})
	_pairs(out, "sea_seaweed", 640.0)
	_pairs(out, "sea_palm_small", 780.0, {"height": 170.0})
	_pairs(out, "sea_grass", 1200.0)
	return out

## 1-5: stone and mud above poison. The obstacle as a swamp stone, dead
## trees, mushrooms and reeds -- placed clear of every row.
static func _decor_swamp() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "swamp_stone")
	_pairs(out, "swamp_tree", 130.0, {"height": 170.0})
	_pairs(out, "swamp_reeds", 835.0)
	_pairs(out, "swamp_mushroom", 1075.0)
	_pairs(out, "swamp_reeds", 1160.0)
	return out

## 1-3: islands (painted_slabs), the rows as grey stone blocks, trees and an
## arch. Not the ruins' signs, flower beds or grass: their sky paintings
## stand on little rock pillars, which read as ledges that are not there.
static func _decor_sky() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_rows_as(out, "blocks")
	_pairs(out, "tree", 250.0, {"size": Vector2(180, 210)})
	_centre(out, "arch", 0.0, {"size": Vector2(200, 200)})
	return out

# ------------------------------------------------------- gimmicks, enemies
## Everything below is a list of plain dictionaries, mirrored: what the scene
## builds (VersusLevelBuilder) and what the probes check. Each is placed away
## from the join, so nothing needs a copy a lap away.

static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for x in layout().get("springs", []):
		for at in [float(x), WIDTH - float(x)]:
			out.append(Vector2(at, top_at(at)))
	return out

## {centre, span, travel}: travel is mirrored, so the twins move apart and
## together rather than in step.
static func movers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in layout().get("movers", []):
		var span := Vector2(float(m[2]), 26.0)
		out.append({"centre": Vector2(m[0], m[1]), "span": span, "travel": Vector2(m[3], m[4])})
		out.append({"centre": Vector2(WIDTH - float(m[0]), m[1]), "span": span,
			"travel": Vector2(-float(m[3]), m[4])})
	return out

static func blinks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in layout().get("blinks", []):
		for x in [float(b[0]), WIDTH - float(b[0])]:
			out.append({"centre": Vector2(x, b[1]), "span": Vector2(float(b[2]), 26.0),
				"colour": int(b[3])})
	return out

## {centre, span} of each rising column of air.
static func updrafts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in layout().get("updrafts", []):
		var top := float(u[1])
		var bottom := float(u[2])
		for x in [float(u[0]), WIDTH - float(u[0])]:
			out.append({"centre": Vector2(x, (top + bottom) * 0.5),
				"span": Vector2(float(u[3]), bottom - top)})
	return out

## {centre, span, dir} of each conveyor, lying on the floor at its x.
static func belts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in layout().get("belts", []):
		for side in [1, -1]:
			var x := float(b[0]) if side == 1 else WIDTH - float(b[0])
			out.append({"centre": Vector2(x, float(b[1]) - 13.0),
				"span": Vector2(float(b[2]), 26.0), "dir": side})
	return out

## The enemies' patrols (VersusEnemies moves them): {kind, x0, x1, y, phase},
## the twin starting at the other end so the two halves are never in step.
static func enemy_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in layout().get("enemies", []):
		out.append({"kind": String(e[0]), "x0": float(e[1]), "x1": float(e[2]),
			"y": float(e[3]), "phase": 0.0})
		out.append({"kind": String(e[0]), "x0": WIDTH - float(e[2]),
			"x1": WIDTH - float(e[1]), "y": float(e[3]), "phase": 0.5})
	return out

## Kept for the callers that used to ask for a lap: the arena IS the whole map.
static func lap_ground() -> Array[Rect2]:
	return ground()

## Brought back inside the field. There is no lap any more, so this is a clamp
## rather than a wrap; the walls already stop a runner, so it only ever matters
## for a star knocked loose right against one.
static func wrap_x(x: float) -> float:
	return LEFT + fposmod(x - LEFT, WIDTH)

## No lap, so every point has exactly one image.
static func nearest_image(of: Vector2, seen_from: Vector2) -> Vector2:
	var dx := fposmod(of.x - seen_from.x + WIDTH * 0.5, WIDTH) - WIDTH * 0.5
	return Vector2(seen_from.x + dx, of.y)

## Where `x` sits across the field, as 0..1. For the map.
static func lap_fraction(x: float) -> float:
	return clampf((wrap_x(x) - MAP_RECT.position.x) / MAP_RECT.size.x, 0.0, 1.0)

## Where `y` sits in the map's height, as 0..1 (0 = top).
static func height_fraction(y: float) -> float:
	return clampf((y - MAP_RECT.position.y) / MAP_RECT.size.y, 0.0, 1.0)

static func kill_y() -> float:
	return Level01Data.KILL_Y

## Where each side starts, in side order: each layout's starts and their
## mirror twins. On a loop "fair" means evenly round it: the first pair (the
## 2v2 starts) is x=800 and x=2400, exactly half a lap apart, and every pair
## is mirrored, so no seat starts higher or nearer the middle than its twin.
static func start_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in layout()["starts"]:
		var x: float = p[0]
		out.append(Vector2(x, top_at(x) - 26.0))
		out.append(Vector2(WIDTH - x, top_at(WIDTH - x) - 26.0))
	return out

static func start_facing() -> Array[int]:
	var out: Array[int] = []
	for p in layout()["starts"]:
		out.append(int(p[1]))
		out.append(-int(p[1]))
	return out

## Where stars may appear. Every surface a runner can stand on, sampled about
## every 180px, 40px above it -- the floors, the steps and the tops of the
## block rows. The host draws from this list at random (VersusMatch
## ._free_point), adds a small sideways jitter, and refuses a point that is
## inside something solid or has no floor under it.
##
const STAR_PITCH: float = 180.0

static func coin_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(_cached("coin_points", _make_coin_points))
	return out

static func _make_coin_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var surfaces: Array[Rect2] = floors()
	surfaces.append_array(solid_decor())
	var solids := collision_rects()
	for s in surfaces:
		var from := s.position.x + 30.0
		var to := s.end.x - 30.0
		if to < from:
			continue
		var n := maxi(1, int(floor((to - from) / STAR_PITCH)) + 1)
		for k in range(n):
			var x := (from + to) * 0.5 if n == 1 \
				else from + (to - from) * float(k) / float(n - 1)
			var p := Vector2(x, s.position.y - 40.0)
			# With hills and rows over them, a point above one surface can be
			# inside the next one up; that is not a place for a star.
			var clear := true
			for r in solids:
				if r.intersects(Rect2(p - Vector2(12, 12), Vector2(24, 24))):
					clear = false
					break
			if clear:
				out.append(p)
	return out

## A runner who is out comes back at their own side's start. The field is
## small enough that this is a few seconds from anywhere, and it is the one
## place guaranteed not to be where the other team is standing.
static func respawn_for(team: int, _from: Vector2 = Vector2.ZERO) -> Vector2:
	var starts := start_positions()
	return starts[clampi(team, 0, starts.size() - 1)]

## Nothing extra: the arena has no enemies. Every machine would have had to
## simulate them independently (docs/versus-1v1-network-plan.md section 2),
## and in a 2v2 the other team is the only thing worth watching.
static func extra_enemies() -> Array[Dictionary]:
	return []

## Still in the match: above the kill plane. A loop has no sides to leave by.
static func in_bounds(at: Vector2) -> bool:
	return at.y < kill_y()

## The one authoritative collision representation of the arena. Scene runners,
## host star physics and remote star physics must all use it.
static func collision_rects(constructs: Array[Rect2] = []) -> Array[Rect2]:
	if constructs.is_empty():
		var out: Array[Rect2] = []
		out.assign(_cached("collision", _make_collision))
		return out
	return _make_collision(constructs)

static func _make_collision(constructs: Array[Rect2] = []) -> Array[Rect2]:
	var one: Array[Rect2] = ground()
	one.append_array(solid_decor())
	one.append_array(constructs)
	var out: Array[Rect2] = []
	for lap in LAPS:
		for r in one:
			var built := clip_to_built(Rect2(r.position + Vector2(WIDTH * float(lap), 0.0), r.size))
			if built.size.x > 0.0:
				out.append(built)
	return out

static func _decor_royal() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_pairs(out, "royal_red_flag", 240.0, {"height": 130.0})
	_pairs(out, "royal_royal_planter", 580.0, {"height": 62.0})
	_pairs(out, "royal_pillar_tall_left", 830.0, {"height": 100.0})
	_pairs(out, "royal_banner_small", 1145.0, {"height": 105.0})
	_pairs(out, "royal_crest_round", 1520.0, {"height": 60.0})
	return out
