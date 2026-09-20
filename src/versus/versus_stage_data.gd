class_name VersusStageData
## Where things go on 1-1, for the coin match.
##
## 1-1 itself is NOT changed and NOT cut down. The stage is built the way the
## cooperative game builds it -- LevelBuilder, the whole 16,700px of it, its
## enemies, its hazards, its checkpoints and its goal -- and this file only
## answers "where do the coins appear" and "where do the runners start".
##
## An earlier version carved a 2,100px slice out of section C and played inside
## it behind a fixed camera. It read well in a screenshot and it was not 1-1: a
## stage whose whole shape is a journey had been turned into a box, which is
## the thing the mode was asked NOT to be.
##
## Everything here is DERIVED from Level01Data rather than written down again,
## so a balance pass on 1-1 moves the coins with it.

# ------------------------------------------------------------------- the loop
## 1-1 is a one-way road: it starts on a plateau whose surface is at y=400 and
## ends 16,700px later on a ledge at y=180. For a mode about chasing each other
## it wants to be a CIRCUIT, and joining those two ends directly would be a
## 220px cliff -- there is no surface at 400 near the far end and none at 180
## near the near one, so no choice of seam makes them meet.
##
## So the ends are not forced together. A short flight of steps is added after
## the stage's last ledge, walking 180 down to 400 in four 55px steps, and the
## next lap's plateau begins exactly where those steps finish. The join is flat.
##
##     ... 15640→16700  surface 180   (1-1's last ledge)
##         16700→16875  surface 235   ┐
##         16875→17050  surface 290   │ the steps this mode adds
##         17050→17225  surface 345   │
##         17225→17400  surface 400   ┘
##         17400→...    surface 400     the next lap's plateau -- no step at all
##
## 55px a step: free going down, and well inside a jump (about 146px) going the
## other way, so the circuit is walkable in both directions. The probe measures
## that rather than taking it on trust.
##
## 1-1's own data is NOT modified. The steps exist only in this mode.
const LOOP_FROM: float = -1600.0
const LOOP_TO: float = 17400.0
const LOOP_SPAN: float = LOOP_TO - LOOP_FROM   ## 19000
const STEP_FROM: float = 16700.0
const STEP_COUNT: int = 4

## The steps. Drawn down to 1-1's own GROUND_BASE so they read as columns of
## earth like every other slab, rather than slabs floating in the sky.
static func connector() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var width := (LOOP_TO - STEP_FROM) / float(STEP_COUNT)
	var last_top := Level01Data.ground()[Level01Data.ground().size() - 1].position.y
	var plateau_top := Level01Data.ground()[0].position.y
	var rise := (plateau_top - last_top) / float(STEP_COUNT)
	for i in range(STEP_COUNT):
		var top := last_top + rise * float(i + 1)
		out.append(Rect2(STEP_FROM + width * float(i), top, width,
			Level01Data.GROUND_BASE - top))
	return out

## Everything solid in one lap: 1-1's own ground plus the steps.
static func lap_ground() -> Array[Rect2]:
	var out: Array[Rect2] = Stage.ground()
	out.append_array(connector())
	return out

## An x brought back into one lap.
static func wrap_x(x: float) -> float:
	return LOOP_FROM + fposmod(x - LOOP_FROM, LOOP_SPAN)

## `of`, expressed in whichever lap is nearest to `seen_from`.
##
## The whole reason a loop is more than a teleport. Two runners either side of
## the join are 20px apart, and every piece of geometry in the match -- who can
## reach a coin, whose strike lands, whether a floor is between them -- would
## otherwise measure that as 18,980. Everything that asks a distance asks this
## first.
static func nearest_image(of: Vector2, seen_from: Vector2) -> Vector2:
	# A DIFFERENCE, so the lap's origin does not come into it. The first
	# version routed this through wrap_x, which adds LOOP_FROM back in, and
	# every distance in the match came out shifted by 17,400px -- no strike
	# landed and no coin could be picked up.
	var dx := fposmod(of.x - seen_from.x + LOOP_SPAN * 0.5, LOOP_SPAN) \
		- LOOP_SPAN * 0.5
	return Vector2(seen_from.x + dx, of.y)

## Where `of` sits around the lap, as 0..1. For the map.
static func lap_fraction(x: float) -> float:
	return (wrap_x(x) - LOOP_FROM) / LOOP_SPAN

static func kill_y() -> float:
	return Stage.kill_y()

## Where the two runners begin: 1-1's own start, a little apart so they are not
## inside each other on the first frame. Both at the same place on purpose --
## the whole stage is ahead of both of them and neither gets a head start.
static func start_positions() -> Array[Vector2]:
	var at := Stage.start()
	return [at + Vector2(-26.0, 0.0), at + Vector2(26.0, 0.0)]

static func start_facing() -> Array[int]:
	return [1, 1]

## Coins, spread the length of the stage, one above each slab of ground.
##
## Generated from 1-1's own slabs rather than listed, so they are always ON
## something and always wherever the stage's floor currently is. A wide slab
## gets two, which keeps the long runs from being empty without putting a coin
## every few steps.
static func coin_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for slab in Level01Data.ground():
		# The start plateau runs a long way off-screen to the left; only the
		# part anybody plays on is worth putting a coin on.
		var from := maxf(slab.position.x, 0.0)
		var to := slab.position.x + slab.size.x
		if to - from < 60.0:
			continue
		var top := slab.position.y - 40.0
		if to - from > 420.0:
			out.append(Vector2(from + (to - from) * 0.33, top))
			out.append(Vector2(from + (to - from) * 0.67, top))
		else:
			out.append(Vector2((from + to) * 0.5, top))
	return out

## Coming back after a death: the last checkpoint the runner reached, which is
## 1-1's own answer to the same question. Sending them to the start of a
## sixteen-thousand-pixel stage for one mistake is not a rule, it is a forfeit.
static func respawn_for(_team: int, from: Vector2 = Vector2.ZERO) -> Vector2:
	var best := Stage.start()
	for c in Stage.checkpoints():
		if c.x <= from.x and c.x > best.x:
			best = c
	return best

## Still in the match.
##
## Y only. A loop has no left and no right edge to fall off -- running far
## enough in either direction brings you back -- so the only way out is down,
## which is 1-1's own kill plane.
static func in_bounds(at: Vector2) -> bool:
	return at.y < kill_y()

## The one authoritative collision representation of 1-1's closed circuit.
## Scene runners, host coin physics and remote coin physics must all use it.
static func collision_rects(constructs: Array[Rect2] = []) -> Array[Rect2]:
	Stage.use(Stage.Which.GREENFIELD)
	var one: Array[Rect2] = lap_ground()
	one.append_array(Stage.solid_decor())
	var out: Array[Rect2] = []
	for lap in [-1, 0, 1]:
		var shift := VersusStageData.LOOP_SPAN * float(lap)
		for r in one:
			out.append(Rect2(r.position + Vector2(shift, 0.0), r.size))
	out.append_array(constructs)
	return out
