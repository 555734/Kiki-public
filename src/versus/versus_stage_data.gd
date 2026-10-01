class_name VersusStageData
## The 2v2 star arena: a small, left-right symmetric field built from 1-1's own
## pieces -- its grass slabs, block rows, conduits, trees and flowers -- rather
## than a lap of 1-1 itself.
##
## Small on purpose. The circuit it replaces was 13,000px around, and on a phone
## the other team was a dot on a bar for most of a match. This is about three
## screens wide, walled at both ends, so the other runner is usually on screen
## and never more than one short run away; the HUD's full-map view and the edge
## arrows cover the rest (docs/versus-2v2-stars.md).
##
## Co-op Level01Data is unchanged. Everything the match measures reads these
## functions, so the scene, the host's star physics and a client's collision
## world are all the same list.
##
## Y is positive downwards and every figure below is the TOP of a surface.
## Mirror rule: a piece at [x0, x1] on the left has a twin at
## [WIDTH - x1, WIDTH - x0] on the right. `test/versus_arena_probe.gd` checks it.

## The playable floor runs from x=0 to x=WIDTH; walls stand beyond both ends.
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
## Tops of the three floor heights, and the base 1-1 draws every slab down to.
const FLOOR_TOP: float = 400.0
const STEP_TOP: float = 330.0
const GROUND_BASE: float = Level01Data.GROUND_BASE
## The region the HUD's map shows. Covers every surface and a jump above the
## highest block, and nothing of the empty sky or the ground's skirt.
const MAP_RECT := Rect2(LEFT, 40.0, WIDTH, 420.0)

## Floors as (x0, x1, top), left half only; the right half is mirrored.
## Two small pits (140px) between the steps and the middle: a hop anyone can
## make, and a place a hit can knock you into -- which costs every star you
## were carrying.
const _LEFT_FLOORS := [
	[0.0, 760.0, FLOOR_TOP],       # home ground, team A starts here
	[760.0, 1160.0, STEP_TOP],     # a 70px step up
	[1300.0, 1600.0, FLOOR_TOP],   # the middle, left half (joined to its twin)
]

## Rows of 1-1's ?/brick blocks, solid, as (x, top, count). About 110px above
## what is under them: one held jump, no platform needed.
const _LEFT_BLOCKS := [
	[330.0, 290.0, 3],
	[620.0, 180.0, 2],
	[880.0, 222.0, 2],
]
## The centre stack sits on the mirror line and is listed once.
const _CENTRE_BLOCKS := [
	[1531.0, 290.0, 3],
	[1554.0, 180.0, 2],
]
const BLOCK_CELL: float = 46.0

static func _mirror_span(x0: float, x1: float) -> Vector2:
	return Vector2(WIDTH - x1, WIDTH - x0)

## Solid ground, one lap of it.
static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for f in _LEFT_FLOORS:
		out.append(_slab(f[0], f[1], f[2]))
	for i in range(_LEFT_FLOORS.size() - 1, -1, -1):
		var f: Array = _LEFT_FLOORS[i]
		var m := _mirror_span(f[0], f[1])
		out.append(_slab(m.x, m.y, f[2]))
	return out

static func _slab(x0: float, x1: float, top: float) -> Rect2:
	return Rect2(x0, top, x1 - x0, GROUND_BASE - top)

## The floors a runner stands on, without the walls.
static func floors() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in ground():
		if r.position.x >= LEFT and r.end.x <= RIGHT:
			out.append(r)
	return out

# ------------------------------------------------------------------- themes
## Which stage's art the arena is painted in. The SHAPE never changes with it:
## every rectangle anything collides with, every star point and every start
## is the same in all three, so no stage is better for anybody and the wire
## never has to carry geometry. Only what is drawn differs.
const THEMES: Array[int] = [Stage.Which.GREENFIELD, Stage.Which.HORROR,
	Stage.Which.SKYWARD_RUINS, Stage.Which.SEA, Stage.Which.SWAMP]
static var theme: int = Stage.Which.GREENFIELD

## Paint the arena as `which` from now on. Also points Stage at it, which is
## what the sky, the terrain painter and the 3D view all read.
static func use_theme(which: int) -> void:
	theme = which if THEMES.has(which) else Stage.Which.GREENFIELD
	Stage.use(theme)

static func theme_label(which: int) -> String:
	match which:
		Stage.Which.HORROR: return "1-2 うつろな村外れ"
		Stage.Which.SKYWARD_RUINS: return "1-3 天空の遺跡"
		Stage.Which.SEA: return "1-4 陽光の海岸"
		Stage.Which.SWAMP: return "1-5 毒の沼地"
		_: return "1-1 みどりの草原"

