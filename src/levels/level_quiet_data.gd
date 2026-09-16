extends RefCounted
## Stage 1-V "THE QUIET" -- the asymmetric-information prototype.
##
## Four short beats, each isolating one kind of asymmetry, because building only
## one of them would say whether THAT one was fun and nothing about the others:
##
##   1  the ground is hidden          static, safe, with landmarks to name
##   2  the things moving are hidden  dynamic, on ground the runner can see
##   3  the sigils are hidden BOTH WAYS   the runner reads the switches, the
##                                        guardian reads what the gate wants
##   4  hidden ground under a closing gate   both at once, and a real fall
##
## Two rules run through the geometry. The runner can always see the DANGER and
## never the SOLUTION -- the pit floor and the spikes are drawn, the platform
## over them is not -- so nobody is ever ambushed by a hole they had no way to
## know about. And failure costs seconds, not progress: beat 1 drops onto a
## ledge rather than killing, and the checkpoint sits PAST the gate so a fall in
## beat 4 never makes the pair solve the sigils a second time.
##
## Online only. On one shared screen both players see everything and the whole
## stage is a walk; NetPanel refuses to select it offline.

const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(-900, 340)
const STAGE_NAME := "THE QUIET"
const STAGE_NUMBER := "1-V"
const OBJECTIVE := "Talk each other through"

## The two floor heights. FLOOR is the near side of the first gap; MID is
## everything after it, and it is deliberately HIGHER than the rescue ledge can
## reach -- see ground().
const FLOOR := 420.0
const MID := 340.0
## The rescue ledge under the first gap.
const LEDGE := 560.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

static func solid_decor() -> Array[Rect2]:
	return []

## Every measurement here is checked against what the runner can actually do,
## which ground_movement_probe and stage_probe measure rather than assume:
## a sprint jump carries 301px across and 193px up, a standing jump 162px up.
##
##   start(420) -> hidden platform(330)   180 across,  90 up    inside a jump
##   platform(330) -> far floor(340)      180 across,  10 down  a walk-off
##   start(600,420) -> far(1100,340)      500 across           impossible alone
##   ledge(560) -> start floor(420)       140 up                the way back
##   ledge(560) -> far floor(340)         220 up                NOT climbable
##
## That last line is what makes beat 1 a real obstacle. Falling in must not be
## a slower route across; 220px is past the 193px sprint jump with enough margin
## that neither a wall kick off the far face (which pushes the wrong way) nor a
## ledge catch (whose hands cannot reach that high) turns it into one.
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		# ---- 0 and 1: the run-up, and the step that is not drawn ----------
		[-1000.0, 600.0, FLOOR],
		[600.0, 1100.0, LEDGE],      # the rescue ledge. VISIBLE: the danger is
		                             # never the secret, only the answer is.
		[780.0, 920.0, 330.0],       # HIDDEN. Flanked by the two signposts.

		# ---- 2 and 3: open ground, then the gate --------------------------
		[1100.0, 2700.0, MID],

		# ---- 4: the same trick, with no landmarks and a real fall ---------
		[2880.0, 2980.0, 260.0],     # HIDDEN
		[3120.0, 3500.0, MID],
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## What one player cannot see.
##
## The rects are generous in y and tight in x, because Veil.holds_surface asks
## whether BOTH top corners of a slab are inside -- a floor that merely passes
## through keeps a corner outside and stays drawn, and only a slab placed
## entirely within the region disappears.
static func veils() -> Array[Dictionary]:
	return [
		# Above the rescue ledge (560) and below nothing: the ledge stays drawn,
		# the platform at 330 does not.
		{"rect": Rect2(600.0, 200.0, 500.0, 320.0),
		 "hides": ["terrain", "marks"], "from": "runner",
		 "name": "the first step"},
		# The ground here is the runner's to see. Only what moves on it is not.
		{"rect": Rect2(1150.0, -160.0, 1050.0, 760.0),
		 "hides": ["enemies", "marks"], "from": "runner",
		 "name": "the moving dark"},
		{"rect": Rect2(2700.0, 120.0, 420.0, 300.0),
		 "hides": ["terrain", "marks"], "from": "runner",
		 "name": "the last step"},
	]

## Spikes at the bottom of the last gap. Drawn, and drawn on purpose: the runner
## is meant to know exactly how much the last jump costs.
static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(2910.0, 700.0), "size": Vector2(400.0, 46.0)},
	]

## Two walkers on ground the runner can see perfectly well. A walker is 44x42
## and a standing jump clears 162px, so getting over one is easy -- the only
## hard part is knowing when, and knowing when is the guardian's, and it stops
## being true a second later. That is the whole beat.
static func enemies() -> Array[Dictionary]:
	return [
		{"type": "walker", "pos": Vector2(1500.0, MID - 21.0), "patrol": 180.0},
		{"type": "walker", "pos": Vector2(1900.0, MID - 21.0), "patrol": 150.0},
	]

## The gate neither player can open alone: the runner can read the sigils on the
## switches and not what the gate is asking for; the guardian can read what the
## gate is asking for and not the sigils. Shooting the wrong one costs four
## seconds of silence and nothing else.
static func gimmicks() -> Array[Dictionary]:
	return [
		{"type": "switch", "id": "quiet_gate", "pos": Vector2(2280.0, 250.0),
		 "sigil": 3, "hold": 6.0},
		{"type": "switch", "id": "quiet_gate", "pos": Vector2(2380.0, 200.0),
		 "sigil": 1, "hold": 6.0},
		{"type": "switch", "id": "quiet_gate", "pos": Vector2(2470.0, 140.0),
		 "sigil": 2, "hold": 6.0},
		{"type": "gate", "id": "quiet_gate", "pos": Vector2(2500.0, MID - 95.0),
		 "span": Vector2(40.0, 190.0), "wants": 2},
	]

## Two signposts either side of the first hidden platform, and nothing at all
## beside the last one.
##
## This is scaffolding and it is meant to be obvious. The pair cannot say "47px
## right", so the first time they need to say WHERE, the answer is standing
## there to be named -- and having invented "between the posts" once, they
## extend it themselves when beat 4 gives them nothing.
static func decor() -> Array[Dictionary]:
	return [
		{"type": "signpost", "pos": Vector2(-700.0, FLOOR)},
		{"type": "tree", "pos": Vector2(-300.0, FLOOR)},
		{"type": "flowers", "pos": Vector2(200.0, FLOOR)},
		{"type": "signpost", "pos": Vector2(780.0, LEDGE)},
		{"type": "signpost", "pos": Vector2(920.0, LEDGE), "flip": true},
		{"type": "tree", "pos": Vector2(1300.0, MID)},
		{"type": "flowers", "pos": Vector2(2050.0, MID)},
		{"type": "signpost", "pos": Vector2(2640.0, MID)},
		{"type": "tree", "pos": Vector2(3300.0, MID)},
	]

## Before the first gap, after it, and PAST the gate. The last one is the
## important one: a fall in beat 4 must not put the sigils back in front of a
## pair who already know the answer.
static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(500.0, FLOOR - 40.0),
		Vector2(1150.0, MID - 40.0),
		Vector2(2520.0, MID - 40.0),
	]

static func goal() -> Vector2:
	return Vector2(3350.0, MID - 55.0)

static func coins() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

static func crystals() -> Array[Vector2]:
	return []
