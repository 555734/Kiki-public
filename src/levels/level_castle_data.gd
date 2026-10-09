class_name LevelCastleData
extends RefCounted
## Stage 1-9 "The King's Road": the road up to the king's castle, built to be
## filmed as much as played.
##
## Eight obstacles in a row, one to a screen, each one the runner cannot get
## past alone and the guardian's hand can open:
##
##   A  the broken bridge     a chasm no jump clears        draw the way
##   B  the bat tunnel        a low tunnel full of bats     sweep them away
##   C  the cannon            fire down the road            send a ball home
##   D  the boulder tunnel    a boulder sweeping it         press it still
##   E  the gatehouse         a shut portcullis, a hound    hold it up, drop it
##   F  the dungeon           no light                      the finger is the lamp
##   G  the keep wall         sheer, far past any jump      the slingshot
##   H  the stone guardian    standing in the way           flick it off the road
##
## Everything is wide and flat and lit, and every obstacle sits in the middle
## of its own screen with room to see it coming: readable at a glance is the
## brief for both the player and the camera.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(100, 320)
## The keep's top, where the last two screens are.
const KEEP_TOP := -70.0
## Where each covered stretch starts and ends (x from, x to).
const TUNNEL_B := Vector2(1900, 2700)
const TUNNEL_D := Vector2(3960, 4660)
const DUNGEON := Vector2(5700, 6820)
## The chasm the first screen is about.
const CHASM := Vector2(700, 1450)
## The keep wall's face.
const KEEP_X := 7400.0
## The gatehouse's portcullis.
const GATE_X := 5150.0
## The stone guardian is four times a golem: taller than the runner's best
## triple jump, so nobody goes over it.
const GOLEM_SCALE := 4.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE KING'S ROAD"
static func stage_number_value() -> String: return "1-9"
static func objective_value() -> String: return "Reach the castle"

static func painted_2d_value() -> bool: return true
static func pit_centre_x_value() -> float: return 4300.0

## Where each obstacle is, for the probes, the review tools and the trailer.
static func sections() -> Array[Dictionary]:
	return [
		{"name": "A - broken bridge", "focus": 900.0, "from": -600.0, "to": 1450.0, "teaches": "platform"},
		{"name": "B - bat tunnel", "focus": 2300.0, "from": 1450.0, "to": 2950.0, "teaches": "swipe"},
		{"name": "C - cannon", "focus": 3500.0, "from": 2950.0, "to": 3900.0, "teaches": "catch"},
		{"name": "D - boulder tunnel", "focus": 4310.0, "from": 3900.0, "to": 4750.0, "teaches": "hold"},
		{"name": "E - gatehouse", "focus": 5150.0, "from": 4750.0, "to": 5650.0, "teaches": "gate"},
		{"name": "F - dungeon", "focus": 6250.0, "from": 5650.0, "to": 6950.0, "teaches": "light"},
		{"name": "G - keep wall", "focus": 7200.0, "from": 6950.0, "to": 7400.0, "teaches": "sling"},
		{"name": "H - stone guardian", "focus": 8200.0, "from": 7400.0, "to": 9300.0, "teaches": "flick"},
	]

## Solid ground: Rect2(x, top_y, width, height). Ceilings are ground too: a
## slab hung in the air with nothing under it.
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		[-600.0, 700.0, GROUND_TOP],        # A: the road up to the broken bridge
		[1450.0, 3900.0, GROUND_TOP],       # B, C: tunnel and cannon road
		[3900.0, 5950.0, GROUND_TOP],       # D, E, and into the dungeon
		[6100.0, 6300.0, GROUND_TOP],       # F: stepping stones over the pits
		[6460.0, 6640.0, GROUND_TOP],
		[6800.0, 7400.0, GROUND_TOP],       # G: the foot of the keep wall
		[7400.0, 9300.0, KEEP_TOP],         # G, H: the wall itself and its top
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	# The rock and masonry the tunnels and the dungeon are cut through: each
	# runs from its ceiling far up off the top of the screen, so it reads as a
	# tunnel mouth and not as a ledge -- and cannot be climbed over.
	for mass in masses():
		g.append(mass)
	return g

## The tunnels' and the dungeon's overhead masses, which CastleSet dresses.
## Their bottoms are the ceilings: low enough that nothing under them can be
## jumped over, which is what makes them obstacles rather than scenery.
static func masses() -> Array[Rect2]:
	return [
		Rect2(TUNNEL_B.x, -1400.0, TUNNEL_B.y - TUNNEL_B.x, 1400.0 + 270.0),
		Rect2(TUNNEL_D.x, -1400.0, TUNNEL_D.y - TUNNEL_D.x, 1400.0 + 160.0),
		Rect2(DUNGEON.x, -1400.0, DUNGEON.y - DUNGEON.x, 1400.0 + 160.0),
	]

