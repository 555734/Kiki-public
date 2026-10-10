class_name LevelCastleData
extends RefCounted
## Stage 1-9 "The King's Road": the road up to the king's castle, built to be
## filmed as much as played -- laid out as the stage's key art paints it
## (docs/art-prompts-castle.md): one road with its traps close together, so a
## wide camera holds several at once.
##
##   the stair          red brick steps up and over
##   D  the spike block a block of spikes dropping on the road  hold it up
##   B  the spiked ball swinging across the road on its chain   hold it still
##   A  the moat        too wide for any jump                   draw the way
##   C  the cannon      firing back over the moat               send a ball home
##   E  the gatehouse   a portcullis, and the hound behind      hold it up, drop it
##   G  the keep wall   sheer, far past any jump                the slingshot
##   H  the stone guardian standing in the way                  flick it off
##
## Flat ground, sky behind everything, and no roof anywhere: nothing but the
## traps themselves in the frame.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(100, 320)
## The keep's top, where the last stretch is.
const KEEP_TOP := -70.0
## The red brick stair at the start: (x, height) of each step, 56 wide.
const STEP_W := 56.0
const STAIR_X := 520.0
## The spike block, hung over the road.
const SPIKE_X := 860.0
## The spiked ball's pivot, and how long its chain is.
const BALL_PIVOT := Vector2(1150, -110)
const BALL_CHAIN := 465.0
## The moat (x from, x to).
const CHASM := Vector2(1450, 2090)
## The cannon, on the far bank, firing back over the moat.
const CANNON_X := 2420.0
## The gatehouse's portcullis, and how tall it stands.
const GATE_X := 2860.0
const GATE_HEIGHT := 250.0
## The keep wall's face, and where its top ends.
const KEEP_X := 3460.0
const KEEP_END := 5200.0
## The stone guardian is four times a golem: taller than the runner's best
## triple jump, so nobody goes over it.
const GOLEM_SCALE := 4.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE KING'S ROAD"
static func stage_number_value() -> String: return "1-9"
static func objective_value() -> String: return "Reach the castle"

static func painted_2d_value() -> bool: return true
static func pit_centre_x_value() -> float: return (CHASM.x + CHASM.y) * 0.5

## Where each obstacle is, for the probes, the review tools and the trailer.
static func sections() -> Array[Dictionary]:
	return [
		{"name": "D - spike block", "focus": SPIKE_X, "from": -600.0, "to": 1000.0, "teaches": "hold"},
		{"name": "B - spiked ball", "focus": BALL_PIVOT.x, "from": 1000.0, "to": CHASM.x, "teaches": "hold"},
		{"name": "A - moat", "focus": (CHASM.x + CHASM.y) * 0.5, "from": CHASM.x, "to": CHASM.y, "teaches": "platform"},
		{"name": "C - cannon", "focus": CANNON_X, "from": CHASM.y, "to": 2650.0, "teaches": "catch"},
		{"name": "E - gatehouse", "focus": GATE_X, "from": 2650.0, "to": 3100.0, "teaches": "gate"},
		{"name": "G - keep wall", "focus": KEEP_X - 200.0, "from": 3100.0, "to": KEEP_X, "teaches": "sling"},
		{"name": "H - stone guardian", "focus": KEEP_X + 650.0, "from": KEEP_X, "to": KEEP_END, "teaches": "flick"},
	]

## Solid ground: Rect2(x, top_y, width, height).
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		[-600.0, CHASM.x, GROUND_TOP],       # the road to the moat
		[CHASM.y, KEEP_X, GROUND_TOP],       # the cannon, the gatehouse, the wall's foot
		[KEEP_X, KEEP_END, KEEP_TOP],        # the keep wall and its top
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	for step in stair():
		g.append(step)
	return g

## The red brick stair: three steps up, then a drop back to the road.
static func stair() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in 3:
		var h := STEP_W * float(k + 1)
		out.append(Rect2(STAIR_X + STEP_W * float(k), GROUND_TOP - h, STEP_W, h))
	return out

## Kept for CastleSet and the probe: 1-9 has no covered stretch any more.
static func masses() -> Array[Rect2]:
	return []

static func solid_decor() -> Array[Rect2]:
	return []

static func hazards() -> Array[Dictionary]:
	return []

static func enemies() -> Array[Dictionary]:
	return [
		# First, so every other enemy's net id stays put. The castle hound:
		# asleep until the runner is over the moat, then on their heels -- and
		# shut out for good by the portcullis, if it is dropped on it.
		{"type": "sky_pursuer", "pos": Vector2(-1500, 335), "activation": CHASM.y + 1500.0 + 260.0,
			"delay": 0.6, "speed": 300.0, "catchup": 520.0, "stun": 1.5},
		# C: the cannon, firing back over the moat.
		{"type": "turret", "pos": Vector2(CANNON_X, GROUND_TOP - 47.0), "aim": Vector2.LEFT, "burst": 3,
			"scale": 1.8},
		# H: the stone guardian, standing in the way of the castle door.
		{"type": "golem", "pos": Vector2(KEEP_X + 650.0, KEEP_TOP - GOLEM_SCALE * 35.0), "patrol": 40.0,
			"period": 6.0, "scale": GOLEM_SCALE},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# D: the spike block, dropping onto the road and back up.
		{"type": "tower_trap", "kind": "piston", "pos": Vector2(SPIKE_X, 150.0), "travel": 200.0,
			"period": 2.6, "holdable": true},
		# B: the spiked ball, swinging across the road.
		{"type": "tower_trap", "kind": "pendulum", "pos": BALL_PIVOT, "length": BALL_CHAIN,
			"period": 2.4, "holdable": true},
		# E: the portcullis.
		{"type": "lift_gate", "pos": Vector2(GATE_X, GROUND_TOP), "height": GATE_HEIGHT},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(CHASM.y + 110.0, 346),        # over the moat
		Vector2(GATE_X + 200.0, 346),         # through the portcullis
		Vector2(KEEP_X + 120.0, KEEP_TOP - 54.0),   # on top of the keep wall
	]

static func goal() -> Vector2:
	return Vector2(KEEP_X + 1300.0, KEEP_TOP - 95.0)

static func crystals() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

## Breadcrumbs only where the way is not plain: up the keep wall, along the
## slingshot's line.
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in 5:
		out.append(Vector2(KEEP_X - 70.0 + 14.0 * float(k), GROUND_TOP - 120.0 - 90.0 * float(k)))
	return out

static func decor() -> Array[Dictionary]:
	return []

static func veils() -> Array[Dictionary]:
	return []
