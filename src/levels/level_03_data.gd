class_name Level03Data
extends RefCounted
## Stage 1-T "THE WORKSHOP" -- not a level, a measuring room.
##
## Nothing here is meant to be fun and nothing here is meant to be fair. It is
## every shape that makes a movement system feel wrong, laid out in a line with
## flat ground between them so each one can be walked into on purpose and
## measured on its own.
##
## The reason it exists is a failure mode, not a wish. Every number in
## balance.gd was tuned on open ground and measured on open ground, and open
## ground is the one place a platformer cannot go wrong. A runner who feels
## perfect on a plateau and catches on the seam between two slabs is a runner
## nobody trusts, and no amount of checking the jump arc would ever have said
## so -- because the arc was fine.
##
## In order along the stage:
##
##   1  a seam                two slabs meeting flush, at the same height
##   2  a step up             one block, walked into rather than jumped
##   3  a step down           the same, going the other way
##   4  a narrow perch        one block wide, with the stopping distance to
##                            match: can you land on it and stay
##   5  a low ceiling         a jump's height above the floor, so a full jump
##                            is refused by it rather than clearing it
##   6  a corridor            low ceiling AND a seam, which is where a runner
##                            who survives both separately still snags
##   7  an outside corner     the lip a jump is taken from
##   8  an inside corner      floor meeting wall, where a run ends
##   9  a moving floor        carried sideways while standing and while jumping
##  10  a measuring straight  long, flat and empty: the arcs are measured here
##
## Every landmark is a named constant so the tests can ask about a shape by
## name rather than by a coordinate that drifts the next time the layout moves.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1100.0
const STAGE_NAME := "THE WORKSHOP"
const STAGE_NUMBER := "1-T"
const OBJECTIVE := "Measure everything"

## The floor everything is measured from, and the block the shapes are built in.
const FLOOR := 420.0
const BLOCK := Balance.B

const START := Vector2(-900, FLOOR - 60.0)

# ------------------------------------------------------------------- landmarks

## Where each shape is, so a test can say "the seam" instead of "1200".
const SEAM_X := 600.0
const STEP_UP_X := 1400.0
const STEP_DOWN_X := 2200.0
const PERCH_X := 3000.0
const LOW_CEILING_X := 3900.0
const CORRIDOR_X := 4800.0
const OUTSIDE_CORNER_X := 5700.0
const INSIDE_CORNER_X := 6400.0
const MOVING_FLOOR_X := 7200.0
const STRAIGHT_X := 8200.0
const STRAIGHT_END_X := 11000.0

## How high the low ceiling sits above the floor it is over.
##
## Deliberately just under a full jump. A ceiling a runner cannot reach teaches
## nothing; one they hit every time is the case worth looking at.
const CEILING_GAP := 120.0

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# The low ceilings are the only overhead terrain in the game, and they go in
	# as solid decor because that is the layer terrain lives on.
	out.append(Rect2(LOW_CEILING_X - 150.0, FLOOR - CEILING_GAP - 40.0, 300.0, 40.0))
	out.append(Rect2(CORRIDOR_X - 250.0, FLOOR - CEILING_GAP - 40.0, 500.0, 40.0))
	return out

## Solid ground. Flat and continuous except where a shape needs it not to be,
## so that walking into a shape is the only thing being measured.
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		# ---- 1: a seam. Two slabs meeting flush, no gap and no step ---------
		# The one shape that looks like nothing on a screenshot and stops a
		# runner dead if the collision shapes disagree by a pixel.
		[-1200.0, SEAM_X, FLOOR],
		[SEAM_X, 1000.0, FLOOR],

		# ---- 2: a step up, one block ---------------------------------------
		[1000.0, STEP_UP_X, FLOOR],
		[STEP_UP_X, 1800.0, FLOOR - BLOCK],

		# ---- 3: and a step down, the same size -----------------------------
		[1800.0, STEP_DOWN_X, FLOOR - BLOCK],
		[STEP_DOWN_X, 2600.0, FLOOR],

		# ---- 4: a perch one block wide, a jump's height up -----------------
		# Landing on it is one question; stopping on it is the other, and the
		# stopping distance is a dial.
		[2600.0, PERCH_X - 300.0, FLOOR],
		[PERCH_X, PERCH_X + BLOCK, FLOOR - 2.0 * BLOCK],
		[PERCH_X + 300.0, 3500.0, FLOOR],

		# ---- 5: under a low ceiling ----------------------------------------
		[3500.0, 4300.0, FLOOR],

		# ---- 6: a corridor -- low ceiling and a seam together --------------
		[4300.0, CORRIDOR_X, FLOOR],
		[CORRIDOR_X, 5300.0, FLOOR],

		# ---- 7: an outside corner: the lip a jump leaves from --------------
		[5300.0, OUTSIDE_CORNER_X, FLOOR],
		[OUTSIDE_CORNER_X + 260.0, 6000.0, FLOOR],

		# ---- 8: an inside corner: floor into wall --------------------------
		[6000.0, INSIDE_CORNER_X, FLOOR],
		[INSIDE_CORNER_X, INSIDE_CORNER_X + 40.0, FLOOR - 4.0 * BLOCK],
		[INSIDE_CORNER_X + 40.0, 6900.0, FLOOR],

		# ---- 9: a moving floor, with ground either side --------------------
		[6900.0, MOVING_FLOOR_X - 200.0, FLOOR],
		[MOVING_FLOOR_X + 500.0, 7900.0, FLOOR],

		# ---- 10: the measuring straight ------------------------------------
		# Long, flat, empty. Every arc in the suite is measured somewhere like
		# this, and having it here means the measurement and the awkward shapes
		# live in the same stage rather than in two different ones.
		[7900.0, STRAIGHT_END_X + 600.0, FLOOR],
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## None. A measuring room that can kill you is a measuring room you stop using.
static func hazards() -> Array[Dictionary]:
	return []

static func enemies() -> Array[Dictionary]:
	return []

static func gimmicks() -> Array[Dictionary]:
	return [
		# The moving floor, across the one gap in the stage. Standing on it and
		# jumping off it are different questions and both get asked here.
		{"type": "moving_platform", "pos": Vector2(MOVING_FLOOR_X, FLOOR - 10.0),
			"span": Vector2(180.0, 26.0), "travel": Vector2(500.0, 0.0)},
	]

static func checkpoints() -> Array[Vector2]:
	return []

static func goal() -> Vector2:
	return Vector2(STRAIGHT_END_X + 400.0, FLOOR - 55.0)

static func crystals() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

static func coins() -> Array[Vector2]:
	return []

## A signpost at every shape, so a person walking through knows what they are
## looking at and in what order.
static func decor() -> Array[Dictionary]:
	return [
		{"type": "signpost", "pos": Vector2(-800, FLOOR)},
		{"type": "signpost", "pos": Vector2(SEAM_X - 120.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(STEP_UP_X - 150.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(STEP_DOWN_X - 150.0, FLOOR - BLOCK)},
		{"type": "signpost", "pos": Vector2(PERCH_X - 420.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(LOW_CEILING_X - 260.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(CORRIDOR_X - 380.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(OUTSIDE_CORNER_X - 200.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(INSIDE_CORNER_X - 200.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(MOVING_FLOOR_X - 320.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(STRAIGHT_X - 120.0, FLOOR)},
	]

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
