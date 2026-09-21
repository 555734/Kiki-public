class_name VersusStageData
## The versus circuit uses sections A-D of 1-1, followed by a return stair.
## Co-op Level01Data is unchanged. All versus geometry reads these bounds.

const LOOP_FROM: float = -1600.0
const LOOP_TO: float = 11400.0
const LOOP_SPAN: float = LOOP_TO - LOOP_FROM   ## 13000
const STEP_FROM: float = 10700.0
const STEP_COUNT: int = 4

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in Level01Data.ground():
		if rect.position.x >= STEP_FROM:
			continue
		rect.size.x = minf(rect.end.x, STEP_FROM) - rect.position.x
		out.append(rect)
	return out

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in Stage.solid_decor():
		if rect.end.x <= STEP_FROM:
			out.append(rect)
	return out

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in Level01Data.decor():
		if Vector2(item["pos"]).x < STEP_FROM:
			out.append(item)
	return out

## The steps. Drawn down to 1-1's own GROUND_BASE so they read as columns of
## earth like every other slab, rather than slabs floating in the sky.
static func connector() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var width := (LOOP_TO - STEP_FROM) / float(STEP_COUNT)
	var slabs := ground()
	var last_top := slabs[slabs.size() - 1].position.y
	var plateau_top := Level01Data.ground()[0].position.y
	var rise := (plateau_top - last_top) / float(STEP_COUNT)
	for i in range(STEP_COUNT):
		var top := last_top + rise * float(i + 1)
		out.append(Rect2(STEP_FROM + width * float(i), top, width,
			Level01Data.GROUND_BASE - top))
	return out

## Everything solid in one lap: 1-1's own ground plus the steps.
static func lap_ground() -> Array[Rect2]:
	var out: Array[Rect2] = ground()
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
	for slab in ground():
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
		if c.x < STEP_FROM and c.x <= from.x and c.x > best.x:
			best = c
	return best

# ----------------------------------------------------------------- the enemies
## Extra enemies, for the versus circuit only.
##
## 1-1's own twenty are spread across a stage you walk through once. Going round
## it over and over leaves long quiet stretches, so this tops the thin parts up.
## 1-1 itself is NOT touched: Level01Data.enemies() is what the cooperative game
## still gets, and the test that measures 1-1's arcs never sees these.
##
## Only WALKERS and FLYERS. Not turrets, and that is not an aesthetic choice:
## Turret keeps a reference to "the runner" and uses it as a range gate
## (turret.gd:30-33), so it fires when THAT runner is near. With two runners on
## two machines, each machine binds a different one, and the same turret would
## fire on one screen and not the other. Walker and Flyer hold no such reference
## -- they patrol geometry and nothing else -- so every machine builds the same
## enemies doing the same thing. 1-1's existing turrets already have this
## wrinkle; there is no reason to add more of it.
##
## Placed by MEASURING, not by eye: the lap is cut into buckets, the ones 1-1
## left thin are topped up, and every walker is seated on the floor that is
## actually there.
const EXTRA_BUCKET: float = 1500.0
const EXTRA_PER_BUCKET: int = 3
const EXTRA_MAX: int = 12
## Clear of the start, and clear of the join: a runner crossing the seam should
## be thinking about nothing else.
const EXTRA_CLEAR_START: float = 400.0
## How far short of the connecting steps the last enemy may stand. DERIVED from
## STEP_FROM rather than written down: the circuit has already been shortened
## once (17,400 to 11,400), and the hard-coded version quietly went on placing
## enemies in a stretch of 1-1 the circuit no longer uses -- where
## VersusLevelBuilder then threw them away.
const EXTRA_SEAM_MARGIN: float = 300.0
## How far either side of the ideal spot to look for floor, and in what steps.
## Two of the ideal spots on this circuit sit over 1-1's gaps; without this the
## two stretches they were meant to fill stay exactly as thin as they were.
const EXTRA_NUDGE: float = 600.0
const EXTRA_NUDGE_STEP: float = 100.0
## No new enemy stands closer than this to one already there. A nudged walker
## has to be allowed to move without ending up inside its neighbour.
const EXTRA_APART: float = 220.0

static func extra_clear_seam() -> float:
	return STEP_FROM - EXTRA_SEAM_MARGIN

## 1-1's own enemies that fall inside the circuit. VersusLevelBuilder frees
## everything at or past STEP_FROM, so these are the ones actually in play --
## and the ones the extras are measured against.
static func circuit_enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in Stage.enemies():
		if Vector2(e.get("pos", Vector2.ZERO)).x < STEP_FROM:
			out.append(e)
	return out