static func solid_decor() -> Array[Rect2]:
	return []

static func hazards() -> Array[Dictionary]:
	return [
		# Spikes at the bottom of the chasm, so the drop reads from the road.
		{"pos": Vector2(1075, 860), "size": Vector2(750, 46)},
		# The dungeon's pits, only seen when the light is on them.
		{"pos": Vector2(6025, 600), "size": Vector2(150, 46)},
		{"pos": Vector2(6380, 600), "size": Vector2(160, 46)},
		{"pos": Vector2(6720, 600), "size": Vector2(160, 46)},
	]

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# First, so every other enemy's net id stays put. The castle hound:
		# asleep until the runner is past the boulders, then on their heels --
		# and shut out for good by the gatehouse portcullis, if it is dropped
		# on it.
		{"type": "sky_pursuer", "pos": Vector2(-1500, 335), "activation": 4400.0,
			"delay": 0.6, "speed": 300.0, "catchup": 520.0, "stun": 1.5},
		# C: the cannon at the end of the road, firing back down it.
		{"type": "turret", "pos": Vector2(3780, GROUND_TOP - 47.0), "aim": Vector2.LEFT, "burst": 3,
			"scale": 1.8},
		# H: the stone guardian, standing in the way of the castle door.
		{"type": "golem", "pos": Vector2(8000, KEEP_TOP - GOLEM_SCALE * 35.0), "patrol": 40.0,
			"period": 6.0, "scale": GOLEM_SCALE},
	]
	# B: a swarm in the tunnel, at head height, all the way through it: under
	# that ceiling there is no going over them and no ducking under them.
	for k in 7:
		out.append({"type": "cave_enemy", "kind": "bat",
			"pos": Vector2(2000.0 + 95.0 * float(k), 350.0 + (8.0 if k % 2 == 0 else -8.0)),
			"wander": Vector2(18, 8), "patrol": 0.0})
	return out

static func gimmicks() -> Array[Dictionary]:
	return [
		# D: one boulder sweeping the whole tunnel faster than anyone can run.
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(4310, 361),
			"travel": 320.0, "period": 2.2},
		# E: the gatehouse.
		{"type": "lift_gate", "pos": Vector2(GATE_X, GROUND_TOP), "height": 420.0},
		# F: the dungeon has no light but the guardian's finger.
		{"type": "darkness", "pos": Vector2(DUNGEON.x - 40.0, 90.0), "size": Vector2(DUNGEON.y - DUNGEON.x + 80.0, 640.0)},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(1560, 346),    # over the bridge
		Vector2(2850, 346),    # out of the tunnel
		Vector2(3920, 346),    # past the cannon
		Vector2(4760, 346),    # out of the boulder tunnel
		Vector2(5620, 346),    # through the gatehouse
		Vector2(6900, 346),    # out of the dungeon
		Vector2(7520, KEEP_TOP - 54.0),   # on top of the keep wall
	]

static func goal() -> Vector2:
	return Vector2(8520, KEEP_TOP - 95.0)

static func crystals() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

## Breadcrumbs that point the way: over the bridge, through each screen, up
## the wall.
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for x in [300.0, 380.0, 460.0, 1650.0, 1730.0, 3100.0, 3180.0, 3260.0,
			4850.0, 4930.0, 5400.0, 5480.0, 7600.0, 7680.0, 8300.0]:
		out.append(Vector2(x, (KEEP_TOP if x > 7400.0 else GROUND_TOP) - 70.0))
	for k in 5:
		out.append(Vector2(7330.0 + 14.0 * float(k), GROUND_TOP - 120.0 - 90.0 * float(k)))
	return out

static func decor() -> Array[Dictionary]:
	return [
		{"type": "signpost", "pos": Vector2(-60, GROUND_TOP)},
		{"type": "flowers", "pos": Vector2(220, GROUND_TOP)},
		{"type": "flowers", "pos": Vector2(4820, GROUND_TOP)},
		{"type": "signpost", "pos": Vector2(6880, GROUND_TOP)},
		{"type": "flowers", "pos": Vector2(7700, KEEP_TOP)},
	]

static func veils() -> Array[Dictionary]:
	return []
