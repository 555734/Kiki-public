class_name ArenaStageData
## The one grey box the coin battle is played in (docs/coin-battle-plan.md 6.1).
##
## Left-right symmetric on purpose: the mode is a competition, and a map that
## favours a side turns "who played better" into "who spawned better". Y is
## positive downwards and every figure below is the TOP of a surface.
##
## The long cooperative stages are not reused. They are built around one runner
## travelling right for three minutes; this needs four fighters to see each
## other for the whole match.
##
## Three point lists, deliberately separate. The plan calls this out (6.1): a
## coin spawn, a respawn and a recycle point are different questions -- what is
## fair to contest, what is safe to appear on, what is central enough to bring
## the match back together -- and collapsing them into one list is how a coin
## ends up appearing on top of somebody who just died.

## Floors. Static, solid, axis-aligned. No one-way platforms, no slopes, no
## breakable floors, no gimmicks in the minimum version.
static func floors() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# The main floor.
	out.append(Rect2(-360.0, 120.0, 720.0, 32.0))
	# Two mid shelves.
	out.append(Rect2(-290.0, 0.0, 180.0, 20.0))
	out.append(Rect2(110.0, 0.0, 180.0, 20.0))
	# The top shelf.
	out.append(Rect2(-80.0, -110.0, 160.0, 20.0))
	# The ceiling. There is no upward blast-out in the minimum version, so this
	# is a real surface rather than a boundary.
	out.append(Rect2(-480.0, -380.0, 960.0, 20.0))
	return out

## Past these, a fighter is out. Left, right and down only.
const BLAST_LEFT: float = -480.0
const BLAST_RIGHT: float = 480.0
const BLAST_BOTTOM: float = 240.0

## Surface tops, from the table above.
const MAIN_FLOOR_TOP: float = 120.0
const MID_SHELF_TOP: float = 0.0
const TOP_SHELF_TOP: float = -110.0

## A body standing ON a surface, given that surface's top.
##
## The plan's 6.1 table is written as "位置は床の上面" -- every number in it is
## the top of a surface, not the middle of a fighter. Using those numbers
## directly as positions buries every fighter and every respawn point half a
## body deep in the floor, which the rules probe caught as "nobody can ever
## respawn": each candidate overlapped terrain and was rejected.
static func standing_on(top: float) -> float:
	return top - ArenaRules.BODY_SIZE.y * 0.5

## Where the four start. A and B open on opposite sides of the main floor, and
## team-mates stand clear of each other (6.1).
static func start_positions() -> Array[Vector2]:
	var y := standing_on(MAIN_FLOOR_TOP)
	return [
		Vector2(-260.0, y), Vector2(-160.0, y),   # team A
		Vector2(160.0, y), Vector2(260.0, y),     # team B
	]

## Where new coins enter, in the order the schedule asks for them (3.2).
## One at the middle, then symmetric pairs, then the shelves, then middle plus
## top -- so the last two still pull a leading team back towards the centre.
static func coin_spawn_points() -> Array[Vector2]:
	return [
		Vector2(0.0, 90.0),
		Vector2(-240.0, 90.0), Vector2(240.0, 90.0),
		Vector2(-200.0, -30.0), Vector2(200.0, -30.0),
		Vector2(0.0, 90.0), Vector2(0.0, -140.0),
	]

## Candidates for coming back after a blast-out. At least eight, all of them on
## a floor with headroom and a normal jump back to the main floor (5).
static func respawn_points() -> Array[Vector2]:
	var main := standing_on(MAIN_FLOOR_TOP)
	var mid := standing_on(MID_SHELF_TOP)
	return [
		Vector2(-300.0, main), Vector2(-200.0, main),
		Vector2(-80.0, main), Vector2(80.0, main),
		Vector2(200.0, main), Vector2(300.0, main),
		Vector2(-200.0, mid), Vector2(200.0, mid),
	]

## Where a coin nobody could take goes back into play. Biased towards the
## middle, because the point of recycling is to restart a contest (3.4).
static func recycle_points() -> Array[Vector2]:
	return [
		Vector2(0.0, 90.0),
		Vector2(-120.0, 90.0), Vector2(120.0, 90.0),
		Vector2(0.0, -140.0),
		Vector2(-200.0, -30.0), Vector2(200.0, -30.0),
	]

## True while a point is inside the arena rather than past a blast line.
static func in_bounds(at: Vector2) -> bool:
	return at.x > BLAST_LEFT and at.x < BLAST_RIGHT and at.y < BLAST_BOTTOM
