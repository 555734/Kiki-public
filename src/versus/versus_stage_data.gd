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
## The end walls. Tall enough that no jump, wall kick or guardian platform gets
## a runner over them: a runner outside the field would be a runner nobody can
## reach, holding stars nobody can take back.
const WALL_THICKNESS: float = 360.0
const WALL_TOP: float = -1400.0
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

## Solid ground, the walls included.
static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(Rect2(LEFT - WALL_THICKNESS, WALL_TOP, WALL_THICKNESS,
		GROUND_BASE - WALL_TOP))
	for f in _LEFT_FLOORS:
		out.append(_slab(f[0], f[1], f[2]))
	for i in range(_LEFT_FLOORS.size() - 1, -1, -1):
		var f: Array = _LEFT_FLOORS[i]
		var m := _mirror_span(f[0], f[1])
		out.append(_slab(m.x, m.y, f[2]))
	out.append(Rect2(RIGHT, WALL_TOP, WALL_THICKNESS, GROUND_BASE - WALL_TOP))
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
	Stage.Which.SKYWARD_RUINS]
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
static func painted_slabs() -> Array[Rect2]:
	if theme != Stage.Which.SKYWARD_RUINS:
		return ground()
	var out: Array[Rect2] = []
	for f in floors():
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

## 1-3: islands (painted_slabs) with the ruins' trees, bushes, columns and an
## arch; the walls are columns stacked to the top of the field.
static func _decor_sky() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_pairs(out, "tree", 70.0, FLOOR_TOP, {"size": Vector2(200, 230)})
	_pairs(out, "sign", 260.0, FLOOR_TOP, {"size": Vector2(80, 90)})
	_pairs(out, "bush", 960.0, STEP_TOP, {"size": Vector2(80, 60)})
	_pairs(out, "flowers", 1400.0, FLOOR_TOP, {"size": Vector2(70, 50)})
	_pairs(out, "tree_tall", 1100.0, STEP_TOP, {"size": Vector2(100, 200)})
	out.append({"type": "arch", "pos": Vector2(WIDTH * 0.5, FLOOR_TOP),
		"size": Vector2(220, 220)})
	var column := Vector2(80.0, 190.0)
	var y := GROUND_BASE
	while y > WALL_TOP:
		out.append({"type": "ruin_column", "pos": Vector2(LEFT - column.x * 0.5, y),
			"size": column})
		out.append({"type": "ruin_column", "pos": Vector2(RIGHT + column.x * 0.5, y),
			"size": column})
		y -= column.y - 10.0
	return out

## Kept for the callers that used to ask for a lap: the arena IS the whole map.
static func lap_ground() -> Array[Rect2]:
	return ground()

## Brought back inside the field. There is no lap any more, so this is a clamp
## rather than a wrap; the walls already stop a runner, so it only ever matters
## for a star knocked loose right against one.
static func wrap_x(x: float) -> float:
	return clampf(x, LEFT + 12.0, RIGHT - 12.0)

## No lap, so every point has exactly one image.
static func nearest_image(of: Vector2, _seen_from: Vector2) -> Vector2:
	return of

## Where `x` sits across the field, as 0..1. For the map.
static func lap_fraction(x: float) -> float:
	return clampf((x - MAP_RECT.position.x) / MAP_RECT.size.x, 0.0, 1.0)

## Where `y` sits in the map's height, as 0..1 (0 = top).
static func height_fraction(y: float) -> float:
	return clampf((y - MAP_RECT.position.y) / MAP_RECT.size.y, 0.0, 1.0)

static func kill_y() -> float:
	return Level01Data.KILL_Y

## Where each side starts, in side order: team A / B (or players 1 and 2) at
## the two ends, then players 3-8 in mirrored pairs -- on the steps, beside
## the conduits, and either side of the middle. Every left start has its
## mirror image on the right, so no seat is nearer the middle than its twin.
## The 2v2 and 1v1 modes only ever use the first two.
const _LEFT_STARTS := [
	[160.0, FLOOR_TOP],
	[960.0, STEP_TOP],
	[440.0, FLOOR_TOP],
	[1440.0, FLOOR_TOP],
]

static func start_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in _LEFT_STARTS:
		out.append(Vector2(p[0], p[1] - 26.0))
		out.append(Vector2(WIDTH - p[0], p[1] - 26.0))
	return out

## Left starts face right, right starts face left: towards the middle.
static func start_facing() -> Array[int]:
	var out: Array[int] = []
	for i in range(_LEFT_STARTS.size()):
		out.append(1)
		out.append(-1)
	return out

## Where stars may appear. Every surface a runner can stand on, sampled about
## every 180px, 40px above it -- the floors, the steps and the tops of the
## block rows. The host draws from this list at random (VersusMatch
## ._free_point), adds a small sideways jitter, and refuses a point that is
## inside something solid or has no floor under it.
##
## The strip right in front of each team's start is left out, so a star never
## appears in one team's lap; the first steps of a match are a race to the
## middle, not a gift.
const STAR_HOME_CLEAR: float = 360.0
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
			if x < LEFT + STAR_HOME_CLEAR or x > RIGHT - STAR_HOME_CLEAR:
				continue
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

## Still in the match: above the kill plane and between the walls.
static func in_bounds(at: Vector2) -> bool:
	return at.y < kill_y() and at.x > LEFT - 4.0 and at.x < RIGHT + 4.0

## The one authoritative collision representation of the arena. Scene runners,
## host star physics and remote star physics must all use it.
static func collision_rects(constructs: Array[Rect2] = []) -> Array[Rect2]:
	var out: Array[Rect2] = ground()
	out.append_array(solid_decor())
	out.append_array(constructs)
	return out