## The conduits, one either side, as the rectangle they occupy.
const PIPE_SIZE := Vector2(46.0, 92.0)
const PIPE_X: float = 560.0
## How thick a floor is painted in 1-3, where the ground is floating islands.
const ISLAND_THICKNESS: float = 150.0

## Everything solid besides the floors and walls: the block rows and the two
## conduits. The same in every theme.
static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for row in _block_rows():
		out.append(Rect2(row["pos"], Vector2(BLOCK_CELL * float(row["count"]), BLOCK_CELL)))
	for x in [PIPE_X, WIDTH - PIPE_X]:
		out.append(Rect2(x - PIPE_SIZE.x * 0.5, FLOOR_TOP - PIPE_SIZE.y,
			PIPE_SIZE.x, PIPE_SIZE.y))
	return out

## The block rows as {pos (top left), count}, mirrored.
static func _block_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in _LEFT_BLOCKS:
		var width := BLOCK_CELL * float(b[2])
		out.append({"pos": Vector2(b[0], b[1]), "count": int(b[2])})
		out.append({"pos": Vector2(WIDTH - b[0] - width, b[1]), "count": int(b[2])})
	for b in _CENTRE_BLOCKS:
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
	if theme == Stage.Which.SEA or theme == Stage.Which.SWAMP:
		# The coast's rocks and the marsh's stones are drawn standing in the
		# water, which is right for the conduits (they stand on the ground)
		# and wrong for a floating row a runner can walk under. The rows are
		# painted as that stage's own ground instead: thin slabs of sand or
		# mud, exactly their collision rectangle.
		var slabs := painted_floors()
		for row in _block_rows():
			slabs.append(Rect2(row["pos"], Vector2(BLOCK_CELL * float(row["count"]), BLOCK_CELL)))
		return slabs
	if theme != Stage.Which.SKYWARD_RUINS:
		return painted_floors()
	var out: Array[Rect2] = []
	for f in painted_floors():
		out.append(Rect2(f.position, Vector2(f.size.x, ISLAND_THICKNESS)))
	out.append_array(solid_decor())
	return out

## Scenery and solid pieces in the current theme's own vocabulary. Solid kinds
## are drawn exactly over solid_decor()'s rectangles; everything else is
## scenery and collides with nothing.
static func decor() -> Array[Dictionary]:
	match theme:
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

static func _pairs(out: Array[Dictionary], kind: String, x: float, top: float,
		extra: Dictionary = {}) -> void:
	var left := {"type": kind, "pos": Vector2(x, top)}
	left.merge(extra)
	var right := left.duplicate()
	right["pos"] = Vector2(WIDTH - x, top)
	right["flip"] = not bool(extra.get("flip", false))
	out.append(left)
	out.append(right)

static func _decor_greenfield() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _block_rows():
		out.append({"type": "blocks", "pos": row["pos"], "count": row["count"],
			"cell": BLOCK_CELL})
	for x in [PIPE_X, WIDTH - PIPE_X]:
		out.append({"type": "conduit", "pos": Vector2(x, FLOOR_TOP), "size": PIPE_SIZE})
	_pairs(out, "tree", 60.0, FLOOR_TOP)
	_pairs(out, "signpost", 260.0, FLOOR_TOP)
	_pairs(out, "flowers", 960.0, STEP_TOP)
	_pairs(out, "flowers", 1400.0, FLOOR_TOP)
	out.append({"type": "fence", "pos": Vector2(WIDTH * 0.5 - 100.0, FLOOR_TOP),
		"width": 200.0})
	return out

## 1-2: the same rows as crumbling ruin blocks, the conduits as two-block
## stacks, and the village's graves, lanterns, banners and cart.
static func _decor_horror() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _block_rows():
		out.append({"type": "ruin_blocks", "pos": row["pos"], "count": row["count"],
			"cell": BLOCK_CELL})
	for x in [PIPE_X, WIDTH - PIPE_X]:
		for k in range(2):
			out.append({"type": "ruin_blocks", "count": 1, "cell": BLOCK_CELL,
				"pos": Vector2(x - PIPE_SIZE.x * 0.5, FLOOR_TOP - PIPE_SIZE.y + BLOCK_CELL * k)})
	_pairs(out, "lantern", 70.0, FLOOR_TOP, {"scale": 0.8})
	_pairs(out, "grave", 250.0, FLOOR_TOP, {"scale": 0.72})
	_pairs(out, "banner", 800.0, STEP_TOP)
	_pairs(out, "roots", 1150.0, STEP_TOP)
	_pairs(out, "puddle", 700.0, FLOOR_TOP)
	_pairs(out, "cart", 1380.0, FLOOR_TOP)
	out.append({"type": "fence", "pos": Vector2(WIDTH * 0.5 - 100.0, FLOOR_TOP),
		"width": 200.0})
	return out