## 1-1 seats a walker with its feet on the ledge -- WALKER_SIZE.y * 0.5 above
## the surface. The same rule here, so the new ones stand the way the old ones
## do.
const WALKER_FEET: float = 21.0
## A flyer bobs on a sine around its origin, so it is hung a body's height above
## the floor rather than resting on it.
const FLYER_HEIGHT: float = 150.0

static func extra_enemies() -> Array[Dictionary]:
	var world := ArenaStage.new(lap_ground())
	var thin := _thin_buckets()
	var taken: Array[float] = []
	for e in circuit_enemies():
		taken.append(Vector2(e.get("pos", Vector2.ZERO)).x)
	var out: Array[Dictionary] = []
	var made := 0
	for entry in thin:
		var bucket: int = entry["bucket"]
		var want: int = entry["want"]
		for k in range(want):
			if made >= EXTRA_MAX:
				return out
			var x := float(bucket) * EXTRA_BUCKET \
				+ EXTRA_BUCKET * (float(k) + 1.0) / (float(want) + 1.0)
			var spec := _seat(world, x, made, taken)
			if spec.is_empty():
				continue
			out.append(spec)
			taken.append(Vector2(spec["pos"]).x)
			made += 1
	return out

## The buckets 1-1 left emptiest, emptiest first. Ties keep their order along
## the lap, so the result is the same on every machine -- which matters, because
## nothing about these enemies goes over the wire.
static func _thin_buckets() -> Array[Dictionary]:
	var counts: Dictionary = {}
	var last := int(extra_clear_seam() / EXTRA_BUCKET)
	for b in range(0, last + 1):
		counts[b] = 0
	for e in circuit_enemies():
		var at: Vector2 = e.get("pos", Vector2.ZERO)
		var b := int(floor(at.x / EXTRA_BUCKET))
		if counts.has(b):
			counts[b] = int(counts[b]) + 1
	var out: Array[Dictionary] = []
	for b in counts.keys():
		var want := EXTRA_PER_BUCKET - int(counts[b])
		if want > 0:
			out.append({"bucket": b, "want": want, "had": int(counts[b])})
	out.sort_custom(func(a, c):
		if int(a["had"]) != int(c["had"]):
			return int(a["had"]) < int(c["had"])
		return int(a["bucket"]) < int(c["bucket"]))
	return out

## One enemy near an x, standing on whatever is under it.
##
## A walker placed over one of 1-1's gaps falls to the kill plane before anybody
## sees it, and a flyer hung over one has no height to be hung relative to -- so
## the ideal spot is only a starting point, and the search steps outwards from
## it until it finds floor that nothing is standing on yet. Returns nothing when
## the whole window is gap or is already occupied.
static func _seat(world: ArenaStage, x: float, index: int,
		taken: Array[float]) -> Dictionary:
	var found := _floor_near(world, x, taken)
	if found == Vector2.INF:
		return {}
	x = found.x
	var top := found.y
	# Three in rotation, so the additions are not a row of identical mushrooms:
	# the plain walker, the spiky one from the 1-1 set, and a flyer.
	match index % 3:
		0:
			return {"type": "walker", "pos": Vector2(x, top - WALKER_FEET),
				"patrol": 200.0}
		1:
			return {"type": "flyer", "pos": Vector2(x, top - FLYER_HEIGHT),
				"patrol": 200.0}
		_:
			return {"type": "walker", "pos": Vector2(x, top - WALKER_FEET),
				"patrol": 240.0, "skin": "walker_spiky"}

## The nearest x to `want` with floor under it and elbow room, as (x, floor y).
## Offsets are tried nearest-first and the ideal spot first of all, so a bucket
## with clear ground in it still gets its enemy exactly where it was measured.
static func _floor_near(world: ArenaStage, want: float,
		taken: Array[float]) -> Vector2:
	var steps := int(EXTRA_NUDGE / EXTRA_NUDGE_STEP)
	for i in range(steps * 2 + 1):
		# 0, +1, -1, +2, -2 ... so the ideal spot is tried first and the rest
		# work outwards from it, alternating sides.
		var reach := float((i + 1) >> 1) * EXTRA_NUDGE_STEP
		var x := want + (reach if i % 2 == 1 else -reach)
		if x < EXTRA_CLEAR_START or x > extra_clear_seam():
			continue
		var crowded := false
		for other in taken:
			if absf(other - x) < EXTRA_APART:
				crowded = true
				break
		if crowded:
			continue
		var top := world.floor_below(Vector2(x, -400.0), 1600.0)
		if top == INF:
			continue
		return Vector2(x, top)
	return Vector2.INF

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
	one.append_array(solid_decor())
	var out: Array[Rect2] = []
	for lap in [-1, 0, 1]:
		var shift := VersusStageData.LOOP_SPAN * float(lap)
		for r in one:
			out.append(Rect2(r.position + Vector2(shift, 0.0), r.size))
	out.append_array(constructs)
	return out
