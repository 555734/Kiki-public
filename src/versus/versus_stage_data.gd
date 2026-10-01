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
const MAP_RECT := Rect2(LEFT, 40.0, WIDTH, 420.0)
## The lowest ground any stage has: the low ground of the original flat
## arena, kept for the few things measured against "the floor".
const FLOOR_TOP: float = 400.0
const BLOCK_CELL: float = 46.0

## Each stage has its own ground (docs/versus-2v2-stars.md). Every layout is
## the LEFT half, x in [0, 1600]; the right half is its mirror, so the two
## ends meet at x=0/3200 at one height and nobody's side is better.
##   floors: [x0, x1, top]      -- solid ground drawn down to GROUND_BASE
##   blocks: [x, top, count]    -- rows of blocks (mirrored)
##   centre: [x, top, count]    -- rows on the mirror line, listed once
##   pipes:  [x]                -- a conduit standing on the floor at x
##   starts: [x, facing]        -- 2v2 uses the first two (half a lap apart)
## Rules every layout keeps (test/versus_probe.gd checks them, and a runner
## driven over every step and pit proved them): a step is <= 80px, a pit is
## <= 140px with its far side no more than 40px higher, every block row is
## one jump above what is under it and keeps 80px clear of the edges of the
## floor beneath -- a row over a take-off is a ceiling the jump hits.
const LAYOUTS := {
	# 1-1: two rolling hills. Up from the low ground to a hilltop with a row
	# over it, down into a valley, across a small pit to the middle hill.
	Stage.Which.GREENFIELD: {
		"floors": [
			[0.0, 380.0, 400.0], [380.0, 620.0, 330.0], [620.0, 900.0, 250.0],
			[900.0, 1080.0, 330.0], [1080.0, 1220.0, 400.0], [1360.0, 1600.0, 370.0],
		],
		"blocks": [[160.0, 290.0, 3], [714.0, 140.0, 2]],
		"centre": [[1554.0, 260.0, 2]],
		"pipes": [1000.0],
		"starts": [[800.0, 1], [200.0, 1], [1450.0, 1], [500.0, 1]],
	},
	# 1-2: a village of cliffs. Up two ledges to a high plateau, then down
	# across two pits to the square in the middle, under a roof of ruin blocks.
	Stage.Which.HORROR: {
		"floors": [
			[0.0, 300.0, 400.0], [300.0, 500.0, 320.0], [500.0, 820.0, 240.0],
			[960.0, 1120.0, 270.0], [1260.0, 1600.0, 300.0],
		],
		"blocks": [[100.0, 290.0, 2], [610.0, 130.0, 2], [1380.0, 190.0, 3]],
		"centre": [[1531.0, 190.0, 3]],
		"pipes": [420.0],
		"starts": [[800.0, 1], [150.0, 1], [1300.0, 1], [400.0, 1]],
	},
	# 1-3: islands in the sky, higher towards the middle, with a ruin row on
	# the first and a high one over the middle. Everything between is a fall.
	Stage.Which.SKYWARD_RUINS: {
		"floors": [
			[0.0, 360.0, 380.0], [500.0, 700.0, 345.0], [700.0, 860.0, 280.0],
			[1000.0, 1180.0, 250.0], [1320.0, 1600.0, 230.0],
		],
		"blocks": [[140.0, 270.0, 2]],
		"centre": [[1531.0, 120.0, 3]],
		"pipes": [],
		"starts": [[800.0, 1], [150.0, 1], [1450.0, 1], [1080.0, 1]],
	},
	# 1-4: a beach and a big dune. Low sand by the sea at the join, a pit
	# onto the water, then the dune climbs to its peak in the middle.
	Stage.Which.SEA: {
		"floors": [
			[0.0, 300.0, 410.0], [440.0, 700.0, 400.0], [700.0, 900.0, 330.0],
			[900.0, 1100.0, 260.0], [1100.0, 1300.0, 210.0], [1300.0, 1600.0, 190.0],
		],
		"blocks": [[80.0, 300.0, 2], [520.0, 290.0, 2]],
		"centre": [[1554.0, 80.0, 2]],
		"pipes": [1000.0],
		"starts": [[800.0, 1], [150.0, 1], [1450.0, 1], [560.0, 1]],
	},
	# 1-5: mud and rock over poison. Low mud, rocks rising out of it, three
	# pits, and a high rock either side of the middle.
	Stage.Which.SWAMP: {
		"floors": [
			[0.0, 260.0, 400.0], [400.0, 560.0, 370.0], [560.0, 680.0, 300.0],
			[680.0, 880.0, 370.0], [1020.0, 1160.0, 340.0], [1160.0, 1300.0, 270.0],
			[1440.0, 1600.0, 250.0],
		],
		"blocks": [[60.0, 290.0, 2]],
		"centre": [[1554.0, 140.0, 2]],
		"pipes": [740.0],
		"starts": [[800.0, 1], [120.0, 1], [1500.0, 1], [1080.0, 1]],
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
	return Rect2(x0, top, x1 - x0, GROUND_BASE - top)

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
	for x in _pipe_xs():
		out.append(_pipe_rect(x))
	return out

static func _pipe_xs() -> Array[float]:
	var out: Array[float] = []
	for x in layout()["pipes"]:
		out.append(float(x))
		out.append(WIDTH - float(x))
	return out

static func _pipe_rect(x: float) -> Rect2:
	var top := top_at(x)
	return Rect2(x - PIPE_SIZE.x * 0.5, top - PIPE_SIZE.y, PIPE_SIZE.x, PIPE_SIZE.y)

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

static func _decor_greenfield() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _block_rows():
		out.append({"type": "blocks", "pos": row["pos"], "count": row["count"],
			"cell": BLOCK_CELL})
	for x in _pipe_xs():
		out.append({"type": "conduit", "pos": Vector2(x, top_at(x)), "size": PIPE_SIZE})
	_pairs(out, "tree", 60.0)
	_pairs(out, "signpost", 300.0)
	_pairs(out, "flowers", 760.0)
	_pairs(out, "flowers", 1140.0)
	_centre(out, "fence", 100.0, {"width": 200.0})
	return out

## 1-2: the rows as crumbling ruin blocks, the conduits as two-block stacks,
## and the village's graves, lanterns, banners and cart.
static func _decor_horror() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _block_rows():
		out.append({"type": "ruin_blocks", "pos": row["pos"], "count": row["count"],
			"cell": BLOCK_CELL})
	for x in _pipe_xs():
		var r := _pipe_rect(x)
		for k in range(2):
			out.append({"type": "ruin_blocks", "count": 1, "cell": BLOCK_CELL,
				"pos": r.position + Vector2(0.0, BLOCK_CELL * k)})
	_pairs(out, "lantern", 70.0, {"scale": 0.8})
	_pairs(out, "grave", 220.0, {"scale": 0.72})
	_pairs(out, "banner", 700.0)
	_pairs(out, "roots", 1040.0)
	_pairs(out, "puddle", 1300.0)
	_pairs(out, "cart", 1450.0)
	_centre(out, "fence", 100.0, {"width": 200.0})
	return out

## The conduits as footing art (1-4's rocks, 1-5's stones), which the stages
## draw standing down into the water -- right for something on the ground.
static func _footings(out: Array[Dictionary], kind: String) -> void:
	for x in _pipe_xs():
		var r := _pipe_rect(x)
		out.append({"type": kind, "rect": r, "pos": r.position + Vector2(r.size.x * 0.5, r.size.y)})

## 1-4: a beach and a dune above the sea. Sand floors, the rows and conduits
## as sea rocks, palms, dune grass, boulders and seaweed.
static func _decor_sea() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "sea_rock")
	_pairs(out, "sea_palm", 70.0, {"height": 280.0})
	_pairs(out, "sea_grass", 240.0)
	_pairs(out, "sea_seaweed", 520.0)
	_pairs(out, "sea_boulder", 620.0, {"width": 120.0})
	_pairs(out, "sea_palm_small", 800.0, {"height": 180.0})
	_pairs(out, "sea_grass", 1450.0)
	return out

## 1-5: mud and rock above poison. The rows and conduits as swamp stones,
## dead trees, mushrooms, reeds and boulders.
static func _decor_swamp() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_footings(out, "swamp_stone")
	_pairs(out, "swamp_tree", 80.0, {"height": 260.0})
	_pairs(out, "swamp_reeds", 200.0)
	_pairs(out, "swamp_boulder", 830.0)
	_pairs(out, "swamp_mushroom", 1230.0)
	_pairs(out, "swamp_reeds", 1500.0)
	return out

## 1-3: islands (painted_slabs) with the ruins' trees, bushes, columns and an
## arch.
static func _decor_sky() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_pairs(out, "tree", 70.0, {"size": Vector2(200, 230)})
	_pairs(out, "sign", 260.0, {"size": Vector2(80, 90)})
	_pairs(out, "bush", 560.0, {"size": Vector2(80, 60)})
	_pairs(out, "tree_tall", 1100.0, {"size": Vector2(100, 200)})
	_pairs(out, "flowers", 1400.0, {"size": Vector2(70, 50)})
	_centre(out, "arch", 0.0, {"size": Vector2(220, 220)})
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
