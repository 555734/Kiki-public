class_name LevelCastleData
extends RefCounted
## Stage 1-9 "The King's Road": the road up to the king's castle, built to be
## filmed as much as played.
##
## Seven obstacles in three places, each one the runner cannot get past alone
## and the guardian's hand can open:
##
##   the gorge
##     A  the broken bridge   a gorge no jump clears          draw the way
##     C  the cannon          firing down the road and over   send a ball home
##     B  the swarm           a wall of bats past any jump    sweep them away
##   the gatehouse
##     D  the guardhouse      a boulder sweeping its passage  press it still
##     E  the portcullis      shut, and the hound behind      hold it up, drop it
##   the keep
##     G  the keep wall       sheer, far past any jump        the slingshot
##     H  the stone guardian  standing in the way             flick it off
##
## Laid out for a wide, still camera: everything is in the open air, under
## the sky -- the only roof is the guardhouse's, a building and not a hill --
## and each place holds its obstacles close enough together that one frame
## takes in the setup, the act and the result.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(100, 320)
## The keep's top, where the last place is.
const KEEP_TOP := -70.0
## The gorge the broken bridge crossed (x from, x to).
const CHASM := Vector2(700, 1450)
## The cannon, on the road beyond the gorge, firing back over it.
const CANNON_X := 1950.0
## The swarm: a column of bats from the road to past any jump.
const SWARM_X := 2650.0
## The guardhouse's covered passage, the boulder sweeping it.
const GUARDHOUSE := Vector2(3200, 3760)
## The gatehouse's portcullis.
const GATE_X := 4150.0
## The keep wall's face, and where its top ends.
const KEEP_X := 4900.0
const KEEP_END := 6800.0
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
		{"name": "A - broken bridge", "focus": 1075.0, "from": -600.0, "to": 1450.0, "teaches": "platform"},
		{"name": "C - cannon", "focus": CANNON_X, "from": 1450.0, "to": 2300.0, "teaches": "catch"},
		{"name": "B - swarm", "focus": SWARM_X, "from": 2300.0, "to": 3000.0, "teaches": "swipe"},
		{"name": "D - guardhouse", "focus": (GUARDHOUSE.x + GUARDHOUSE.y) * 0.5, "from": 3000.0, "to": 3900.0, "teaches": "hold"},
		{"name": "E - gatehouse", "focus": GATE_X, "from": 3900.0, "to": 4500.0, "teaches": "gate"},
		{"name": "G - keep wall", "focus": KEEP_X - 200.0, "from": 4500.0, "to": KEEP_X, "teaches": "sling"},
		{"name": "H - stone guardian", "focus": KEEP_X + 700.0, "from": KEEP_X, "to": KEEP_END, "teaches": "flick"},
	]

## Solid ground: Rect2(x, top_y, width, height). A ceiling is ground too: a
## mass hung over the road with nothing under it.
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		[-600.0, CHASM.x, GROUND_TOP],       # the road up to the gorge
		[CHASM.y, KEEP_X, GROUND_TOP],       # the cannon, the swarm, the gatehouse
		[KEEP_X, KEEP_END, KEEP_TOP],        # the keep wall and its top
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	for mass in masses():
		g.append(mass)
	return g

## The guardhouse over its passage, which CastleSet builds as a building. Its
## bottom is the passage's ceiling: too low to jump the boulder under it, and
## the building goes up far past anyone's reach.
static func masses() -> Array[Rect2]:
	return [Rect2(GUARDHOUSE.x, -1400.0, GUARDHOUSE.y - GUARDHOUSE.x, 1400.0 + 160.0)]

static func solid_decor() -> Array[Rect2]:
	return []

static func hazards() -> Array[Dictionary]:
	return [
		# Spikes far down in the gorge.
		{"pos": Vector2((CHASM.x + CHASM.y) * 0.5, 860), "size": Vector2(CHASM.y - CHASM.x, 46)},
	]

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# First, so every other enemy's net id stays put. The castle hound:
		# asleep until the runner is through the guardhouse, then on their
		# heels -- and shut out for good by the portcullis, if it is dropped
		# on it.
		{"type": "sky_pursuer", "pos": Vector2(-1500, 335), "activation": GUARDHOUSE.y + 1500.0 + 40.0,
			"delay": 0.6, "speed": 300.0, "catchup": 520.0, "stun": 1.5},
		# C: the cannon, firing back down the road and over the gorge.
		{"type": "turret", "pos": Vector2(CANNON_X, GROUND_TOP - 47.0), "aim": Vector2.LEFT, "burst": 3,
			"scale": 1.8},
		# H: the stone guardian, standing in the way of the castle door.
		{"type": "golem", "pos": Vector2(KEEP_X + 700.0, KEEP_TOP - GOLEM_SCALE * 35.0), "patrol": 40.0,
			"period": 6.0, "scale": GOLEM_SCALE},
	]
	# B: the swarm, a loose column from the road to above the best jump: there
	# is no going over it and no going through it.
	for k in 8:
		out.append({"type": "cave_enemy", "kind": "bat",
			"pos": Vector2(SWARM_X + (22.0 if k % 2 == 0 else -22.0) + 6.0 * sin(float(k) * 2.3),
				GROUND_TOP - 36.0 - 44.0 * float(k)),
			"wander": Vector2(14, 6), "patrol": 0.0})
	return out

static func gimmicks() -> Array[Dictionary]:
	return [
		# D: one boulder sweeping the guardhouse's passage end to end.
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2((GUARDHOUSE.x + GUARDHOUSE.y) * 0.5, 361),
			"travel": 220.0, "period": 2.2},
		# E: the portcullis.
		{"type": "lift_gate", "pos": Vector2(GATE_X, GROUND_TOP), "height": 420.0},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(CHASM.y + 110.0, 346),        # over the gorge
		Vector2(GUARDHOUSE.y + 110.0, 346),   # through the guardhouse
		Vector2(GATE_X + 200.0, 346),         # through the portcullis
		Vector2(KEEP_X + 120.0, KEEP_TOP - 54.0),   # on top of the keep wall
	]

static func goal() -> Vector2:
	return Vector2(KEEP_X + 1320.0, KEEP_TOP - 95.0)

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
	return [
		{"type": "flowers", "pos": Vector2(220, GROUND_TOP)},
		{"type": "flowers", "pos": Vector2(GATE_X + 420.0, GROUND_TOP)},
		{"type": "flowers", "pos": Vector2(KEEP_X + 400.0, KEEP_TOP)},
	]

static func veils() -> Array[Dictionary]:
	return []