## The conduits as footing art (1-4's rocks, 1-5's stones), which the stages
## draw standing down into the water -- right for something on the ground.
static func _footings(out: Array[Dictionary], kind: String) -> void:
	for x in [PIPE_X, WIDTH - PIPE_X]:
		var r := Rect2(x - PIPE_SIZE.x * 0.5, FLOOR_TOP - PIPE_SIZE.y, PIPE_SIZE.x, PIPE_SIZE.y)
		out.append({"type": kind, "rect": r, "pos": r.position + Vector2(r.size.x * 0.5, r.size.y)})

## 1-4: a beach above the sea. Sand floors, the rows and conduits as sea
## rocks, palms, dune grass, boulders and seaweed; the pits open onto water.
static func _decor_sea() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "sea_rock")
	_pairs(out, "sea_palm", 70.0, FLOOR_TOP, {"height": 280.0})
	_pairs(out, "sea_grass", 260.0, FLOOR_TOP)
	_pairs(out, "sea_palm_small", 1000.0, STEP_TOP, {"height": 180.0})
	_pairs(out, "sea_boulder", 720.0, FLOOR_TOP, {"width": 120.0})
	_pairs(out, "sea_seaweed", 1420.0, FLOOR_TOP)
	return out

## 1-5: stone and mud above poison. The rows and conduits as swamp stones,
## dead trees, mushrooms, reeds and boulders; the pits open onto the marsh.
static func _decor_swamp() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "swamp_stone")
	_pairs(out, "swamp_tree", 80.0, FLOOR_TOP, {"height": 260.0})
	_pairs(out, "swamp_reeds", 270.0, FLOOR_TOP)
	_pairs(out, "swamp_mushroom", 1000.0, STEP_TOP)
	_pairs(out, "swamp_boulder", 720.0, FLOOR_TOP)
	_pairs(out, "swamp_reeds", 1430.0, FLOOR_TOP)
	return out

## 1-3: islands (painted_slabs) with the ruins' trees, bushes, columns and an
## arch.
static func _decor_sky() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_pairs(out, "tree", 70.0, FLOOR_TOP, {"size": Vector2(200, 230)})
	_pairs(out, "sign", 260.0, FLOOR_TOP, {"size": Vector2(80, 90)})
	_pairs(out, "bush", 960.0, STEP_TOP, {"size": Vector2(80, 60)})
	_pairs(out, "flowers", 1400.0, FLOOR_TOP, {"size": Vector2(70, 50)})
	_pairs(out, "tree_tall", 1100.0, STEP_TOP, {"size": Vector2(100, 200)})
	out.append({"type": "arch", "pos": Vector2(WIDTH * 0.5, FLOOR_TOP),
		"size": Vector2(220, 220)})
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

## Where each side starts, in side order. On a loop "fair" means evenly
## round it: the two 2v2 starts are exactly half a lap apart (x=800 and 2400,
## both on the steps), and the other six free-for-all starts are mirrored
## pairs on floor, no two closer than 280px either way round.
const _STARTS := [
	[800.0, STEP_TOP, 1], [2400.0, STEP_TOP, -1],
	[200.0, FLOOR_TOP, 1], [3000.0, FLOOR_TOP, -1],
	[1400.0, FLOOR_TOP, 1], [1800.0, FLOOR_TOP, -1],
	[460.0, FLOOR_TOP, 1], [2740.0, FLOOR_TOP, -1],
]

static func start_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in _STARTS:
		out.append(Vector2(p[0], p[1] - 26.0))
	return out

static func start_facing() -> Array[int]:
	var out: Array[int] = []
	for p in _STARTS:
		out.append(int(p[2]))
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
	var surfaces: Array[Rect2] = floors()
	surfaces.append_array(solid_decor())
	for s in surfaces:
		var from := s.position.x + 30.0
		var to := s.end.x - 30.0
		if to < from:
			continue
		var n := maxi(1, int(floor((to - from) / STAR_PITCH)) + 1)
		for k in range(n):
			var x := (from + to) * 0.5 if n == 1 \
				else from + (to - from) * float(k) / float(n - 1)
			out.append(Vector2(x, s.position.y - 40.0))
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
	var one: Array[Rect2] = ground()
	one.append_array(solid_decor())
	one.append_array(constructs)
	var out: Array[Rect2] = []
	for lap in LAPS:
		for r in one:
			out.append(Rect2(r.position + Vector2(WIDTH * float(lap), 0.0), r.size))
	return out
